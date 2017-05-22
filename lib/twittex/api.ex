defmodule Twittex.API do
  @moduledoc false

  use HTTPoison.Base

  alias OAuther, as: OAuth1

  def api_version, do: 1.1
  def api_url, do: "https://api.twitter.com"

  def request(method, url, body \\ "", headers \\ [], options \\ []) do
    # make url absolute
    url =
      unless URI.parse(url).scheme do
        api_url() <> "/#{api_version()}" <> url
      else
        url
      end

    # if available, inject authentication header
    {headers, options} =
      if Keyword.has_key?(options, :auth) do
        {auth, options} = Keyword.pop(options, :auth)
        oauth =
          case auth do
            %OAuth2.AccessToken{} = token ->
              {"Authorization", "#{token.token_type} #{token.access_token}"}
            %OAuth1.Credentials{} = credentials ->
              OAuth1.sign(to_string(method), url, [], credentials) |> OAuth1.header |> elem(0)
          end
        {[oauth|headers], options}
      else
        {headers, options}
      end

    # call HTTPoison.request/5
    case super(method, url, body, headers, options) do
      {:ok, %HTTPoison.Response{status_code: status_code, headers: headers, body: body} = response} ->
        body = process_response_body(body, headers)
        if status_code in 200..299 do
          {:ok, struct(response, body: body)}
        else
          case body do
            %{"errors" => [%{"message" => reason}]} ->
              {:error, %HTTPoison.Error{reason: reason}}
            reason ->
              {:error, %HTTPoison.Error{reason: reason}}
          end
        end
      {:ok, %HTTPoison.AsyncResponse{} = async_response} ->
        {:ok, async_response}
      {:error, error} ->
        {:error, error}
    end
  end

  #
  # Helpers
  #

  defp process_response_body(body, headers) do
    import OAuth2.Util, only: [content_type: 1]
    case content_type(headers) do
      "application/json" ->
        Poison.decode!(body)
      "text/javascript" ->
        Poison.decode!(body)
      "application/x-www-form-urlencoded" ->
        URI.decode_query(body)
      _ ->
        body
    end
  end
end
