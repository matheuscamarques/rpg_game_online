defmodule RpgGameServer.Game.Room1 do
  use GenServer
  require Logger

  @table :room1_data_table

  # --- CLIENT API ---

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  # Converte pixel -> tile e verifica colisão
  def is_blocked?(pixel_x, pixel_y) do
    # 1. Busca o tamanho da célula (config)
    case :ets.lookup(@table, :config_cell_size) do
      [{_, cell_size}] ->
        # 2. Converte Pixel para Grid
        tile_x = floor(pixel_x / cell_size)
        tile_y = floor(pixel_y / cell_size)

        # 3. Verifica se é parede (1) ou livre (0)
        case :ets.lookup(@table, {tile_x, tile_y}) do
          [{{^tile_x, ^tile_y}, 1}] -> true   # Parede!
          [{{^tile_x, ^tile_y}, 0}] -> false  # Livre
          [] -> true # Fora do mapa é parede
        end

      [] -> true # Se não carregou config, bloqueia tudo por segurança
    end
  end

  # Retorna um ponto aleatório de uma zona específica
  def get_random_spawn(zone_id) do
    # O JSON usa strings para chaves ("1", "2"), então convertemos se vier int
    key = to_string(zone_id)

    case :ets.lookup(@table, {:spawn_zone, key}) do
      [{_, coords_list}] -> Enum.random(coords_list)
      [] -> nil
    end
  end

  # --- SERVER CALLBACKS ---

  @impl true
  def init(_) do
    # Cria tabela ETS otimizada para leitura concorrente
    :ets.new(@table, [:set, :named_table, :protected, {:read_concurrency, true}])
    # Pode colocar no init do MapServer ou EnemySpawner
    :ets.new(:enemy_positions, [:set, :named_table, :public, {:read_concurrency, true}])
    # Carrega os dados assincronamente para não travar o boot do app
    send(self(), :load_data)
    {:ok, %{}}
  end

  @impl true
  def handle_info(:load_data, state) do
    path = Application.app_dir(:rpg_game_server, "priv/rooms/Room1.json")

    with {:ok, body} <- File.read(path),
         {:ok, json} <- Jason.decode(body) do

      Logger.info(">>> MapServer: Carregando JSON...")

      cell_size = json["cell_size"]
      :ets.insert(@table, {:config_cell_size, cell_size})

      # 1. Carregar Colisões (Matriz)
      json["collisions"]
      |> Enum.with_index()
      |> Enum.each(fn {row, y} ->
        Enum.with_index(row)
        |> Enum.each(fn {val, x} ->
          :ets.insert(@table, {{x, y}, val})
        end)
      end)

      # 2. Carregar Spawns (Map/Struct)
      json["spawns"]
      |> Enum.each(fn {zone_id, list} ->
        # Converte lista de maps [%{"x"=>10...}] para lista de atoms/tuplas [{x,y}...]
        clean_list = Enum.map(list, fn point -> {point["x"], point["y"]} end)
        :ets.insert(@table, {{:spawn_zone, zone_id}, clean_list})
      end)

      Logger.info(">>> Room1: Mapa carregado com sucesso!")
    else
      err -> Logger.error(">>> Room1: Erro ao carregar mapa: #{inspect(err)}")
    end

    {:noreply, state}
  end
end
