defmodule RpgGameServer.Game.WorldTickerWorker do
  use GenServer
  require Logger
  alias RpgGameServerWeb.Endpoint

  @broadcast_rate 50

  @cell_size 600

  # 2. CONFIGURAÇÃO DE CHUNK: Máximo de entidades por pacote JSON
  @max_chunk_size 150

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl true
  def init(_) do
    schedule_tick()
    {:ok, %{updates: %{}}}
  end

  @impl true
  def handle_cast({:update, data}, state) do
    # Recebe Map do EnemyAI, guarda Map no estado
    new_updates = Map.put(state.updates, data.id, data)
    {:noreply, %{state | updates: new_updates}}
  end

  @impl true
  def handle_cast({:remove, id}, state) do
    new_updates = Map.delete(state.updates, id)
    {:noreply, %{state | updates: new_updates}}
  end

  @impl true
  def handle_info(:tick, state) do
    if map_size(state.updates) > 0 do
      # A. Validação de Existência (Evita Fantasmas)
      valid_entities =
        state.updates
        |> Map.values()
        |> Enum.filter(fn entity -> entity_exists?(entity.id) end)

      # B. Agrupamento por Área
      grouped_updates =
        valid_entities
        |> Enum.group_by(fn mob -> getCellTopic(mob.x, mob.y) end)

      # C. Processamento por Tópico
      Enum.each(grouped_updates, fn {topic, entities} ->
        # 3. OTIMIZAÇÃO: MAP -> ARRAY (Compressão)
        # Transforma %{x: 10...} em [id, type, x, y, state, face]
        compressed_list =
          Enum.map(entities, fn e ->
            [
              e.id,
              e.type,
              # Arredonda para int (economiza bytes)
              round(e.x),
              round(e.y),
              e.state,
              e.face
            ]
          end)

        # 4. OTIMIZAÇÃO: CHUNKING (Quebra em pacotes menores)
        # Se tiver 500 mobs na área, manda 4 pacotes de 150 (aprox)
        # Isso impede o navegador de travar no JSON Parse.
        compressed_list
        |> Enum.chunk_every(@max_chunk_size)
        |> Enum.each(fn chunk ->
          Endpoint.broadcast!(topic, "world_update", %{
            entities: chunk,
            server_time: System.system_time(:millisecond)
          })
        end)
      end)
    end

    schedule_tick()
    {:noreply, %{state | updates: %{}}}
  end

  # --- HELPERS ---
  defp entity_exists?(id) do
    case Registry.lookup(RpgGameServer.EnemyRegistry, id) do
      [{_pid, _}] -> true
      [] -> false
    end
  end

  defp getCellTopic(x, y) do
    cx = floor(x / @cell_size)
    cy = floor(y / @cell_size)
    "area:#{cx}:#{cy}"
  end

  defp schedule_tick, do: Process.send_after(self(), :tick, @broadcast_rate)
end
