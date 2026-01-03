defmodule RpgGameServer.Game.PlayerSpatialGrid do
  alias RpgGameServer.Game.ShardManager

  @index_table :player_location_index
  @cell_size 2100
  @zone_size 500

  def init do
    if :ets.info(@index_table) == :undefined do
      :ets.new(@index_table, [
        :set,
        :named_table,
        :public,
        {:read_concurrency, true},
        {:write_concurrency, true}
      ])
    end
  end

  # --- ESCRITA ---

  def insert(id, x, y) do
    # Busca TID via Manager
    target_tid = get_or_create_tid(x, y)
    new_key = to_cell_key(x, y)

    # Limpeza via Index
    case :ets.lookup(@index_table, id) do
      [{^id, old_tid, old_key, old_x, old_y}] ->
        if old_tid != target_tid and is_valid_tid(old_tid) do
          :ets.delete_object(old_tid, {old_key, id, old_x, old_y})
        end

        # Se for o mesmo TID, o insert abaixo já atualiza se for :set,
        # mas como shards são :bag, melhor garantir a remoção da entrada velha
        if old_tid == target_tid do
          :ets.delete_object(old_tid, {old_key, id, old_x, old_y})
        end

      [] ->
        :ok
    end

    :ets.insert(target_tid, {new_key, id, x, y})
    # Guardamos o TID no index agora, não o nome
    :ets.insert(@index_table, {id, target_tid, new_key, x, y})
  end

  def update(id, _, _, new_x, new_y) do
    new_tid = get_or_create_tid(new_x, new_y)
    new_key = to_cell_key(new_x, new_y)

    case :ets.lookup(@index_table, id) do
      [{^id, current_tid, current_key, current_x, current_y}] ->
        # Verifica mudança
        if current_tid != new_tid or current_key != new_key or current_x != new_x or
             current_y != new_y do
          # Remove do antigo
          if is_valid_tid(current_tid) do
            :ets.delete_object(current_tid, {current_key, id, current_x, current_y})
          end

          :ets.insert(new_tid, {new_key, id, new_x, new_y})
          :ets.insert(@index_table, {id, new_tid, new_key, new_x, new_y})
        end

      [] ->
        insert(id, new_x, new_y)
    end
  end

  def remove(id) do
    case :ets.lookup(@index_table, id) do
      [{^id, tid, key, x, y}] ->
        if is_valid_tid(tid) do
          :ets.delete_object(tid, {key, id, x, y})
        end

        :ets.delete(@index_table, id)

      [] ->
        :ok
    end
  end

  # --- LEITURA (Overlap Aware) ---

  def get_nearby_players(x, y) do
    cx_base = floor(x / @cell_size)
    cy_base = floor(y / @cell_size)

    neighbor_cells = for dx <- -1..1, dy <- -1..1, do: {cx_base + dx, cy_base + dy}

    Enum.flat_map(neighbor_cells, fn {cx, cy} ->
      # Obtém lista de TIDs que sobrepõem esta célula
      shards_tids = get_shards_overlapping_cell(cx, cy)

      Enum.flat_map(shards_tids, fn tid ->
        if is_valid_tid(tid) do
          :ets.lookup(tid, {cx, cy})
        else
          []
        end
      end)
    end)
    |> Enum.map(fn {_, id, px, py} -> {id, {px, py}} end)
  end

  # --- HELPERS ---

  defp is_valid_tid(tid), do: tid != nil and :ets.info(tid) != :undefined

  defp get_or_create_tid(x, y) do
    xi = floor(x / @zone_size)
    yi = floor(y / @zone_size)
    ShardManager.get_or_create_shard(:player, xi, yi)
  end

  # Retorna lista de TIDs (consultando o Manager)
  defp get_shards_overlapping_cell(cx, cy) do
    min_px = cx * @cell_size
    max_px = min_px + @cell_size - 1
    min_py = cy * @cell_size
    max_py = min_py + @cell_size - 1

    start_sx = floor(min_px / @zone_size)
    end_sx = floor(max_px / @zone_size)
    start_sy = floor(min_py / @zone_size)
    end_sy = floor(max_py / @zone_size)

    for sx <- start_sx..end_sx, sy <- start_sy..end_sy do
      # Aqui usamos get_shard_tid (sem create) porque na leitura
      # não queremos criar shards vazios desnecessariamente
      ShardManager.get_shard_tid(:player, sx, sy)
    end
    # Remove nils de shards que não existem
    |> Enum.reject(&is_nil/1)
  end

  defp to_cell_key(x, y), do: {floor(x / @cell_size), floor(y / @cell_size)}
end
