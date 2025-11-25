defmodule RpgGameServer.RpgTest do
  use RpgGameServer.DataCase

  alias RpgGameServer.Rpg

  describe "characters" do
    alias RpgGameServer.Rpg.Character

    import RpgGameServer.RpgFixtures

    @invalid_attrs %{name: nil, level: nil, class: nil, sprite_idx: nil}

    test "list_characters/0 returns all characters" do
      character = character_fixture()
      assert Rpg.list_characters() == [character]
    end

    test "get_character!/1 returns the character with given id" do
      character = character_fixture()
      assert Rpg.get_character!(character.id) == character
    end

    test "create_character/1 with valid data creates a character" do
      valid_attrs = %{name: "some name", level: 42, class: "some class", sprite_idx: 42}

      assert {:ok, %Character{} = character} = Rpg.create_character(valid_attrs)
      assert character.name == "some name"
      assert character.level == 42
      assert character.class == "some class"
      assert character.sprite_idx == 42
    end

    test "create_character/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Rpg.create_character(@invalid_attrs)
    end

    test "update_character/2 with valid data updates the character" do
      character = character_fixture()

      update_attrs = %{
        name: "some updated name",
        level: 43,
        class: "some updated class",
        sprite_idx: 43
      }

      assert {:ok, %Character{} = character} = Rpg.update_character(character, update_attrs)
      assert character.name == "some updated name"
      assert character.level == 43
      assert character.class == "some updated class"
      assert character.sprite_idx == 43
    end

    test "update_character/2 with invalid data returns error changeset" do
      character = character_fixture()
      assert {:error, %Ecto.Changeset{}} = Rpg.update_character(character, @invalid_attrs)
      assert character == Rpg.get_character!(character.id)
    end

    test "delete_character/1 deletes the character" do
      character = character_fixture()
      assert {:ok, %Character{}} = Rpg.delete_character(character)
      assert_raise Ecto.NoResultsError, fn -> Rpg.get_character!(character.id) end
    end

    test "change_character/1 returns a character changeset" do
      character = character_fixture()
      assert %Ecto.Changeset{} = Rpg.change_character(character)
    end
  end
end
