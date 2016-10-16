alias Experimental.Flow

defmodule Twittex.Classifier do
  @moduledoc """
  Conveniences for working with natural language processing and sentiment analysis.
  """

  @doc """
  Trains bayes with both, positive and negative samples.
  """
  @spec train_corpora(Keyword.t) :: pid
  def train_corpora(options \\ []) do
    ~w(positive negative)a
    |> Enum.map(&train_corpus(&1, options))
    |> merge(options)
  end

  @doc """
  Trains bayes with the given categorized samples.
  """
  @spec train_corpus(:positive | :negative, Keyword.t) :: pid
  def train_corpus(category, options \\ []) do
    :code.priv_dir(:twittex)
    |> Path.join("twitter_samples")
    |> Path.join(Atom.to_string(category) <> "_tweets.json")
    |> File.stream!(read_ahead: 1_000)
    |> Flow.from_enumerable()
    |> Flow.map(&Poison.decode!/1)
    |> Flow.map(&Map.fetch!(&1, "text"))
    |> train(category, options)
  end

  @doc """
  Trains bayes with the given enumerable and category.
  """
  @spec train(Enumerable.t, Atom.t, Keyword.t) :: pid
  def train(enum, category, options \\ [])

  def train(%Flow{} = flow, category, options) do
    options = Keyword.merge(default_options, options)
    flow
    |> Flow.reduce(fn -> SimpleBayes.init(options) end, &SimpleBayes.train(&2, category, &1))
    |> Flow.map_state(&export_bayes/1)
    |> Flow.emit(:state)
    |> Enum.reduce(%SimpleBayes{opts: options}, &merge_bayes/2)
    |> SimpleBayes.Storage.Memory.init(options)
  end

  def train(enum, category, options) do
    options = Keyword.merge(default_options, options)
    Enum.reduce(enum, SimpleBayes.init(options), &SimpleBayes.train(&2, category, &1))
  end

  @doc """
  Merges multiples bayes into one.
  """
  @spec merge([pid], Keyword.t) :: pid
  def merge(pids, options \\ []) do
    options = Keyword.merge(default_options, options)
    pids
    |> Enum.map(&export_bayes/1)
    |> Enum.reduce(%SimpleBayes{opts: options}, &merge_bayes/2)
    |> SimpleBayes.Storage.Memory.init(options)
  end

  #
  # Delegates
  #

  defdelegate classify(pid, string, opts \\ []),     to: SimpleBayes.Classifier
  defdelegate classify_one(pid, string, opts \\ []), to: SimpleBayes.Classifier

  #
  # Helpers
  #

  defp default_options do
    [model: :binarized_multinomial,
      storage: :memory,
      default_weight: 1,
      smoothing: 0,
      stem: &Stemmer.stem/1,
      top: nil,
      stop_words: ~w(a about above after again against all am an and any are aren't
        as at be because been before being below between both but by can't cannot could
        couldn't did didn't do does doesn't doing don't down during each few for from
        further had hadn't has hasn't have haven't having he he'd he'll he's her here
        here's hers herself him himself his how how's i i'd i'll i'm i've if in into
        is isn't it it's its itself let's me more most mustn't my myself no nor not of
        off on once only or other ought our ours ourselves out over own same shan't
        she she'd she'll she's should shouldn't so some such than that that's the
        their theirs them themselves then there there's these they they'd they'll
        they're they've this those through to too under until up very was wasn't we
        we'd we'll we're we've were weren't what what's when when's where where's
        which while who who's whom why why's with won't would wouldn't you you'd
        you'll you're you've your yours yourself yourselves)]
  end

  defp export_bayes(pid) do
    bayes = Agent.get(pid, & &1)
    Agent.stop(pid)
    bayes
  end

  defp merge_bayes(bayes, acc) do
    if bayes, do: Map.merge(acc, bayes, &update_bayes/3), else: acc
  end

  defp update_bayes(key, v1, v2) do
    case key do
      :categories          -> Map.merge(v1, v2, &update_bayes_category/3)
      :tokens              -> Map.merge(v1, v2, &update_bayes_tokens/3)
      :tokens_per_training -> Map.merge(v1, v2)
      :trainings           -> v1 + v2
      _                    -> v1
    end
  end

  defp update_bayes_category(_key, v1, v2) do
    Keyword.merge(v1, v2, &update_bayes/3)
  end

  defp update_bayes_tokens(_key, v1, v2) do
    v1 + v2
  end
end
