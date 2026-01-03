defmodule RpgGameServer.Game.EnemySpatialGrid do
  alias RpgGameServer.Game.ShardManager

  @cell_size 2100
  # ATENÇÃO: Deve ser múltiplo de @cell_size para evitar edge-cases simples
  @chunk_size 2100

  def init, do: :ok
  @neighbor_deltas for x <- -1..1, y <- -1..1, do: {x, y}
  # --- ESCRITA ---

  def update(id, old_x, old_y, new_x, new_y) do
    old_cell = to_cell_key(old_x, old_y)
    new_cell = to_cell_key(new_x, new_y)

    if old_cell != new_cell do
      # Agora buscamos TIDs.
      # Para o antigo, usamos get_shard_tid (pode ser nil se foi limpo).
      # Para o novo, usamos get_or_create (garante existência).
      old_tid = get_shard_tid_for_coord(old_x, old_y)
      new_tid = get_or_create_tid_for_coord(new_x, new_y)

      # Remove da velha (Se a tabela ainda existir)
      if old_tid && :ets.info(old_tid) != :undefined do
        :ets.delete_object(old_tid, {old_cell, id, old_x, old_y})
      end

      # Insere na nova
      :ets.insert(new_tid, {new_cell, id, new_x, new_y})
    else
      :ok
    end
  end

  def insert(id, x, y) do
    tid = get_or_create_tid_for_coord(x, y)
    cell = to_cell_key(x, y)
    :ets.insert(tid, {cell, id, x, y})
  end

  def remove(id, x, y) do
    tid = get_shard_tid_for_coord(x, y)
    cell = to_cell_key(x, y)

    if tid && :ets.info(tid) != :undefined do
      :ets.delete_object(tid, {cell, id, x, y})
    end
  end

  # --- LEITURA ---

  def get_nearby_entities(x, y) do
    {cx, cy} = to_cell_key(x, y)

    # Em vez de gerar ranges e rodar um 'for', apenas iteramos a lista pronta.
    # É mais rápido e elimina o risco de erro de sintaxe do pipe.
    @neighbor_deltas
    |> Enum.group_by(fn {dx, dy} ->
      # Calculamos a coordenada real do vizinho
      nx = cx + dx
      ny = cy + dy

      # Lógica de Shard
      px = nx * @cell_size
      py = ny * @cell_size
      {floor(px / @chunk_size), floor(py / @chunk_size)}
    end)
    |> Enum.flat_map(fn {{sx, sy}, deltas} ->
      case ShardManager.get_shard_tid(:enemy, sx, sy) do
        nil ->
          []

        tid ->
          if :ets.info(tid) != :undefined do
            Enum.flat_map(deltas, fn {dx, dy} ->
              key = {cx + dx, cy + dy}
              :ets.lookup(tid, key)
            end)
          else
            []
          end
      end
    end)
    |> Enum.map(fn {_, id, ex, ey} -> {id, {ex, ey}} end)
  end

  # --- HELPERS ---

  defp to_cell_key(x, y), do: {floor(x / @cell_size), floor(y / @cell_size)}

  defp get_or_create_tid_for_coord(x, y) do
    xi = floor(x / @chunk_size)
    yi = floor(y / @chunk_size)
    ShardManager.get_or_create_shard(:enemy, xi, yi)
  end

  defp get_shard_tid_for_coord(x, y) do
    xi = floor(x / @chunk_size)
    yi = floor(y / @chunk_size)
    ShardManager.get_shard_tid(:enemy, xi, yi)
  end
end
