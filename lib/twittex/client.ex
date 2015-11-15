defmodule Twittex.Client do
  @moduledoc """
  """

  use Twittex.Client.Base

  @doc """
  """
  def search(term, options \\ []) do
    get "/search/tweets.json?" <> URI.encode_query(Dict.merge(%{q: term}, options))
  end
end
