# Twittex

Twitter client library for Elixir.

It provides support for both OAuth1.0 and OAuth2.0 authentication protocols.

This mean that you can access the Twitter RESTful API either with the
[Application-only authentication](https://dev.twitter.com/oauth/application-only)
or with [xAuth](https://dev.twitter.com/oauth/xauth). The latter requires user
credentials to login with.

## Installation

  1. Add twittex to your list of dependencies in `mix.exs`:

        def deps do
          [{:twittex, "~> 0.0.1"}]
        end

  2. Ensure twittex is started before your application:

        def application do
          [applications: [:twittex]]
        end

3. Add your app's `consumer_key` and `consumer_secret` to `config/config.exs`:

        config :twittex,
          consumer_key: "",
          consumer_secret: ""

## Documentation

See the [online documentation](https://hexdocs.pm/twittex/) for more information.

## Usage

    iex> Twittex.Client.search "#myelixirstatus"
    %{}
