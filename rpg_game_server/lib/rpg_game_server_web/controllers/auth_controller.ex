defmodule RpgGameServerWeb.AuthController do
  alias RpgGameServer.Accounts
  use RpgGameServerWeb, :controller

  def login(conn, %{"username" => username, "password" => password}) do
    case Accounts.authenticate_user(username, password) do
      {:ok, _, token} ->
        conn
        |> put_status(:ok)
        |> json(%{status: "success", token: token})

      {:error, _reason} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{status: "error", message: "Credenciais inválidas"})
    end
  end

  def register(conn, %{"username" => user, "password" => pass, "email" => email}) do
    case Accounts.create_user(%{username: user, email: email, password: pass}) do
      {:ok, _user} ->
        conn
        |> put_status(:created)
        |> json(%{status: "success", message: "Conta criada!"})

      {:error, changeset} ->
        errors = Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)

        conn
        |> put_status(:bad_request)
        |> json(%{status: "error", message: "Erro ao criar", errors: errors})
    end
  end
end
