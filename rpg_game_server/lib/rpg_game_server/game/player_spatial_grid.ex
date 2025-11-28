defmodule RpgGameServer.Game.PlayerSpatialGrid do
  @table :player_spatial_grid
  @cell_size 600 # Mesmo tamanho do AOI para facilitar a lógica

  # Inicia a tabela (Chame no Application.ex)
  def init do
    if :ets.info(@table) == :undefined do
      # :bag permite múltiplos players na mesma célula
      :ets.new(@table, [:bag, :named_table, :public, {:read_concurrency, true}, {:write_concurrency, true}])
    end
  end

  # Atualiza a posição (Chamado pelo RoomChannel quando o player anda)
  def update(id, old_x, old_y, new_x, new_y) do
    old_key = to_key(old_x, old_y)
    new_key = to_key(new_x, new_y)

    if old_key != new_key or old_x != new_x or old_y != new_y do
      :ets.delete_object(@table, {old_key, id, old_x, old_y})
      :ets.insert(@table, {new_key, id, new_x, new_y})
    end
  end

  # Insere (Chamado no Join)
  def insert(id, x, y) do
    key = to_key(x, y)
    :ets.insert(@table, {key, id, x, y})
  end

  # Remove (Chamado no Leave/Terminate)
  def remove(id, x, y) do
    key = to_key(x, y)
    :ets.delete_object(@table, {key, id, x, y})
  end

  # Busca players próximos (Usado pelo EnemyAI)
  # Retorna lista de: {id, {x, y}}
  def get_nearby_players(x, y) do
    {cx, cy} = to_key(x, y)

    for dx <- -1..1, dy <- -1..1 do
      {cx + dx, cy + dy}
    end
    |> Enum.flat_map(fn key ->
      :ets.lookup(@table, key)
    end)
    |> Enum.map(fn {_, id, ex, ey} -> {id, {ex, ey}} end)
  end

  defp to_key(x, y) do
    {floor(x / @cell_size), floor(y / @cell_size)}
  end
end
