defmodule RpgGameServer.Game.EnemySpawner do
  use GenServer
  # Certifique-se que Room1 é o nome correto do seu MapServer
  alias RpgGameServer.Game.Room1
  alias RpgGameServer.Game.EnemySupervisor
  require Logger

  @respawn_time 5000 # Aumentei para 5s para dar tempo de ver o bicho morto

  # Configuração do Level
  @mobs_config [
    %{zone: "1", type: "human", count: 5},
  ]

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @impl true
  def init(_) do
    # Espera 2 segundos pro MapServer carregar antes de spawnar
    Process.send_after(self(), :spawn_wave, 2000)
    {:ok, nil}
  end

  @impl true
  def handle_info(:spawn_wave, state) do
    Logger.info(">>> Spawner: Iniciando spawn dos monstros...")

    Enum.each(@mobs_config, fn config ->
      spawn_zone_mobs(config.zone, config.type, config.count)
    end)

    {:noreply, state}
  end

  @impl true
  def handle_info({:schedule_respawn, params}, state) do
    # Agenda o respawn
    Process.send_after(self(), {:respawn_mob, params}, @respawn_time)
    {:noreply, state}
  end

  @impl true
  def handle_info({:respawn_mob, params}, state) do
    # CORREÇÃO:
    # Ao renascer, precisamos gerar um ID novo para garantir que não conflite
    # com o ID antigo que acabou de morrer (caso o Registry demore ms para limpar).
    # Usamos System.unique_integer para garantir unicidade.

    new_id = "#{params.type}_#{params.zone}_#{System.unique_integer([:positive])}"

    # Chama a função auxiliar criada abaixo
    create_mob_process(params.type, params.zone, new_id)

    {:noreply, state}
  end

  # --- LÓGICA DE LOOP INICIAL ---
  defp spawn_zone_mobs(zone, type, count) do
    1..count
    |> Enum.each(fn i ->
      # Gera ID sequencial bonito para o início (ex: human_1_0, human_1_1)
      unique_id = "#{type}_#{zone}_#{i}"
      create_mob_process(type, zone, unique_id)
    end)
  end

  # --- FUNÇÃO AUXILIAR DE CRIAÇÃO (Extraída para reuso) ---
  defp create_mob_process(type, zone, unique_id) do
    # Pede ao MapServer (Room1) uma posição válida daquela zona
    case Room1.get_random_spawn(zone) do
      {x, y} ->
         # Inicia o processo do inimigo via Supervisor
         EnemySupervisor.start_enemy(%{
           id: unique_id,
           type: type,
           x: x,
           y: y
         })

         # Logger.debug("Mob spawnado: #{unique_id} em {#{x}, #{y}}")

      nil ->
         Logger.warning("Spawner: Zona #{zone} sem pontos de spawn definidos no JSON!")
    end
  end
end
