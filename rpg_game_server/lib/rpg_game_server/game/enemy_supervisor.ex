defmodule RpgGameServer.Game.EnemySupervisor do
  use DynamicSupervisor

  def start_link(_arg) do
    DynamicSupervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  # Função auxiliar para criar um mob dinamicamente
  def start_enemy(args) do
    spec = {RpgGameServer.Game.EnemyAI, args}
    DynamicSupervisor.start_child(__MODULE__, spec)
  end
end
