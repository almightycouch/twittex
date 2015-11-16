defmodule Twittex.Client do
  @moduledoc """
  Twitter client implementation, provides helper functions to query the API.
  """

  use Twittex.Client.Base

  @doc """
  Returns a collection of relevant Tweets matching the given `query`.

  For more informations about this function, see [Twitter's Search API
  documentation](https://dev.twitter.com/rest/public/search).
  """
  @spec search(String.t, Keyword.t) :: {:ok, %{}} | {:error, HTTPoison.Error.t}
  def search(query, options \\ []) do
    get "/search/tweets.json?" <> URI.encode_query(Dict.merge(%{q: query}, options))
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
  Returns a collection of the most recent Tweets posted by the user with the given
  `screen_name`.
  """
  @spec user_timeline(String.t, Keyword.t) :: {:ok, %{}} | {:error, HTTPoison.Error.t}
  def user_timeline(screen_name, options \\ []) do
    get "/statuses/user_timeline.json?" <> URI.encode_query(Dict.merge(%{screen_name: screen_name}, options))
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
  Returns the most recent tweets authored by the authenticating user that have been
  retweeted by others.
  """
  @spec retweets_of_me(Keyword.t) :: {:ok, %{}} | {:error, HTTPoison.Error.t}
  def retweets_of_me(options \\ []) do
    get "/statuses/retweets_of_me.json?" <> URI.encode_query(options)
  end
end
