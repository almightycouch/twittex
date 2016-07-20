# Twittex

Twitter client library for Elixir.

It provides support for both OAuth1.0 and OAuth2.0 authentication protocols.

This mean that you can access the Twitter RESTful API either with the OAuth2.0
[Application-only authentication](https://dev.twitter.com/oauth/application-only)
or with the OAuth1.0 [xAuth](https://dev.twitter.com/oauth/xauth) extension. The
latter requires user credentials to login with.

## Installation

  1. Add twittex to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:twittex, "~> 0.1"}]
end
```

  2. Ensure twittex is started before your application:

```elixir
def application do
  [applications: [:twittex]]
end
```

3. Add your app's `consumer_key` and `consumer_secret` to `config/config.exs`:

```elixir
config :twittex,
  consumer_key: "",
  consumer_secret: ""
```

## Documentation

See the [online documentation](https://hexdocs.pm/twittex/) for more information.

## Usage

Returns a collection of relevant Tweets matching `#myelixirstatus`:

```elixir
iex> Twittex.Client.search "#myelixirstatus"
{:ok, %{}}
```

Same a the previous example but returns the last 50 Tweets (instead of 15):

```elixir
iex> Twittex.Client.search "#myelixirstatus", count: 50
{:ok, %{}}
```

Returns a collection of the most recent Tweets and retweets posted by the
authenticating user and the users they follow:

```elixir
iex> Twittex.Client.home_timeline
{:ok, %{}}
```

Returns a stream that consume Tweets from public data flowing through Twitter:

```elixir
iex> {:ok, stream} = Twittex.Client.stream "cop21"
{:ok, stream}
iex> Enum.each stream, &IO.inspect/1
```
