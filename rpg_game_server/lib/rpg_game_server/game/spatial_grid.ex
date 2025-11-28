defmodule RpgGameServer.Game.SpatialGrid do
  # Nome da tabela ETS
  @table :spatial_grid

  # Tamanho da célula (Grid de 100x100 pixels)
  @cell_size 35

  # Inicia a tabela (Chame isso no Application.ex ou no init do Spawner)
  def init do
    if :ets.info(@table) == :undefined do
      # :bag = permite vários inimigos na mesma célula
      # :public = qualquer processo (EnemyAI) pode ler e escrever
      :ets.new(@table, [:bag, :named_table, :public, {:read_concurrency, true}, {:write_concurrency, true}])
    end
  end

  # Atualiza a posição (Movimento)
  def update(id, old_x, old_y, new_x, new_y) do
    old_key = to_key(old_x, old_y)
    new_key = to_key(new_x, new_y)

    # Como o EnemyAI só chama essa função se (x != last_x),
    # nós SEMPRE precisamos atualizar o registro no ETS.

    # 1. Remove o registro antigo exato
    :ets.delete_object(@table, {old_key, id, old_x, old_y})

    # 2. Insere o novo registro
    :ets.insert(@table, {new_key, id, new_x, new_y})
  end

  # Insere um novo inimigo (Spawn)
  def insert(id, x, y) do
    key = to_key(x, y)
    :ets.insert(@table, {key, id, x, y})
  end

  # Remove um inimigo (Morte)
  def remove(id, x, y) do
    key = to_key(x, y)
    :ets.delete_object(@table, {key, id, x, y})
  end

  # Busca vizinhos nas 9 células adjacentes (Grid 3x3)
  def get_nearby_entities(x, y) do
    {gx, gy} = to_key(x, y)

    for dx <- -1..1, dy <- -1..1 do
      {gx + dx, gy + dy}
    end
    |> Enum.flat_map(fn key ->
      :ets.lookup(@table, key) # Retorna lista de tuplas {key, id, x, y}
    end)
    # Formata para o padrão que o EnemyAI espera: {id, {x, y}}
    |> Enum.map(fn {_, id, ex, ey} -> {id, {ex, ey}} end)
  end

  # Converte coordenada de Pixel para Chave do Grid {0, 0}, {0, 1}, etc
  defp to_key(x, y) do
    {floor(x / @cell_size), floor(y / @cell_size)}
  end
end
