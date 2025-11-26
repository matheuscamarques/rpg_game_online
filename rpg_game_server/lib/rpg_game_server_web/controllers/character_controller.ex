defmodule RpgGameServerWeb.CharacterController do
  use RpgGameServerWeb, :controller
  alias RpgGameServer.Rpg

  # ===========================================================================
  # INDEX
  # ===========================================================================
  # Pattern Matching: Extrai 'current_user' de dentro de conn.assigns
  def index(%{assigns: %{current_user: user}} = conn, _params) do
    # Busca apenas os personagens do dono do token
    # (Você precisa garantir que essa função exista no Context Rpg, ex: where user_id == ^id)
    characters = Rpg.list_characters({:user_id, user.id})

    json_list =
      Enum.map(characters, fn c ->
        %{id: c.id, name: c.name, classe: c.class, level: c.level, sprite: c.sprite_idx}
      end)

    json(conn, %{status: "success", personagens: json_list})
  end

  # ===========================================================================
  # CREATE
  # ===========================================================================
  def create(%{assigns: %{current_user: user}} = conn, params) do
    # SEGURANÇA: Ignoramos qualquer "user_id" que venha no JSON e forçamos
    # o ID do usuário logado. Isso impede que eu crie um char na conta de outro.
    character_params = Map.put(params, "user_id", user.id)

    case Rpg.create_character(character_params) do
      {:ok, character} ->
        json(conn, %{status: "success", id: character.id})

      {:error, changeset} ->
        # Dica: É bom retornar os erros do changeset para o front saber o que houve
        errors = Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)

        conn
        |> put_status(:unprocessable_entity)
        |> json(%{status: "error", message: "Falha ao criar", errors: errors})
    end
  end

  # ===========================================================================
  # DELETE
  # ===========================================================================
  def delete(%{assigns: %{current_user: user}} = conn, %{"id" => id}) do
    # Precisamos buscar o personagem e verificar se ele pertence ao usuário logado
    case Rpg.get_character!(id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Personagem não encontrado"})

      # Verifica se o dono do personagem é o mesmo do token
      %Rpg.Character{user_id: owner_id} = character when owner_id == user.id ->
        {:ok, _} = Rpg.delete_character(character)
        json(conn, %{status: "success"})

      # Se o personagem existe mas o dono é outro
      _character ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "Você não tem permissão para deletar este personagem"})
    end
  end
end
