# Twittex

[![Travis](https://img.shields.io/travis/almightycouch/twittex.svg)](https://travis-ci.org/almightycouch/twittex)
[![Hex.pm](https://img.shields.io/hexpm/v/twittex.svg)](https://hex.pm/packages/twittex)
[![Documentation Status](https://img.shields.io/badge/docs-hexdocs-blue.svg)](http://hexdocs.pm/twittex)
[![GitHub license](https://img.shields.io/badge/license-MIT-blue.svg)](https://raw.githubusercontent.com/almightycouch/twittex/master/LICENSE)
[![Github Issues](https://img.shields.io/github/issues/almightycouch/twittex.svg)](http://github.com/almightycouch/twittex/issues)

![Cover image](http://fs5.directupload.net/images/170405/pdohhvec.jpg)

Twitter client library for Elixir.

It provides support for both *OAuth1.0* and *OAuth2.0* authentication protocols.

## Documentation

See the [online documentation](https://hexdocs.pm/twittex/) for more information.

## Installation

Add `:twittex` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:twittex, "~> 0.2"}]
end
```

Add your app's `consumer_key` and `consumer_secret` to `config/config.exs`:

```elixir
config :twittex,
  consumer_key: "3rJOl1ODzm9yZy63FACdg",
  consumer_secret: "5jPoQ5kQvMJFDYRNE8bQ4rHuds4xJqhvgNJM4awaE8"
```

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
iex> {:ok, stream} = Twittex.Client.stream "#myelixirstatus"
{:ok, stream}
iex> Enum.each stream, &IO.inspect/1
```

## Authentication

Twittex supports both *Application-only* and user-credentials (*xAuth*) authentication
methods.

You should read the Twitter [OAuth](https://dev.twitter.com/oauth) documentation for more details.

Using *Application-only* authentication, your app will be able to, for example:

* Pull user timelines;
* Access friends and followers of any account;
* Access lists resources;
* Search in tweets;
* Retrieve any user information;

And it won’t be able to:

* Post tweets or other resources;
* Connect in Streaming endpoints;
* Search for users;
* Use any geo endpoint;
* Access DMs or account credentials;

In order to have the context of an authenticated user and access restricted
endpoints and features you cannot access with the former method, you will have
to use the *xAuth* extension.

To do so, simply add your credentials to your application config file:

```elixir
config :twittex,
  # consumer key and secret
  username: "myusername",
  password: "mypassword"
```
