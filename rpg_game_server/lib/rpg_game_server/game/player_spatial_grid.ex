defmodule RpgGameServer.Game.PlayerSpatialGrid do
  alias RpgGameServer.Game.ShardManager

  @index_table :player_location_index

  # Configurações
  @cell_size 700
  # Com a nova lógica de leitura abaixo, este valor pode ser qualquer um
  # (mesmo que não seja múltiplo de 700), pois o sistema agora checa sobreposições.
  @zone_size 2_500

  # ===================================================================
  # INICIALIZAÇÃO
  # ===================================================================
  def init do
    # Cria apenas o índice global (que é fixo)
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

  # ===================================================================
  # ESCRITA DINÂMICA
  # ===================================================================

  def insert(id, x, y) do
    target_shard = get_shard_name(x, y)

    # Garante que o Shard existe antes de escrever
    ShardManager.ensure_shard_exists(target_shard)

    new_key = to_cell_key(x, y)

    # Limpeza Preventiva (Index-First)
    case :ets.lookup(@index_table, id) do
      [{^id, old_shard, old_key, old_x, old_y}] ->
        # Se o shard antigo ainda existe, limpa o registro velho
        if :ets.info(old_shard) != :undefined do
          :ets.delete_object(old_shard, {old_key, id, old_x, old_y})
        end
      [] ->
        :ok
    end

    :ets.insert(target_shard, {new_key, id, x, y})
    :ets.insert(@index_table, {id, target_shard, new_key, x, y})
  end

  def update(id, _, _, new_x, new_y) do
    new_shard = get_shard_name(new_x, new_y)
    new_key = to_cell_key(new_x, new_y)

    case :ets.lookup(@index_table, id) do
      [{^id, current_shard, current_key, current_x, current_y}] ->
        # Só faz algo se mudou de posição (célula ou shard)
        if current_shard != new_shard or current_key != new_key or current_x != new_x or current_y != new_y do

          # Se mudou de SHARD, precisamos garantir que o novo existe
          if current_shard != new_shard do
            ShardManager.ensure_shard_exists(new_shard)
          end

          # Remove do antigo (se tabela ainda existir)
          if :ets.info(current_shard) != :undefined do
            :ets.delete_object(current_shard, {current_key, id, current_x, current_y})
          end

          :ets.insert(new_shard, {new_key, id, new_x, new_y})
          :ets.insert(@index_table, {id, new_shard, new_key, new_x, new_y})
        end

      [] ->
        insert(id, new_x, new_y)
    end
  end

  def remove(id) do
    case :ets.lookup(@index_table, id) do
      [{^id, shard, key, x, y}] ->
        if :ets.info(shard) != :undefined do
          :ets.delete_object(shard, {key, id, x, y})
        end
        :ets.delete(@index_table, id)
      [] ->
        :ok
    end
  end

  # ===================================================================
  # LEITURA (MULTI-SHARD AWARE)
  # ===================================================================

  def get_nearby_players(x, y) do
    # 1. Identifica a célula central de quem está buscando
    cx_base = floor(x / @cell_size)
    cy_base = floor(y / @cell_size)

    # 2. Gera as coordenadas das 9 células vizinhas
    neighbor_cells = for dx <- -1..1, dy <- -1..1, do: {cx_base + dx, cy_base + dy}

    # 3. Para cada célula, descobrimos quais Shards ela toca e buscamos em todos
    # Isso resolve o problema de bordas desalinhadas entre Zone e Cell
    Enum.flat_map(neighbor_cells, fn {cx, cy} ->

      # Descobre quais tabelas ETS podem conter dados desta célula específica
      shards = get_shards_overlapping_cell(cx, cy)

      # Varre todas as tabelas encontradas buscando esta chave de célula
      Enum.flat_map(shards, fn shard_name ->
        case :ets.info(shard_name) do
          :undefined -> [] # Área vazia/inexplorada
          _ -> :ets.lookup(shard_name, {cx, cy})
        end
      end)
    end)
    # 4. Formata o retorno para a AI usar: {id, {x, y}}
    |> Enum.map(fn {_, id, px, py} -> {id, {px, py}} end)
  end

  # ===================================================================
  # HELPERS MATEMÁTICOS
  # ===================================================================

  # Retorna uma lista de átomos de Shards que uma determinada célula sobrepõe
  defp get_shards_overlapping_cell(cx, cy) do
    # Calcula os limites em pixels da célula
    min_px = cx * @cell_size
    min_py = cy * @cell_size

    # -1 é crucial: o pixel 700 já pertence à próxima célula
    max_px = min_px + @cell_size - 1
    max_py = min_py + @cell_size - 1

    # Calcula os índices de shard para o canto superior esquerdo (min) e inferior direito (max)
    # Floor garante suporte a coordenadas negativas
    start_shard_x = floor(min_px / @zone_size)
    end_shard_x   = floor(max_px / @zone_size)
    start_shard_y = floor(min_py / @zone_size)
    end_shard_y   = floor(max_py / @zone_size)

    # Gera a lista de todos os shards envolvidos
    for sx <- start_shard_x..end_shard_x,
        sy <- start_shard_y..end_shard_y do
      :"player_#{sx}_#{sy}"
    end
  end

  defp get_shard_name(x, y) do
    x_index = floor(x / @zone_size)
    y_index = floor(y / @zone_size)
    :"player_#{x_index}_#{y_index}"
  end

  defp to_cell_key(x, y), do: {floor(x / @cell_size), floor(y / @cell_size)}
end
