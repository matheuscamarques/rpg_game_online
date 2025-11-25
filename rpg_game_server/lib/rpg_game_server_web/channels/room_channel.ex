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

    # Se o GM não mandar o char, garantimos um mapa vazio para não quebrar
    char = Map.get(payload, "char", %{})

    # 1. Rastreia no Presence
    {:ok, _} =
      Presence.track(socket, user_id, %{
        x: x,
        y: y,
        spr: spr,
        char: char, # Salvamos o objeto completo aqui!
        online_at: System.system_time(:second)
      })

    # 2. Manda lista para quem entrou (COM OS DADOS DE CHAR)
    push(socket, "current_players", %{players: list_present_players(socket)})

    # 3. Welcome
    push(socket, "welcome", %{my_id: user_id})

    # 4. Broadcast de entrada (COM OS DADOS DE CHAR)
    # Se não mandar o char aqui, os outros jogadores não saberão seu nome/classe
    broadcast_from!(socket, "player_moved", %{
      id: user_id,
      x: x,
      y: y,
      spr: spr,
      char: char
    })

    {:noreply, socket}
  end

  @impl true
  def handle_in("move", %{"x" => x, "y" => y} = payload, socket) do
    user_id = socket.assigns.current_user_id
    spr = Map.get(payload, "spr", 0)

    # Atualiza Presence (Não precisa atualizar 'char' toda hora, ele não muda andando)
    Presence.update(socket, user_id, fn meta ->
      Map.merge(meta, %{x: x, y: y, spr: spr})
    end)

    # Broadcast de movimento
    final_payload = Map.put(payload, "id", user_id)
    broadcast_from!(socket, "player_moved", final_payload)

    {:noreply, socket}
  end

  # Faltava o terminate para limpar o boneco no GameMaker quando fecha o jogo
  @impl true
  def terminate(_reason, socket) do
    user_id = socket.assigns.current_user_id
    broadcast_from(socket, "player_left", %{id: user_id})
    :ok
  end

  # Função auxiliar corrigida para incluir o CHAR
  defp list_present_players(socket) do
    Presence.list(socket)
    |> Enum.map(fn {id, data} ->
      meta = List.first(data.metas)

      # Retorna tudo, incluindo o objeto char que salvamos no track
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
