defmodule RpgGameServer.Rpg.Character do
  use Ecto.Schema
  import Ecto.Changeset

  schema "characters" do
    field :name, :string
    field :class, :string
    field :level, :integer
    field :sprite_idx, :integer

    belongs_to :user, RpgGameServer.Accounts.User
    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(character, attrs) do
    character
    |> cast(attrs, [:name, :class, :level, :sprite_idx, :user_id])
    |> validate_required([:name, :class, :level, :sprite_idx, :user_id])
  end
end
