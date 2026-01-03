defmodule RpgGameServer.Game.EnemyAI do
  use GenServer, restart: :temporary
  require Logger

  alias RpgGameServer.Game.Factory.Weapon
  alias RpgGameServer.Game.EnemySpatialGrid, as: SpatialGrid
  alias RpgGameServer.Game.PlayerSpatialGrid
  alias RpgGameServer.Game.{Room1, StatsCalculator, ActorContext}
  alias RpgGameServerWeb.Endpoint

  # --- CONFIGURAÇÕES DE GAMEPLAY ---
  @speed 120.0
  @vision_radius 400
  @give_up_radius 700
  @attack_range 35
  @attack_cooldown 1000

  # --- CONFIGURAÇÕES TÉCNICAS ---
  # Deve bater com o EnemySpatialGrid
  @cell_size 2100
  @tick_rate 100
  @sleep_distance 2500

  # --- PESOS DA FÍSICA E STEERING (Sem Números Mágicos) ---
  # Peso do vetor de ir até o alvo
  @chase_weight 4.0
  # Peso do vetor de separação de outros mobs
  @sep_weight 6.0
  # Peso do vetor de evasão de parede
  @wall_weight 1.0
  # Fator de repulsão para sondas diagonais (Wall Avoidance)
  @diag_repel_factor 0.7

  # Física de Boids (Evitar que fiquem um dentro do outro)
  # <-- AJUSTE ESTE RAIO PARA O TAMANHO VISUAL DO SEU MOB
  @enemy_radius 32
  @safe_radius_factor 1.0

  # Limiares de IA
  @flee_threshold 0.3
  @return_threshold 0.8
  @heal_rate 5

  # Stats Base (Fallback)
  @base_mob_stats %{
    vigor: 10,
    endurance: 10,
    strength: 10,
    dexterity: 10,
    intelligence: 5,
    faith: 5,
    attunement: 5
  }

  def start_link(args), do: GenServer.start_link(__MODULE__, args)

  # ==============================================================================
  # INIT
  # ==============================================================================
  @impl true
  def init(initial_state) do
    # 1. Registra no Registry
    {:ok, _} = Registry.register(RpgGameServer.EnemyRegistry, initial_state.id, nil)

    # 2. Insere na Grid Espacial
    SpatialGrid.insert(initial_state.id, initial_state.x, initial_state.y)

    # 3. Configuração do Ator (Stats, Arma, Tipo)
    visual_type = Map.get(initial_state, :type, "human")
    zone = Map.get(initial_state, :zone, "1")

    target_power_score = determine_target_power(initial_state.x, initial_state.y)

    {stats, weapon, head, chest, gloves, pants, ring1, ring2, ring3, ring4, ring5, level} =
      generate_mob_build(target_power_score)

    actor =
      ActorContext.new(visual_type, %{
        id: initial_state.id,
        name: "#{String.capitalize(visual_type)} Lvl #{level}",
        stats: stats,
        weapon: weapon,
        head: head
      })

    # 4. Estado Inicial Completo
    state =
      Map.merge(initial_state, %{
        actor: actor,
        zone: zone,
        level: level,
        xp_reward: trunc(target_power_score * 5),
        mode: :idle,
        wander_target: nil,
        wander_deadline: 0,
        target_id: nil,
        state: 0,
        last_attack_time: 0,
        facing: 270,
        damage_history: %{},
        last_x: initial_state.x,
        last_y: initial_state.y,
        dist_to_player: 999_999,
        tile_size: RpgGameServer.Game.Room1.get_cell_size()
      })

    schedule_tick(state, @tick_rate)
    {:ok, state}
  end

  # ==============================================================================
  # TICK LOOP (CORAÇÃO DA IA)
  # ==============================================================================
  @impl true
  def handle_info(:tick, state), do: handle_info({:tick, @tick_rate}, state)

  def handle_info({:tick, dt}, state) do
    # 1. Atualiza Grid Espacial se moveu
    if state.x != state.last_x or state.y != state.last_y do
      SpatialGrid.update(state.id, state.last_x, state.last_y, state.x, state.y)
    end

    # 2. Processa IA e Movimento
    new_state = process_ai(state, dt)

    # ---------------------------------------------------------
    # DETECÇÃO DE TROCA DE SHARD (CHANNEL)
    # ---------------------------------------------------------
    check_shard_crossing(state, new_state)
    # ---------------------------------------------------------

    # 3. Atualiza tracking 'last' para o próximo tick
    final_state = %{new_state | last_x: state.x, last_y: state.y}

    # 4. Broadcast para o Ticker (apenas se mudou algo visualmente)
    if changed?(state, final_state), do: broadcast_to_ticker(final_state)

    schedule_tick(final_state, dt)
    {:noreply, final_state}
  end

  # ==============================================================================
  # RECEBIMENTO DE DANO
  # ==============================================================================
  @impl true
  def handle_cast({:take_damage, raw_amount, attacker_id}, state) do
    # 1. Tenta Esquivar
    evasion_chance = StatsCalculator.calculate_evasion_chance(state.actor.stats.dexterity)

    if :rand.uniform() < evasion_chance do
      broadcast_aoi(state, "damage_missed", %{
        target_id: state.id,
        attacker_id: attacker_id,
        type: "miss"
      })

      {:noreply, state}
    else
      # 2. Aplica Dano via Contexto
      {updated_actor, final_damage, is_dead} = ActorContext.take_damage(state.actor, raw_amount)

      # 3. Registra histórico para XP
      new_history =
        Map.update(state.damage_history, attacker_id, final_damage, &(&1 + final_damage))

      hp_p = if updated_actor.max_hp > 0, do: round(updated_actor.hp / updated_actor.max_hp * 100), else: 0
      # 4. Notifica Visual (Popup de Dano)
      broadcast_aoi(state, "damage_applied", %{
        target_id: state.id,
        attacker_id: attacker_id,
        damage: final_damage,
        hp_percent: hp_p,
        type: "pve"
      })

      if is_dead do
        handle_death(%{state | actor: updated_actor}, new_history)
        {:stop, :normal, %{state | actor: updated_actor}}
      else
        # Reage ao dano (foge ou foca no agressor)
        new_mode = determine_mode_after_damage(updated_actor.hp, updated_actor.max_hp, state.mode)

        {:noreply,
         %{
           state
           | actor: updated_actor,
             damage_history: new_history,
             mode: new_mode,
             # Vira o aggro para quem bateu
             target_id: attacker_id,
             # Força atualização imediata da IA
             dist_to_player: 0
         }}
      end
    end
  end

  @impl true
  def terminate(_reason, state) do
    SpatialGrid.remove(state.id, state.x, state.y)
    broadcast_aoi(state, "enemy_died", %{id: state.id})
    :ok
  end

  # ==============================================================================
  # IA & MOVIMENTAÇÃO
  # ==============================================================================

  defp process_ai(state, dt) do
    # Otimização: Busca player mais próximo
    {closest_player, dist_sq} = find_closest_player_optimized(state)
    dist = :math.sqrt(dist_sq)
    state = %{state | dist_to_player: dist}

    # Se ninguém por perto, não gasta CPU movendo
    if dist > @sleep_distance and state.mode != :flee do
      state
    else
      # Máquina de Estados (Idle <-> Chase <-> Flee)
      state = update_mode(state, closest_player, dist_sq)

      # Determina alvo de movimento (tx, ty) baseado no modo
      {tx, ty, state} =
        case state.mode do
          :chase ->
            if closest_player do
              {closest_player.x, closest_player.y, state}
            else
              {state.x, state.y, %{state | mode: :idle, target_id: nil}}
            end

          :idle ->
            get_wander_target(state)

          :flee ->
            state = regenerate_hp(state)
            get_flee_target(state, closest_player)
        end

      # Executa física de movimento (Boids + Colisão)
      move_entity(state, tx, ty, dt)
    end
  end

  defp move_entity(s, tx, ty, dt) do
    dx = tx - s.x
    dy = ty - s.y
    d_sq = dx * dx + dy * dy
    dist = :math.sqrt(d_sq)

    if dist < 1.0 do
      s
    else
      nf = if dist > 1, do: calc_facing(dx, dy), else: s.facing

      cond do
        s.mode == :flee ->
          do_phys(s, dx, dy, dist, nf, dt)

        s.mode == :chase and d_sq <= @attack_range * @attack_range ->
          perform_attack(s, nf)

        true ->
          do_phys(s, dx, dy, dist, nf, dt)
      end
    end
  end

  # Física (Velocity + Separation + Wall Avoidance)
  defp do_phys(s, dx, dy, dist, nf, dt) do
    # Vetor Desejo (ir até o alvo)
    vx = dx / dist
    vy = dy / dist

    # Vetores de Steering (Desvio)
    {sx, sy} = calc_separation(s)
    {wx, wy} = calc_wall_avoidance(s)

    # Soma vetorial (Usando constantes nomeadas para pesos)
    fvx = vx * @chase_weight + sx * @sep_weight + wx * @wall_weight
    fvy = vy * @chase_weight + sy * @sep_weight + wy * @wall_weight

    # Normaliza e aplica Speed
    mag = :math.sqrt(fvx * fvx + fvy * fvy)
    time_factor = dt / 1000.0
    current_speed = @speed * time_factor

    scale = if mag > 0, do: current_speed / mag, else: 0

    # Próxima posição candidata
    nx = s.x + fvx * scale
    ny = s.y + fvy * scale

    # -----------------------------------------------------------
    # HARD COLLISION CHECK (CORRIGIDO: 8 Pontos de Checagem)
    # -----------------------------------------------------------
    radius = @enemy_radius
    ts = s.tile_size

    # Constante para distância diagonal (sqrt(2)/2 = ~0.7071)
    r_diag = radius * 0.7071

    # Função auxiliar interna para verificar 8 pontos de colisão
    check_blocked = fn check_x, check_y ->
      # Direita
      # Esquerda
      # Baixo
      # Cima
      # Pontos Diagonais (Corrigem passagem por Quinas)
      # Sudeste
      # Sudoeste
      # Nordeste
      # Noroeste
      Room1.is_blocked?(check_x + radius, check_y, ts) or
        Room1.is_blocked?(check_x - radius, check_y, ts) or
        Room1.is_blocked?(check_x, check_y + radius, ts) or
        Room1.is_blocked?(check_x, check_y - radius, ts) or
        Room1.is_blocked?(check_x + r_diag, check_y + r_diag, ts) or
        Room1.is_blocked?(check_x - r_diag, check_y + r_diag, ts) or
        Room1.is_blocked?(check_x + r_diag, check_y - r_diag, ts) or
        Room1.is_blocked?(check_x - r_diag, check_y - r_diag, ts)
    end

    # Atribui o resultado da expressão if/else a fx
    fx =
      if check_blocked.(nx, s.y) do
        s.x
      else
        nx
      end

    # Atribui o resultado da expressão if/else a fy
    # Usa o fx corrigido na checagem Y
    fy =
      if check_blocked.(fx, ny) do
        s.y
      else
        ny
      end

    %{s | x: fx, y: fy, state: 0, facing: nf}
  end

  # ==============================================================================
  # SHARD CROSSING
  # ==============================================================================
  defp check_shard_crossing(old_state, new_state) do
    old_cx = floor(old_state.x / @cell_size)
    old_cy = floor(old_state.y / @cell_size)

    new_cx = floor(new_state.x / @cell_size)
    new_cy = floor(new_state.y / @cell_size)

    if {old_cx, old_cy} != {new_cx, new_cy} do
      Endpoint.broadcast!("area:#{old_cx}:#{old_cy}", "enemy_left", %{
        id: old_state.id
      })
    end
  end

  # ==============================================================================
  # COMBATE
  # ==============================================================================
  defp perform_attack(state, facing) do
    now = System.system_time(:millisecond)

    if now - state.last_attack_time > @attack_cooldown do
      if state.target_id do
        {final_damage, is_crit} = ActorContext.calculate_outgoing_damage(state.actor)

        Endpoint.broadcast("player:#{state.target_id}", "take_damage", %{
          damage: final_damage,
          attacker_id: state.id,
          is_crit: is_crit
        })
      end

      %{state | state: 1, last_attack_time: now, facing: facing}
    else
      %{state | state: 0, facing: facing}
    end
  end

  defp handle_death(s, history) do
    RpgGameServer.Game.WorldTicker.report_movement(%{
      id: s.id,
      type: s.actor.type,
      x: s.x,
      y: s.y,
      state: s.state,
      face: s.facing,
      hp_percent: 0,
      area: "#{floor(s.x / @cell_size)}:#{floor(s.y / @cell_size)}"
    })

    SpatialGrid.remove(s.id, s.x, s.y)
    broadcast_aoi(s, "enemy_died", %{id: s.id})

    distribute_xp(history, s.xp_reward)
    drop_loot(s)

    Process.send(
      RpgGameServer.Game.EnemySpawner,
      {:mob_died, %{type: s.actor.type, zone: s.zone}},
      []
    )
  end

  # ==============================================================================
  # HELPERS (Boids, Visão, XP, etc)
  # ==============================================================================

  # Separação (Evita empilhamento de mobs)
  defp calc_separation(s) do
    neighbors = SpatialGrid.get_nearby_entities(s.x, s.y) |> Enum.take(6)

    Enum.reduce(neighbors, {0, 0}, fn {oid, {ox, oy}}, {ax, ay} ->
      if oid != s.id do
        dx = s.x - ox
        dy = s.y - oy
        d_sq = dx * dx + dy * dy
        safe_sq = (@enemy_radius * @safe_radius_factor) ** 2

        if d_sq < safe_sq and d_sq > 0.0001 do
          d = :math.sqrt(d_sq)
          strength = (@enemy_radius * @safe_radius_factor - d) / d
          {ax + dx * strength, ay + dy * strength}
        else
          {ax, ay}
        end
      else
        {ax, ay}
      end
    end)
  end

  # Evasão de Parede (Usa 8 "sondas" e constantes nomeadas)
  defp calc_wall_avoidance(s) do
    tile_size = s.tile_size
    d = @enemy_radius + tile_size * 1.5

    whiskers = [
      # Cardeais
      {s.x + d, s.y, {-1.0, 0.0}},
      {s.x - d, s.y, {1.0, 0.0}},
      {s.x, s.y + d, {0.0, -1.0}},
      {s.x, s.y - d, {0.0, 1.0}},

      # Diagonais (usa o fator de repulsão nomeado)
      {s.x + d, s.y - d, {-@diag_repel_factor, @diag_repel_factor}},
      {s.x - d, s.y - d, {@diag_repel_factor, @diag_repel_factor}},
      {s.x + d, s.y + d, {-@diag_repel_factor, -@diag_repel_factor}},
      {s.x - d, s.y + d, {@diag_repel_factor, -@diag_repel_factor}}
    ]

    {fx, fy} =
      Enum.reduce(whiskers, {0.0, 0.0}, fn
        {px, py, {rx, ry}}, {ax, ay} ->
          if Room1.is_blocked?(px, py, tile_size) do
            {ax + rx, ay + ry}
          else
            {ax, ay}
          end
      end)

    mag = :math.sqrt(fx * fx + fy * fy)

    if mag > 0.0 do
      {fx / mag, fy / mag}
    else
      {0.0, 0.0}
    end
  end

  defp find_closest_player_optimized(s) do
    PlayerSpatialGrid.get_nearby_players(s.x, s.y)
    |> Enum.reduce({nil, 9_999_999_999}, fn {id, {px, py}}, {bp, bd} ->
      d = (s.x - px) ** 2 + (s.y - py) ** 2
      if d < bd, do: {%{id: id, x: px, y: py}, d}, else: {bp, bd}
    end)
  end

  # Utilitários de Broadcast
  defp broadcast_aoi(s, evt, pay) do
    topic = "area:#{floor(s.x / @cell_size)}:#{floor(s.y / @cell_size)}"
    Endpoint.broadcast!(topic, evt, pay)
  end

  defp broadcast_to_ticker(s) do
    hp_p = if s.actor.max_hp > 0, do: round(s.actor.hp / s.actor.max_hp * 100), else: 0
    area = "#{floor(s.x / @cell_size)}:#{floor(s.y / @cell_size)}"

    RpgGameServer.Game.WorldTicker.report_movement(%{
      id: s.id,
      type: s.actor.type,
      x: s.x,
      y: s.y,
      state: s.state,
      face: s.facing,
      hp_percent: hp_p,
      area: area
    })
  end

  # Loot e XP (Simplificado)
  defp drop_loot(state) do
    if state.actor.weapon && :rand.uniform() < 0.3 do
      broadcast_aoi(state, "loot_dropped", %{
        x: state.x,
        y: state.y,
        item: state.actor.weapon,
        dropped_at: System.system_time(:millisecond)
      })
    end
  end

  defp distribute_xp(hist, total_xp) do
    total_dmg = Enum.reduce(hist, 0, fn {_, d}, a -> a + d end)

    if total_dmg > 0 do
      Enum.each(hist, fn {pid, dmg} ->
        share = round(total_xp * (dmg / total_dmg))

        if share > 0,
          do: Endpoint.broadcast("player:#{pid}", "xp_gain", %{amount: share, source: "kill"})
      end)
    end
  end

  # Helpers de Lógica Simples
  defp calc_facing(dx, dy), do: round(:math.atan2(-dy, dx) * (180 / :math.pi()))
  defp changed?(o, n), do: o.x != n.x or o.y != n.y or o.state != n.state or o.facing != n.facing
  defp regenerate_hp(s), do: put_in(s.actor.hp, min(s.actor.hp + @heal_rate, s.actor.max_hp))

  defp schedule_tick(state, _last_dt) do
    rate =
      cond do
        state.dist_to_player < 1500 -> @tick_rate
        state.dist_to_player < 3000 -> 1000
        true -> 5000
      end

    Process.send_after(self(), {:tick, rate}, rate)
  end

  # ------------------------------------------------------------------
  # MÁQUINA DE ESTADOS (Helpers)
  # ------------------------------------------------------------------
  defp update_mode(%{mode: :idle} = s, p, d_sq) do
    cond do
      s.actor.hp / s.actor.max_hp < @flee_threshold -> %{s | mode: :flee}
      p && d_sq <= @vision_radius ** 2 -> %{s | mode: :chase, target_id: p.id}
      true -> s
    end
  end

  defp update_mode(%{mode: :chase} = s, p, d_sq) do
    cond do
      s.actor.hp / s.actor.max_hp < @flee_threshold -> %{s | mode: :flee}
      is_nil(p) || d_sq > @give_up_radius ** 2 -> %{s | mode: :idle, target_id: nil}
      true -> %{s | target_id: p.id}
    end
  end

  defp update_mode(%{mode: :flee} = s, _, _) do
    if s.actor.hp / s.actor.max_hp > @return_threshold do
      if s.target_id, do: %{s | mode: :chase}, else: %{s | mode: :idle}
    else
      s
    end
  end

  defp determine_mode_after_damage(hp, max, current) do
    if hp / max < @flee_threshold,
      do: :flee,
      else: if(current == :idle, do: :chase, else: current)
  end

  # Geração de Wander e Flee (Simplificado)
  defp get_wander_target(%{wander_target: nil} = s) do
    ang = :rand.uniform() * 2 * :math.pi()
    dist = :rand.uniform(200) + 50
    tx = s.x + :math.cos(ang) * dist
    ty = s.y + :math.sin(ang) * dist

    if Room1.is_blocked?(tx, ty, s.tile_size),
      do: {s.x, s.y, s},
      else:
        {tx, ty,
         %{
           s
           | wander_target: %{x: tx, y: ty},
             wander_deadline: System.system_time(:millisecond) + 3000
         }}
  end

  defp get_wander_target(s) do
    d = (s.x - s.wander_target.x) ** 2 + (s.y - s.wander_target.y) ** 2

    if d < 100 or System.system_time(:millisecond) > s.wander_deadline,
      do: {s.x, s.y, %{s | wander_target: nil}},
      else: {s.wander_target.x, s.wander_target.y, s}
  end

  defp get_flee_target(s, nil), do: {s.x, s.y, s}

  defp get_flee_target(s, p) do
    dx = s.x - p.x
    dy = s.y - p.y
    dist = :math.sqrt(dx * dx + dy * dy)
    if dist < 0.1, do: {s.x, s.y, s}, else: {s.x + dx / dist * 150, s.y + dy / dist * 150, s}
  end

  # Setup de Build (Stats e Arma)
  defp determine_target_power(x, y) do
    case PlayerSpatialGrid.get_nearby_players(x, y) do
      [] -> 60
      _ -> 80
    end
  end

  defp generate_mob_build(score) do
    level = max(1, trunc(score / 6))
    stats = @base_mob_stats
    weapon = Weapon.generate_random(level)
    chest = Chest.generate_random(level)
    head = nil
    gloves = nil
    pants = nil

    # Rings
    ring1 = nil
    ring2 = nil
    ring3 = nil
    ring4 = nil
    ring5 = nil

    {stats, weapon, head, chest, gloves, pants, ring1, ring2, ring3, ring4, ring5, level}
  end
end
