defmodule RpgGameServer.Game.Factory.Weapon do
  @moduledoc """
  Responsável por gerar armas proceduralmente em memória.
  Combina templates (Espada, Machado, etc) com prefixos baseados em nível.
  """

  alias RpgGameServer.Game.Schema.Item

  # --- DEFINIÇÕES (TEMPLATES) ---

  # Aqui definimos o "DNA" de cada tipo de arma.
  # speed: 1.0 é normal, < 1.0 é lento, > 1.0 é rápido
  @templates %{
    sword: %{
      name: "Sword",
      base_dmg: 8,
      scale_str: 0.7,
      scale_dex: 0.5,
      speed: 1.0
    },
    dagger: %{
      name: "Dagger",
      base_dmg: 5,
      scale_str: 0.2,
      # Escala muito com Dex
      scale_dex: 1.1,
      # Ataca mais rápido (futuro)
      speed: 1.4
    },
    axe: %{
      name: "Axe",
      base_dmg: 12,
      # Escala muito com Força
      scale_str: 1.2,
      scale_dex: 0.1,
      # Lento
      speed: 0.8
    },
    spear: %{
      name: "Spear",
      base_dmg: 9,
      scale_str: 0.6,
      scale_dex: 0.6,
      speed: 1.1
    }
  }

  @keys Map.keys(@templates)

  # --- API PÚBLICA ---

  @doc """
  Gera uma arma aleatória apropriada para o nível informado.
  """
  def generate_random(level, rarity \\ :common) do
    type_key = Enum.random(@keys)
    generate(type_key, level, rarity)
  end

  @doc """
  Gera uma arma específica (ex: :sword) para o nível informado.
  """
  def generate(type_key, level, rarity) do
    template = Map.get(@templates, type_key)

    # 1. Determina o material/prefixo pelo nível
    {prefix, tier_bonus} = get_tier_info(level)

    # 2. Calcula atributos finais
    # Fórmula: DanoBase + (Nível * Multiplicador) + BonusMaterial
    final_damage = trunc(template.base_dmg + level * 1.5 + tier_bonus)

    full_name = "#{prefix} #{template.name}"

    # 3. Retorna a Struct Item pronta
    %Item{
      id: System.unique_integer([:positive]),
      name: full_name,
      type: :weapon,
      slot: :main_hand,
      rarity: rarity,
      # Stats passivos extras podem ser adicionados aqui
      stats: %{},
      combat_stats: %{
        base_damage: final_damage,
        scale_str: template.scale_str,
        scale_dex: template.scale_dex,
        attack_speed: template.speed,
        # Exemplo de alcance
        range: if(type_key == :spear, do: 70, else: 40)
      }
    }
  end

  # --- HELPERS PRIVADOS ---

  # Retorna {NomeDoMaterial, BonusDeDano} baseado no nível
  defp get_tier_info(level) do
    cond do
      level <= 3 -> {"Rusty", 0}
      level <= 8 -> {"Wooden", 2}
      level <= 15 -> {"Iron", 5}
      level <= 25 -> {"Steel", 10}
      level <= 40 -> {"Mithril", 20}
      true -> {"Dragonbone", 40}
    end
  end
end
