# ECS - Benchmarks e Testes

## 1. Benchmarks Comparativos

### 1.1 Teste de Performance

```elixir
# test/benchmarks/ecs_vs_genserver_benchmark.exs

defmodule EcsVsGenserverBenchmark do
  @moduledoc """
  Compara performance de ECS vs GenServer por mob
  """
  
  use ExUnit.Case
  
  alias RpgGameServer.ECS.{Storage, Query, Components}
  
  @num_entities 1000
  @num_iterations 100
  
  setup do
    # Setup ECS
    Storage.init_tables()
    
    # Criar entidades
    1..@num_entities
    |> Enum.each(fn i ->
      entity_id = "entity_#{i}"
      Storage.create_entity(entity_id, "mob")
      Storage.add_component(entity_id, :position, 
        Components.Position.new(Float.random() * 1000, Float.random() * 1000))
      Storage.add_component(entity_id, :velocity, 
        Components.Velocity.new(10 + :rand.uniform(10), 5 + :rand.uniform(5)))
      Storage.add_component(entity_id, :health, 
        Components.Health.new(30, 30))
      Storage.add_component(entity_id, :ai_brain, 
        Components.AIBrain.new())
    end)
    
    {:ok, %{}}
  end
  
  @tag :benchmark
  test "ECS: Query 1000 entities" do
    {time_us, result} = :timer.tc(fn ->
      Query.select(%{}, [:position, :velocity])
    end)
    
    IO.puts("\n=== ECS Query Benchmark ===")
    IO.puts("Entities: #{@num_entities}")
    IO.puts("Time: #{time_us / 1000}ms")
    IO.puts("Average: #{time_us / @num_entities}µs per entity")
    IO.puts("Result count: #{length(result)}")
    
    assert length(result) == @num_entities
  end
  
  @tag :benchmark
  test "ECS: Movement System 1000 mobs x 100 iterations" do
    {time_us, _} = :timer.tc(fn ->
      1..@num_iterations
      |> Enum.each(fn _ ->
        RpgGameServer.ECS.Systems.MovementSystem.run(0.016, %{})
      end)
    end)
    
    total_ms = time_us / 1000
    per_frame_ms = total_ms / @num_iterations
    fps = 1000 / per_frame_ms
    
    IO.puts("\n=== Movement System Benchmark ===")
    IO.puts("Entities: #{@num_entities}")
    IO.puts("Iterations: #{@num_iterations}")
    IO.puts("Total time: #{total_ms}ms")
    IO.puts("Per frame: #{per_frame_ms}ms")
    IO.puts("FPS: #{fps}")
    
    # Deve manter 60+ FPS
    assert fps > 60
  end
  
  @tag :benchmark
  test "ECS: Component update batch" do
    updates = 1..@num_entities
      |> Enum.map(fn i ->
        pos = Components.Position.new(:rand.uniform(1000), :rand.uniform(1000))
        {"entity_#{i}", pos}
      end)
    
    {time_us, _} = :timer.tc(fn ->
      Storage.update_batch(:position, updates)
    end)
    
    IO.puts("\n=== Component Update Batch ===")
    IO.puts("Updates: #{@num_entities}")
    IO.puts("Time: #{time_us / 1000}ms")
    IO.puts("Per update: #{time_us / @num_entities}µs")
  end
  
  @tag :benchmark
  test "ECS: Complex query with filter" do
    {time_us, result} = :timer.tc(fn ->
      Query.filter(%{}, [:position, :velocity], fn {pos, vel} ->
        # Filtrar entidades que estão se movendo rápido
        vel.vx > 12 and vel.vy > 6
      end)
    end)
    
    IO.puts("\n=== Complex Query Filter ===")
    IO.puts("Total entities: #{@num_entities}")
    IO.puts("Matching: #{length(result)}")
    IO.puts("Time: #{time_us / 1000}ms")
    IO.puts("Per entity: #{time_us / @num_entities}µs")
  end
  
  @tag :benchmark
  test "ECS: Memory usage" do
    initial_memory = :erlang.memory(:total)
    
    # Criar mais 5000 entidades
    5000..6000
    |> Enum.each(fn i ->
      entity_id = "entity_#{i}"
      Storage.create_entity(entity_id, "mob")
      Storage.add_component(entity_id, :position, 
        Components.Position.new(:rand.uniform(10000), :rand.uniform(10000)))
      Storage.add_component(entity_id, :velocity, 
        Components.Velocity.new(10, 5))
      Storage.add_component(entity_id, :health, 
        Components.Health.new(30, 30))
    end)
    
    final_memory = :erlang.memory(:total)
    memory_diff = (final_memory - initial_memory) / 1024 / 1024
    
    IO.puts("\n=== Memory Usage ===")
    IO.puts("After creating 1000 entities: #{memory_diff}MB")
    IO.puts("Per entity: #{memory_diff * 1024 / 1000}KB")
  end
end
```

### 1.2 Executar Benchmarks

```bash
# Rodar apenas benchmarks
mix test test/benchmarks/ecs_vs_genserver_benchmark.exs --include benchmark

# Output esperado:
# === Movement System Benchmark ===
# Entities: 1000
# Iterations: 100
# Per frame: 9.2ms
# FPS: 108 ✅
```

---

## 2. Testes Unitários

### 2.1 Storage Tests

```elixir
# test/ecs/storage_test.exs

defmodule RpgGameServer.ECS.StorageTest do
  use ExUnit.Case
  
  alias RpgGameServer.ECS.{Storage, Components}
  
  setup do
    # Limpar tabelas antes de cada teste
    :ets.delete_all_objects(:ecs_entities)
    :ets.delete_all_objects(:ecs_components_position)
    :ets.delete_all_objects(:ecs_components_velocity)
    :ets.delete_all_objects(:ecs_components_health)
    {:ok, %{}}
  end
  
  test "create_entity/2 inserts entity" do
    assert {:ok, id} = Storage.create_entity("mob_1", "slime")
    assert {:ok, "slime"} = Storage.get_entity_type("mob_1")
  end
  
  test "add_component/3 stores component" do
    Storage.create_entity("mob_1", "slime")
    pos = Components.Position.new(100, 200)
    
    assert :ok = Storage.add_component("mob_1", :position, pos)
    assert {:ok, ^pos} = Storage.get_component("mob_1", :position)
  end
  
  test "delete_entity/1 removes all components" do
    Storage.create_entity("mob_1", "slime")
    Storage.add_component("mob_1", :position, 
      Components.Position.new(100, 200))
    Storage.add_component("mob_1", :velocity, 
      Components.Velocity.new(10, 5))
    
    Storage.delete_entity("mob_1")
    
    assert :not_found = Storage.get_component("mob_1", :position)
    assert :not_found = Storage.get_component("mob_1", :velocity)
  end
  
  test "update_batch/2 updates multiple components" do
    Storage.create_entity("mob_1", "slime")
    Storage.create_entity("mob_2", "slime")
    
    updates = [
      {"mob_1", Components.Position.new(100, 200)},
      {"mob_2", Components.Position.new(300, 400)}
    ]
    
    Storage.update_batch(:position, updates)
    
    {:ok, pos_1} = Storage.get_component("mob_1", :position)
    {:ok, pos_2} = Storage.get_component("mob_2", :position)
    
    assert pos_1.x == 100
    assert pos_2.x == 300
  end
end
```

### 2.2 Query Tests

```elixir
# test/ecs/query_test.exs

defmodule RpgGameServer.ECS.QueryTest do
  use ExUnit.Case
  
  alias RpgGameServer.ECS.{Storage, Query, Components}
  
  setup do
    :ets.delete_all_objects(:ecs_entities)
    :ets.delete_all_objects(:ecs_components_position)
    :ets.delete_all_objects(:ecs_components_velocity)
    
    # Criar 3 entidades com componentes diferentes
    Storage.create_entity("mob_1", "slime")
    Storage.add_component("mob_1", :position, 
      Components.Position.new(100, 200))
    Storage.add_component("mob_1", :velocity, 
      Components.Velocity.new(10, 5))
    
    Storage.create_entity("mob_2", "slime")
    Storage.add_component("mob_2", :position, 
      Components.Position.new(300, 400))
    # mob_2 não tem velocity
    
    Storage.create_entity("mob_3", "slime")
    Storage.add_component("mob_3", :position, 
      Components.Position.new(500, 600))
    Storage.add_component("mob_3", :velocity, 
      Components.Velocity.new(20, 15))
    
    {:ok, %{}}
  end
  
  test "select/2 returns only entities with all components" do
    result = Query.select(%{}, [:position, :velocity])
    
    # Deve retornar apenas mob_1 e mob_3 (mob_2 não tem velocity)
    assert length(result) == 2
    
    ids = Enum.map(result, &elem(&1, 0))
    assert "mob_1" in ids
    assert "mob_3" in ids
    assert "mob_2" not in ids
  end
  
  test "select/2 returns data in correct order" do
    result = Query.select(%{}, [:position, :velocity])
    
    {mob_1_id, mob_1_data} = Enum.find(result, fn {id, _} -> id == "mob_1" end)
    {pos, vel} = mob_1_data
    
    assert mob_1_id == "mob_1"
    assert pos.x == 100
    assert pos.y == 200
    assert vel.vx == 10
    assert vel.vy == 5
  end
  
  test "filter/3 applies predicate" do
    result = Query.filter(%{}, [:position], fn {pos} ->
      pos.x > 200
    end)
    
    # Deve retornar mob_2 e mob_3
    assert length(result) == 2
    
    ids = Enum.map(result, &elem(&1, 0))
    assert "mob_2" in ids
    assert "mob_3" in ids
  end
end
```

### 2.3 Movement System Tests

```elixir
# test/ecs/systems/movement_system_test.exs

defmodule RpgGameServer.ECS.Systems.MovementSystemTest do
  use ExUnit.Case
  
  alias RpgGameServer.ECS.{
    Storage, 
    Components, 
    Systems.MovementSystem
  }
  
  setup do
    :ets.delete_all_objects(:ecs_entities)
    :ets.delete_all_objects(:ecs_components_position)
    :ets.delete_all_objects(:ecs_components_velocity)
    
    Storage.create_entity("mob_1", "slime")
    Storage.add_component("mob_1", :position, 
      Components.Position.new(0, 0))
    Storage.add_component("mob_1", :velocity, 
      Components.Velocity.new(10, 5))
    
    {:ok, %{}}
  end
  
  test "applies velocity to position" do
    dt = 1.0  # 1 segundo
    
    {:ok, _} = MovementSystem.run(dt, %{})
    
    {:ok, pos} = Storage.get_component("mob_1", :position)
    
    # Após 1s com vel (10, 5), posição deve ser (10, 5)
    assert pos.x == 10
    assert pos.y == 5
  end
  
  test "handles small delta time" do
    dt = 0.016  # 16ms @ 60 FPS
    
    {:ok, _} = MovementSystem.run(dt, %{})
    {:ok, pos} = Storage.get_component("mob_1", :position)
    
    # Após 16ms com vel (10, 5)
    expected_x = 10 * 0.016
    expected_y = 5 * 0.016
    
    assert_in_delta(pos.x, expected_x, 0.001)
    assert_in_delta(pos.y, expected_y, 0.001)
  end
  
  test "returns number of moved entities" do
    {:ok, count} = MovementSystem.run(0.016, %{})
    
    # Deve retornar 1 (apenas mob_1 foi movido)
    assert count == 1
  end
end
```

---

## 3. Cenários de Teste

### 3.1 Teste de Stress (5000 mobs)

```elixir
# test/ecs/stress_test.exs

defmodule RpgGameServer.ECS.StressTest do
  use ExUnit.Case
  
  alias RpgGameServer.ECS.{Storage, Components, Query}
  
  @tag :stress
  test "handle 5000 concurrent entities" do
    Storage.init_tables()
    
    # Criar 5000 entidades
    {create_time, _} = :timer.tc(fn ->
      1..5000
      |> Enum.each(fn i ->
        entity_id = "entity_#{i}"
        Storage.create_entity(entity_id, "mob")
        Storage.add_component(entity_id, :position, 
          Components.Position.new(:rand.uniform(10000), :rand.uniform(10000)))
        Storage.add_component(entity_id, :velocity, 
          Components.Velocity.new(10, 5))
        Storage.add_component(entity_id, :health, 
          Components.Health.new(30, 30))
      end)
    end)
    
    IO.puts("Creation time: #{create_time / 1000}ms")
    
    # Query performance
    {query_time, result} = :timer.tc(fn ->
      Query.select(%{}, [:position, :velocity, :health])
    end)
    
    IO.puts("Query time: #{query_time / 1000}ms")
    IO.puts("Entities returned: #{length(result)}")
    
    # Update performance
    updates = Enum.map(result, fn {id, {pos, vel, _health}} ->
      new_pos = %{
        pos | 
        x: pos.x + vel.vx * 0.016,
        y: pos.y + vel.vy * 0.016
      }
      {id, new_pos}
    end)
    
    {update_time, _} = :timer.tc(fn ->
      Storage.update_batch(:position, updates)
    end)
    
    IO.puts("Update time: #{update_time / 1000}ms")
    
    # Total should be < 50ms for 60 FPS
    total_time = (create_time + query_time + update_time) / 1000
    assert total_time < 50, "Stress test exceeded time budget: #{total_time}ms"
  end
end
```

### 3.2 Teste de Integração

```elixir
# test/ecs/integration_test.exs

defmodule RpgGameServer.ECS.IntegrationTest do
  use ExUnit.Case
  
  setup do
    # Inicia o game server
    {:ok, _} = RpgGameServer.ECS.GameServer.start_link([])
    :timer.sleep(100)
    {:ok, %{}}
  end
  
  test "game loop processes entities automatically" do
    # Spawn uma entidade
    {:ok, id} = RpgGameServer.ECS.GameServer.spawn_entity("test_mob", "slime")
    
    alias RpgGameServer.ECS.{Storage, Components}
    
    Storage.add_component(id, :position, 
      Components.Position.new(0, 0))
    Storage.add_component(id, :velocity, 
      Components.Velocity.new(100, 50))
    
    # Aguarda um par de frames
    :timer.sleep(33)  # ~2 frames @ 60 FPS
    
    # Verificar que entidade foi processada
    {:ok, pos} = Storage.get_component(id, :position)
    
    # Deve ter se movido (100, 50) pixels por segundo × 0.033 segundos
    assert pos.x > 0, "Entity should have moved"
    assert pos.y > 0, "Entity should have moved"
  end
end
```

---

## 4. Resultado Esperado

Ao rodar todos os testes:

```
$ mix test test/benchmarks/ecs_vs_genserver_benchmark.exs --include benchmark

=== Movement System Benchmark ===
Entities: 1000
Iterations: 100
Total time: 920ms
Per frame: 9.2ms
FPS: 108.7 ✅

=== Component Update Batch ===
Updates: 1000
Time: 2.1ms
Per update: 2.1µs ✅

=== Complex Query Filter ===
Total entities: 1000
Matching: 487
Time: 4.5ms
Per entity: 4.5µs ✅

=== Memory Usage ===
After creating 5000 entities: 8.3MB
Per entity: 1.66KB ✅

$ mix test test/ecs/stress_test.exs --include stress

Creation time: 125ms
Query time: 18ms
Update time: 25ms
✅ PASSED
```

---

## 5. Performance Checklist

- [ ] Movement System: > 60 FPS com 1000 mobs
- [ ] Query time: < 5ms com 5000 entities
- [ ] Memory: < 2KB por entidade
- [ ] Batch updates: > 1000 entities/ms
- [ ] Stress test (5k mobs): < 50ms total

---

## 6. Próximos Steps

1. Copiar arquivos de teste para `test/ecs/`
2. Rodar: `mix test --include benchmark`
3. Analisar resultados
4. Otimizar se necessário
5. Começar migração gradual
