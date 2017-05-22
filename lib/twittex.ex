defmodule Twittex do
  @moduledoc """
  Twitter client with OAuth1 and OAuth2 support.
  """

  defdelegate home_timeline(options \\ []), to: Twittex.Client
  defdelegate home_timeline!(options \\ []), to: Twittex.Client

  defdelegate mentions_timeline(options \\ []), to: Twittex.Client
  defdelegate mentions_timeline!(options \\ []), to: Twittex.Client

  defdelegate retweets_of_me(options \\ []), to: Twittex.Client
  defdelegate retweets_of_me!(options \\ []), to: Twittex.Client

  defdelegate search(options \\ []), to: Twittex.Client
  defdelegate search!(options \\ []), to: Twittex.Client

  defdelegate stream(options \\ []), to: Twittex.Client
  defdelegate stream!(options \\ []), to: Twittex.Client

  defdelegate user_stream(options \\ []), to: Twittex.Client
  defdelegate user_stream!(options \\ []), to: Twittex.Client

  defdelegate user_timeline(options \\ []), to: Twittex.Client
  defdelegate user_timeline!(options \\ []), to: Twittex.Client
end
