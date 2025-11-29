defmodule RpgGameServer.Game.EnemySpawner do
  use GenServer
  require Logger

  alias RpgGameServer.Game.EnemySupervisor
  alias RpgGameServer.Game.Room1

  # Configuração
  @mobs_config [
    %{zone: "1", type: "human", count: 1000}
  ]

  # Configuração de Throttle (Controle de fluxo)
  # A cada 100 mobs, ele dorme 10ms.
  # Isso previne que o banco de dados ou o Supervisor fiquem sobrecarregados.
  @throttle_batch 100
  @throttle_sleep_ms 10

  # --- CLIENT API ---

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  # --- SERVER CALLBACKS ---

  @impl true
  def init(_) do
    Process.send_after(self(), :schedule_respawn, 5_000)
    {:ok, nil}
  end

  def handle_info({:schedule_respawn, %{}}, state) do
    # Process.send_after(self(), :schedule_respawn, 5_000)
    {:noreply, state}
  end


  @impl true
  def handle_info(:schedule_respawn, state) do
    Logger.info(">>> Spawner: Iniciando spawn sequencial controlado...")

    Enum.each(@mobs_config, fn config ->
      case Room1.get_all_walkable_tiles(config.zone) do
        [] ->
          Logger.error("Spawner: Zona #{config.zone} vazia!")

        spawn_points when is_list(spawn_points) ->
          # Dispara a Task única (Fire and Forget)
          spawn_zone_mobs_sequentially(config.zone, config.type, config.count, spawn_points)
      end
    end)

    {:noreply, state}
  end

  # --- LÓGICA DE SPAWN SEQUENCIAL ---

  defp spawn_zone_mobs_sequentially(zone, type, count, spawn_points_list) do
    # Convertemos para tupla para acesso rápido O(1) sem percorrer lista ligada
    spawn_tuple = List.to_tuple(spawn_points_list)
    total_points = tuple_size(spawn_tuple)

    # Iniciamos UMA única Task. Isso libera o GenServer principal imediatamente.
    # Não usamos Task.async (que espera resposta), usamos Task.start (fogo e esquece).
    Task.start(fn ->
      Logger.info(">>> Iniciando loop sequencial para #{count} #{type}s...")
      start_time = System.monotonic_time(:millisecond)

      # Loop recursivo ou Enum.each.
      # Usaremos reduce para manter contagem e aplicar o throttle.
      Enum.reduce(1..count, 0, fn i, _acc ->
        # 1. Lógica do Spawn
        spawn_one_mob(i, zone, type, spawn_tuple, total_points)

        # 2. Mecanismo de "Respiro" (Throttle)
        # Se o resto da divisão do índice atual pelo tamanho do lote for 0...
        if rem(i, @throttle_batch) == 0 do
          # ...damos uma pequena pausa.
          Process.sleep(@throttle_sleep_ms)
        end

        # Log de progresso a cada 10.000 (opcional, para não sujar o log)
        if rem(i, 10_000) == 0 do
          Logger.info("Progresso: #{i} / #{count} mobs criados...")
        end

        i
      end)

      time_taken = System.monotonic_time(:millisecond) - start_time
      Logger.info(">>> Spawn finalizado! #{count} mobs em #{time_taken}ms.")
    end)
  end

  defp spawn_one_mob(i, zone, type, spawn_tuple, total_points) do
    unique_id = "#{type}_#{zone}_#{i}_#{System.unique_integer([:positive])}"

    # Sorteio rápido
    idx = :rand.uniform(total_points) - 1
    {x, y} = elem(spawn_tuple, idx)

    # Chama o Supervisor
    # Como estamos em um processo único sequencial, se isso demorar,
    # o próximo mob espera, evitando sobrecarga.
    EnemySupervisor.start_enemy(%{
      id: unique_id,
      type: type,
      x: x,
      y: y
    })
  end
end
