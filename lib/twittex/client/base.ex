defmodule Twittex.Client.Base do
  @moduledoc """
  A behaviour module for implementing your own Twitter client.

  Provides convenience functions for working with Twitter's RESTful API. You can
  use `get/3` and `post/4`using a relative url pointing to the API endpoint.

  ## Example

  To create your own client, create a new module and `use Twittex.Client.Base` as follow:

      defmodule TwitterBot do
        use Twittex.Client.Base

        def search(term, options \\ []) do
          get "/search/tweets.json?" <> URI.encode_query(Keyword.merge(%{q: term}, options))
        end
      end

  This client works as a *singleton* and can be added to a supervisor tree:

      Supervisor.start_link([TwittexBot.child_spec], strategy: :one_for_one)

  And here's how you may use it:

      TwitterBot.search "#myelixirstatus", count: 3

  ## Authentication

  Twittex supports following OAuth authentication methods:

  * [application-only] authentication.
  * [owner-token] from [dev.twitter.com](https://dev.twitter.com/oauth/overview/application-owner-access-tokens).

  To request an access token with one of the method listed above. See `get_token/1`
  and `get_token/3`. Here's, a brief example for *application-only* authentication:

      iex> token = Twittex.Client.Base.get_token!
      %OAuth2.AccessToken{...}

  Under the hood, the `Twittex.Client.Base` module uses `HTTPoison.Base` and overrides the
  `request/5` method to pass the authentication headers along the request.

  [owner-token]: https://dev.twitter.com/oauth/overview/application-owner-access-tokens
  [application-only]: https://dev.twitter.com/oauth/application-only
  """

  alias Twittex.API
  alias Twittex.Client.Stream

  alias OAuther, as: OAuth1

  use GenServer

  @api_key Application.get_env(:twittex, :consumer_key)
  @api_secret Application.get_env(:twittex, :consumer_secret)

  @doc """
  Starts the process as part of a supervisor tree.

  ## Options

  * `:token` -- Access token
  * `:token_secret` -- Access token secret

  Further options are passed to `GenServer.start_link/1`.
  """
  @spec start_link(Keyword.t) :: GenServer.on_start
  def start_link(options \\ []) do
    {token, options} = Keyword.pop(options, :token, Application.get_env(:twittex, :token))
    {token_secret, options} = Keyword.pop(options, :token_secret, Application.get_env(:twittex, :token_secret))

    if token && token_secret do
      GenServer.start_link(__MODULE__, {token, token_secret}, options)
    else
      GenServer.start_link(__MODULE__, nil, options)
    end
  end

  @doc """
  Returns a OAuth1 token for the given `token` and `token_secret`.
  """
  @spec get_token(String.t, String.t, Keyword.t) :: {:ok, OAuth1.Credentials.t} | {:error, HTTPoison.Error.t}
  def get_token(token, token_secret, _options \\ []) do
    token = OAuth1.credentials(consumer_key: @api_key, consumer_secret: @api_secret, token: token, token_secret: token_secret)
    {:ok, token}
  end

  @doc """
  Same as `get_token/3` but raises `HTTPoison.Error` if an error occurs during the request.
  """
  @spec get_token!(String.t, String.t, Keyword.t) :: OAuth1.Credentials.t
  def get_token!(token, token_secret, options \\ []) do
    case get_token(token, token_secret, options) do
      {:ok, token} -> token
      {:error, error} -> raise error
    end
  end

  @doc """
  Returns a OAuth2 *application-only* token.

  With [application-only] authentication you don’t have the context of an
  authenticated user and this means that accessing APIs that require user context, will not work.

  [application-only]: https://dev.twitter.com/oauth/application-only
  """
  @spec get_token(Keyword.t) :: {:ok, OAuth2.AccessToken.t} | {:error, OAuth2.Error.t}
  def get_token(options \\ []) do
    # build basic OAuth2 client credentials
    client = OAuth2.Client.new([
      strategy: OAuth2.Strategy.ClientCredentials,
      client_id: @api_key,
      client_secret: @api_secret,
      site: API.api_url,
      token_url: "/oauth2/token",
    ])

    # request bearer token
    case OAuth2.Client.get_token(client, [], [], options) do
      {:ok, %OAuth2.Client{token: token}} ->
        {:ok, OAuth2.AccessToken.new(token.access_token)}
      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Same as `get_token/1` but raises `OAuth2.Error` if an error occurs during the
  request.
  """
  @spec get_token!(Keyword.t) :: OAuth2.AccessToken.t
  def get_token!(options \\ []) do
    case get_token(options) do
      {:ok, token} -> token
      {:error, error} -> raise error
    end
  end

  @doc """
  Issues a GET request to the given url.

  Returns `{:ok, response}` if the request is successful, `{:error, reason}`
  otherwise.
  """
  @spec get(pid, String.t, List.t, Keyword.t) :: {:ok, %{}} | {:error, HTTPoison.Error.t}
  def get(pid, url, headers \\ [], options \\ []) do
    GenServer.call(pid, {:get, url, "", headers, options})
  end

  @doc """
  Same as `get/4` but raises `HTTPoison.Error` if an error occurs during the
  request.
  """
  @spec get!(pid, String.t, List.t, Keyword.t) :: %{}
  def get!(pid, url, headers \\ [], options \\ []) do
    case get(pid, url, headers, options) do
      {:ok, result} -> result
      {:error, error} -> raise error
    end
  end

  @doc """
  Issues a POST request to the given url.

  Returns `{:ok, response}` if the request is successful, `{:error, reason}`
  otherwise.

  See `Twittex.API.request/5` for more detailed information.
  """
  @spec post(pid, String.t, binary, List.t, Keyword.t) :: {:ok, %{}} | {:error, HTTPoison.Error.t}
  def post(pid, url, body \\ [], headers \\ [], options \\ []) do
    GenServer.call(pid, {:post, url, body, headers, options})
  end

  @doc """
  Same as `post/5` but raises `HTTPoison.Error` if an error occurs during the
  request.
  """
  @spec post!(pid, String.t, binary, List.t, Keyword.t) :: %{}
  def post!(pid, url, body, headers \\ [], options \\ []) do
    case post(pid, url, body, headers, options) do
      {:ok, result} -> result
      {:error, error} -> raise error
    end
  end

  @doc """
  Streams data from the given url.

  Returns `{:ok, stage}` if the request is successful, `{:error, reason}`
  otherwise.
  """
  @spec stage(pid, Atom.t, String.t, binary, List.t, Keyword.t) :: {:ok, Stream.t} | {:error, HTTPoison.Error.t}
  def stage(pid, method, url, body \\ [], headers \\ [], options \\ []) do
    {:ok, stage} = Stream.start_link()
    options = Keyword.merge(options, hackney: [stream_to: stage, async: :once], recv_timeout: :infinity)
    case GenServer.call(pid, {method, url, body, headers, options}) do
      {:ok, %HTTPoison.AsyncResponse{}} ->
        {:ok, stage}
      {:error, error} ->
        GenStage.stop(stage)
        {:error, error}
    end
  end

  @doc """
  Same as `stage/6` but raises `HTTPoison.Error` if an error occurs during the
  request.
  """
  @spec stage!(pid, Atom.t, String.t, binary, List.t, Keyword.t) :: Stream.t
  def stage!(pid, method, url, body \\ [], headers \\ [], options \\ []) do
    case stage(pid, method, url, body, headers, options) do
      {:ok, result} -> result
      {:error, error} -> raise error
    end
  end

  def init(nil) do
    case get_token() do
      {:ok, token} -> {:ok, token}
      {:error, error} -> {:stop, error.reason}
    end
  end

  def init({token, secret}) do
    case get_token(token, secret) do
      {:ok, token} -> {:ok, token}
      {:error, error} -> {:stop, error.reason}
    end
  end

  def handle_call({method, url, body, headers, options}, _from, token) do
    case API.request(method, url, body, headers, [{:auth, token} | options]) do
      {:ok, %HTTPoison.Response{body: body}} -> {:reply, {:ok, body}, token}
      {:ok, response} -> {:reply, {:ok, response}, token}
      {:error, error} -> {:reply, {:error, error}, token}
    end
  end

  defmacro __using__(options) do
    if Keyword.get(options, :pool) do
      quote do
        @doc """
        Returns the childspec that starts the client pool.
        """
        @spec child_spec(Keyword.t) :: Supervisor.Spec.spec
        def child_spec(options \\ []) do
          pool_options = [
            name: {:local, __MODULE__},
            worker_module: __MODULE__,
            size: 5,
            max_overflow: 10
          ]
          :poolboy.child_spec(__MODULE__, pool_options, options)
        end

        @doc false
        def start_link(options \\ []) do
          Twittex.Client.Base.start_link(options)
        end

        defp get(url, headers \\ [], options \\ []) do
          :poolboy.transaction(__MODULE__, fn client ->
            Twittex.Client.Base.get(client, url, headers, options)
          end)
        end

        defp get!(url, headers \\ [], options \\ []) do
          :poolboy.transaction(__MODULE__, fn client ->
            Twittex.Client.Base.get!(client, url, headers, options)
          end)
        end

        defp post(url, body \\ [], headers \\ [], options \\ []) do
          :poolboy.transaction(__MODULE__, fn client ->
            Twittex.Client.Base.post(client, url, headers, options)
          end)
        end

        defp post!(url, body \\ [], headers \\ [], options \\ []) do
          :poolboy.transaction(__MODULE__, fn client ->
            Twittex.Client.Base.post!(client, url, headers, options)
          end)
        end

        defp stage(method, url, body \\ [], headers \\ [], options \\ []) do
          :poolboy.transaction(__MODULE__, fn client ->
            Twittex.Client.Base.stage(client, url, headers, options)
          end)
        end

        defp stage!(method, url, body \\ [], headers \\ [], options \\ []) do
          :poolboy.transaction(__MODULE__, fn client ->
            Twittex.Client.Base.stage!(client, url, headers, options)
          end)
        end
      end
    else
      quote do
        @doc """
        Returns the childspec that starts the client process.
        """
        @spec child_spec(Keyword.t) :: Supervisor.Spec.spec
        def child_spec(options \\ []) do
          import Supervisor.Spec
          options = Keyword.put(options, :name, __MODULE__)
          worker(__MODULE__, [options])
        end

        @doc false
        def start_link(options \\ []) do
          Twittex.Client.Base.start_link(options)
        end

        defp get(url, headers \\ [], options \\ []) do
          Twittex.Client.Base.get(__MODULE__, url, headers, options)
        end

        defp get!(url, headers \\ [], options \\ []) do
          Twittex.Client.Base.get!(__MODULE__, url, headers, options)
        end

        defp post(url, body \\ [], headers \\ [], options \\ []) do
          Twittex.Client.Base.post(__MODULE__, url, body, headers, options)
        end

        defp post!(url, body \\ [], headers \\ [], options \\ []) do
          Twittex.Client.Base.post!(__MODULE__, url, body, headers, options)
        end

        defp stage(method, url, body \\ [], headers \\ [], options \\ []) do
          Twittex.Client.Base.stage(__MODULE__, method, url, body, headers, options)
        end

        defp stage!(method, url, body \\ [], headers \\ [], options \\ []) do
          Twittex.Client.Base.stage!(__MODULE__, method, url, body, headers, options)
        end
      end
    end
  end
end
