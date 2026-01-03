defmodule RpgGameServer.Game.ActorContext do
  alias RpgGameServer.Game.StatsCalculator
  alias RpgGameServer.Game.Schema.Item

  # Struct de Ator atualizada
  defstruct [
    :id,
    :type,
    :name,
    :stats,
    :hp,
    :max_hp,
    # Agora esperamos que isso seja um %Item{} ou nil
    :weapon
  ]

  # --- CRIAÇÃO ---
  def new(type, params) do
    default_stats = %{
      vigor: 10,
      endurance: 10,
      strength: 10,
      dexterity: 10,
      intelligence: 5,
      faith: 5,
      attunement: 5
    }

    stats = Map.merge(default_stats, params[:stats] || %{})
    max_hp = StatsCalculator.calculate_max_hp(stats.vigor)

    struct!(__MODULE__, %{
      id: params.id,
      type: type,
      name: params[:name] || "Unknown",
      stats: stats,
      hp: params[:hp] || max_hp,
      max_hp: max_hp,
      # Pode ser nil (desarmado)
      weapon: params[:weapon]
    })
  end

  # --- DANO DE SAÍDA (ATUALIZADO PARA ITEM) ---
  def calculate_outgoing_damage(%__MODULE__{} = actor) do
    stats = actor.stats

    # Se não tiver arma, usa "Punhos" (Fists)
    weapon_combat =
      case actor.weapon do
        %Item{combat_stats: cs} -> cs
        # Unarmed
        _ -> %{base_damage: 2, scale_str: 0.5, scale_dex: 0.5}
      end

    # Cálculo usando os dados extraídos
    str_bonus = StatsCalculator.calculate_stat_bonus(stats.strength)
    dex_bonus = StatsCalculator.calculate_stat_bonus(stats.dexterity)

    # Verifica se as chaves existem no mapa (defensive coding)
    w_dmg = Map.get(weapon_combat, :base_damage, 1)
    s_str = Map.get(weapon_combat, :scale_str, 0.0)
    s_dex = Map.get(weapon_combat, :scale_dex, 0.0)

    scaling_dmg = w_dmg * s_str * str_bonus + w_dmg * s_dex * dex_bonus
    attack_rating = trunc(w_dmg + scaling_dmg)

    variation = 0.9 + :rand.uniform() * 0.2
    raw_final = trunc(attack_rating * variation)

    crit_chance = StatsCalculator.calculate_crit_chance(stats.dexterity)
    is_crit = :rand.uniform() < crit_chance
    final_damage = if is_crit, do: trunc(raw_final * 1.5), else: raw_final

    {final_damage, is_crit}
  end

  def take_damage(actor, raw_damage) do
    defense = StatsCalculator.calculate_physical_defense(actor.stats.strength)
    min_damage = trunc(raw_damage * 0.1)
    final_damage = max(min_damage, raw_damage - trunc(defense))
    new_hp = actor.hp - final_damage
    updated_actor = %{actor | hp: max(0, new_hp)}
    {updated_actor, final_damage, new_hp <= 0}
  end
end
