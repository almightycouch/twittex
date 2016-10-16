defmodule Mix.Tasks.InteractiveTraining do
  use Mix.Task

  def run(args) do
    Application.ensure_all_started(:twittex)
    corpora_dir = :code.priv_dir(:twittex)

    pos_file = File.open!(Path.join(corpora_dir, "positive_tweets.json"), [:write, :append, :utf8])
    neg_file = File.open!(Path.join(corpora_dir, "negative_tweets.json"), [:write, :append, :utf8])

    Twittex.Client.stream!(List.first(args) || :sample, language: "en")
    |> Stream.each(&interactive_classification(&1, pos_file, neg_file))
    |> Stream.run()
  end

  defp interactive_classification(tweet, pos_file, neg_file) do
    IEx.Helpers.clear()
    IO.puts(tweet["text"])
    case String.trim(IO.read(:stdio, :line)) do
      "y" -> IO.puts(pos_file, Poison.encode!(tweet))
      "n" -> IO.puts(neg_file, Poison.encode!(tweet))
      _   -> :skip
    end
  end
end
