defmodule Twittex.Aggregator do
  @moduledoc """
  A behaviour module for implementing stream aggregators.

  ## Example

  To create a stream aggregator, create a new module and `use Twittex.Aggregator` as follow:

      defmodule TagAggregator do
        use Twittex.Aggregator

        def map(stream) do
          stream
          |> Stream.flat_map(& &1["entities"]["hashtags"])
          |> Stream.map(& &1["text"])
        end

        def reduce(tag, acc) do
          Map.update(acc, tag, 1, & &1 + 1)
        end
      end

  And this is how you may use it:

      iex> "#elixir-lang" |> TagAggregator.new |> TagAggregator.run
  """

  @type accumulator :: %{}

  @callback map(Stream.t) :: Stream.t

  @callback reduce(any, accumulator) :: accumulator

  defmacro __using__(_options) do
    quote do
      def new(query, options \\ []), do:
        Twittex.Aggregator.new(__MODULE__, query, options)

      def next(stream, duration \\ 1, duration_unit \\ :seconds), do:
        Twittex.Aggregator.next(__MODULE__, stream, duration, duration_unit)

      def run(stream, max \\ 10, frame_duration \\ 1, duration_unit \\ :seconds), do:
        Twittex.Aggregator.run(__MODULE__, stream, &print_tag/1, &sort_tag/1, max, frame_duration, duration_unit)

      def sort_tag(tag) do
        Twittex.Aggregator.sort_tag(tag)
      end

      def print_tag(tag) do
        Twittex.Aggregator.print_tag(tag)
      end

      defoverridable [sort_tag: 1, print_tag: 1]
    end
  end

  @doc """
  Returns a new stream of tags matching the given `query`.

  See `Twittex.Client.stream/2` for more detailed information.
  """
  @spec new(module, String.t, Keyword.t) :: Stream.t
  def new(aggregator, query, options \\ []) do
    query
    |> Twittex.Client.stream!(options)
    |> aggregator.map()
  end

  @doc """
  Returns the next batch of tweets from the `stream`.
  """
  @spec next(module, Stream.t, Integer.t, System.time_unit) :: %{}
  def next(aggregator, stream, duration \\ 1, duration_unit \\ :seconds) do
    timestamp = now(duration_unit)
    Enum.reduce_while stream, %{}, fn tag, acc ->
      acc = aggregator.reduce(tag, acc)
      unless now(duration_unit) > timestamp + duration do
        {:cont, acc}
      else
        {:halt, acc}
      end
    end
  end

  @doc """
  Runs the given `stream`.
  """
  @spec run(module, Stream.t, (any -> :ok), (any -> any), Integer.t, Integer.t, System.time_unit) :: :ok
  def run(aggregator, stream, print_fun \\ nil, sort_fun \\ nil, max \\ 10, frame_duration \\ 1, duration_unit \\ :seconds) do
    {print_fun, sort_fun} =
      unless print_fun do
        {&print_tag/1, &sort_tag/1}
      else
        {print_fun, sort_fun || &sort_tag/1}
      end

    Stream.iterate(%{}, &accumulate_next(aggregator, stream, &1, frame_duration, duration_unit))
    |> Stream.each(&print_top(&1, print_fun, sort_fun, max))
    |> Stream.run()
  end

  @doc false
  def sort_tag(tag) do
    elem(tag, 1)
  end

  @doc false
  def print_tag({tag, count}) do
    IO.puts("#{count} #{IO.ANSI.bright}##{tag}#{IO.ANSI.reset}")
  end

  defp now(duration_unit) do
    System.system_time(duration_unit)
  end

  defp accumulate_next(aggregator, stream, acc, duration, duration_unit) do
    Map.merge(acc, next(aggregator, stream, duration, duration_unit), fn _k, v1, v2 -> v1 + v2 end)
  end

  defp print_top(acc, print_fun, sort_fun, max) do
    IEx.Helpers.clear()
    acc
    |> Enum.to_list
    |> Enum.sort_by(sort_fun, &>=/2)
    |> Enum.slice(0, max)
    |> Enum.each(print_fun)
  end
end
