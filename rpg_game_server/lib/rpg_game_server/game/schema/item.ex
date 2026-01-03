defmodule RpgGameServer.Game.Schema.Item do
  @moduledoc """
  Representa qualquer item do jogo (Arma, Armadura, Consumível).
  """

  # ID gerado via System.unique_integer ou UUID no futuro
  @derive Jason.Encoder
  defstruct [
    :id,
    # "Rusty Sword"
    :name,
    # :weapon, :armor
    :type,
    # :main_hand, :chest, :legs
    :slot,
    # :common, :rare, :legendary
    :rarity,
    # Atributos passivos: %{strength: 2, vigor: 5}
    :stats,
    # Dados de combate: %{base_damage: 10, scale_str: 1.0}
    :combat_stats
  ]

  def new_weapon(name, level, rarity \\ :common) do
    # Lógica simples de geração procedural
    base_dmg = 5 + level * 2
    scale = 0.5 + level * 0.1

    %__MODULE__{
      id: System.unique_integer([:positive]),
      name: name,
      type: :weapon,
      slot: :main_hand,
      rarity: rarity,
      # Poderia ter stats aleatórios aqui
      stats: %{},
      combat_stats: %{
        base_damage: base_dmg,
        scale_str: if(String.contains?(name, "Sword"), do: scale, else: 0.2),
        scale_dex: if(String.contains?(name, "Dagger"), do: scale, else: 0.2),
        attack_speed: 1.0
      }
    }
  end
end
