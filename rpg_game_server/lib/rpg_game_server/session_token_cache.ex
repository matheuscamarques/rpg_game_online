defmodule RpgGameServer.SessionTokenCache do
  use Nebulex.Cache,
    otp_app: :rpg_game_server,
    adapter: Application.compile_env(:rpg_game_server, RpgGameServer.SessionTokenCache)[:adapter],
    gc_interval: :timer.hours(12),
    max_size: 1_000_000,
    allocated_memory: 2_000_000_000,
    gc_cleanup_min_timeout: :timer.seconds(10),
    gc_cleanup_max_timeout: :timer.minutes(10),
    backend: :shards,
    partitions: System.schedulers_online() * 2
end
