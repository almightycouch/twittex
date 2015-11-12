defmodule Twittex.Client do
  @moduledoc """
  A behaviour module for implementing your own Twitter client.

  It implements the `GenServer` behaviour, and keeps the authentication state
  during the entire process livetime.  If the server dies, and is part of a
  supervisor tree, it will restart with the same token.

  See `get/4` and `post/5` for more detailed informations.

  ## Example

  To create a client, create a new module and `use Twittex.Client` as follow:

      defmodule TwitterBot do
        use Twittex.Client

        def search(term, options \\ []) do
          get "/search/tweets.json?" <> URI.encode_query(Dict.merge(%{q: term}, options))
        end
      end

  This client works as a singleton and can be added to a supervisor tree:

      worker(TwitterBot, [])

  And this is how you may use it:

      > TwitterBot.search "#myelixirstatus", count: 3
      {:ok, %{...}}
  """

  use GenServer

  @doc """
  Starts the process linked to the current process.

  ## Options

  * `:username` - Twitter username or email address
  * `:password` - Twitter password

  Other options are passed to `GenServer._start_link/1`.
  """
  def start_link(options \\ []) do
    {username, options} = Keyword.pop(options, :username)
    {password, options} = Keyword.pop(options, :password)

    if username && password do
      GenServer.start_link(__MODULE__, {username, password}, options)
    else
      GenServer.start_link(__MODULE__, nil, options)
    end
  end

  @doc """
  Issues a GET request to the given url.

  Returns `{:ok, response}` if the request is successful, `{:error, reason}`
  otherwise.

  See `Twitter.API.request/5` for more detailed information.
  """
  def get(pid, url, headers \\ [], options \\ []) do
    GenServer.call(pid, {:get, url, "", headers, options})
  end

  @doc """
  Same as `get/4` but raises `HTTPoison.Error` if an error occurs during the
  request.
  """
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

  See `Twitter.API.request/5` for more detailed information.
  """
  def post(pid, url, body \\ [], headers \\ [], options \\ []) do
    GenServer.call(pid, {:post, url, body, headers, options})
  end

  @doc """
  Same as `post/5` but raises `HTTPoison.Error` if an error occurs during the
  request.
  """
  def post!(pid, url, body, headers \\ [], options \\ []) do
    case post(pid, url, body, headers, options) do
      {:ok, result} -> result
      {:error, error} -> raise error
    end
  end

  def init(nil) do
    case Twittex.API.get_token() do
      {:ok, token} -> {:ok, token}
      {:error, error} -> {:stop, error.reason}
    end
  end

  def init({username, password}) do
    case Twittex.API.get_token(username, password) do
      {:ok, token} -> {:ok, token}
      {:error, error} -> {:stop, error.reason}
    end
  end

  def handle_call({method, url, body, headers, options}, _from, token) do
    case Twittex.API.request(method, url, body, headers, [{:auth, token} | options]) do
      {:ok, response} -> {:reply, {:ok, response.body}, token}
      {:error, error} -> {:reply, {:error, error}, token}
    end
  end

  @doc false
  defmacro __using__(_options) do
    quote do
      def start_link(options \\ []) do
        Twittex.Client.start_link(Dict.put_new(options, :name, __MODULE__))
      end

      defp get(url, headers \\ [], options \\ []) do
        Twittex.Client.get(__MODULE__, url, headers, options)
      end

      defp get!(url, headers \\ [], options \\ []) do
        Twittex.Client.get!(__MODULE__, url, headers, options)
      end

      defp post(url, body \\ [], headers \\ [], options \\ []) do
        Twittex.Client.post(__MODULE__, url, body, headers, options)
      end

      defp post!(url, body \\ [], headers \\ [], options \\ []) do
        Twittex.Client.post!(__MODULE__, url, body, headers, options)
      end
    end
  end
end
