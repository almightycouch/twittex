defmodule Twittex.Mixfile do
  use Mix.Project

  @version "0.3.3"

  def project do
    [app: :twittex,
     name: "Twittex",
     version: @version,
     elixir: "~> 1.4",
     package: package(),
     description: description(),
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     docs: docs(),
     deps: deps()]
  end

  def application do
    [extra_applications: [:logger],
     mod: {Twittex.Application, []}]
  end

  defp package do
    [files: ["lib", "mix.exs", "README.md", "LICENSE"],
     maintainers: ["Mario Flach"],
     licenses: ["MIT"],
     links: %{github: "https://github.com/almightycouch/twittex"}]
  end

  defp description do
    "Twitter client library for Elixir"
  end

  defp docs do
    [extras: ["README.md"],
     main: "readme",
     source_ref: "v#{@version}",
     source_url: "https://github.com/almightycouch/twittex"]
  end

  defp deps do
    [{:poison, "~> 3.1"},
     {:httpoison, "~> 0.11"},
     {:oauth2, "~> 0.9"},
     {:oauther, "~> 1.1"},
     {:gen_stage, "~> 0.11"},
     {:poolboy, "~> 1.5"},
     {:ex_doc, "~> 0.15", only: :dev, runtime: false}]
  end
end
