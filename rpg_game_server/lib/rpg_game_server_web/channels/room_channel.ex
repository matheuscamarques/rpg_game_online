defmodule RpgGameServerWeb.Channels.RoomChannel do
  use RpgGameServerWeb, :channel
  alias RpgGameServerWeb.Presence
  require Logger

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

    socket = assign(socket, :char_name, char_name)

    # Rastreia no Presence
    {:ok, _} = Presence.track(socket, user_id, Map.put(player_state, :online_at, System.system_time(:second)))

    push(socket, "welcome", %{my_id: user_id})
    push(socket, "current_players", %{players: list_present_players(socket)})

    # Broadcast da entrada visual
    broadcast_movement(socket, player_state, user_id)

    {:noreply, socket}
  end

  @impl true
  def handle_in("move", payload, socket) do
    user_id = socket.assigns.current_user_id

    # Extrai apenas os campos permitidos (segurança)
    changes = parse_incoming_changes(payload)

    # Atualiza o Presence
    Presence.update(socket, user_id, fn current_meta ->
      Map.merge(current_meta, changes)
    end)

    # Broadcast de movimento
    broadcast_movement(socket, changes, user_id)

    {:noreply, socket}
  end

  @impl true
  def handle_in("new_msg", %{"text" => text}, socket) do
    sender_name = socket.assigns.char_name
    Logger.debug("Chat from #{sender_name}: #{text}")
    broadcast!(socket, "new_msg", %{text: text, sender: sender_name, type: "global"})
    {:noreply, socket}
  end

  # --- LÓGICA DE COMBATE CENTRALIZADA ---
  @impl true
  def handle_in("attack_hit", payload, socket) do
    attacker_id = socket.assigns.current_user_id
    target_id = Map.get(payload, "target_id")

    # Busca posição de quem bateu
    attacker_pos = get_player_pos(socket, attacker_id)

    # 1. TENTA ACHAR PLAYER (PvP via Presence)
    target_player_pos = get_player_pos(socket, target_id)

    if target_player_pos do
      # --- Lógica PvP ---
      process_pvp_hit(socket, attacker_id, target_id, attacker_pos, target_player_pos)
    else
      # 2. TENTA ACHAR INIMIGO (PvE via Registry)
      process_pve_hit(attacker_id, target_id)
    end

    {:noreply, socket}
  end

  @impl true
  def terminate(_reason, socket) do
    user_id = socket.assigns.current_user_id
    broadcast_from(socket, "player_left", %{id: user_id})
    :ok
  end

  # ===================================================================
  # FUNÇÕES PRIVADAS DE LÓGICA DE JOGO
  # ===================================================================

  defp process_pvp_hit(socket, attacker_id, target_id, attacker_pos, target_pos) do
    # Alcance em pixels + tolerância de lag
    max_reach = 70.0

    if is_valid_hit?(attacker_pos, target_pos, max_reach) do
      damage = 10 # Pode vir do banco de dados futuramente

      broadcast!(socket, "damage_applied", %{
        target_id: target_id,
        attacker_id: attacker_id,
        damage: damage,
        type: "pvp"
      })
      Logger.info("PvP Hit: #{attacker_id} -> #{target_id}")
    else
      Logger.warning("PvP Hit Inválido (Range): #{attacker_id} -> #{target_id}")
    end
  end

  defp process_pve_hit(attacker_id, target_id) do
    # Busca o PID do inimigo no Registry
    case Registry.lookup(RpgGameServer.EnemyRegistry, target_id) do
      [{pid, _}] ->
        # Envia mensagem direta ao processo do inimigo
        GenServer.cast(pid, {:take_damage, 10, attacker_id})
        Logger.warning("PvE Hit enviado: #{attacker_id} -> #{target_id}")

      [] ->
        Logger.warning("Alvo não encontrado (nem player, nem mob): #{target_id}")
    end
  end

  defp is_valid_hit?({ax, ay}, {tx, ty}, reach) do
    dx = ax - tx
    dy = ay - ty
    distance = :math.sqrt(dx * dx + dy * dy)
    distance <= reach
  end
  # Fallback se posições forem nil
  defp is_valid_hit?(_, _, _), do: false

  # ===================================================================
  # HELPERS DE DADOS E PARSING
  # ===================================================================

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
    # Whitelist de campos atualizáveis via move
    allowed_keys = ~w(x y spr state face)

    payload
    |> Map.take(allowed_keys)
    |> Map.new(fn {k, v} -> {String.to_atom(k), v} end)
  end

  defp broadcast_movement(socket, data, user_id) do
    payload = Map.put(data, :id, user_id)
    broadcast_from!(socket, "player_moved", payload)
  end

  defp list_present_players(socket) do
    Presence.list(socket)
    |> Enum.map(fn {id, data} ->
      meta = List.first(data.metas)
      Map.merge(@default_state, meta)
      |> Map.take([:x, :y, :spr, :state, :face, :char])
      |> Map.put(:id, id)
    end)
  end
end
