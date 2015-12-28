defmodule Twittex.Mixfile do
  use Mix.Project

  @version "0.0.4"

  def project do
    [app: :twittex,
     version: @version,
     elixir: "~> 1.1",
     package: package,
     description: description,
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     docs: docs,
     deps: deps]
  end

  def application do
    [applications: [:logger, :httpoison],
     mod: {Twittex, []}]
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
      main: "extra-readme",
      source_ref: "v#{@version}",
      source_url: "https://github.com/almightycouch/twittex"]
  end

  defp deps do
    [{:oauth2, "~> 0.5"},
     {:oauther, "~> 1.0.1"},
     {:ex_doc, "~> 0.10", only: :dev},
     {:earmark, ">= 0.0.0", only: :dev}]
  end
end
