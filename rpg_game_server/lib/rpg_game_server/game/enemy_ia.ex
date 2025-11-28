defmodule RpgGameServer.Game.EnemyAI do
  use GenServer, restart: :temporary
  require Logger

  # Aliases
  # Added PlayerSpatialGrid to alias list
  alias RpgGameServer.Game.{Room1, SpatialGrid, PlayerSpatialGrid}
  alias RpgGameServerWeb.Presence
  alias RpgGameServerWeb.Endpoint

  # --- CONFIGURAÇÕES DE GAMEPLAY ---
  @tick_rate 100          # Base tick (será dinâmico agora)
  @speed 5                # Pixels por tick
  @vision_radius 100      # Raio de detecção (Chase)
  @give_up_radius 200     # Raio de desistência
  @attack_range 15        # Alcance do ataque melee
  @attack_cooldown 1000   # 1 segundo entre ataques

  # Física
  @separation_force 1.5
  @wall_repulsion_force 3.0
  @enemy_radius 5

  # Status
  @max_hp 50
  @xp_reward 50

  # Fleeing
  @flee_threshold 0.3
  @return_threshold 0.8
  @heal_rate 1

  # Wander
  @wander_timeout 3000

  # Networking (AOI)
  @cell_size 700 # Matches RoomChannel

  # --- API ---
  def start_link(args), do: GenServer.start_link(__MODULE__, args)

  # --- CALLBACKS ---
  @impl true
  def init(initial_state) do
    {:ok, _} = Registry.register(RpgGameServer.EnemyRegistry, initial_state.id, nil)
    SpatialGrid.insert(initial_state.id, initial_state.x, initial_state.y)

    state =
      Map.merge(initial_state, %{
        mode: :idle,         # :idle, :chase, :flee
        wander_target: nil,
        wander_deadline: 0,
        target_id: nil,
        hp: @max_hp,
        state: 0,
        last_attack_time: 0,
        facing: 270,
        damage_history: %{},
        last_x: initial_state.x,
        last_y: initial_state.y,
        dist_to_player: 999999 # Cache for LOD
      })

    # Inicia o tick dinâmico passando o estado inicial
    schedule_tick(state)
    {:ok, state}
  end

  @impl true
  def handle_cast({:take_damage, amount, attacker_id}, state) do
    new_hp = state.hp - amount
    new_history = Map.update(state.damage_history, attacker_id, amount, &(&1 + amount))

    broadcast_aoi(state, "damage_applied", %{
      target_id: state.id,
      attacker_id: attacker_id,
      damage: amount,
      type: "pve"
    })

    if new_hp <= 0 do
      die(state, new_history)
      {:stop, :normal, state}
    else
      new_mode = determine_mode_after_damage(new_hp, state.mode)
      # Force active tick (dist_to_player = 0) to react immediately
      new_state = %{state | hp: new_hp, target_id: attacker_id, mode: new_mode, damage_history: new_history, wander_target: nil, dist_to_player: 0}
      {:noreply, new_state}
    end
  end

  defp die(state, damage_history) do
    SpatialGrid.remove(state.id, state.last_x, state.last_y)
    RpgGameServer.Game.WorldTicker.remove_from_buffer(state.id)

    broadcast_aoi(state, "enemy_died", %{id: state.id})
    distribute_xp(damage_history)

    spawn_params = %{type: state.type, zone: "1"}
    Process.send(RpgGameServer.Game.EnemySpawner, {:schedule_respawn, spawn_params}, [])
  end

  @impl true
  def handle_info(:tick, state) do
    # Atualiza Grid Espacial apenas se moveu
    if state.x != state.last_x or state.y != state.last_y do
       SpatialGrid.update(state.id, state.last_x, state.last_y, state.x, state.y)
    end

    new_state = process_ai(state)
    final_state = %{new_state | last_x: state.x, last_y: state.y}

    if changed?(state, final_state) do
      broadcast_to_ticker(final_state)
    end

    # Chama o agendamento dinâmico passando o novo estado (para recalcular distância)
    schedule_tick(final_state)
    {:noreply, final_state}
  end

  # --- LÓGICA DE TICK ADAPTATIVO (LOD) ---

  defp schedule_tick(state) do
    dist = state.dist_to_player

    rate = cond do
      dist < 1000 -> 100     # Tier 1: Ativo (10 FPS)
      dist < 2000 -> 1000    # Tier 2: Buffer (1 FPS)
      true -> 5000           # Tier 3: Longe (0.2 FPS)
    end

    Process.send_after(self(), :tick, rate)
  end

  # --- CÉREBRO DA IA ---

  defp process_ai(state) do
    # Optimization: Find player using SpatialGrid and get squared distance
    {closest_player, dist_sq} = find_closest_player_optimized(state)

    # Store approximate distance for LOD check in next tick
    actual_dist = :math.sqrt(dist_sq)
    state = %{state | dist_to_player: actual_dist}

    state = update_mode(state, closest_player, dist_sq)

    {tx, ty, state} =
      case state.mode do
        :chase -> {closest_player.x, closest_player.y, state}
        :idle -> get_wander_target(state)
        :flee ->
          state = regenerate_hp(state)
          get_flee_target(state, closest_player)
      end

    move_entity(state, tx, ty)
  end

  # --- MÁQUINA DE ESTADOS (Optimized for dist_sq) ---

  defp determine_mode_after_damage(hp, current_mode) do
    if hp / @max_hp < @flee_threshold, do: :flee, else: (if current_mode == :idle, do: :chase, else: current_mode)
  end

  defp update_mode(%{mode: :idle} = state, player, dist_sq) do
    # Optimization: Use squared radius for check
    vision_sq = @vision_radius * @vision_radius

    if state.hp / @max_hp < @flee_threshold do
       %{state | mode: :flee}
    else
       if player && dist_sq <= vision_sq do
         %{state | mode: :chase, wander_target: nil, target_id: player.id}
       else
         state
       end
    end
  end

  defp update_mode(%{mode: :chase} = state, player, dist_sq) do
    give_up_sq = @give_up_radius * @give_up_radius

    if state.hp / @max_hp < @flee_threshold do
       %{state | mode: :flee}
    else
       if is_nil(player) || dist_sq > give_up_sq do
         %{state | mode: :idle, target_id: nil, state: 0}
       else
         %{state | target_id: player.id}
       end
    end
  end

  defp update_mode(%{mode: :flee} = state, _player, _dist_sq) do
    if state.hp / @max_hp > @return_threshold do
       if state.target_id, do: %{state | mode: :chase}, else: %{state | mode: :idle}
    else
       state
    end
  end

  defp regenerate_hp(state), do: %{state | hp: min(state.hp + @heal_rate, @max_hp)}

  # --- MOVIMENTO E ALVOS ---

  defp get_flee_target(state, nil), do: {state.x, state.y, state}
  defp get_flee_target(state, player) do
    dx = state.x - player.x
    dy = state.y - player.y
    dist = :math.sqrt(dx*dx + dy*dy)

    if dist == 0 do
       {state.x, state.y, state}
    else
       vx = (dx / dist) * 100
       vy = (dy / dist) * 100
       tx = state.x + vx
       ty = state.y + vy
       if Room1.is_blocked?(tx, ty), do: pick_random_point_panic(state), else: {tx, ty, state}
    end
  end

  defp get_wander_target(%{wander_target: nil} = state) do
    target = pick_valid_wander_point(state)
    deadline = System.system_time(:millisecond) + @wander_timeout
    {target.x, target.y, %{state | wander_target: target, wander_deadline: deadline}}
  end

  defp get_wander_target(%{wander_target: target, wander_deadline: deadline} = state) do
    now = System.system_time(:millisecond)
    # Simple squared dist check for arrival
    dx = state.x - target.x
    dy = state.y - target.y
    dist_sq = (dx*dx) + (dy*dy)

    cond do
      dist_sq < 100 -> {state.x, state.y, %{state | wander_target: nil}} # < 10px
      now > deadline -> {state.x, state.y, %{state | wander_target: nil}}
      true -> {target.x, target.y, state}
    end
  end

  defp pick_valid_wander_point(state, attempts \\ 3)
  defp pick_valid_wander_point(state, 0), do: %{x: state.x, y: state.y}
  defp pick_valid_wander_point(state, attempts) do
    angle = :rand.uniform() * 2 * :math.pi()
    dist = :rand.uniform(100) + 50
    tx = state.x + :math.cos(angle) * dist
    ty = state.y + :math.sin(angle) * dist

    if is_path_clear?(state.x, state.y, tx, ty) do
      %{x: tx, y: ty}
    else
      pick_valid_wander_point(state, attempts - 1)
    end
  end

  defp pick_random_point_panic(state) do
     angle = :rand.uniform() * 2 * :math.pi()
     tx = state.x + :math.cos(angle) * 30
     ty = state.y + :math.sin(angle) * 30
     {tx, ty, state}
  end

  defp is_path_clear?(x1, y1, x2, y2) do
    if Room1.is_blocked?(x2, y2) do
      false
    else
      mid_x = (x1 + x2) / 2
      mid_y = (y1 + y2) / 2
      not Room1.is_blocked?(mid_x, mid_y)
    end
  end

  # --- PHYSICS ---

  defp move_entity(state, tx, ty) do
    dx = tx - state.x
    dy = ty - state.y
    dist_target_sq = (dx*dx) + (dy*dy)
    dist_target = :math.sqrt(dist_target_sq)

    new_facing = if dist_target > 1, do: calc_facing(dx, dy), else: state.facing

    # Optimization: Use squared distance for range check
    attack_range_sq = @attack_range * @attack_range

    cond do
      state.mode == :flee ->
         state = %{state | state: 0, facing: new_facing}
         do_physics_move(state, dx, dy, dist_target)

      state.mode == :chase and dist_target_sq <= attack_range_sq ->
        perform_attack(state, new_facing)

      true ->
        state = %{state | state: 0, facing: new_facing}
        do_physics_move(state, dx, dy, dist_target)
    end
  end

  defp do_physics_move(state, dx, dy, dist_target) do
    if dist_target < 2 do
      state
    else
      vx = dx / dist_target
      vy = dy / dist_target

      {sep_x, sep_y} = calculate_separation_optimized(state)
      {wall_x, wall_y} = calculate_wall_repulsion(state)

      final_vx = vx + (sep_x * @separation_force) + (wall_x * @wall_repulsion_force)
      final_vy = vy + (sep_y * @separation_force) + (wall_y * @wall_repulsion_force)

      mag = :math.sqrt(final_vx * final_vx + final_vy * final_vy)
      scale = if mag > 0, do: @speed / mag, else: 0

      next_x = state.x + (final_vx * scale)
      next_y = state.y + (final_vy * scale)

      final_x = if Room1.is_blocked?(next_x, state.y), do: state.x, else: next_x
      final_y = if Room1.is_blocked?(final_x, next_y), do: state.y, else: next_y

      %{state | x: final_x, y: final_y}
    end
  end

  defp calculate_wall_repulsion(state) do
    dist = @enemy_radius + 10
    force_x = (if Room1.is_blocked?(state.x + dist, state.y), do: -1, else: 0) + (if Room1.is_blocked?(state.x - dist, state.y), do: 1, else: 0)
    force_y = (if Room1.is_blocked?(state.x, state.y + dist), do: -1, else: 0) + (if Room1.is_blocked?(state.x, state.y - dist), do: 1, else: 0)
    {force_x, force_y}
  end

  defp calculate_separation_optimized(state) do
    nearby_entities = SpatialGrid.get_nearby_entities(state.x, state.y)

    Enum.reduce(nearby_entities, {0, 0}, fn {other_id, {ox, oy}}, {acc_x, acc_y} ->
      if other_id != state.id do
        dx = state.x - ox
        dy = state.y - oy
        dist_sq = (dx * dx) + (dy * dy)
        min_dist = @enemy_radius * 2
        min_dist_sq = min_dist * min_dist

        if dist_sq > 0 and dist_sq < min_dist_sq do
          dist = :math.sqrt(dist_sq)
          force = 1.0 / dist
          {acc_x + (dx * force), acc_y + (dy * force)}
        else
          {acc_x, acc_y}
        end
      else
        {acc_x, acc_y}
      end
    end)
  end

  # --- HELPERS ---

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
      broadcast_aoi(state, "damage_applied", %{
        target_id: state.target_id, attacker_id: state.id, damage: 10, type: "enemy_hit"
      })
    end
  end

  defp distribute_xp(history) do
    total = Enum.reduce(history, 0, fn {_, d}, acc -> acc + d end)
    if total > 0 do
      Enum.each(history, fn {pid, dmg} ->
        xp = round(@xp_reward * (dmg / total))
        if xp > 0, do: Endpoint.broadcast!("room:lobby", "xp_gain", %{player_id: pid, amount: xp, source: "kill"})
      end)
    end
  end

  defp broadcast_aoi(state, event, payload) do
    cx = floor(state.x / @cell_size)
    cy = floor(state.y / @cell_size)
    topic = "area:#{cx}:#{cy}"
    Endpoint.broadcast!(topic, event, payload)
  end

  defp broadcast_to_ticker(state) do
    RpgGameServer.Game.WorldTicker.report_movement(%{
      id: state.id,
      type: state.type,
      x: state.x,
      y: state.y,
      state: state.state,
      face: state.facing
    })
  end

  # --- PLAYER SEARCH OPTIMIZED (PlayerSpatialGrid) ---
  defp find_closest_player_optimized(state) do
    # Search only nearby cells (O(1)) instead of all players (O(N))
    nearby_players = PlayerSpatialGrid.get_nearby_players(state.x, state.y)

    nearby_players
    |> Enum.reduce({nil, 9999999999}, fn {id, {px, py}}, {best_p, best_dist_sq} ->
      dx = state.x - px
      dy = state.y - py
      dist_sq = (dx * dx) + (dy * dy)

      if dist_sq < best_dist_sq do
        {%{id: id, x: px, y: py}, dist_sq}
      else
        {best_p, best_dist_sq}
      end
    end)
  end

  # Fallback helper just in case (though not used in main loop anymore)
  defp distance(%{x: x1, y: y1}, %{x: x2, y: y2}), do: :math.sqrt(:math.pow(x1-x2, 2) + :math.pow(y1-y2, 2))

  defp calc_facing(dx, dy), do: round(:math.atan2(-dy, dx) * (180 / :math.pi()))
  defp changed?(old, new), do: old.x != new.x or old.y != new.y or old.state != new.state or old.facing != new.facing
end
