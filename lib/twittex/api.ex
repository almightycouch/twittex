defmodule Twittex.API do
  @moduledoc """
  Twitter API wrapper.

  Provides convenience functions for working with Twitter's RESTful API.

  You can use `head/3`, `get/3`, `post/4`, `put/4`, `patch/4`, `delete/3` and
  others using a relative url pointing to the API endpoint. For example:

      > API.get! "/search/tweets.json?q=%23myelixirstatus"
      %HTTPoison.Response{}

  ## Authentication

  Under the hood, the `Twittex.API` module uses `HTTPoison.Base` and overrides the
  `request/5` method to add support for following OAuth authentication method:

  * `xAuth` authentication with user credentials.
  * `Application-only authentication` based on the OAuth 2 specification.

  To request an access token with one of the method listed above. See `get_token/1`
  and `get_token/3`. Here, a brief example:

      > token = API.get_token!
      %OAuth2.AccessToken{}

  With `Application-only authentication` you don’t have the context of an
  authenticated user and this means that any request to API for endpoints that
  require user context, such as posting tweets, will not work.

  Twitter requires clients accessing their API to be authenticated. This means
  that you must provide an authentication token for each request.

  This can be done by passing an OAuth token as a value of the `:auth` option:

      > API.get! "/statuses/home_timeline.json", [], auth: token
      %HTTPoison.Response{}
  """

  use HTTPoison.Base

  alias OAuther, as: OAuth1

  @api_version 1.1
  @api_url "https://api.twitter.com"

  @api_key Application.get_env(:twittex, :consumer_key)
  @api_secret Application.get_env(:twittex, :consumer_secret)

  @doc """
  Request a user specific (`xAuth`) authentication token.

  Returns `{:ok, token}` if the request is successful, `{:error, reason}` otherwise.

  `xAuth` provides a way for applications to exchange a username and password for
  an OAuth access token. Once the access token is retrieved, the application should
  dispose of the login and password corresponding to the user.
  """
  @spec get_token(String.t, String.t, Keyword.t) :: {:ok, OAuth1.Credentials.t} | {:error, HTTPoison.Error.t}
  def get_token(username, password, options \\ []) do
    # build basic OAuth1 credentials
    credentials = OAuth1.credentials([
      consumer_key: @api_key,
      consumer_secret: @api_secret
    ])

    # build authentication header and request parameters
    access_token_url = @api_url <> "/oauth/access_token"
    {header, params} = OAuth1.sign("post", access_token_url, [
      {"x_auth_mode", "client_auth"},
      {"x_auth_username", username},
      {"x_auth_password", password},
    ], credentials) |> OAuth1.header

    # request single-user token
    case post(access_token_url, {:form, params}, [header], options) do
      {:ok, response} ->
        {:ok, struct(credentials, (for {"oauth_" <> key, val} <- URI.decode_query(response.body), do: {String.to_atom(key), val}))}
      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Same as `get_token/3` but raises `HTTPoison.Error` if an error occurs during the
  request.
  """
  @spec get_token!(String.t, String.t, Keyword.t) :: OAuth1.Credentials.t
  def get_token!(username, password, options \\ []) do
    case get_token(username, password, options) do
      {:ok, token} -> token
      {:error, error} -> raise error
    end
  end

  @doc """
  Request an application-only authentication token.

  Returns `{:ok, token}` if the request is successful, `{:error, reason}` otherwise.

  With `Application-only authentication` you don’t have the context of an
  authenticated user and this means that any request to API for endpoints that
  require user context, such as posting tweets, will not work.
  """
  @spec get_token(Keyword.t) :: {:ok, OAuth2.AccessToken.t} | {:error, OAuth2.Error.t}
  def get_token(options \\ []) do
    # build basic OAuth2 client credentials
    client = OAuth2.Client.new([
      strategy: OAuth2.Strategy.ClientCredentials,
      client_id: @api_key,
      client_secret: @api_secret,
      site: @api_url,
      token_url: "/oauth2/token",
    ])

    # request bearer token
    case OAuth2.Client.get_token(client, [], [], options) do
      {:ok, %OAuth2.AccessToken{other_params: %{"errors" => [%{"message" => error}|_]}}} ->
        {:error, %OAuth2.Error{reason: error}}
      {:ok, %OAuth2.AccessToken{access_token: access_token}} ->
        {:ok, OAuth2.AccessToken.new(access_token, client)}
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

  def request(method, url, body \\ "", headers \\ [], options \\ []) do
    # make url absolute
    unless URI.parse(url).scheme do
      url = @api_url <> "/#{@api_version}" <> url
    end

    # if available, inject authentication header
    if Keyword.has_key?(options, :auth) do
      {auth, options} = Keyword.pop(options, :auth)
      headers = [case auth do
        %OAuth2.AccessToken{} = token ->
          {"Authorization", "#{token.token_type} #{token.access_token}"}
        %OAuth1.Credentials{} = credentials ->
          OAuth1.sign(to_string(method), url, [], credentials) |> OAuth1.header |> elem(0)
      end | headers]
    end

    # call HTTPoison.request/5
    case super(method, url, body, headers, options) do
      {:ok, %HTTPoison.Response{status_code: status} = response} when status in 200..299 ->
        # decode body depending on the content-type
        {:ok, struct(response, body: process_response_body(response.body, response.headers))}
      {:ok, response} ->
        # reject bad status codes
        {:error, %HTTPoison.Error{reason: "Bad status code #{response.status_code}"}}
      {:error, error} ->
        {:error, error}
    end
  end

  defp process_response_body(body, headers) do
    import OAuth2.Util, only: [content_type: 1]

    case content_type(headers) do
      "application/json" ->
        Poison.decode!(body)
      "text/javascript" ->
        Poison.decode!(body)
      "application/x-www-form-urlencoded" ->
        URI.decode_query!(body)
      _ ->body
    end
  end
end
