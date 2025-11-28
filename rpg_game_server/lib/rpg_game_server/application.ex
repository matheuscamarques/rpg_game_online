defmodule RpgGameServer.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false
  alias RpgGameServer.SessionTokenCache

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      RpgGameServerWeb.Telemetry,
      RpgGameServer.Repo,
      {DNSCluster, query: Application.get_env(:rpg_game_server, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: RpgGameServer.PubSub},
      # Start a worker by calling: RpgGameServer.Worker.start_link(arg)
      # {RpgGameServer.Worker, arg},
      # Start to serve requests, typically the last entry
      RpgGameServerWeb.Endpoint,
      RpgGameServerWeb.Presence,
      {SessionTokenCache, []},
      {PartitionSupervisor,
       child_spec: RpgGameServer.Game.WorldTickerWorker, name: RpgGameServer.WorldTickerPartition},
      # 1. Inicia o MapServer (Precisa ser antes do Spawner)
      RpgGameServer.Game.Room1,
      {Registry, keys: :unique, name: RpgGameServer.EnemyRegistry},
      # 2. Inicia o Supervisor Dinâmico (Para os Mobs viverem dentro)
      {PartitionSupervisor,
       child_spec: DynamicSupervisor, name: RpgGameServer.Game.EnemySupervisor},

      # 3. Inicia o Spawner (Que vai usar os dois acima)
      RpgGameServer.Game.EnemySpawner
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: RpgGameServer.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    RpgGameServerWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
