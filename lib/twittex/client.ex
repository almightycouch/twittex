defmodule Twittex.Client do
  @moduledoc """
  Twitter client implementation, provides helper functions to query the API.
  """

  use Twittex.Client.Base

  @doc """
  Returns a collection of relevant Tweets matching the given `query`.
  """
  @spec search(String.t, Keyword.t) :: {:ok, %{}} | {:error, HTTPoison.Error.t}
  def search(query, options \\ []) do
    get "/search/tweets.json?" <> URI.encode_query(Dict.merge(%{q: query}, options))
  end

  @doc """
  Same as `search/2` but raises `HTTPoison.Error` if an error occurs during the
  request.
  """
  @spec search!(String.t, Keyword.t) :: %{}
  def search!(query, options \\ []) do
    get! "/search/tweets.json?" <> URI.encode_query(Dict.merge(%{q: query}, options))
  end

  @doc """
  Returns the 20 most recent mentions (tweets containing a users’s `@screen_name`)
  for the authenticating user.
  """
  @spec mentions_timeline(Keyword.t) :: {:ok, %{}} | {:error, HTTPoison.Error.t}
  def mentions_timeline(options \\ []) do
    get "/statuses/mentions_timeline.json?" <> URI.encode_query(options)
  end

  @doc """
  Same as `mentions_timeline/1` but raises `HTTPoison.Error` if an error occurs during the
  request.
  """
  @spec mentions_timeline!(Keyword.t) :: %{}
  def mentions_timeline!(options \\ []) do
    get! "/statuses/mentions_timeline.json?" <> URI.encode_query(options)
  end

  @doc """
  Returns a collection of the most recent Tweets posted by the user with the given
  `screen_name`.
  """
  @spec user_timeline(String.t, Keyword.t) :: {:ok, %{}} | {:error, HTTPoison.Error.t}
  def user_timeline(screen_name, options \\ []) do
    get "/statuses/user_timeline.json?" <> URI.encode_query(Dict.merge(%{screen_name: screen_name}, options))
  end

  @doc """
  Same as `user_timeline/2` but raises `HTTPoison.Error` if an error occurs during the
  request.
  """
  @spec user_timeline!(String.t, Keyword.t) :: %{}
  def user_timeline!(screen_name, options \\ []) do
    get! "/statuses/user_timeline.json?" <> URI.encode_query(Dict.merge(%{screen_name: screen_name}, options))
  end

  @doc """
  Returns a collection of the most recent Tweets and retweets posted by the
  authenticating user and the users they follow.
  """
  @spec home_timeline(Keyword.t) :: {:ok, %{}} | {:error, HTTPoison.Error.t}
  def home_timeline(options \\ []) do
    get "/statuses/home_timeline.json?" <> URI.encode_query(options)
  end

  @doc """
  Same as `home_timeline/1` but raises `HTTPoison.Error` if an error occurs during the
  request.
  """
  @spec home_timeline!(Keyword.t) :: %{}
  def home_timeline!(options \\ []) do
    get! "/statuses/home_timeline.json?" <> URI.encode_query(options)
  end

  @doc """
  Returns the most recent tweets authored by the authenticating user that have been
  retweeted by others.
  """
  @spec retweets_of_me(Keyword.t) :: {:ok, %{}} | {:error, HTTPoison.Error.t}
  def retweets_of_me(options \\ []) do
    get "/statuses/retweets_of_me.json?" <> URI.encode_query(options)
  end

  @doc """
  Same as `retweets_of_me/1` but raises `HTTPoison.Error` if an error occurs during the
  request.
  """
  @spec retweets_of_me!(Keyword.t) :: %{}
  def retweets_of_me!(options \\ []) do
    get! "/statuses/retweets_of_me.json?" <> URI.encode_query(options)
  end

  @doc """
  Returns a `GenEvent.Stream` that consume Tweets from a Twitter streaming
  endpoint.
  """
  @spec stream(String.t, Keyword.t) :: {:ok, GenEvent.Stream.t} | {:error, HTTPoison.Error.t}
  def stream(query, options \\ []) do
    {:ok, listener} = GenEvent.start_link()
    stream_url = "https://stream.twitter.com/1.1/statuses/filter.json?" <> URI.encode_query(Dict.merge(%{track: query, delimited: "length"}, options))
    case post stream_url, "", [], stream_to: spawn(fn -> stream_loop(listener) end) do
      {:ok, %HTTPoison.AsyncResponse{id: id}} ->
        GenEvent.add_handler(listener, Twittex.Client.StreamHandler, id)
        {:ok, GenEvent.stream(listener)}
      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Same as `stream/2` but raises `HTTPoison.Error` if an error occurs during the
  request.
  """
  @spec stream!(String.t, Keyword.t) :: GenEvent.Stream.t
  def stream!(query, options \\ []) do
    case stream(query, options) do
      {:ok, stream} -> stream
      {:error, error} -> raise error
    end
  end

  defp stream_loop(listener, buffer \\ "", size \\ 0) do
    receive do
      %HTTPoison.AsyncChunk{chunk: chunk} ->
        chunk_size = String.length(chunk)
        cond do
          size == 0 ->
            [size, chunk] = String.split(chunk, "\r\n", parts: 2)
            stream_loop(listener, chunk, String.to_integer(size) - String.length(chunk) - 1)
          size > chunk_size ->
            stream_loop(listener, buffer <> chunk, size - chunk_size)
          size < chunk_size ->
            raise "Oops, reading ahead of chunk"
          size == chunk_size ->
            GenEvent.ack_notify(listener, Poison.decode!(buffer <> chunk))
        end
      _ -> :noop
    end
    stream_loop(listener)
  end
end
