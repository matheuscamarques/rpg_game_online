defmodule RpgGameServer.Game.EnemySpatialGrid do
  # Reutilizamos o Gerente de Tabelas (criado para o Player)
  # Ele garante que as tabelas pertençam ao servidor e não morram com o mob.
  alias RpgGameServer.Game.ShardManager

  # Configurações
  @cell_size 35           # Resolução fina para colisão
  @chunk_size 2_100       # Cada tabela cobre 2000x2000 pixels

  # REMOVIDO: @world_size (Agora é infinito)

  def init do
    # Não fazemos nada aqui.
    # As tabelas serão criadas sob demanda pelo ShardManager.
    :ok
  end

  # --- ESCRITA (Dinâmica) ---

  def update(id, old_x, old_y, new_x, new_y) do
    # 1. Otimização de Delta
    old_cell = to_cell_key(old_x, old_y)
    new_cell = to_cell_key(new_x, new_y)

    if old_cell != new_cell do
      old_shard = get_shard_name(old_x, old_y)
      new_shard = get_shard_name(new_x, new_y)

      # A. Se mudou de SHARD, precisamos garantir que o novo existe
      if old_shard != new_shard do
        ShardManager.ensure_shard_exists(new_shard)
      end

      # B. Remove da velha (COM SEGURANÇA)
      # Pode ser que a tabela antiga tenha sido limpa ou nunca criada (bug), checamos antes.
      if :ets.info(old_shard) != :undefined do
        :ets.delete_object(old_shard, {old_cell, id, old_x, old_y})
      end

      # C. Insere na nova (Se for o mesmo shard, já existe. Se for novo, criamos acima)
      # Nota: Se for o mesmo shard, ensure_shard_exists seria redundante, mas seguro.
      # Para performance máxima, confiamos que se ele já estava lá, a tabela existe.
      :ets.insert(new_shard, {new_cell, id, new_x, new_y})
    else
      :ok
    end
  end

  def insert(id, x, y) do
    shard = get_shard_name(x, y)

    # GARANTIA: Antes de colocar o mob no mundo, cria o chão.
    ShardManager.ensure_shard_exists(shard)

    cell = to_cell_key(x, y)
    :ets.insert(shard, {cell, id, x, y})
  end

  def remove(id, x, y) do
    shard = get_shard_name(x, y)
    cell = to_cell_key(x, y)

    # Só tenta deletar se a tabela existir
    if :ets.info(shard) != :undefined do
      :ets.delete_object(shard, {cell, id, x, y})
    end
  end

  # --- LEITURA (Inalterada mas Segura) ---

  def get_nearby_entities(x, y) do
    {cx, cy} = to_cell_key(x, y)

    neighbors = for dx <- -1..1, dy <- -1..1, do: {cx + dx, cy + dy}

    neighbors
    |> Enum.group_by(fn {nx, ny} ->
       px = nx * @cell_size
       py = ny * @cell_size
       get_shard_name(px, py)
    end)
    |> Enum.flat_map(fn {shard, keys} ->
      # Safety check: Se olhar pro abismo (tabela não criada), retorna vazio.
      if :ets.info(shard) != :undefined do
        Enum.flat_map(keys, fn key -> :ets.lookup(shard, key) end)
      else
        []
      end
    end)
    |> Enum.map(fn {_, id, ex, ey} -> {id, {ex, ey}} end)
  end

  # --- HELPERS ---

  defp to_cell_key(x, y), do: {floor(x / @cell_size), floor(y / @cell_size)}

  defp get_shard_name(x, y) do
    # Floor garante coordenadas negativas corretas (-2500 vira índice -2)
    xi = floor(x / @chunk_size)
    yi = floor(y / @chunk_size)
    :"enemy_grid_#{xi}_#{yi}"
  end
end
