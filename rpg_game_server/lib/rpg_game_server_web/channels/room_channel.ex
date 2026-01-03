defmodule RpgGameServerWeb.Channels.RoomChannel do
  use RpgGameServerWeb, :channel
  alias RpgGameServer.Game.Factory
  alias RpgGameServerWeb.Presence
  # <--- Adicionado ActorContext
  alias RpgGameServer.Game.{PlayerSpatialGrid, ActorContext}
  require Logger

  # Configuração AOI
  @cell_size 2100

  # Estado padrão para coordenadas e visual (Stats agora ficam no Actor)
  @default_visuals %{
    x: 200,
    y: 200,
    spr: 0,
    state: 0,
    face: 270,
    char: %{},
    xp: 0
  }

  @impl true
  def join("room:lobby", payload, socket) do
    send(self(), {:after_join, payload})
    {:ok, socket}
  end

  @impl true
  def handle_info({:after_join, payload}, socket) do
    user_id = socket.assigns.current_user_id

    # 1. Parse de dados básicos (Posição, Sprite, Nome)
    player_visuals = parse_player_visuals(payload)
    char_data = get_in(player_visuals, [:char]) || %{}
    char_name = Map.get(char_data, "name", "Player #{user_id}")

    # 2. Parse de Stats para criar o Ator
    incoming_stats = %{
      vigor: 10,
      endurance: 10,
      strength: 10,
      dexterity: 10,
      intelligence: 10,
      faith: 10,
      attunement: 10
    }

    estimated_level = Map.values(incoming_stats) |> Enum.sum()
    equipped_weapon = Factory.Weapon.generate_random(estimated_level, :rare)

    # 3. CRIAÇÃO DO ATOR VIA CONTEXTO (Unificado)
    actor =
      ActorContext.new(:player, %{
        id: user_id,
        name: char_name,
        stats: incoming_stats,
        # Se nil, o Context calcula baseado no Vigor
        hp: payload["hp"],
        weapon: equipped_weapon
      })

    # Cálculo do Power Score para balanceamento de Mobs
    power_score = Map.values(actor.stats) |> Enum.sum()

    # 4. Assinatura do Tópico Privado
    RpgGameServerWeb.Endpoint.subscribe("player:#{user_id}")

    # 5. Configura o Socket
    # Agora guardamos o struct :actor inteiro no socket
    socket =
      socket
      |> assign(:actor, actor)
      |> assign(:char_name, char_name)
      |> assign(:char, char_data)
      |> assign(:last_x, player_visuals.x)
      |> assign(:last_y, player_visuals.y)
      |> assign(:xp, Map.get(payload, "xp", 0))

    # 6. Grid e Presence
    socket = update_aoi_subscriptions(socket, player_visuals.x, player_visuals.y)
    PlayerSpatialGrid.insert(user_id, player_visuals.x, player_visuals.y)

    # --- PRESENCE ATUALIZADO ---
    presence_meta =
      player_visuals
      |> Map.put(:online_at, System.system_time(:second))
      # Mobs leem isso para se balancear
      |> Map.put(:power_score, power_score)

    {:ok, _} = Presence.track(socket, user_id, presence_meta)

    # Envia estado inicial para o cliente
    push(socket, "welcome", %{my_id: user_id, hp: actor.hp, max_hp: actor.max_hp})
    push(socket, "current_players", %{players: list_present_players(socket)})
    broadcast_movement(socket, player_visuals, user_id)

    {:noreply, socket}
  end

  # ===================================================================
  # RECEBER DANO (Input Damage) - REFATORADO
  # ===================================================================

  @impl true
  def handle_info(%{event: "take_damage", payload: payload}, socket) do
    # 1. Delega a lógica de defesa e cálculo de HP para o Contexto
    {updated_actor, final_damage, is_dead} =
      ActorContext.take_damage(socket.assigns.actor, payload.damage)

    # 2. Atualiza o Socket com o Ator modificado (novo HP)
    socket = assign(socket, :actor, updated_actor)

    # 3. Atualiza Cliente (UI)
    push(socket, "update_stats", %{
      hp: updated_actor.hp,
      max_hp: updated_actor.max_hp,
      damage_taken: final_damage,
      source: payload.attacker_id,
      is_crit: Map.get(payload, :is_crit, false)
    })

    # 4. Broadcast Visual (Numbers popups)
    broadcast_damage_visual(
      socket,
      payload.attacker_id,
      final_damage,
      Map.get(payload, :is_crit, false)
    )

    if is_dead do
      handle_player_death(socket, payload.attacker_id)
      # Mantém HP zerado no socket visualmente
      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info(%{event: "xp_gain", payload: payload}, socket) do
    amount = payload.amount
    current_xp = socket.assigns.xp
    new_xp = current_xp + amount
    socket = assign(socket, :xp, new_xp)

    push(socket, "xp_gain", %{
      amount: amount,
      total_xp: new_xp,
      source: payload.source,
      player_id: socket.assigns.actor.id
    })

    {:noreply, socket}
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: event, payload: payload}, socket) do
    push(socket, event, payload)
    {:noreply, socket}
  end

  # ===================================================================
  # MOVIMENTO
  # ===================================================================

  @impl true
  def handle_in("move", payload, socket) do
    user_id = socket.assigns.actor.id
    changes = parse_incoming_changes(payload)

    {socket, _moved?} =
      if Map.has_key?(changes, :x) and Map.has_key?(changes, :y) do
        sock_aoi = update_aoi_subscriptions(socket, changes.x, changes.y)

        PlayerSpatialGrid.update(
          user_id,
          sock_aoi.assigns.last_x,
          sock_aoi.assigns.last_y,
          changes.x,
          changes.y
        )

        {assign(sock_aoi, last_x: changes.x, last_y: changes.y), true}
      else
        {socket, false}
      end

    Presence.update(socket, user_id, fn meta -> Map.merge(meta, changes) end)
    broadcast_movement(socket, changes, user_id)
    {:noreply, socket}
  end

  @impl true
  def handle_in("new_msg", %{"text" => text}, socket) do
    broadcast!(socket, "new_msg", %{text: text, sender: socket.assigns.char_name, type: "global"})
    {:noreply, socket}
  end

  # ===================================================================
  # COMBATE (CAUSAR DANO - Output Damage) - REFATORADO
  # ===================================================================

  @impl true
  def handle_in("attack_hit", payload, socket) do
    attacker_id = socket.assigns.actor.id
    target_id = Map.get(payload, "target_id")
    attacker_pos = {socket.assigns.last_x, socket.assigns.last_y}

    target_player_pos = get_player_pos(socket, target_id)

    if target_player_pos do
      process_pvp_hit(socket, attacker_id, target_id, attacker_pos, target_player_pos)
    else
      process_pve_hit(socket, target_id)
    end

    {:noreply, socket}
  end

  defp process_pve_hit(socket, target_id) do
    attacker_id = socket.assigns.actor.id

    # 1. Calcula dano usando a Lógica Unificada do Contexto
    {damage, _is_crit} = ActorContext.calculate_outgoing_damage(socket.assigns.actor)

    case Registry.lookup(RpgGameServer.EnemyRegistry, target_id) do
      [{pid, _}] -> GenServer.cast(pid, {:take_damage, damage, attacker_id})
      [] -> Logger.warning("Mob #{target_id} não encontrado")
    end
  end

  defp process_pvp_hit(socket, attacker_id, target_id, attacker_pos, target_pos) do
    max_reach = 70.0

    if is_valid_hit?(attacker_pos, target_pos, max_reach) do
      # 1. Calcula dano usando a Lógica Unificada do Contexto
      {damage, is_crit} = ActorContext.calculate_outgoing_damage(socket.assigns.actor)

      RpgGameServerWeb.Endpoint.broadcast("player:#{target_id}", "take_damage", %{
        damage: damage,
        attacker_id: attacker_id,
        is_crit: is_crit,
        type: "pvp"
      })
    end
  end

  # --- A FUNÇÃO ANTIGA calculate_player_output_damage FOI REMOVIDA ---
  # Toda a lógica agora reside em RpgGameServer.Game.ActorContext

  # ===================================================================
  # HELPERS GERAIS
  # ===================================================================
  @impl true
  def terminate(_reason, socket) do
    # O ActorContext não precisa de cleanup especial aqui, apenas removemos do Grid
    user_id = socket.assigns.actor.id
    PlayerSpatialGrid.remove(user_id)
    broadcast_from(socket, "player_left", %{id: user_id})
    :ok
  end

  defp update_aoi_subscriptions(socket, x, y) do
    new_cx = floor(x / @cell_size)
    new_cy = floor(y / @cell_size)
    old_cx = Map.get(socket.assigns, :current_cx)
    old_cy = Map.get(socket.assigns, :current_cy)

    if new_cx != old_cx or new_cy != old_cy do
      new_topics = get_neighbor_topics(new_cx, new_cy)
      old_topics = Map.get(socket.assigns, :subscribed_topics, [])
      (old_topics -- new_topics) |> Enum.each(&RpgGameServerWeb.Endpoint.unsubscribe/1)
      (new_topics -- old_topics) |> Enum.each(&RpgGameServerWeb.Endpoint.subscribe/1)
      assign(socket, current_cx: new_cx, current_cy: new_cy, subscribed_topics: new_topics)
    else
      socket
    end
  end

  defp get_neighbor_topics(cx, cy) do
    for dx <- -1..1, dy <- -1..1, do: "area:#{cx + dx}:#{cy + dy}"
  end

  defp broadcast_movement(socket, data, user_id) do
    base = Map.put(data, :id, user_id)

    payload =
      if socket.assigns[:char], do: Map.put_new(base, :char, socket.assigns.char), else: base

    cx = socket.assigns[:current_cx] || 0
    cy = socket.assigns[:current_cy] || 0
    RpgGameServerWeb.Endpoint.broadcast_from!(self(), "area:#{cx}:#{cy}", "player_moved", payload)
  end

  defp broadcast_damage_visual(socket, attacker_id, damage, is_crit) do
    cx = socket.assigns.current_cx
    cy = socket.assigns.current_cy

    RpgGameServerWeb.Endpoint.broadcast!("area:#{cx}:#{cy}", "damage_applied", %{
      target_id: socket.assigns.actor.id,
      attacker_id: attacker_id,
      damage: damage,
      is_crit: is_crit,
      type: "pve_hit"
    })
  end

  defp handle_player_death(socket, killer_id) do
    push(socket, "player_died", %{killer_id: killer_id})
  end

  defp list_present_players(socket) do
    x = socket.assigns[:last_x] || 200
    y = socket.assigns[:last_y] || 200

    nearby =
      PlayerSpatialGrid.get_nearby_players(x, y) |> Enum.map(fn {id, _} -> id end) |> MapSet.new()

    Presence.list(socket)
    |> Enum.filter(fn {id, _} -> MapSet.member?(nearby, id) end)
    |> Enum.map(fn {id, d} ->
      # Mescla o default visual com os metadados do presence
      Map.merge(@default_visuals, List.first(d.metas))
      |> Map.take([:x, :y, :spr, :state, :face, :char])
      |> Map.put(:id, id)
    end)
  end

  defp is_valid_hit?({ax, ay}, {tx, ty}, reach) do
    :math.sqrt(:math.pow(ax - tx, 2) + :math.pow(ay - ty, 2)) <= reach
  end

  defp get_player_pos(socket, user_id) do
    case Presence.list(socket) |> Map.get(to_string(user_id)) do
      %{metas: [meta | _]} -> {meta.x, meta.y}
      _ -> nil
    end
  end

  defp parse_player_visuals(payload) do
    Enum.reduce(@default_visuals, %{}, fn {k, d}, acc ->
      Map.put(acc, k, Map.get(payload, Atom.to_string(k), d))
    end)
  end

  defp parse_incoming_changes(payload) do
    payload
    |> Map.take(~w(x y spr state face))
    |> Map.new(fn {k, v} -> {String.to_atom(k), v} end)
  end
end
