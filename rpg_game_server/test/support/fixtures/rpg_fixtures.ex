defmodule RpgGameServer.RpgFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `RpgGameServer.Rpg` context.
  """

  @doc """
  Generate a character.
  """
  def character_fixture(attrs \\ %{}) do
    {:ok, character} =
      attrs
      |> Enum.into(%{
        class: "some class",
        level: 42,
        name: "some name",
        sprite_idx: 42
      })
      |> RpgGameServer.Rpg.create_character()

    character
  end
end
