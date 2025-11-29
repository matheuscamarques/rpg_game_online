defmodule RpgGameServer.Game.EnemyAI do
  use GenServer, restart: :temporary
  require Logger

  # --- ALIASES ---
  alias RpgGameServer.Game.EnemySpatialGrid, as: SpatialGrid
  alias RpgGameServer.Game.PlayerSpatialGrid
  alias RpgGameServer.Game.{Room1, StatsCalculator}
  alias RpgGameServerWeb.Endpoint

  # --- CONFIGURAÇÕES ---
  @speed 5 # Pixels por 100ms (Base)
  @vision_radius 100
  @give_up_radius 200
  @attack_range 15
  @attack_cooldown 1000

  # Física e Colisão
  @enemy_radius 5
  @safe_radius_factor 2.5 # Multiplicador do raio para "zona de conforto" da separação

  # Otimização
  @flee_threshold 0.3
  @return_threshold 0.8
  @heal_rate 1
  @wander_timeout 3000
  @cell_size 700
  @sleep_distance 1400

  # --- API ---
  def start_link(args), do: GenServer.start_link(__MODULE__, args)

  # --- CALLBACKS ---
  @impl true
  def init(initial_state) do
    {:ok, _} = Registry.register(RpgGameServer.EnemyRegistry, initial_state.id, nil)
    SpatialGrid.insert(initial_state.id, initial_state.x, initial_state.y)

    base_xp = 100 + :rand.uniform(9_029_900)
    {stats, weapon, max_hp, attack_rating, level} = initialize_random_build(base_xp)

    state =
      Map.merge(initial_state, %{
        mode: :idle,
        wander_target: nil,
        wander_deadline: 0,
        target_id: nil,
        level: level,
        stats: stats,
        weapon: weapon,
        max_hp: max_hp,
        hp: max_hp,
        attack_damage: attack_rating,
        xp_reward: base_xp,
        state: 0,
        last_attack_time: 0,
        facing: 270,
        damage_history: %{},
        last_x: initial_state.x,
        last_y: initial_state.y,
        dist_to_player: 999_999
      })

    # Inicia o loop com um tick padrão de 100ms
    schedule_tick(state, 100)
    {:ok, state}
  end

  @impl true
  def terminate(_reason, state) do
    SpatialGrid.remove(state.id, state.x, state.y)
    RpgGameServer.Game.WorldTicker.remove_from_buffer(state.id)
    :ok
  end

  # --- BUILD ---
  defp initialize_random_build(xp) do
    level = max(1, trunc(:math.pow(xp / 100, 1 / 2.2)))
    points = level * 3

    base_stats = %{
      vigor: 10,
      endurance: 10,
      strength: 10,
      dexterity: 10,
      intelligence: 5,
      faith: 5,
      attunement: 5
    }

    final_stats = distribute_points(base_stats, points)
    max_hp = StatsCalculator.calculate_max_hp(final_stats.vigor)
    weapon = generate_random_weapon(level)
    str_bonus = StatsCalculator.calculate_stat_bonus(final_stats.strength)
    scaling_damage = weapon.base_damage * weapon.scale_str * str_bonus
    attack_rating = trunc(weapon.base_damage + scaling_damage)
    {final_stats, weapon, max_hp, attack_rating, level}
  end

  defp generate_random_weapon(level) do
    tier_damage = 5 + level * 1.5

    %{
      name: "Rusty Weapon",
      base_damage: tier_damage,
      scale_str: 0.8 + :rand.uniform() * 0.7,
      scale_dex: 0.2
    }
  end

  defp distribute_points(stats, 0), do: stats

  defp distribute_points(stats, points_left) do
    keys = [:vigor, :vigor, :strength, :strength, :endurance, :dexterity]
    chosen = Enum.random(keys)
    Map.update!(stats, chosen, &(&1 + 1)) |> distribute_points(points_left - 1)
  end

  # --- HANDLERS ---
  @impl true
  def handle_cast({:take_damage, raw_amount, attacker_id}, state) do
    evasion_chance = StatsCalculator.calculate_evasion_chance(state.stats.dexterity)

    if :rand.uniform() < evasion_chance do
      broadcast_aoi(state, "damage_missed", %{
        target_id: state.id,
        attacker_id: attacker_id,
        type: "miss"
      })

      {:noreply, state}
    else
      defense = StatsCalculator.calculate_physical_defense(state.stats.strength)
      min_damage = trunc(raw_amount * 0.1)
      final_damage = max(min_damage, raw_amount - trunc(defense))
      new_hp = state.hp - final_damage

      new_history =
        Map.update(state.damage_history, attacker_id, final_damage, &(&1 + final_damage))

      broadcast_aoi(state, "damage_applied", %{
        target_id: state.id,
        attacker_id: attacker_id,
        damage: final_damage,
        type: "pve"
      })

      if new_hp <= 0 do
        die(state, new_history)
        {:stop, :normal, state}
      else
        new_mode = determine_mode_after_damage(new_hp, state.max_hp, state.mode)

        {:noreply,
         %{
           state
           | hp: new_hp,
             target_id: attacker_id,
             mode: new_mode,
             damage_history: new_history,
             wander_target: nil,
             dist_to_player: 0
         }}
      end
    end
  end

  # Compatibilidade para mensagens antigas ou primeiro tick
  @impl true
  def handle_info(:tick, state) do
    handle_info({:tick, 100}, state)
  end

  @impl true
  def handle_info({:tick, dt}, state) do
    if state.x != state.last_x or state.y != state.last_y,
      do: SpatialGrid.update(state.id, state.last_x, state.last_y, state.x, state.y)

    # Processa IA passando o Delta Time (dt) para corrigir velocidade
    new_state = process_ai(state, dt)

    final_state = %{new_state | last_x: state.x, last_y: state.y}

    if changed?(state, final_state), do: broadcast_to_ticker(final_state)

    schedule_tick(final_state, dt)
    {:noreply, final_state}
  end

  defp schedule_tick(state, _last_dt) do
    dist = state.dist_to_player

    rate =
      cond do
        dist < 1000 -> 100
        dist < 2000 -> 1000
        dist < 3000 -> 2000
        dist < 4000 -> 3000
        true -> 5000 * 4
      end

    # Envia o rate calculado como 'dt' para o próximo ciclo
    Process.send_after(self(), {:tick, rate}, rate)
  end

  # --- IA & MOVIMENTO ---
  defp process_ai(state, dt) do
    {closest_player, dist_sq} = find_closest_player_optimized(state)
    dist = :math.sqrt(dist_sq)
    state = %{state | dist_to_player: dist}

    if dist > @sleep_distance and state.mode != :flee do
      state
    else
      state = update_mode(state, closest_player, dist_sq)

      {tx, ty, state} =
        case state.mode do
          :chase ->
            {closest_player.x, closest_player.y, state}

          :idle ->
            get_wander_target(state)

          :flee ->
            state = regenerate_hp(state)
            get_flee_target(state, closest_player)
        end

      move_entity(state, tx, ty, dt)
    end
  end

  # --- COMBATE ---
  defp perform_attack(state, facing) do
    now = System.system_time(:millisecond)

    if now - state.last_attack_time > @attack_cooldown do
      apply_damage_to_target(state)
      %{state | state: 1, last_attack_time: now, facing: facing}
    else
      %{state | state: 0, facing: facing}
    end
  end

  defp apply_damage_to_target(state) do
    if state.target_id do
      variation = 0.9 + :rand.uniform() * 0.2
      raw_damage = trunc(state.attack_damage * variation)
      crit_chance = StatsCalculator.calculate_crit_chance(state.stats.dexterity)

      {final_damage, is_crit} =
        if :rand.uniform() < crit_chance,
          do: {trunc(raw_damage * 1.5), true},
          else: {raw_damage, false}

      Endpoint.broadcast("player:#{state.target_id}", "take_damage", %{
        damage: final_damage,
        attacker_id: state.id,
        is_crit: is_crit
      })
    end
  end

  # --- UTILS IA ---
  defp determine_mode_after_damage(hp, max_hp, current) do
    if hp / max_hp < @flee_threshold,
      do: :flee,
      else: if(current == :idle, do: :chase, else: current)
  end

  defp update_mode(%{mode: :idle} = s, p, d_sq) do
    if s.hp / s.max_hp < @flee_threshold,
      do: %{s | mode: :flee},
      else:
        if(p && d_sq <= @vision_radius * @vision_radius,
          do: %{s | mode: :chase, target_id: p.id},
          else: s
        )
  end

  defp update_mode(%{mode: :chase} = s, p, d_sq) do
    if s.hp / s.max_hp < @flee_threshold,
      do: %{s | mode: :flee},
      else:
        if(is_nil(p) || d_sq > @give_up_radius * @give_up_radius,
          do: %{s | mode: :idle, target_id: nil},
          else: %{s | target_id: p.id}
        )
  end

  defp update_mode(%{mode: :flee} = s, _, _) do
    if s.hp / s.max_hp > @return_threshold,
      do: if(s.target_id, do: %{s | mode: :chase}, else: %{s | mode: :idle}),
      else: s
  end

  defp regenerate_hp(s), do: %{s | hp: min(s.hp + @heal_rate, s.max_hp)}

  # --- MOVIMENTO ---
  defp get_flee_target(s, nil), do: {s.x, s.y, s}

  defp get_flee_target(s, p) do
    dx = s.x - p.x
    dy = s.y - p.y
    dist = :math.sqrt(dx * dx + dy * dy)

    if dist < 0.001 do
      {s.x, s.y, s}
    else
      tx = s.x + dx / dist * 100
      ty = s.y + dy / dist * 100
      if Room1.is_blocked?(tx, ty), do: pick_random_point_panic(s), else: {tx, ty, s}
    end
  end

  defp get_wander_target(%{wander_target: nil} = s) do
    target = pick_valid_wander_point(s)
    dl = System.system_time(:millisecond) + @wander_timeout
    {target.x, target.y, %{s | wander_target: target, wander_deadline: dl}}
  end

  defp get_wander_target(s) do
    dx = s.x - s.wander_target.x
    dy = s.y - s.wander_target.y

    if dx * dx + dy * dy < 100 or System.system_time(:millisecond) > s.wander_deadline,
      do: {s.x, s.y, %{s | wander_target: nil}},
      else: {s.wander_target.x, s.wander_target.y, s}
  end

  defp pick_valid_wander_point(s, a \\ 3)
  defp pick_valid_wander_point(s, 0), do: %{x: s.x, y: s.y}

  defp pick_valid_wander_point(s, a) do
    ang = :rand.uniform() * 2 * :math.pi()
    d = :rand.uniform(100) + 50
    tx = s.x + :math.cos(ang) * d
    ty = s.y + :math.sin(ang) * d

    if is_path_clear?(s.x, s.y, tx, ty),
      do: %{x: tx, y: ty},
      else: pick_valid_wander_point(s, a - 1)
  end

  defp pick_random_point_panic(s) do
    ang = :rand.uniform() * 2 * :math.pi()
    {s.x + :math.cos(ang) * 30, s.y + :math.sin(ang) * 30, s}
  end

  defp is_path_clear?(x1, y1, x2, y2),
    do: not Room1.is_blocked?(x2, y2) and not Room1.is_blocked?((x1 + x2) / 2, (y1 + y2) / 2)

  defp move_entity(s, tx, ty, dt) do
    dx = tx - s.x
    dy = ty - s.y
    d_sq = dx * dx + dy * dy
    dist = :math.sqrt(d_sq)

    # CORREÇÃO CRÍTICA PARA ARITHMETIC ERROR
    # Se a distância for muito pequena, considera que chegou e não move.
    if dist < 0.001 do
       s
    else
       nf = if dist > 1, do: calc_facing(dx, dy), else: s.facing

       cond do
         s.mode == :flee -> do_phys(s, dx, dy, dist, nf, dt)
         s.mode == :chase and d_sq <= @attack_range * @attack_range -> perform_attack(s, nf)
         true -> do_phys(s, dx, dy, dist, nf, dt)
       end
    end
  end

  # LÓGICA DE FÍSICA CORRIGIDA E ESTABILIZADA
  defp do_phys(s, dx, dy, dist, nf, dt) do
    # 1. Vetor de Intenção (Normalizado)
    # Como garantimos dist >= 0.001 no move_entity, podemos dividir aqui com segurança.
    vx = dx / dist
    vy = dy / dist

    # 2. Calcular Vetores de Força
    {sx, sy} = calc_sep(s)
    {wx, wy} = calc_wall(s)

    # 3. Pesos (Ajuste fino para evitar flicker)
    # Separação: Forte o suficiente para empurrar, mas não "canhão"
    sep_weight = 2.5
    wall_weight = 4.0

    # 4. Somatório de Forças
    fvx = vx + sx * sep_weight + wx * wall_weight
    fvy = vy + sy * sep_weight + wy * wall_weight

    # 5. Normalização Final (Impede que a soma das forças exceda a velocidade máxima)
    mag = :math.sqrt(fvx * fvx + fvy * fvy)

    # 6. Aplicação de Velocidade com Delta Time
    # Se dt=100ms (perto), fator=1.0. Se dt=5000ms (longe), fator=50.0.
    # Isso garante que ele percorra a mesma distância no tempo real.
    time_factor = dt / 100.0
    current_speed = @speed * time_factor

    # Se magnitude > 0, normalizamos e aplicamos speed. Se 0, fica parado.
    scale = if mag > 0, do: current_speed / mag, else: 0

    move_x = fvx * scale
    move_y = fvy * scale

    nx = s.x + move_x
    ny = s.y + move_y

    # 7. Colisão Simples (Slide)
    fx = if Room1.is_blocked?(nx, s.y), do: s.x, else: nx
    fy = if Room1.is_blocked?(fx, ny), do: s.y, else: ny

    %{s | x: fx, y: fy, state: 0, facing: nf}
  end

  defp calc_wall(s) do
    d = @enemy_radius + 10

    fx =
      if(Room1.is_blocked?(s.x + d, s.y), do: -1, else: 0) +
        if(Room1.is_blocked?(s.x - d, s.y), do: 1, else: 0)

    fy =
      if(Room1.is_blocked?(s.x, s.y + d), do: -1, else: 0) +
        if(Room1.is_blocked?(s.x, s.y - d), do: 1, else: 0)

    {fx, fy}
  end

  # CORREÇÃO DE SEPARAÇÃO (Soft Collision)
  defp calc_sep(s) do
    # Otimização: Limitar a verificação aos primeiros 8-10 vizinhos em áreas densas
    neighbors = SpatialGrid.get_nearby_entities(s.x, s.y)  |> Enum.take(10)

    Enum.reduce(neighbors, {0, 0}, fn {oid, {ox, oy}}, {ax, ay} ->
      if oid != s.id do
        dx = s.x - ox
        dy = s.y - oy
        d_sq = dx * dx + dy * dy

        # Safe Radius com margem de respiro
        safe_radius = @enemy_radius * @safe_radius_factor

        # Só aplicamos força se:
        # 1. Não estão exatamente no mesmo pixel (d_sq > 0.001) para evitar div/0
        # 2. Estão dentro da zona de conforto
        if d_sq > 0.001 and d_sq < safe_radius * safe_radius do
          d = :math.sqrt(d_sq)

          # INTERPOLAÇÃO LINEAR (O segredo anti-flicker)
          # Se d=0 (encostado), força = 100%
          # Se d=safe_radius, força = 0%
          pct = 1.0 - (d / safe_radius)

          # Vetor normalizado (dx/d, dy/d) multiplicado pela intensidade (pct)
          {ax + (dx / d) * pct, ay + (dy / d) * pct}
        else
          {ax, ay}
        end
      else
        {ax, ay}
      end
    end)
  end

  # --- UTILS FINAIS ---
  defp die(s, h) do
    SpatialGrid.remove(s.id, s.last_x, s.last_y)
    RpgGameServer.Game.WorldTicker.remove_from_buffer(s.id)
    broadcast_aoi(s, "enemy_died", %{id: s.id})
    distribute_xp(h, s.xp_reward)

    Process.send(
      RpgGameServer.Game.EnemySpawner,
      {:schedule_respawn, %{type: s.type, zone: "1"}},
      []
    )
  end

  defp distribute_xp(hist, total_xp_reward) do
    total_dmg = Enum.reduce(hist, 0, fn {_, d}, a -> a + d end)

    if total_dmg > 0 do
      Enum.each(hist, fn {player_id, dmg} ->
        xp_share = round(total_xp_reward * (dmg / total_dmg))

        if xp_share > 0,
          do:
            Endpoint.broadcast("player:#{player_id}", "xp_gain", %{
              amount: xp_share,
              source: "kill"
            })
      end)
    end
  end

  defp broadcast_aoi(s, evt, pay),
    do:
      Endpoint.broadcast!("area:#{floor(s.x / @cell_size)}:#{floor(s.y / @cell_size)}", evt, pay)

  defp broadcast_to_ticker(s),
    do:
      RpgGameServer.Game.WorldTicker.report_movement(%{
        id: s.id,
        type: s.type,
        x: s.x,
        y: s.y,
        state: s.state,
        face: s.facing
      })

  defp find_closest_player_optimized(s) do
    PlayerSpatialGrid.get_nearby_players(s.x, s.y)
    |> Enum.reduce({nil, 9_999_999_999}, fn {id, {px, py}}, {bp, bd} ->
      dx = s.x - px
      dy = s.y - py
      d = dx * dx + dy * dy
      if d < bd, do: {%{id: id, x: px, y: py}, d}, else: {bp, bd}
    end)
  end

  defp calc_facing(dx, dy), do: round(:math.atan2(-dy, dx) * (180 / :math.pi()))
  defp changed?(o, n), do: o.x != n.x or o.y != n.y or o.state != n.state or o.facing != n.facing
end
