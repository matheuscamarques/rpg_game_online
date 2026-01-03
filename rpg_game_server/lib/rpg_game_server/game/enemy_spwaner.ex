defmodule RpgGameServer.Game.EnemySpawner do
  use GenServer
  require Logger

  alias RpgGameServer.Game.EnemySupervisor
  alias RpgGameServer.Game.Room1

  # Configuração
  @mobs_config [
    %{zone: "1", type: "human", count: 100}
  ]


  @throttle_batch 10
  @throttle_sleep_ms 10
  @group_size 1

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

  @impl true
  def handle_info(:schedule_respawn, state) do
    Logger.info(">>> Spawner: Iniciando spawn em SQUADS de #{@group_size}...")

    Enum.each(@mobs_config, fn config ->
      # NÃO CHAMA MAIS get_all_walkable_tiles
      spawn_zone_mobs_in_groups(config.zone, config.type, config.count)
    end)

    {:noreply, state}
  end

  @impl true
  def handle_info({:schedule_respawn, %{}}, state) do
    Logger.info(">>> Spawner: Iniciando spawn sequencial controlado...")

    Enum.each(@mobs_config, fn config ->
      # Dispara a Task única (Fire and Forget)
      # NÃO CHAMA MAIS get_all_walkable_tiles
      spawn_zone_mobs_in_groups(config.zone, config.type, 1)
    end)

    {:noreply, state}
  end

  # Ignora mensagens extras
  def handle_info(_, state), do: {:noreply, state}

  # --- LÓGICA DE SPAWN EM GRUPO (AJUSTADA) ---

  # A lista de pontos de spawn foi removida dos argumentos
  defp spawn_zone_mobs_in_groups(zone, type, total_count) do
    # Calcula o total de grupos necessários
    total_groups = :erlang.ceil(total_count / @group_size) |> trunc()

    Task.start(fn ->
      Logger.info(">>> Iniciando loop para #{total_groups} grupos (Total: #{total_count})...")

      start_time = System.monotonic_time(:millisecond)

      Enum.reduce(1..total_groups, 0, fn group_idx, mobs_spawned ->
        remaining_mobs = total_count - mobs_spawned
        current_group_size = min(@group_size, remaining_mobs)

        # 1. NOVO: Sorteia a posição chamando Room1.get_random_spawn/1
        case Room1.get_random_spawn(zone) do
          nil ->
            Logger.error("Spawner: Falha ao obter ponto de spawn para a zona #{zone}.")
            # Se falhar, não spawna o grupo e continua o loop
            mobs_spawned

          {group_x, group_y} ->
            # 2. Criamos os membros do grupo ao redor dessa posição
            Enum.each(1..current_group_size, fn member_idx ->
              unique_suffix = "#{group_idx}_#{member_idx}"
              # group_x e group_y são Coordenadas de PIXEL (assumindo Room1 corrigido)
              spawn_one_mob(unique_suffix, zone, type, group_x, group_y)
            end)

            # 3. Throttle
            if rem(group_idx, @throttle_batch) == 0 do
              Process.sleep(@throttle_sleep_ms)
            end

            mobs_spawned + current_group_size
        end
      end)

      time_taken = System.monotonic_time(:millisecond) - start_time
      Logger.info(">>> Spawn finalizado! #{total_count} mobs criados em #{time_taken}ms.")
    end)
  end

  defp spawn_one_mob(suffix, zone, type, base_x, base_y) do
    unique_id = "#{type}_#{zone}_#{suffix}_#{System.unique_integer([:positive])}"

    # base_x e base_y são as coordenadas de PIXEL sorteadas pelo Room1.
    EnemySupervisor.start_enemy(%{
      id: unique_id,
      type: type,
      x: base_x,
      y: base_y
    })
  end
end
