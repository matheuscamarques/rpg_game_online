defmodule RpgGameServer.Game.WorldStateBroadcaster do
  use GenServer

  alias RpgGameServer.Game.WorldTicker
  alias RpgGameServerWeb.Endpoint

  @broadcast_rate 60

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    schedule_tick()
    # O estado fica vazio, não precisamos mais guardar contadores
    {:ok, %{}}
  end

  @impl true
  def handle_info(:tick, state) do
    # 1. Pega o Timestamp Atual (Server Time)
    # :millisecond é seguro para JSON (dentro do MAX_SAFE_INTEGER do JS)
    server_time = System.system_time(:millisecond)

    all_updates = WorldTicker.get_all_updates()

    all_updates
    |> Enum.group_by(& &1.area)
    |> Enum.each(fn {area, entities_history} ->
      # 2. DEDUPLICAÇÃO (Mantém apenas a atualização mais recente por ID)
      unique_entities =
        Enum.reduce(entities_history, %{}, fn entity, acc ->
          Map.put(acc, entity.id, entity)
        end)
        |> Map.values()

      # 3. Serializa para listas (Arrays)
      payload = Enum.map(unique_entities, &serialize_entity/1)

      # 4. Envia o tempo do servidor no cabeçalho do pacote
      Endpoint.broadcast!("area:" <> area, "world_update", %{
        time: server_time,
        entities: payload
      })
    end)

    schedule_tick()
    {:noreply, state}
  end

  # Helper de serialização (mantido igual)
  defp serialize_entity(entity) do
    [
      entity.id,
      entity.type,
      entity.x,
      entity.y,
      entity.state,
      entity.face,
      entity.hp_percent
    ]
  end

  defp schedule_tick() do
    Process.send_after(self(), :tick, @broadcast_rate)
  end
end
