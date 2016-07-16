defmodule Twittex.Client.Stream do
  @moduledoc false

  alias Experimental.GenStage

  use GenStage

  defstruct ref: nil, demand: 0, buffer: "", buffer_size: 0

  def start_link(options \\ []) do
    GenStage.start_link(__MODULE__, [], options)
  end

  def init([]) do
    {:producer, %__MODULE__{}}
  end

  def handle_demand(demand, state) do
    :hackney.stream_next(state.ref)
    {:noreply, [], %__MODULE__{state | demand: state.demand + demand}}
  end

  def handle_info({:hackney_response, ref, {:status, status_code, _body}}, %__MODULE__{ref: nil} = state) do
    if status_code in 200..299 do
      :hackney.stream_next(ref)
      {:noreply, [], %__MODULE__{state | ref: ref}}
    else
      {:stop, "Invalid status code #{status_code}", state}
    end
  end

  def handle_info({:hackney_response, _ref, {:headers, _headers}}, state) do
    :hackney.stream_next(state.ref)
    {:noreply, [], state}
  end

  def handle_info({:hackney_response, _ref, {:error, reason}}, state) do
    {:stop, reason, state}
  end

  def handle_info({:hackney_response, _ref, chunk}, state) when is_binary(chunk) do
    chunk_size = String.length(chunk)
    cond do
      state.buffer_size == 0 ->
        [size, chunk] = String.split(chunk, "\r\n", parts: 2)
        :hackney.stream_next(state.ref)
        {:noreply, [], %__MODULE__{state | buffer: chunk, buffer_size: String.to_integer(size) - String.length(chunk) - 1}}
      state.buffer_size > chunk_size ->
        :hackney.stream_next(state.ref)
        {:noreply, [], %__MODULE__{state | buffer: state.buffer <> chunk, buffer_size: state.buffer_size - chunk_size}}
      state.buffer_size == chunk_size ->
        event = Poison.decode!(state.buffer <> chunk)
        if state.demand > 1, do: :hackney.stream_next(state.ref)
        {:noreply, [event], %__MODULE__{state | buffer: "", buffer_size: 0, demand: max(0, state.demand - 1)}}
    end
  end

  def terminate(_reason, state) do
    :hackney.stop_async(state.ref)
  end
end
