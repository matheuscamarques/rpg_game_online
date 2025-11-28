defmodule RpgGameServerWeb.Channels.RoomChannel do
  use RpgGameServerWeb, :channel
  alias RpgGameServerWeb.Presence

  # Alias do novo Grid de Players
  alias RpgGameServer.Game.PlayerSpatialGrid

  require Logger

  @cell_size 600

  # Definição do estado padrão para garantir consistência
  @default_state %{
    x: 200,
    y: 200,
    spr: 0,
    state: 0,
    face: 270,
    char: %{}
  }

  @impl true
  def join("room:lobby", payload, socket) do
    send(self(), {:after_join, payload})
    {:ok, socket}
  end

  @impl true
  def handle_info({:after_join, payload}, socket) do
    user_id = socket.assigns.current_user_id

    # Normaliza o input combinando com os defaults
    player_state = parse_player_state(payload)
    char_name = get_in(player_state, [:char, "name"]) || "Player #{user_id}"

    # 1. Configura Socket Inicial e salva posição inicial para o Grid
    socket = socket
             |> assign(:char_name, char_name)
             |> assign(:last_x, player_state.x) # <--- CRUCIAL para o Grid Update/Remove
             |> assign(:last_y, player_state.y)

    # 2. INICIALIZAÇÃO AOI: Inscreve nos tópicos da área
    socket = update_aoi_subscriptions(socket, player_state.x, player_state.y)

    # 3. OTIMIZAÇÃO: Insere o Player no Grid Espacial (Para IAs o acharem)
    PlayerSpatialGrid.insert(user_id, player_state.x, player_state.y)

    # Rastreia no Presence
    {:ok, _} =
      Presence.track(
        socket,
        user_id,
        Map.put(player_state, :online_at, System.system_time(:second))
      )

    push(socket, "welcome", %{my_id: user_id})
    push(socket, "current_players", %{players: list_present_players(socket)})

    # Broadcast da entrada visual
    broadcast_movement(socket, player_state, user_id)

    {:noreply, socket}
  end

  # HANDLER IMPORTANTE PARA AOI (Repassa mensagens de Broadcast para o Client)
  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: event, payload: payload}, socket) do
    push(socket, event, payload)
    {:noreply, socket}
  end

  @impl true
  def handle_in("move", payload, socket) do
    user_id = socket.assigns.current_user_id

    # Extrai apenas os campos permitidos
    changes = parse_incoming_changes(payload)

    # Verifica se houve movimento físico (X ou Y mudou)
    {socket, moved?} =
      if Map.has_key?(changes, :x) and Map.has_key?(changes, :y) do

        # A. Atualiza AOI (Inscrições de Rede)
        sock_aoi = update_aoi_subscriptions(socket, changes.x, changes.y)

        # B. OTIMIZAÇÃO: Atualiza Grid Espacial (Para IAs)
        # Usa last_x/y salvo no socket para remover da célula antiga
        PlayerSpatialGrid.update(user_id, sock_aoi.assigns.last_x, sock_aoi.assigns.last_y, changes.x, changes.y)

        # C. Atualiza last_x/y no socket para a próxima vez
        new_sock = assign(sock_aoi, last_x: changes.x, last_y: changes.y)

        {new_sock, true}
      else
        {socket, false}
      end

    # Atualiza o Presence
    Presence.update(socket, user_id, fn current_meta ->
      Map.merge(current_meta, changes)
    end)

    # Broadcast de movimento (Se não moveu fisicamente, ainda pode ter mudado Sprite/State)
    broadcast_movement(socket, changes, user_id)

    {:noreply, socket}
  end

  @impl true
  def handle_in("new_msg", %{"text" => text}, socket) do
    sender_name = socket.assigns.char_name
    broadcast!(socket, "new_msg", %{text: text, sender: sender_name, type: "global"})
    {:noreply, socket}
  end

  # --- LÓGICA DE COMBATE ---
  @impl true
  def handle_in("attack_hit", payload, socket) do
    attacker_id = socket.assigns.current_user_id
    target_id = Map.get(payload, "target_id")

    attacker_pos = get_player_pos(socket, attacker_id)
    target_player_pos = get_player_pos(socket, target_id)

    if target_player_pos do
      process_pvp_hit(socket, attacker_id, target_id, attacker_pos, target_player_pos)
    else
      process_pve_hit(attacker_id, target_id)
    end

    {:noreply, socket}
  end

  @impl true
  def terminate(_reason, socket) do
    user_id = socket.assigns.current_user_id

    # 4. OTIMIZAÇÃO: Remove o player do Grid ao sair
    # Usamos as coordenadas salvas no socket, pois o Presence já pode estar inacessível
    if Map.has_key?(socket.assigns, :last_x) do
      PlayerSpatialGrid.remove(user_id, socket.assigns.last_x, socket.assigns.last_y)
    end

    broadcast_from(socket, "player_left", %{id: user_id})
    :ok
  end

  # ===================================================================
  # LÓGICA DE AREA OF INTEREST (AOI)
  # ===================================================================

  defp update_aoi_subscriptions(socket, x, y) do
    new_cx = floor(x / @cell_size)
    new_cy = floor(y / @cell_size)

    old_cx = Map.get(socket.assigns, :current_cx)
    old_cy = Map.get(socket.assigns, :current_cy)

    if new_cx != old_cx or new_cy != old_cy do
      new_topics = get_neighbor_topics(new_cx, new_cy)
      old_topics = Map.get(socket.assigns, :subscribed_topics, [])

      to_leave = old_topics -- new_topics
      to_join = new_topics -- old_topics

      Enum.each(to_leave, fn topic -> RpgGameServerWeb.Endpoint.unsubscribe(topic) end)
      Enum.each(to_join, fn topic -> RpgGameServerWeb.Endpoint.subscribe(topic) end)

      socket
      |> assign(:current_cx, new_cx)
      |> assign(:current_cy, new_cy)
      |> assign(:subscribed_topics, new_topics)
    else
      socket
    end
  end

  defp get_neighbor_topics(cx, cy) do
    for dx <- -1..1, dy <- -1..1 do
      "area:#{cx + dx}:#{cy + dy}"
    end
  end

  # ===================================================================
  # HELPERS
  # ===================================================================

  defp process_pvp_hit(socket, attacker_id, target_id, attacker_pos, target_pos) do
    max_reach = 70.0
    if is_valid_hit?(attacker_pos, target_pos, max_reach) do
      damage = Enum.random(1..1000)
      broadcast!(socket, "damage_applied", %{target_id: target_id, attacker_id: attacker_id, damage: damage, type: "pvp"})
    end
  end

  defp process_pve_hit(attacker_id, target_id) do
    case Registry.lookup(RpgGameServer.EnemyRegistry, target_id) do
      [{pid, _}] -> GenServer.cast(pid, {:take_damage, Enum.random(1..1000), attacker_id})
      [] -> Logger.warning("Alvo não encontrado: #{target_id}")
    end
  end

  defp is_valid_hit?({ax, ay}, {tx, ty}, reach) do
    distance = :math.sqrt(:math.pow(ax - tx, 2) + :math.pow(ay - ty, 2))
    distance <= reach
  end
  defp is_valid_hit?(_, _, _), do: false

  defp get_player_pos(socket, user_id) when is_number(user_id), do: get_player_pos(socket, "#{user_id}")
  defp get_player_pos(socket, user_id) do
    case Presence.list(socket) |> Map.get(user_id) do
      %{metas: [meta | _]} -> {meta.x, meta.y}
      _ -> nil
    end
  end

  defp parse_player_state(payload) do
    Enum.reduce(@default_state, %{}, fn {key, default}, acc ->
      val = Map.get(payload, Atom.to_string(key), default)
      Map.put(acc, key, val)
    end)
  end

  defp parse_incoming_changes(payload) do
    allowed_keys = ~w(x y spr state face)
    payload |> Map.take(allowed_keys) |> Map.new(fn {k, v} -> {String.to_atom(k), v} end)
  end

  defp broadcast_movement(socket, data, user_id) do
    payload = Map.put(data, :id, user_id)
    broadcast_from!(socket, "player_moved", payload)
  end

  defp list_present_players(socket) do
    Presence.list(socket)
    |> Enum.map(fn {id, data} ->
      meta = List.first(data.metas)
      Map.merge(@default_state, meta) |> Map.take([:x, :y, :spr, :state, :face, :char]) |> Map.put(:id, id)
    end)
  end
end
