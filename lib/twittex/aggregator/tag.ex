defmodule Twittex.Aggregator.Tag do
  @moduledoc false

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

