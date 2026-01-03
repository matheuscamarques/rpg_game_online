defmodule RpgGameServer.Game.WorldTickerWorker do
  use GenServer

  @spec start_link(any()) :: :ignore | {:error, any()} | {:ok, pid()}
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl true
  def init(_) do
    {:ok, %{updates: %{}}}
  end

  @impl true
  def handle_cast({:update, data}, state) do
    new_updates = Map.put(state.updates, data.id, data)
    {:noreply, %{state | updates: new_updates}}
  end

  @impl true
  def handle_call(:get_updates, _from, state) do
    {:reply, Map.values(state.updates), %{state | updates: %{}}}
  end
end
