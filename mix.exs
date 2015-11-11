defmodule Twittex.Mixfile do
  use Mix.Project

  def project do
    [app: :twittex,
     version: "0.0.1",
     elixir: "~> 1.1",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps]
  end

  def application do
    [applications: [:logger, :httpoison],
     mod: {Twittex, []}]
  end

  defp deps do
    [{:oauth2, "~> 0.5"},
     {:oauther, "~> 1.0.1"}]
  end
end
