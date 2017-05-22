defmodule Twittex.Client.Stream do
  @moduledoc false

  use GenStage

  defstruct ref: nil, demand: 0, buffer: "", buffer_size: 0

  @doc """
  Starts a stage as part of a supervision tree.
  """
  @spec start_link(Keyword.t) :: GenServer.on_start
  def start_link(options \\ []) do
    GenStage.start_link(__MODULE__, [], options)
  end

  #
  # Callbacks
  #

  @doc false
  def init([]) do
    {:producer, %__MODULE__{}}
  end

  @doc false
  def handle_demand(demand, state) do
    if state.demand == 0, do: :hackney.stream_next(state.ref)
    {:noreply, [], %__MODULE__{state | demand: state.demand + demand}}
  end

  def handle_info({:hackney_response, ref, {:status, status_code, reason}}, state)  do
    if status_code in 200..299 do
      if state.demand > 0, do: :hackney.stream_next(ref)
      {:noreply, [], %__MODULE__{state | ref: ref}}
    else
      {:stop, reason, state}
    end
  end

  def handle_info({:hackney_response, _ref, {:headers, _headers}}, state) do
    :hackney.stream_next(state.ref)
    {:noreply, [], state}
  end

  def handle_info({:hackney_response, _ref, {:error, reason}}, state) do
    {:stop, reason, state}
  end

  def handle_info({:hackney_response, _ref, :done}, state) do
    {:stop, "Connection Closed", state}
  end

  def handle_info({:hackney_response, _ref, chunk}, state) when is_binary(chunk) do
    chunk_size = byte_size(chunk)
    cond do
      state.buffer_size == 0 ->
        :hackney.stream_next(state.ref)
        case String.split(chunk, "\r\n", parts: 2) do
          ["", chunk] ->
            {:noreply, [], %__MODULE__{state | buffer: chunk, buffer_size: 0 - byte_size(chunk)}}
          [size, chunk] ->
            {:noreply, [], %__MODULE__{state | buffer: chunk, buffer_size: String.to_integer(size) - byte_size(chunk)}}
          _ ->
            {:noreply, [], state}
        end
      state.buffer_size > chunk_size ->
        :hackney.stream_next(state.ref)
        {:noreply, [], %__MODULE__{state | buffer: state.buffer <> chunk, buffer_size: state.buffer_size - chunk_size}}
      state.buffer_size == chunk_size ->
        if state.demand > 0, do: :hackney.stream_next(state.ref)
        event = Poison.decode!(state.buffer <> chunk)
        {:noreply, [event], %__MODULE__{state | buffer: "", buffer_size: 0, demand: max(0, state.demand - 1)}}
    end
  end

  def terminate(_reason, state) do
    :hackney.stop_async(state.ref)
  end
end
