defmodule RpgGameServer.Game.ShardManager do
  alias RpgGameServer.Game.EnemySpatialGrid
  alias RpgGameServer.Game.PlayerSpatialGrid
  use GenServer

  # Tabela pública que mapeia {tipo, x_index, y_index} -> tid
  @registry_table :game_shard_registry

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_) do
    # Tabela nomeada fixa (gasta apenas 1 átomo)
    # Read concurrency é vital aqui pois todos os processos lerão daqui
    :ets.new(@registry_table, [:set, :named_table, :public, {:read_concurrency, true}])
    PlayerSpatialGrid.init()
    EnemySpatialGrid.init()
    {:ok, %{}}
  end

  # --- API Otimizada (Hot Path) ---

  @doc """
  Retorna o TID da tabela para a coordenada. Cria se não existir.
  Não gera átomos dinâmicos.
  """
  def get_or_create_shard(type, x_index, y_index) do
    key = {type, x_index, y_index}

    # 1. Tentativa de leitura rápida (sem lock/call no GenServer)
    case :ets.lookup(@registry_table, key) do
      [{^key, tid}] ->
        tid

      [] ->
        # 2. Se não existe, entra na fila do GenServer (Cold Path)
        GenServer.call(__MODULE__, {:get_or_create, key})
    end
  end

  # --- API de Leitura Segura ---

  @doc "Tenta buscar o TID, retorna nil se não existir (não cria)"
  def get_shard_tid(type, x_index, y_index) do
    key = {type, x_index, y_index}

    case :ets.lookup(@registry_table, key) do
      [{^key, tid}] -> tid
      [] -> nil
    end
  end

  # --- Callbacks ---

  def handle_call({:get_or_create, key}, _from, state) do
    # 3. Double-check locking: verifica de novo se alguém criou enquanto a msg estava na fila
    case :ets.lookup(@registry_table, key) do
      [{^key, tid}] ->
        {:reply, tid, state}

      [] ->
        # 4. Cria tabela ANÔNIMA (sem :named_table).
        # Zero átomos criados, não importa quantos shards existam.
        tid =
          :ets.new(:shard, [:bag, :public, {:read_concurrency, true}, {:write_concurrency, true}])

        :ets.insert(@registry_table, {key, tid})
        {:reply, tid, state}
    end
  end
end
