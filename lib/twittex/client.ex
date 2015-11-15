defmodule Twittex.Client do
  @moduledoc """
  Twitter client with helper functions to query the API.
  """

  use Twittex.Client.Base

  @doc """
  Queries against the indices of recent or popular Tweets.

  For more informations about this function, see [Twitter's Search API
  documentation](https://dev.twitter.com/rest/public/search).
  """
  @spec search(String.t, Keyword.t) :: {:ok, %{}} | {:error, HTTPoison.Error.t}
  def search(term, options \\ []) do
    get "/search/tweets.json?" <> URI.encode_query(Dict.merge(%{q: term}, options))
  end
end
