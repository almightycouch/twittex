defmodule Twittex.Client.StreamHandler do
  use GenEvent

  def init(id) do
    {:ok, id}
  end

  def terminate(reason, id) do
    :hackney.stop_async(id)
    reason
  end
end
