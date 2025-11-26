defmodule RpgGameServerWeb.Channels.RoomChannel do
  use RpgGameServerWeb, :channel
  alias RpgGameServerWeb.Presence
  require Logger

  @impl true
  def join("room:lobby", payload, socket) do
    send(self(), {:after_join, payload})
    {:ok, socket}
  end

  @impl true
  def handle_info({:after_join, payload}, socket) do
    user_id = socket.assigns.current_user_id

    x = Map.get(payload, "x", 200)
    y = Map.get(payload, "y", 200)
    spr = Map.get(payload, "spr", 0)

    # Recupera o objeto char e o nome
    char = Map.get(payload, "char", %{})

    # --- NOVO: Extrai o nome e salva no Socket ---
    # Como você confirmou que "name" existe, pegamos direto.
    # Usamos Map.get para garantir que não quebre caso venha nil por algum bug.
    char_name = Map.get(char, "name", "Player #{user_id}")

    # Atualizamos o socket com o nome para usar no chat depois
    socket = assign(socket, :char_name, char_name)

    # 1. Rastreia no Presence
    {:ok, _} =
      Presence.track(socket, user_id, %{
        x: x,
        y: y,
        spr: spr,
        char: char,
        online_at: System.system_time(:second)
      })
    push(socket, "welcome", %{my_id: user_id})
    # 2. Manda lista para quem entrou
    push(socket, "current_players", %{players: list_present_players(socket)})

    # 3. Welcome

    # 4. Broadcast de entrada
    broadcast_from!(socket, "player_moved", %{
      id: user_id,
      x: x,
      y: y,
      spr: spr,
      char: char
    })

    # IMPORTANTE: Retornar o socket atualizado (com o assign do nome)
    {:noreply, socket}
  end

  # --- NOVO: Handler de Chat ---
  # Recebe "text" do GameMaker e devolve para todos com o nome do sender
  @impl true
  def handle_in("new_msg", %{"text" => text}, socket) do
    sender_name = socket.assigns.char_name
    Logger.debug("Receive message from #{sender_name}: #{text}")
    broadcast!(socket, "new_msg", %{
      text: text,
      sender: sender_name,
      type: "global"
    })

    {:noreply, socket}
  end

  @impl true
  def handle_in("move", %{"x" => x, "y" => y} = payload, socket) do
    user_id = socket.assigns.current_user_id
    spr = Map.get(payload, "spr", 0)

    Presence.update(socket, user_id, fn meta ->
      Map.merge(meta, %{x: x, y: y, spr: spr})
    end)

    final_payload = Map.put(payload, "id", user_id)
    broadcast_from!(socket, "player_moved", final_payload)

    {:noreply, socket}
  end

  @impl true
  def terminate(_reason, socket) do
    user_id = socket.assigns.current_user_id
    broadcast_from(socket, "player_left", %{id: user_id})
    :ok
  end

  defp list_present_players(socket) do
    Presence.list(socket)
    |> Enum.map(fn {id, data} ->
      meta = List.first(data.metas)

      %{
        id: id,
        x: meta.x,
        y: meta.y,
        spr: meta.spr,
        char: Map.get(meta, :char, %{})
      }
    end)
  end
end
