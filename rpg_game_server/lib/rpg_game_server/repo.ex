defmodule RpgGameServer.Repo do
  use Ecto.Repo,
    otp_app: :rpg_game_server,
    adapter: Ecto.Adapters.Postgres
end
