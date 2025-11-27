defmodule RpgGameServer.Game.EnemyAI do
  use GenServer, restart: :temporary
  require Logger
  alias RpgGameServer.Game.Room1
  alias RpgGameServerWeb.Presence
  alias RpgGameServerWeb.Endpoint

  # --- CONFIGURAÇÕES ---
  @tick_rate 100
  @speed 5
  @vision_radius 100
  @give_up_radius 200
  @attack_range 15
  @attack_cooldown 1000
  @separation_force 1.5
  @enemy_radius 5
  @max_hp 1000

  # Fleeing Config
  @flee_threshold 0.3
  @return_threshold 0.8
  @heal_rate 5

  # XP Config
  @xp_reward 50 # XP total que o monstro dá

  # --- API ---
  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  # --- CALLBACKS ---
  @impl true
  def init(initial_state) do
    {:ok, _} = Registry.register(RpgGameServer.EnemyRegistry, initial_state.id, nil)

    state =
      Map.merge(initial_state, %{
        mode: :idle,
        wander_target: nil,
        target_id: nil,
        hp: @max_hp,
        state: 0,
        last_attack_time: 0,
        facing: 270,

        # --- NOVO: Histórico de Dano ---
        # Mapa: %{"player_id_1" => 150, "player_id_2" => 50}
        damage_history: %{}
      })

    schedule_tick()
    {:ok, state}
  end

  @impl true
  def handle_cast({:take_damage, amount, attacker_id}, state) do
    new_hp = state.hp - amount

    # --- NOVO: Registra o dano no histórico ---
    new_history = Map.update(state.damage_history, attacker_id, amount, fn current -> current + amount end)

    Endpoint.broadcast!("room:lobby", "damage_applied", %{
      target_id: state.id,
      attacker_id: attacker_id,
      damage: amount,
      type: "pve"
    })

    if new_hp <= 0 do
      # Passamos o histórico atualizado para a função die processar o XP
      die(state, new_history)
      {:stop, :normal, state}
    else
      new_mode = determine_mode_after_damage(new_hp, state.mode)

      new_state = %{state |
        hp: new_hp,
        target_id: attacker_id,
        mode: new_mode,
        damage_history: new_history # Salva o histórico atualizado
      }
      {:noreply, new_state}
    end
  end

  # Atualizei a assinatura para receber o history
  defp die(state, damage_history) do
    Endpoint.broadcast!("room:lobby", "enemy_died", %{id: state.id})

    # --- NOVO: Lógica de Distribuição de XP ---
    distribute_xp(damage_history)

    spawn_params = %{type: state.type, zone: "1"}
    Process.send(RpgGameServer.Game.EnemySpawner, {:schedule_respawn, spawn_params}, [])
  end

  # Função auxiliar para calcular e entregar XP
  defp distribute_xp(history) do
    total_damage = Enum.reduce(history, 0, fn {_, dmg}, acc -> acc + dmg end)

    if total_damage > 0 do
      Enum.each(history, fn {player_id, damage_dealt} ->
        # Cálculo proporcional (Contribution Based)
        # Se eu dei 50% do dano, ganho 50% do XP
        percentage = damage_dealt / total_damage
        xp_gain = round(@xp_reward * percentage)

        if xp_gain > 0 do
           # Envia evento de XP para o player (RoomChannel ou PlayerChannel deve tratar isso)
           # Como o player_id aqui é o ID do socket ou user, precisamos rotear.
           # Supondo broadcast global por enquanto, mas idealmente seria direct push.
           Endpoint.broadcast!("room:lobby", "xp_gain", %{
             player_id: player_id,
             amount: xp_gain,
             source: "kill"
           })
           Logger.info("Player #{player_id} ganhou #{xp_gain} XP.")
        end
      end)
    end
  end

  # ... (Resto do código handle_info, process_ai, etc continua igual) ...
  @impl true
  def handle_info(:tick, state) do
    if :ets.info(:enemy_positions) != :undefined do
      :ets.insert(:enemy_positions, {state.id, {state.x, state.y}})
    end

    new_state = process_ai(state)

    if changed?(state, new_state) do
      broadcast_update(new_state)
    end

    schedule_tick()
    {:noreply, new_state}
  end

  defp process_ai(state) do
    closest_player = find_closest_player(state)
    state = update_mode(state, closest_player)

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

  defp determine_mode_after_damage(hp, current_mode) do
    if hp / @max_hp < @flee_threshold do
      :flee
    else
      if current_mode == :idle, do: :chase, else: current_mode
    end
  end

  defp update_mode(%{mode: :idle} = state, player) do
    if state.hp / @max_hp < @flee_threshold do
       %{state | mode: :flee}
    else
       if player && distance(state, player) <= @vision_radius do
         %{state | mode: :chase, wander_target: nil, target_id: player.id}
       else
         state
       end
    end
  end

  defp update_mode(%{mode: :chase} = state, player) do
    if state.hp / @max_hp < @flee_threshold do
       %{state | mode: :flee}
    else
       if is_nil(player) || distance(state, player) > @give_up_radius do
         %{state | mode: :idle, target_id: nil, state: 0}
       else
         %{state | target_id: player.id}
       end
    end
  end

  defp update_mode(%{mode: :flee} = state, _player) do
    if state.hp / @max_hp > @return_threshold do
       if state.target_id, do: %{state | mode: :chase}, else: %{state | mode: :idle}
    else
       state
    end
  end

  defp regenerate_hp(state) do
    new_hp = min(state.hp + @heal_rate, @max_hp)
    %{state | hp: new_hp}
  end

  defp get_flee_target(state, nil), do: {state.x, state.y, state}
  defp get_flee_target(state, player) do
    dx = state.x - player.x
    dy = state.y - player.y
    dist = :math.sqrt(dx*dx + dy*dy)

    if dist == 0 do
       {state.x, state.y, state}
    else
       flee_dist = 100
       vx = (dx / dist) * flee_dist
       vy = (dy / dist) * flee_dist
       tx = state.x + vx
       ty = state.y + vy

       if Room1.is_blocked?(tx, ty) do
          pick_random_point_panic(state)
       else
          {tx, ty, state}
       end
    end
  end

  defp pick_random_point_panic(state) do
     angle = :rand.uniform() * 2 * :math.pi()
     dist = 30
     tx = state.x + :math.cos(angle) * dist
     ty = state.y + :math.sin(angle) * dist
     {tx, ty, state}
  end

  defp move_entity(state, tx, ty) do
    dx = tx - state.x
    dy = ty - state.y
    dist_target = :math.sqrt(dx * dx + dy * dy)
    new_facing = if dist_target > 1, do: calc_facing(dx, dy), else: state.facing

    cond do
      state.mode == :flee ->
         state = %{state | state: 0, facing: new_facing}
         do_physics_move(state, dx, dy, dist_target)

      state.mode == :chase and dist_target <= @attack_range ->
        perform_attack(state, new_facing)

      true ->
        state = %{state | state: 0, facing: new_facing}
        do_physics_move(state, dx, dy, dist_target)
    end
  end

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
      damage_amount = 10
      Endpoint.broadcast!("room:lobby", "damage_applied", %{
        target_id: state.target_id,
        attacker_id: state.id,
        damage: damage_amount,
        type: "enemy_hit"
      })
    end
  end

  defp do_physics_move(state, dx, dy, dist_target) do
    if dist_target < 2 do
      state
    else
      vx = dx / dist_target
      vy = dy / dist_target
      {sep_x, sep_y} = calculate_separation(state)
      final_vx = vx + sep_x * @separation_force
      final_vy = vy + sep_y * @separation_force
      mag = :math.sqrt(final_vx * final_vx + final_vy * final_vy)
      scale = if mag > 0, do: @speed / mag, else: 0
      move_x = final_vx * scale
      move_y = final_vy * scale
      next_x = state.x + move_x
      next_y = state.y + move_y
      final_x = if Room1.is_blocked?(next_x, state.y), do: state.x, else: next_x
      final_y = if Room1.is_blocked?(final_x, next_y), do: state.y, else: next_y
      %{state | x: final_x, y: final_y}
    end
  end

  defp calculate_separation(state) do
    if :ets.info(:enemy_positions) == :undefined do
      {0, 0}
    else
      :ets.tab2list(:enemy_positions)
      |> Enum.reduce({0, 0}, fn {other_id, {ox, oy}}, {acc_x, acc_y} ->
        if other_id != state.id do
          dx = state.x - ox
          dy = state.y - oy
          dist = :math.sqrt(dx * dx + dy * dy)
          if dist > 0 and dist < @enemy_radius * 2 do
            force = 1.0 / dist
            {acc_x + dx * force, acc_y + dy * force}
          else
            {acc_x, acc_y}
          end
        else
          {acc_x, acc_y}
        end
      end)
    end
  end

  defp get_wander_target(%{wander_target: nil} = state) do
    target = pick_random_point(state)
    {target.x, target.y, %{state | wander_target: target}}
  end

  defp get_wander_target(%{wander_target: target} = state) do
    dist = distance(state, target)
    if dist < 10 do
      {state.x, state.y, %{state | wander_target: nil}}
    else
      {target.x, target.y, state}
    end
  end

  defp pick_random_point(%{x: x, y: y}) do
    angle = :rand.uniform() * 2 * :math.pi()
    dist = :rand.uniform(100) + 50
    tx = x + :math.cos(angle) * dist
    ty = y + :math.sin(angle) * dist
    if Room1.is_blocked?(tx, ty), do: %{x: x, y: y}, else: %{x: tx, y: ty}
  end

  defp calc_facing(dx, dy) do
    rad = :math.atan2(-dy, dx)
    deg = rad * (180 / :math.pi())
    round(deg)
  end

  defp find_closest_player(state) do
    Presence.list("room:lobby")
    |> Enum.map(fn {id, meta} ->
      d = List.first(meta.metas)
      %{id: id, x: d.x, y: d.y}
    end)
    |> Enum.min_by(fn p -> distance(state, p) end, fn -> nil end)
  end

  defp distance(%{x: x1, y: y1}, %{x: x2, y: y2}) do
    dx = x1 - x2
    dy = y1 - y2
    :math.sqrt(dx * dx + dy * dy)
  end

  defp changed?(old, new) do
    old.x != new.x or old.y != new.y or old.state != new.state or old.facing != new.facing
  end

  defp broadcast_update(state) do
    Endpoint.broadcast!("room:lobby", "enemy_update", %{
      id: state.id,
      type: state.type,
      x: state.x,
      y: state.y,
      state: state.state,
      face: state.facing
    })
  end

  defp schedule_tick, do: Process.send_after(self(), :tick, @tick_rate)
end
