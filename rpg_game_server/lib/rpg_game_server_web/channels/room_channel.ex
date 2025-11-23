defmodule RpgGameServerWeb.Channels.RoomChannel do
  alias RpgGameServerWeb.Presence
  require Logger
  use RpgGameServerWeb, :channel

  @impl true
  @spec join(<<_::80>>, any(), Phoenix.Socket.t()) :: {:ok, Phoenix.Socket.t()}
  def join("room:lobby", _payload, socket) do
    # 1. Gera um ID temporário para esse socket (pode ser UUID ou random)
    Logger.info("ENTROU NO LOBBY")
    user_id = Integer.to_string(:rand.uniform(1_000_000))

    # 2. Salva o ID no socket para usarmos depois
    socket = assign(socket, :user_id, user_id)

    # 3. Avisa para o próprio usuário qual é o ID dele (Welcome)
    send(self(), :after_join)

    {:ok, socket}
  end

  @impl true
  # Hook para mandar mensagem logo após conectar
  def handle_info(:after_join, socket) do
    push(socket, "welcome", %{my_id: socket.assigns.user_id})
    start_x = 220;
    start_y = 150;
    spr = 0;

    {:ok, _} =
      Presence.track(socket, socket.assigns.user_id, %{
        x: start_x,
        y: start_y,
        # Sprite padrão
        spr: spr,
        online_at: System.system_time(:second)
      })

    players_list =
      Presence.list(socket)
      |> Enum.map(fn {id, data} ->
        # Pega os metadados mais recentes do usuário
        meta = List.first(data.metas)
        %{id: id, x: meta.x, y: meta.y, spr: meta.spr}
      end)
    IO.inspect(players_list)
    # 4. Envia a lista para quem acabou de entrar
    push(socket, "current_players", %{players: players_list})
    broadcast_from!(socket,"player_moved", %{id: socket.assigns.user_id,x: start_x, y: start_y,spr: spr})
    {:noreply, socket}
  end

  # Recebe movimento e espalha, ANEXANDO o ID de quem mandou
  @impl true
  def handle_in("move", %{"x" => x, "y" => y} = payload, socket) do
    user_id = socket.assigns.user_id

    # 1. Atualiza a memória do servidor (Presence)
    # Assim, quem entrar DEPOIS vai te ver na posição certa, e não no spawn.
    spr = Map.get(payload, "spr", 0)

    Presence.update(socket, user_id, fn meta ->
      Map.merge(meta, %{x: x, y: y, spr: spr})
    end)

    # 2. Broadcast normal (o código que você já tinha)
    final_payload = Map.put(payload, "id", user_id)
    broadcast_from!(socket, "player_moved", final_payload)

    {:noreply, socket}
  end

  # Quando alguém desconecta
  @impl true
  def terminate(_reason, socket) do
    broadcast_from(socket, "player_left", %{id: socket.assigns.user_id})
    :ok
  end
end
