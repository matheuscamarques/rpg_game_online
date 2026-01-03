defmodule RpgGameServer.Game.Room1 do
  use GenServer
  require Logger

  @table :room1_data_table

  # --- CLIENT API ---

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  # ===================================================================
  # FUNÇÕES PÚBLICAS FALTANTES (Corrigindo Warnings)
  # ===================================================================

  # NOVO: Função para obter o tamanho do tile (chamada por EnemyAI)
  def get_cell_size() do
    case :ets.lookup(@table, :config_cell_size) do
      [{_, cell_size}] -> cell_size
      # Fallback
      [] -> 32
    end
  end

  # NOVO: Função otimizada de colisão (chamada por EnemyAI com cell_size)
  def is_blocked?(pixel_x, pixel_y, cell_size) do
    # Conversão direta de pixel para coordenadas de tile
    tile_x = floor(pixel_x / cell_size)
    tile_y = floor(pixel_y / cell_size)

    case :ets.lookup(@table, {tile_x, tile_y}) do
      # Parede (valor 1)
      [{{^tile_x, ^tile_y}, 1}] -> true
      # Livre (valor 0)
      [{{^tile_x, ^tile_y}, 0}] -> false
      # Fora do mapa (ou não mapeado)
      # É mais seguro assumir bloqueado se não estiver mapeado.
      _ -> true
    end
  end

  # ===================================================================

  # Retorna a lista completa de tiles/pixels {x,y} definidos para aquela zona.
  def get_all_walkable_tiles(zone_id) do
    # Garante que a chave seja string
    key = to_string(zone_id)

    case :ets.lookup(@table, {:spawn_zone, key}) do
      # Retorna a lista de tuplas [{x,y}, {x,y}, ...]
      [{_, coords_list}] -> coords_list
      # Se a zona não existir, retorna lista vazia
      [] -> []
    end
  end

  # Converte pixel -> tile e verifica colisão (versão antiga/não otimizada)
  def is_blocked?(pixel_x, pixel_y) do
    case get_cell_size() do
      cell_size when is_integer(cell_size) -> is_blocked?(pixel_x, pixel_y, cell_size)
      _ -> true
    end
  end

  # Mantido para compatibilidade, caso use spawns unitários em outro lugar
  def get_random_spawn(zone_id) do
    key = to_string(zone_id)

    case :ets.lookup(@table, {:spawn_zone, key}) do
      [{_, coords_list}] -> Enum.random(coords_list)
      [] -> nil
    end
  end

  # --- SERVER CALLBACKS ---

  @impl true
  def init(_) do
    # :protected permite que EnemySpawner LEIA a tabela diretamente
    :ets.new(@table, [:set, :named_table, :protected, {:read_concurrency, true}])

    # Tabela auxiliar de posições (se necessário)
    if :ets.info(:enemy_positions) == :undefined do
      :ets.new(:enemy_positions, [:set, :named_table, :public, {:read_concurrency, true}])
    end

    send(self(), :load_data)
    {:ok, %{}}
  end

  @impl true
  def handle_info(:load_data, state) do
    path = Application.app_dir(:rpg_game_server, "priv/rooms/Room1.json")

    with {:ok, body} <- File.read(path),
         {:ok, json} <- Jason.decode(body) do
      Logger.info(">>> Room1: Carregando dados do mapa...")

      cell_size = json["cell_size"]
      :ets.insert(@table, {:config_cell_size, cell_size})

      # 1. Carregar Colisões
      json["collisions"]
      |> Enum.with_index()
      |> Enum.each(fn {row, y} ->
        Enum.with_index(row)
        |> Enum.each(fn {val, x} ->
          :ets.insert(@table, {{x, y}, val})
        end)
      end)

      # 2. Carregar Spawns (Mantido em Coordenadas de Tile, conforme seu código original)
      json["spawns"]
      |> Enum.each(fn {zone_id, list} ->
        clean_list = Enum.map(list, fn point -> {point["x"], point["y"]} end)
        :ets.insert(@table, {{:spawn_zone, zone_id}, clean_list})
      end)

      Logger.info(">>> Room1: Mapa carregado (Spawns e Colisões prontos).")
    else
      err -> Logger.error(">>> Room1: Erro crítico ao carregar mapa: #{inspect(err)}")
    end

    {:noreply, state}
  end
end
