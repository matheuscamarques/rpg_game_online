defmodule RpgGameServer.Game.ShardManager do
  alias RpgGameServer.Game.PlayerSpatialGrid
  use GenServer

  # Nome para facilitar o acesso
  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_) do
    PlayerSpatialGrid.init()
    # Tabela Index continua sendo criada aqui ou no SpatialGrid,
    # mas o ideal é centralizar criações de tabela aqui.
    {:ok, %{}}
  end

  # API Pública
  def ensure_shard_exists(table_name) do
    # Otimização: Primeiro checa localmente se existe (rápido)
    if :ets.info(table_name) == :undefined do
      # Se não existe, pede pro GenServer criar (síncrono e seguro)
      GenServer.call(__MODULE__, {:create_shard, table_name})
    else
      :ok
    end
  end

  # Callback do GenServer
  def handle_call({:create_shard, table_name}, _from, state) do
    # Checa de novo dentro do processo único (Double-check locking pattern)
    if :ets.info(table_name) == :undefined do
      :ets.new(table_name, [
        :bag,
        :named_table,
        :public,
        {:read_concurrency, true},
        {:write_concurrency, true}
      ])
    end
    {:reply, :ok, state}
  end
end
