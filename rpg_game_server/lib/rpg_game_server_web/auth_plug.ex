defmodule RpgGameServerWeb.AuthPlug do
  import Plug.Conn
  import Phoenix.Controller

  # Alias para a Struct do Usuário para podermos fazer Pattern Matching
  alias RpgGameServer.Accounts.User
  alias RpgGameServer.SessionTokenCache

  def init(opts), do: opts

  def call(conn, _opts) do
    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         %User{} = user <- SessionTokenCache.get(token) do
      assign(conn, :current_user, user)
    else
      _ ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Não autorizado: Token inválido ou expirado"})
        |> halt()
    end
  end
end
