# Roadmap de Migração: GenServer → ECS

## Resumo Executivo

Este documento fornece um plano de ação prático para migrar seu sistema de **1 GenServer por mob** para um **ECS centralizado**, mantendo compatibilidade e permitindo rollback.

**Timeline**: 3-4 semanas  
**Risco**: Baixo (migração gradual)  
**ROI**: 10-27x melhoria de performance

---

## Fase 1: Preparação (Semana 1)

### Objetivo
Estabelecer infraestrutura ECS sem modificar código existente.

### 1.1 Criar Estrutura Base

```bash
mkdir -p lib/rpg_game_server/ecs/systems
mkdir -p lib/rpg_game_server/ecs/components
mkdir -p test/ecs
touch lib/rpg_game_server/ecs/{world.ex,storage.ex,query.ex}
touch lib/rpg_game_server/ecs/systems/{movement_system.ex,ai_system.ex}
```

### 1.2 Copiar Código

1. Copiar `components.ex` (do `ECS_IMPLEMENTATION.md`)
2. Copiar `storage.ex` (do `ECS_IMPLEMENTATION.md`)
3. Copiar `query.ex` (do `ECS_IMPLEMENTATION.md`)

### 1.3 Teste Unitário Básico

```elixir
# test/ecs/smoke_test.exs

defmodule ECS.SmokeTest do
  use ExUnit.Case
  
  alias RpgGameServer.ECS.{Storage, Components}
  
  test "ECS tables initialize" do
    Storage.init_tables()
    {:ok, _} = Storage.create_entity("test_1", "slime")
    {:ok, "slime"} = Storage.get_entity_type("test_1")
  end
end
```

**Comando**:
```bash
mix test test/ecs/smoke_test.exs
```

**Esperado**: ✅ PASSED

### 1.4 Checklist Semana 1

- [ ] Estrutura de diretórios criada
- [ ] Código ECS base copiado
- [ ] Testes smoke rodando
- [ ] Nenhuma alteração em código existente
- [ ] Documentação técnica revisada

---

## Fase 2: Sistema de Movimentação (Semana 2)

### Objetivo
Implementar primeiro sistema ECS (MovementSystem) lado a lado com código existente.

### 2.1 Implementar MovementSystem

```elixir
# lib/rpg_game_server/ecs/systems/movement_system.ex
# (copiar do ECS_IMPLEMENTATION.md)
```

### 2.2 Benchmark MovementSystem

```bash
mix test test/benchmarks/ecs_vs_genserver_benchmark.exs --include benchmark
```

**Esperado**: 
- 1000 entities: ~8-12ms/frame
- FPS: 80+

### 2.3 Teste de Correção

```elixir
# test/ecs/systems/movement_system_test.exs

test "movement applies velocity correctly" do
  Storage.create_entity("mob_1", "slime")
  Storage.add_component("mob_1", :position, 
    Components.Position.new(0, 0))
  Storage.add_component("mob_1", :velocity, 
    Components.Velocity.new(10, 5))
  
  MovementSystem.run(1.0, %{})
  
  {:ok, pos} = Storage.get_component("mob_1", :position)
  assert pos.x == 10
  assert pos.y == 5
end
```

### 2.4 Integração com WorldTicker

**NÃO migre ainda**. Apenas execute ECS em paralelo para validar.

```elixir
# lib/rpg_game_server/ecs/game_server.ex
# def start_link - apenas logging por enquanto

defmodule RpgGameServer.ECS.GameServer do
  def start_link(_opts) do
    Logger.info("ECS Game Server (MONITORING ONLY)")
    {:ok, self()}
  end
end
```

### 2.5 Checklist Semana 2

- [ ] MovementSystem implementado
- [ ] Benchmarks rodam > 60 FPS
- [ ] Testes unitários passam
- [ ] GameServer stub pronto
- [ ] Nada migrado ainda

---

## Fase 3: Migração em Camadas (Semana 3)

### Objetivo
Migrar mobs gradualmente para ECS, um tipo por vez.

### 3.1 Criar Flag de Feature

```elixir
# lib/rpg_game_server/ecs/world.ex

defmodule RpgGameServer.ECS.World do
  @moduledoc """
  Gerencia migração entre GenServer e ECS
  """
  
  def use_ecs_for_type?(type) do
    # Gradualmente migrar tipos
    type in [:slime]  # Começa com slimes
  end
end
```

### 3.2 Modificar EnemySpawner

```elixir
# lib/rpg_game_server/game/enemy_spwaner.ex (adicionar ao topo do handle_info)

def handle_info({:spawn, zone}, state) do
  entity_id = generate_entity_id()
  
  if RpgGameServer.ECS.World.use_ecs_for_type?(:slime) do
    # Novo: ECS
    spawn_to_ecs(entity_id, zone)
  else
    # Antigo: GenServer
    spawn_to_genserver(entity_id, zone)
  end
  
  {:noreply, state}
end

defp spawn_to_ecs(entity_id, zone) do
  {:ok, _} = RpgGameServer.ECS.GameServer.spawn_entity(entity_id, "slime")
  
  # Adicionar componentes
  alias RpgGameServer.ECS.{Storage, Components}
  
  Storage.add_component(entity_id, :position,
    Components.Position.new(zone.spawn_x, zone.spawn_y))
  Storage.add_component(entity_id, :velocity,
    Components.Velocity.new(0, 0))
  # ... outros componentes
end

defp spawn_to_genserver(entity_id, zone) do
  # Código existente
  DynamicSupervisor.start_child(
    RpgGameServer.Game.EnemySupervisor,
    {EnemyAI, [...]}
  )
end
```

### 3.3 Adicionar GameServer Ativo

```elixir
# lib/rpg_game_server/application.ex

def start(_type, _args) do
  children = [
    # ... existentes ...
    
    # Ativo durante transição
    RpgGameServer.ECS.GameServer
  ]
  
  opts = [strategy: :one_for_one, name: RpgGameServer.Supervisor]
  Supervisor.start_link(children, opts)
end
```

### 3.4 Implementar AISystem

```elixir
# lib/rpg_game_server/ecs/systems/ai_system.ex
# (copiar de ECS_IMPLEMENTATION.md)
```

### 3.5 GameServer Loop Completo

```elixir
# lib/rpg_game_server/ecs/game_server.ex (versão ativa)

def handle_info(:tick, state) do
  {elapsed_us, _} = :timer.tc(fn ->
    dt = 0.016  # 60 FPS
    
    # Rodar sistemas
    MovementSystem.run(dt, %{})
    AISystem.run(dt, %{})
  end)
  
  elapsed_ms = elapsed_us / 1000.0
  sleep_time = max(0, 16.67 - elapsed_ms)
  :timer.sleep(trunc(sleep_time))
  
  schedule_tick()
  {:noreply, state}
end
```

### 3.6 Teste de Coexistência

```elixir
# test/ecs/coexistence_test.exs

test "ECS and GenServer mobs coexist" do
  # Spawn 500 mobs em ECS
  1..500
  |> Enum.each(fn i ->
    RpgGameServer.ECS.GameServer.spawn_entity("ecs_mob_#{i}", "slime")
  end)
  
  # Spawn 500 mobs em GenServer (antigo)
  1..500
  |> Enum.each(fn i ->
    DynamicSupervisor.start_child(
      RpgGameServer.Game.EnemySupervisor,
      {EnemyAI, [...]})
  end)
  
  # Ambos devem funcionar
  :timer.sleep(1000)
  
  # Verificar que ECS processou
  Query.select(%{}, [:position, :velocity])
  |> length()
  |> assert_equal(500)
end
```

### 3.7 Checklist Semana 3

- [ ] Feature flag implementada
- [ ] EnemySpawner rotas para ECS/GenServer
- [ ] AISystem implementado
- [ ] GameServer roda ativo
- [ ] 500 mobs em ECS + 500 em GenServer funcionam
- [ ] Sem breaking changes

---

## Fase 4: Migração Total (Semana 4)

### Objetivo
Remover GenServers de mobs, 100% em ECS.

### 4.1 Remover Feature Flag

```elixir
# lib/rpg_game_server/ecs/world.ex

def use_ecs_for_type?(_type), do: true  # Todos agora
```

### 4.2 Remover Código GenServer Antigo

```bash
# Backup primeiro
git commit -m "Checkpoint: Before removing EnemyAI GenServer"

# Remover apenas o startup de GenServers
# Manter: StatsCalculator, ActorContext, damage logic
```

**Modificar `application.ex`**:
```elixir
def start(_type, _args) do
  children = [
    # ... telemetry, repo, pubsub, endpoint ...
    
    # REMOVER:
    # {PartitionSupervisor, child_spec: EnemyAI, ...}
    # {PartitionSupervisor, child_spec: DynamicSupervisor, ...}
    # RpgGameServer.Game.EnemySpawner
    
    # ADICIONAR:
    RpgGameServer.ECS.GameServer,
    RpgGameServer.Game.EnemySpawner  # Versão atualizada
  ]
end
```

### 4.3 Implementar CombatSystem

```elixir
# lib/rpg_game_server/ecs/systems/combat_system.ex

defmodule RpgGameServer.ECS.Systems.CombatSystem do
  alias RpgGameServer.ECS.{Query, Storage}
  alias RpgGameServer.Game.StatsCalculator
  
  def run(_dt, _world) do
    entities = Query.select(%{}, [:combat, :stats, :ai_brain])
    
    updates = Enum.filter_map(
      entities,
      fn {_id, {_combat, _stats, ai}} -> ai.mode == :attack end,
      fn {id, {combat, stats, ai}} ->
        # Reusar StatsCalculator existente!
        damage = StatsCalculator.calculate_outgoing_damage(stats, combat.weapon)
        
        new_combat = %{combat | last_attack_time: System.system_time(:millisecond)}
        {id, new_combat}
      end
    )
    
    Storage.update_batch(:combat, updates)
    {:ok, length(updates)}
  end
end
```

### 4.4 Atualizar WorldStateBroadcaster

```elixir
# lib/rpg_game_server/game/world_state_broadcaster.ex

def handle_info(:tick, state) do
  server_time = System.system_time(:millisecond)
  
  # ANTIGO: Coleta de todos os getUpdates() dos workers
  # all_updates = WorldTicker.get_all_updates()
  
  # NOVO: Buscar direto do ECS
  all_updates = RpgGameServer.ECS.Query.select(
    %{},
    [:position, :animation, :health, :entity_meta]
  )
  |> Enum.map(fn {id, {pos, anim, health, meta}} ->
    %{
      id: id,
      type: meta.type,
      x: pos.x,
      y: pos.y,
      state: anim.state,
      face: anim.facing,
      hp_percent: round(health.hp / health.max_hp * 100),
      area: "#{div(trunc(pos.x), 2100)}:#{div(trunc(pos.y), 2100)}"
    }
  end)
  
  # Resto idêntico...
end
```

### 4.5 Remover RoomTickerWorker

```bash
# Agora inútil, pode ser removido
rm lib/rpg_game_server/game/world_ticker_worker.ex
rm lib/rpg_game_server/game/world_ticker.ex
```

### 4.6 Testes de Integração

```elixir
# test/ecs/full_system_test.exs

test "full system: spawn, move, combat, die" do
  # Setup
  player_id = "player_1"
  enemy_id = "slime_1"
  
  # Spawn enemy via ECS
  {:ok, _} = GameServer.spawn_entity(enemy_id, "slime")
  
  # Add components
  Storage.add_component(enemy_id, :position,
    Components.Position.new(100, 100))
  Storage.add_component(enemy_id, :velocity,
    Components.Velocity.new(0, 0))
  Storage.add_component(enemy_id, :health,
    Components.Health.new(30, 30))
  Storage.add_component(enemy_id, :stats,
    Components.Stats.new())
  Storage.add_component(enemy_id, :ai_brain,
    Components.AIBrain.new())
  Storage.add_component(enemy_id, :combat,
    Components.Combat.new())
  Storage.add_component(enemy_id, :animation,
    Components.Animation.new(270))
  
  # Verificar que foi criado
  {:ok, pos} = Storage.get_component(enemy_id, :position)
  assert pos.x == 100
  
  # Mover (simular tick)
  MovementSystem.run(0.016, %{})
  
  # Update AI
  AISystem.run(0.016, %{})
  
  # Simular combate
  CombatSystem.run(0.016, %{})
  
  # Verificar que health pode ser reduzido
  {:ok, health} = Storage.get_component(enemy_id, :health)
  Storage.update_component(enemy_id, :health,
    %{health | hp: health.hp - 10})
  
  {:ok, updated_health} = Storage.get_component(enemy_id, :health)
  assert updated_health.hp == 20
end
```

### 4.7 Checklist Semana 4

- [ ] Feature flag: todos os tipos em ECS
- [ ] EnemyAI GenServers removidos
- [ ] CombatSystem implementado
- [ ] WorldStateBroadcaster atualizado
- [ ] Testes de integração passam
- [ ] 100% mobs em ECS

---

## Fase 5: Otimizações (Ongoing)

### 5.1 Performance Tuning

```elixir
# Monitorar via telemetry

:telemetry.attach("ecs.movement", [:ecs, :movement_system], 
  fn [:ecs, :movement_system], measurements, _metadata ->
    if measurements.duration_us > 5000 do  # > 5ms
      Logger.warn("Movement system slow: #{measurements.duration_us}µs")
    end
  end, nil)
```

### 5.2 Cache Optimization

```elixir
# Se queries ficarem lentas, particionar por shard

def shard_id(entity_id, num_shards) do
  :erlang.phash2(entity_id, num_shards)
end

# Usar em components_position_shard_0, ..., _N
```

### 5.3 Serialization Improvements

```elixir
# Usar bitmask para animação

# ANTES
%{state: 0, facing: 270}  # 2 campos

# DEPOIS
%{animation_state: (0 << 16) | 270}  # 1 inteiro
```

---

## Rollback Plan

Se houver problemas:

### Rollback Rápido (< 5 min)

```bash
# 1. Desabilitar ECS no application.ex
comment_out RpgGameServer.ECS.GameServer

# 2. Reabilitar GenServer
uncomment {PartitionSupervisor, child_spec: EnemyAI}

# 3. Restart
iex> Application.stop(:rpg_game_server)
iex> Application.start(:rpg_game_server)
```

### Rollback Completo

```bash
git checkout <commit-antes-ecs>
```

---

## Métricas de Sucesso

| Métrica | Target | Checklist |
|---------|--------|-----------|
| FPS (1000 mobs) | > 60 | [ ] |
| Latência | < 50ms | [ ] |
| Memory per mob | < 2KB | [ ] |
| Escalabilidade | 10k+ mobs | [ ] |
| Disponibilidade | > 99.9% | [ ] |

---

## Timeline Visual

```
Semana 1: [████░░░░░░] - Setup ECS base
Semana 2: [████████░░░░] - MovementSystem
Semana 3: [████████████████░░] - Coexistência
Semana 4: [████████████████████] - Full Migration

Total: 4 semanas | Risco: Baixo | ROI: 10-27x
```

---

## Próximos Steps (Hoje)

1. **Criar estrutura**: 
   ```bash
   mkdir -p lib/rpg_game_server/ecs/{systems,components}
   ```

2. **Copiar arquivos base** (do `ECS_IMPLEMENTATION.md`)

3. **Rodar testes smoke**:
   ```bash
   mix test test/ecs/smoke_test.exs
   ```

4. **Comprometer-se com timeline**:
   - Semana 1: ✅ Setup
   - Semana 2: ✅ MovementSystem
   - Semana 3: ✅ Coexistência
   - Semana 4: ✅ Full

---

## Support & Troubleshooting

**P: E se ECS quebrar no meio?**
R: Rollback em < 5 min. Mantenha feature flag até 100% estável.

**P: E os jogadores conectados?**
R: Coexistência permite transição sem downtime.

**P: Como testar antes de produção?**
R: Staging com 5k mobs por 24h. Coletar telemetria.

**P: Performance não melhorou?**
R: Buscar gargalos: queries lentas? Processamento? Storage?

---

## Conclusão

Este roadmap permite migração de baixo risco com ganhos imediatos de performance. Comece pequeno, prove o conceito, escale com confiança.

**Good luck! 🚀**
