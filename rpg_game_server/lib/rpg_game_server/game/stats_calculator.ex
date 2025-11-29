defmodule RpgGameServer.Game.StatsCalculator do
  @moduledoc """
  Calcula estatísticas derivadas (HP, Stamina, Dano) baseadas em atributos primários
  usando lógica de Soft Caps estilo Dark Souls.
  """

  # --- CONSTANTES BASE ---
  @base_hp 400
  @base_stamina 80
  @base_mana 60
  @base_equip_load 40.0

  # ===================================================================
  # 1. CUSTO DE NÍVEL (XP)
  # ===================================================================

  def xp_for_next_level(current_level) do
    # Curva exponencial suave.
    # Nível 10: ~15.000 XP | Nível 50: ~500.000 XP
    base = 100
    exponent = 2.2
    trunc(base * :math.pow(current_level, exponent))
  end

  # ===================================================================
  # 2. VIGOR -> HP MÁXIMO (A função que faltava)
  # ===================================================================

  def calculate_max_hp(vigor) do
    cond do
      # [Nível 1-20] Crescimento Acelerado (Early Game)
      # Ganha 30 HP por ponto.
      vigor <= 20 ->
        @base_hp + vigor * 30

      # [Nível 21-40] Soft Cap 1 (Mid Game)
      # Ganha 20 HP por ponto.
      vigor <= 40 ->
        hp_at_20 = @base_hp + 20 * 30
        hp_at_20 + (vigor - 20) * 20

      # [Nível 41-60] Soft Cap 2 (Late Game)
      # Ganha 10 HP por ponto. Começa a não valer tanto a pena.
      vigor <= 60 ->
        hp_at_40 = @base_hp + 20 * 30 + 20 * 20
        hp_at_40 + (vigor - 40) * 10

      # [Nível 61+] Hard Cap (End Game)
      # Ganha apenas 2 HP por ponto. Desperdício de ponto.
      true ->
        hp_at_60 = @base_hp + 20 * 30 + 20 * 20 + 20 * 10
        hp_at_60 + (vigor - 60) * 2
    end
  end

  # ===================================================================
  # 3. SCALING DE DANO (A função que faltava)
  # ===================================================================

  # Esta função retorna um MULTIPLICADOR (ex: 0.85 = 85%).
  # Usado para Força, Destreza, Inteligência e Fé.
  # Fórmula: Dano = DanoArma + (DanoArma * ScalingArma * calculate_stat_bonus(SeuAtributo))
  def calculate_stat_bonus(stat_value) do
    cond do
      # [0-20] Crescimento Rápido
      # Sobe linearmente até 50% de eficiência
      stat_value <= 20 ->
        stat_value / 40.0

      # [21-40] O "Sweet Spot" (Onde a maioria das builds para)
      # Sobe de 50% para 85% de eficiência
      stat_value <= 40 ->
        0.50 + (stat_value - 20) * (0.35 / 20)

      # [41-60] Retornos Decrescentes
      # Sobe de 85% para 100% (custa 20 pontos pra ganhar 15%)
      stat_value <= 60 ->
        0.85 + (stat_value - 40) * (0.15 / 20)

      # [61+] Hard Cap
      # Sobe migalhas (0.2% por ponto)
      true ->
        1.0 + (stat_value - 60) * 0.002
    end
  end

  # ===================================================================
  # 4. ENDURANCE -> STAMINA & CARGA
  # ===================================================================

  def calculate_stamina(endurance) do
    cond do
      endurance <= 40 -> @base_stamina + endurance * 2
      # Hard Cap total em 40
      true -> @base_stamina + 40 * 2
    end
  end

  def calculate_stamina_regen(endurance) do
    # pontos/segundo
    base_regen = 30
    bonus = if endurance > 20, do: (endurance - 20) * 0.5, else: 0
    base_regen + bonus
  end

  def calculate_equip_load(endurance) do
    cond do
      endurance <= 25 ->
        @base_equip_load + endurance * 1.5

      endurance <= 60 ->
        base_25 = @base_equip_load + 25 * 1.5
        base_25 + (endurance - 25) * 1.0

      true ->
        base_60 = @base_equip_load + 25 * 1.5 + 35 * 1.0
        base_60 + (endurance - 60) * 0.5
    end
  end

  # ===================================================================
  # 5. ATTUNEMENT -> MANA & SLOTS
  # ===================================================================

  def calculate_mana(attunement) do
    cond do
      attunement <= 20 ->
        @base_mana + attunement * 6

      attunement <= 35 ->
        at_20 = @base_mana + 20 * 6
        at_20 + (attunement - 20) * 3

      true ->
        at_35 = @base_mana + 20 * 6 + 15 * 3
        at_35 + (attunement - 35) * 1
    end
  end

  def calculate_attunement_slots(attunement) do
    cond do
      attunement < 10 -> 0
      attunement < 14 -> 1
      attunement < 18 -> 2
      attunement < 24 -> 3
      attunement < 30 -> 4
      attunement < 40 -> 5
      true -> 6 + div(attunement - 40, 10)
    end
  end

  # ===================================================================
  # 6. HELPERS SECUNDÁRIOS (Dex Crit, Faith Heal)
  # ===================================================================

  def calculate_crit_chance(dexterity) do
    base_crit = 0.05

    cond do
      # até 25%
      dexterity <= 40 -> base_crit + dexterity * 0.005
      # até 30%
      dexterity <= 60 -> 0.25 + (dexterity - 40) * 0.0025
      # Hard Cap 35%
      true -> 0.35
    end
  end

  def calculate_evasion_chance(dexterity) do
    max_evasion = 0.30
    if dexterity >= 80, do: max_evasion, else: dexterity / 80 * max_evasion
  end

  def calculate_healing_power(faith) do
    base_heal = 100
    # Reusa a lógica de scaling
    bonus_pct = calculate_stat_bonus(faith)
    trunc(base_heal * (1 + bonus_pct))
  end

  # ===================================================================
  # 7. DEFESAS (Mitigação de Dano)
  # ===================================================================

  # Defesa Física baseada em Força (Strength)
  # Ex: 40 Str = 80 de defesa. Se o ataque for 100, recebe apenas 20.
  def calculate_physical_defense(strength) do
    # Multiplicador 2.0 garante que Tanks sejam realmente duros de matar
    trunc(strength * 2.0)
  end

  # Defesa Mágica baseada em Inteligência (Intelligence)
  def calculate_magic_defense(intelligence) do
    trunc(intelligence * 2.0)
  end
end
