defmodule RpgGameServerWeb.Channels.RoomChannel do
  use RpgGameServerWeb, :channel
  alias RpgGameServerWeb.Presence
  alias RpgGameServer.Game.{PlayerSpatialGrid, StatsCalculator}
  require Logger

  # Configuração AOI
  @cell_size 700

  # Estado padrão
  @default_state %{
    x: 200,
    y: 200,
    spr: 0,
    state: 0,
    face: 270,
    char: %{},
    xp: 0,
    stats: %{
      vigor: 500,
      endurance: 500,
      attunement: 500,
      strength: 500,
      dexterity: 500,
      intelligence: 500,
      faith: 500
    }
  }

  @impl true
  def join("room:lobby", payload, socket) do
    send(self(), {:after_join, payload})
    {:ok, socket}
  end

  @impl true
  def handle_info({:after_join, payload}, socket) do
    user_id = socket.assigns.current_user_id

    # 1. Parse inicial
    player_state = parse_player_state(payload)
    char_data = get_in(player_state, [:char]) || %{}
    char_name = Map.get(char_data, "name", "Player #{user_id}")

    # 2. Configuração de Stats
    stats = Map.merge(@default_state.stats, player_state[:stats] || %{})
    max_hp = StatsCalculator.calculate_max_hp(stats.vigor)
    current_hp = Map.get(player_state, :hp, max_hp)
    current_xp = Map.get(player_state, :xp, 0)
    # --- NOVO: SIMULAÇÃO DE ARMA EQUIPADA ---
    # Futuramente isso virá do seu banco de dados (Inventory Context)
    equipped_weapon = %{
      # Nome
      name: "Longsword",
      # Dano base decente
      base_damage: 575,
      # Escala B em Força (1.1x)
      scale_str: 1.1,
      # Escala E em Dex (0.4x)
      scale_dex: 0.4
    }

    # 3. Assinatura do Tópico Privado
    RpgGameServerWeb.Endpoint.subscribe("player:#{user_id}")

    # 4. Configura o Socket
    socket =
      socket
      |> assign(:char_name, char_name)
      |> assign(:char, char_data)
      |> assign(:last_x, player_state.x)
      |> assign(:last_y, player_state.y)
      |> assign(:stats, stats)
      |> assign(:hp, current_hp)
      |> assign(:max_hp, max_hp)
      |> assign(:xp, current_xp)
      |> assign(:weapon, equipped_weapon)

    # 5. Grid e Presence
    socket = update_aoi_subscriptions(socket, player_state.x, player_state.y)
    PlayerSpatialGrid.insert(user_id, player_state.x, player_state.y)

    {:ok, _} =
      Presence.track(
        socket,
        user_id,
        Map.put(player_state, :online_at, System.system_time(:second))
      )

    push(socket, "welcome", %{my_id: user_id, hp: current_hp, max_hp: max_hp})
    push(socket, "current_players", %{players: list_present_players(socket)})
    broadcast_movement(socket, player_state, user_id)

    {:noreply, socket}
  end

  # ===================================================================
  # RECEBER DANO (Mitigação de Defesa - Input Damage)
  # ===================================================================

  @impl true
  def handle_info(%{event: "take_damage", payload: payload}, socket) do
    raw_damage = payload.damage
    attacker_id = payload.attacker_id
    is_crit = Map.get(payload, :is_crit, false)

    # 1. Calcula Defesa (Strength)
    defense = StatsCalculator.calculate_physical_defense(socket.assigns.stats.strength)

    # 2. Mitigação (Dano nunca é zero)
    min_damage = trunc(raw_damage * 0.1)
    final_damage = max(min_damage, raw_damage - defense)

    # 3. Atualiza HP
    new_hp = socket.assigns.hp - final_damage

    # 4. Atualiza Cliente
    push(socket, "update_stats", %{
      hp: new_hp,
      max_hp: socket.assigns.max_hp,
      damage_taken: final_damage,
      source: attacker_id,
      is_crit: is_crit
    })

    # 5. Broadcast Visual
    broadcast_damage_visual(socket, attacker_id, final_damage, is_crit)

    if new_hp <= 0 do
      handle_player_death(socket, attacker_id)
      {:noreply, assign(socket, :hp, 0)}
    else
      {:noreply, assign(socket, :hp, new_hp)}
    end
  end

  # Handler para receber XP do EnemyAI (mensagem privada via tópico player:{id})
  @impl true
  def handle_info(%{event: "xp_gain", payload: payload}, socket) do
    amount = payload.amount

    # 1. ACUMULA O XP NO ESTADO DO SERVIDOR
    current_xp = socket.assigns.xp
    new_xp = current_xp + amount

    # 2. Atualiza o socket com o novo total
    socket = assign(socket, :xp, new_xp)

    # 3. ENVIA PARA O CLIENTE GAMEMAKER
    push(socket, "xp_gain", %{
      # Quanto ganhou agora (pra mostrar o "+100 xp" flutuando)
      amount: amount,
      # Total acumulado (pra atualizar a barra de progresso)
      total_xp: new_xp,
      source: payload.source,
      player_id: socket.assigns.current_user_id
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
    user_id = socket.assigns.current_user_id
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
  # COMBATE (CAUSAR DANO - Output Damage)
  # ===================================================================

  @impl true
  def handle_in("attack_hit", payload, socket) do
    attacker_id = socket.assigns.current_user_id
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

  # --- Helpers de Combate ---

  defp process_pve_hit(socket, target_id) do
    attacker_id = socket.assigns.current_user_id

    # Calcula Dano usando a Arma e Stats
    {damage, _is_crit} = calculate_player_output_damage(socket)

    case Registry.lookup(RpgGameServer.EnemyRegistry, target_id) do
      [{pid, _}] ->
        GenServer.cast(pid, {:take_damage, damage, attacker_id})

      [] ->
        Logger.warning("Mob #{target_id} não encontrado")
    end
  end

  defp process_pvp_hit(socket, attacker_id, target_id, attacker_pos, target_pos) do
    max_reach = 70.0

    if is_valid_hit?(attacker_pos, target_pos, max_reach) do
      # Calcula Dano usando a Arma e Stats
      {damage, is_crit} = calculate_player_output_damage(socket)

      RpgGameServerWeb.Endpoint.broadcast("player:#{target_id}", "take_damage", %{
        damage: damage,
        attacker_id: attacker_id,
        is_crit: is_crit,
        type: "pvp"
      })
    end
  end

  # --- CÁLCULO DE DANO DO PLAYER (COM LÓGICA DE ARMA) ---

  defp calculate_player_output_damage(socket) do
    stats = socket.assigns.stats
    # <--- Recupera a arma do socket
    weapon = socket.assigns.weapon

    # 1. Bônus de Stats (Eficiência do Jogador)
    # Retorna uma % baseada na curva de nível (ex: 0.85 para lvl 40)
    str_bonus_pct = StatsCalculator.calculate_stat_bonus(stats.strength)
    dex_bonus_pct = StatsCalculator.calculate_stat_bonus(stats.dexterity)

    # 2. Cálculo do Scaling (Quanto a arma aproveita dessa força)
    # Ex: Base 20 * Scaling 1.1 * BonusJogador 0.85 = +18.7 dano
    added_str_dmg = weapon.base_damage * weapon.scale_str * str_bonus_pct
    added_dex_dmg = weapon.base_damage * weapon.scale_dex * dex_bonus_pct

    # 3. Attack Rating (AR) Total
    attack_rating = trunc(weapon.base_damage + added_str_dmg + added_dex_dmg)

    # 4. Variação (RNG +/- 10%)
    variation = 0.9 + :rand.uniform() * 0.2
    final_raw_damage = trunc(attack_rating * variation)

    # 5. Crítico (Baseado na Destreza)
    crit_chance = StatsCalculator.calculate_crit_chance(stats.dexterity)

    if :rand.uniform() < crit_chance do
      # Crítico!
      {trunc(final_raw_damage * 1.5), true}
    else
      {final_raw_damage, false}
    end
  end

  # ===================================================================
  # HELPERS GERAIS
  # ===================================================================
  @impl true
  def terminate(_reason, socket) do
    user_id = socket.assigns.current_user_id

    # Remove o player de onde quer que ele esteja
    # Requer que o remove/1 exista no PlayerSpatialGrid
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
      target_id: socket.assigns.current_user_id,
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
      Map.merge(@default_state, List.first(d.metas))
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

  defp parse_player_state(payload) do
    parsed =
      Enum.reduce(@default_state, %{}, fn {k, d}, acc ->
        Map.put(acc, k, Map.get(payload, Atom.to_string(k), d))
      end)

    if Map.has_key?(payload, "stats") do
      atom_stats = Map.new(payload["stats"], fn {k, v} -> {String.to_atom(k), v} end)
      Map.put(parsed, :stats, atom_stats)
    else
      parsed
    end
  end

  defp parse_incoming_changes(payload) do
    payload
    |> Map.take(~w(x y spr state face))
    |> Map.new(fn {k, v} -> {String.to_atom(k), v} end)
  end
end
