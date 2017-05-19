defmodule Twittex.Client.Base do
  @moduledoc """
  A behaviour module for implementing your own Twitter client.

  It implements the `GenServer` behaviour, authenticates when starting and keeps
  the authentication token in it state during the entire process livetime.

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

  * `:username` - Twitter username or email address
  * `:password` - Twitter password
  * `:access_token` - Twitter access token from dev.twitter.com
  * `:access_token_secrect` - Twitter access token secret from dev.twitter.com

  Further options are passed to `GenServer.start_link/1`.
  """
  @spec start_link(Keyword.t) :: GenServer.on_start
  def start_link(options \\ []) do
    {username, options} = Keyword.pop(options, :username, Application.get_env(:twittex, :username))
    {password, options} = Keyword.pop(options, :password, Application.get_env(:twittex, :password))
    {access_token, options} = Keyword.pop(options, :access_token, Application.get_env(:twittex, :access_token))
    {access_token_secrect, options} = Keyword.pop(options, :access_token, Application.get_env(:twittex, :access_token_secrect))

    cond do
        access_token && access_token_secrect -> GenServer.start_link(__MODULE__, %{:access_token => access_token, :access_token_secrect => access_token_secrect}, options)
        username && password -> GenServer.start_link(__MODULE__, {username, password}, options)
        true -> GenServer.start_link(__MODULE__, nil, options)
    end
  end

  @doc """
  Issues a GET request to the given url.

  Returns `{:ok, response}` if the request is successful, `{:error, reason}`
  otherwise.

  See `Twittex.API.request/5` for more detailed information.
  """
  @spec get(pid, String.t, API.headers, Keyword.t) :: {:ok, %{}} | {:error, HTTPoison.Error.t}
  def get(pid, url, headers \\ [], options \\ []) do
    GenServer.call(pid, {:get, url, "", headers, options})
  end

  @doc """
  Same as `get/4` but raises `HTTPoison.Error` if an error occurs during the
  request.
  """
  @spec get!(pid, String.t, API.headers, Keyword.t) :: %{}
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
  @spec post(pid, String.t, binary, API.headers, Keyword.t) :: {:ok, %{}} | {:error, HTTPoison.Error.t}
  def post(pid, url, body \\ [], headers \\ [], options \\ []) do
    GenServer.call(pid, {:post, url, body, headers, options})
  end

  @doc """
  Same as `post/5` but raises `HTTPoison.Error` if an error occurs during the
  request.
  """
  @spec post!(pid, String.t, binary, API.headers, Keyword.t) :: %{}
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
  @spec stage(pid, Atom.t, String.t, binary, API.headers, Keyword.t) :: {:ok, Stream.t} | {:error, HTTPoison.Error.t}
  def stage(pid, method, url, body \\ [], headers \\ [], options \\ []) do
    {:ok, stage} = Stream.start_link()
    options = Keyword.merge(options, hackney: [stream_to: stage, async: :once], recv_timeout: :infinity)
    case GenServer.call(pid, {method, url, body, headers, options}) do
      {:ok, %HTTPoison.AsyncResponse{}} ->
        {:ok, stage}
      {:error, error} ->
        Stream.stop(stage)
        {:error, error}
    end
  end

  @doc """
  Same as `stage/6` but raises `HTTPoison.Error` if an error occurs during the
  request.
  """
  @spec stage!(pid, Atom.t, String.t, binary, API.headers, Keyword.t) :: Stream.t
  def stage!(pid, method, url, body \\ [], headers \\ [], options \\ []) do
    case stage(pid, method, url, body, headers, options) do
      {:ok, result} -> result
      {:error, error} -> raise error
    end
  end

  def init(nil) do
    case API.get_token() do
      {:ok, token} -> {:ok, token}
      {:error, error} -> {:stop, error.reason}
    end
  end

  def init(tokens) when is_map(tokens) do
    token = OAuth1.credentials(consumer_key: @api_key, consumer_secret: @api_secret, token: tokens[:access_token], token_secret: tokens[:access_token_secrect])
    {:ok, token}
  end

  def init({username, password}) do
    case API.get_token(username, password) do
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

  @doc """
  Generates a *singleton* Twitter client.

  ## Options

  * `:pool` - Use pool of clients (default: `false`)

  It generates `get/3`, `post/4`, `stage/5` and their `!` counterparts so you don't have to care about authentication.
  Here's, a very basic example:

      defmodule TwitterBot do
        use Twittex.Client.Base

        def search(term, options \\ []) do
          get "/search/tweets.json?" <> URI.encode_query(Keyword.merge(%{q: term}, options))
        end
      end

  Note that the generated `child_spec/1` helper function can be used to start the client as part of a supervisor tree.
  """
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
