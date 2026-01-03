# Entity Component System - Implementação Prática

## Overview
Este arquivo demonstra a implementação prática de um ECS em Elixir adaptado para seu RPG.

---

## 1. Estrutura de Diretórios

```
lib/rpg_game_server/ecs/
├── components.ex           # Definições de componentes
├── query.ex               # DSL de queries
├── storage.ex             # Camada de armazenamento (ETS)
├── world.ex               # Context principal
├── systems/
│   ├── movement_system.ex
│   ├── ai_system.ex
│   ├── combat_system.ex
│   ├── spatial_grid_system.ex
│   └── animation_system.ex
└── game_server.ex         # Game loop central
```

---

## 2. Definição de Componentes

### 2.1 Components Module
```elixir
# lib/rpg_game_server/ecs/components.ex

defmodule RpgGameServer.ECS.Components do
  @moduledoc """
  Define todos os componentes reutilizáveis do sistema ECS.
  
  Componentes são simples estruturas de dados sem comportamento.
  """
  
  # ========== COMPONENTES CORE ==========
  
  defmodule Position do
    defstruct [:x, :y, :z]
    
    def new(x, y, z \\ 0) do
      %__MODULE__{x: x, y: y, z: z}
    end
  end
  
  defmodule Velocity do
    defstruct [:vx, :vy, speed: 0]
    
    def new(vx, vy, speed \\ 0) do
      %__MODULE__{vx: vx, vy: vy, speed: speed}
    end
  end
  
  defmodule Health do
    defstruct [:hp, :max_hp, regeneration: 0]
    
    def new(hp, max_hp, regen \\ 0) do
      %__MODULE__{hp: hp, max_hp: max_hp, regeneration: regen}
    end
  end
  
  defmodule Stats do
    defstruct [
      vigor: 10,
      endurance: 10,
      strength: 10,
      dexterity: 10,
      intelligence: 5,
      faith: 5,
      attunement: 5
    ]
    
    def new(overrides \\ %{}) do
      defaults = %__MODULE__{}
      Map.merge(defaults, overrides)
    end
  end
  
  # ========== COMPONENTES DE IA ==========
  
  defmodule AIBrain do
    defstruct [
      mode: :idle,           # :idle, :chase, :flee, :patrol
      target_id: nil,
      wander_target: nil,
      wander_deadline: 0,
      dist_to_player: 9999999,
      last_attack_time: 0
    ]
    
    def new(overrides \\ %{}) do
      defaults = %__MODULE__{}
      Map.merge(defaults, overrides)
    end
  end
  
  # ========== COMPONENTES DE COMBATE ==========
  
  defmodule Combat do
    defstruct [
      weapon: nil,           # %Item{} ou nil
      armor: nil,
      last_attack_time: 0,
      attack_cooldown: 1000,
      damage_history: %{}    # {attacker_id => [dano1, dano2, ...]}
    ]
    
    def new(weapon \\ nil) do
      %__MODULE__{weapon: weapon}
    end
  end
  
  # ========== COMPONENTES DE ANIMAÇÃO ==========
  
  defmodule Animation do
    defstruct [
      state: 0,              # 0: idle, 1: attack, 2: hurt
      facing: 270,           # ângulo em graus
      animation_frame: 0
    ]
    
    def new(facing \\ 270) do
      %__MODULE__{facing: facing}
    end
  end
  
  # ========== COMPONENTES ESPACIAIS ==========
  
  defmodule SpatialCell do
    defstruct [:cell_x, :cell_y, :in_grid]
    
    def new(x, y, cell_size) do
      cell_x = div(trunc(x), cell_size)
      cell_y = div(trunc(y), cell_size)
      %__MODULE__{cell_x: cell_x, cell_y: cell_y, in_grid: true}
    end
  end
  
  # ========== TIPOS DE ENTIDADE ==========
  
  defmodule EntityMeta do
    defstruct [:id, :type, :name, :level, :zone, :owner_id]
    
    def new(id, type, opts \\ []) do
      %__MODULE__{
        id: id,
        type: type,
        name: Keyword.get(opts, :name, "Unknown"),
        level: Keyword.get(opts, :level, 1),
        zone: Keyword.get(opts, :zone, "zone_1"),
        owner_id: Keyword.get(opts, :owner_id, nil)
      }
    end
  end
end
```

---

## 3. Storage Layer (ETS)

### 3.1 Storage Module
```elixir
# lib/rpg_game_server/ecs/storage.ex

defmodule RpgGameServer.ECS.Storage do
  @moduledoc """
  Gerencia todas as tabelas ETS para armazenamento de entidades e componentes.
  
  Usa read_concurrency e write_concurrency para máxima performance.
  """
  
  require Logger
  
  @tables [
    :ecs_entities,
    :ecs_components_position,
    :ecs_components_velocity,
    :ecs_components_health,
    :ecs_components_stats,
    :ecs_components_ai_brain,
    :ecs_components_combat,
    :ecs_components_animation,
    :ecs_components_spatial_cell,
    :ecs_components_entity_meta
  ]
  
  def init_tables() do
    Logger.info("Initializing ECS tables...")
    
    Enum.each(@tables, fn table ->
      case :ets.whereis(table) do
        :undefined ->
          :ets.new(table, [
            :set,
            :public,
            :named_table,
            {:read_concurrency, true},
            {:write_concurrency, true}
          ])
          Logger.debug("Created table: #{table}")
        
        _pid ->
          Logger.debug("Table already exists: #{table}")
      end
    end)
    
    :ok
  end
  
  # ========== ENTITY OPERATIONS ==========
  
  def create_entity(id, type, opts \\ []) do
    meta = Components.EntityMeta.new(id, type, opts)
    :ets.insert(:ecs_entities, {id, type})
    :ets.insert(:ecs_components_entity_meta, {id, meta})
    {:ok, id}
  end
  
  def delete_entity(id) do
    # Remove all components for this entity
    @tables
    |> Enum.filter(&String.starts_with?(Atom.to_string(&1), "ecs_components_"))
    |> Enum.each(&:ets.delete(&1, id))
    
    :ets.delete(:ecs_entities, id)
    :ok
  end
  
  # ========== COMPONENT OPERATIONS ==========
  
  def add_component(entity_id, component_type, component) do
    table = table_for_component(component_type)
    :ets.insert(table, {entity_id, component})
    :ok
  end
  
  def get_component(entity_id, component_type) do
    table = table_for_component(component_type)
    case :ets.lookup(table, entity_id) do
      [{^entity_id, component}] -> {:ok, component}
      [] -> :not_found
    end
  end
  
  def update_component(entity_id, component_type, component) do
    add_component(entity_id, component_type, component)
  end
  
  def remove_component(entity_id, component_type) do
    table = table_for_component(component_type)
    :ets.delete(table, entity_id)
    :ok
  end
  
  # ========== BATCH OPERATIONS ==========
  
  def update_batch(component_type, updates) when is_list(updates) do
    table = table_for_component(component_type)
    Enum.each(updates, fn {id, component} ->
      :ets.insert(table, {id, component})
    end)
    :ok
  end
  
  # ========== QUERIES ==========
  
  def all_entities() do
    :ets.all() |> Enum.to_list()
  end
  
  def get_entity_type(entity_id) do
    case :ets.lookup(:ecs_entities, entity_id) do
      [{^entity_id, type}] -> {:ok, type}
      [] -> :not_found
    end
  end
  
  # ========== INTERNAL ==========
  
  defp table_for_component(:position), do: :ecs_components_position
  defp table_for_component(:velocity), do: :ecs_components_velocity
  defp table_for_component(:health), do: :ecs_components_health
  defp table_for_component(:stats), do: :ecs_components_stats
  defp table_for_component(:ai_brain), do: :ecs_components_ai_brain
  defp table_for_component(:combat), do: :ecs_components_combat
  defp table_for_component(:animation), do: :ecs_components_animation
  defp table_for_component(:spatial_cell), do: :ecs_components_spatial_cell
  defp table_for_component(:entity_meta), do: :ecs_components_entity_meta
  defp table_for_component(type), do: raise "Unknown component: #{type}"
end
```

---

## 4. Query DSL

### 4.1 Query Module
```elixir
# lib/rpg_game_server/ecs/query.ex

defmodule RpgGameServer.ECS.Query do
  @moduledoc """
  DSL para queries eficientes sobre componentes.
  
  Exemplo:
    Query.select(world, [:position, :velocity])
    |> Enum.filter(fn {_id, {pos, vel}} -> pos.x > 100 end)
  """
  
  alias RpgGameServer.ECS.Storage
  
  @component_tables %{
    position: :ecs_components_position,
    velocity: :ecs_components_velocity,
    health: :ecs_components_health,
    stats: :ecs_components_stats,
    ai_brain: :ecs_components_ai_brain,
    combat: :ecs_components_combat,
    animation: :ecs_components_animation,
    spatial_cell: :ecs_components_spatial_cell,
    entity_meta: :ecs_components_entity_meta
  }
  
  def select(world, components) when is_list(components) do
    # Busca entidades de interesse (com todos os componentes solicitados)
    tables = Enum.map(components, &Map.fetch!(@component_tables, &1))
    
    # Obter todas as entidades da primeira tabela
    first_table = List.first(tables)
    entities = :ets.match_object(first_table, {:"$1", :_})
    
    # Filtrar: manter apenas entidades presentes em TODOS os componentes
    entities
    |> Enum.filter(fn {entity_id, _} ->
      Enum.all?(tables, fn table ->
        :ets.member(table, entity_id)
      end)
    end)
    |> Enum.map(fn {entity_id, _} ->
      components_data = Enum.map(tables, fn table ->
        [{^entity_id, data}] = :ets.lookup(table, entity_id)
        data
      end)
      {entity_id, List.to_tuple(components_data)}
    end)
  end
  
  def select_by_type(world, entity_type, components) do
    select(world, components)
    |> Enum.filter(fn {entity_id, _} ->
      case Storage.get_entity_type(entity_id) do
        {:ok, ^entity_type} -> true
        _ -> false
      end
    end)
  end
  
  def filter(world, components, predicate) when is_function(predicate) do
    select(world, components)
    |> Enum.filter(fn {_id, data} -> predicate.(data) end)
  end
end
```

---

## 5. Sistemas Exemplo

### 5.1 Movement System
```elixir
# lib/rpg_game_server/ecs/systems/movement_system.ex

defmodule RpgGameServer.ECS.Systems.MovementSystem do
  @moduledoc """
  Sistema que aplica velocidade a posições.
  Roda a cada tick e move todas as entidades com Position + Velocity.
  """
  
  alias RpgGameServer.ECS.{Query, Storage, Components}
  
  def run(dt, _world) when is_number(dt) do
    # Query: entidades com Position + Velocity
    entities = Query.select(%{}, [:position, :velocity])
    
    # Mapear e calcular novas posições
    updates = Enum.map(entities, fn {id, {pos, vel}} ->
      new_x = pos.x + vel.vx * dt
      new_y = pos.y + vel.vy * dt
      
      new_pos = %{pos | x: new_x, y: new_y}
      {id, new_pos}
    end)
    
    # Batch update em ETS
    Storage.update_batch(:position, updates)
    
    {:ok, length(updates)}
  end
  
  def stop_entity(entity_id) do
    case Storage.get_component(entity_id, :velocity) do
      {:ok, vel} ->
        new_vel = %{vel | vx: 0, vy: 0}
        Storage.update_component(entity_id, :velocity, new_vel)
      :not_found -> :ok
    end
  end
end
```

### 5.2 AI System
```elixir
# lib/rpg_game_server/ecs/systems/ai_system.ex

defmodule RpgGameServer.ECS.Systems.AISystem do
  @moduledoc """
  Sistema de IA simplificado.
  Determina o estado mental e comportamento de entidades controladas por IA.
  """
  
  alias RpgGameServer.ECS.{Query, Storage, Components}
  alias RpgGameServer.Game.PlayerSpatialGrid
  
  @vision_radius 400
  @attack_range 35
  
  def run(dt, _world) do
    # Query: entidades com AI Brain + Position
    entities = Query.select(%{}, [:ai_brain, :position])
    
    updates = Enum.map(entities, fn {id, {ai, pos}} ->
      new_ai = update_ai_state(id, ai, pos, dt)
      {id, new_ai}
    end)
    
    Storage.update_batch(:ai_brain, updates)
    {:ok, length(updates)}
  end
  
  defp update_ai_state(entity_id, ai, pos, _dt) do
    # Buscar players próximos
    nearby_players = PlayerSpatialGrid.get_nearby_players(pos.x, pos.y, @vision_radius)
    
    new_mode = 
      case nearby_players do
        [] -> 
          :idle
        players ->
          # Entidades próximas detectadas
          closest = find_closest_player(players, pos)
          
          if distance(pos, closest) <= @attack_range do
            :attack
          else
            :chase
          end
      end
    
    %{ai | mode: new_mode}
  end
  
  defp find_closest_player(players, pos) do
    players
    |> Enum.min_by(fn {_id, {px, py}} ->
      (pos.x - px) ** 2 + (pos.y - py) ** 2
    end)
    |> elem(1)
  end
  
  defp distance(pos, {px, py}) do
    :math.sqrt((pos.x - px) ** 2 + (pos.y - py) ** 2)
  end
end
```

### 5.3 Combat System
```elixir
# lib/rpg_game_server/ecs/systems/combat_system.ex

defmodule RpgGameServer.ECS.Systems.CombatSystem do
  @moduledoc """
  Sistema de combate.
  Processa ataques, dano e morte de entidades.
  """
  
  alias RpgGameServer.ECS.{Query, Storage, Components}
  alias RpgGameServer.Game.StatsCalculator
  
  def run(_dt, _world) do
    # Query: entidades com Combat + Stats + Health + AI Brain
    entities = Query.select(%{}, [:combat, :stats, :health, :ai_brain])
    
    # Processar combate para entidades em modo :attack
    updates = Enum.filter_map(
      entities,
      fn {_id, {_combat, _stats, _health, ai}} -> ai.mode == :attack end,
      fn {id, {combat, stats, health, ai}} ->
        new_combat = perform_attack(id, combat, stats, ai)
        {id, new_combat}
      end
    )
    
    Storage.update_batch(:combat, updates)
    {:ok, length(updates)}
  end
  
  defp perform_attack(entity_id, combat, stats, ai) do
    now = System.system_time(:millisecond)
    
    # Verificar cooldown
    if now - combat.last_attack_time > combat.attack_cooldown do
      # Calcular dano
      damage = StatsCalculator.calculate_outgoing_damage(stats, combat.weapon)
      
      # Broadcast dano (para ser capturado pelo client)
      # TODO: Integrar com broadcast system
      
      %{combat | last_attack_time: now}
    else
      combat
    end
  end
end
```

---

## 6. Game Loop Central

### 6.1 Game Server
```elixir
# lib/rpg_game_server/ecs/game_server.ex

defmodule RpgGameServer.ECS.GameServer do
  @moduledoc """
  Game loop central. Executa todos os sistemas em sincronismo.
  
  - 60 FPS = 16.67ms por frame
  - Determinístico
  - Batch processing
  """
  
  use GenServer
  require Logger
  
  alias RpgGameServer.ECS.{
    Storage,
    Systems.MovementSystem,
    Systems.AISystem,
    Systems.CombatSystem
  }
  
  @tick_rate 16  # milliseconds = 60 FPS
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @impl true
  def init(_opts) do
    Logger.info("Starting ECS Game Server (60 FPS)")
    Storage.init_tables()
    
    schedule_tick()
    
    {:ok, %{
      tick_count: 0,
      frame_times: []
    }}
  end
  
  @impl true
  def handle_info(:tick, state) do
    {elapsed_us, _} = :timer.tc(fn ->
      dt = @tick_rate / 1000.0  # Convert ms to seconds
      world = %{}
      
      # Executar sistemas em ordem
      {:ok, moved} = MovementSystem.run(dt, world)
      {:ok, thought} = AISystem.run(dt, world)
      {:ok, attacked} = CombatSystem.run(dt, world)
      
      # Log a cada 60 frames (1 segundo)
      new_tick = state.tick_count + 1
      if rem(new_tick, 60) == 0 do
        Logger.debug("Game loop tick #{new_tick}: " <>
          "#{moved} moved, #{thought} AI, #{attacked} attacks")
      end
      
      new_tick
    end)
    
    elapsed_ms = elapsed_us / 1000.0
    
    # Aguardar até completar o intervalo de tick
    sleep_time = max(0, @tick_rate - elapsed_ms)
    :timer.sleep(trunc(sleep_time))
    
    schedule_tick()
    
    {:noreply, %{state | tick_count: state.tick_count + 1}}
  end
  
  defp schedule_tick() do
    Process.send_after(self(), :tick, @tick_rate)
  end
  
  # ========== PUBLIC API ==========
  
  def spawn_entity(id, type, opts \\ []) do
    Storage.create_entity(id, type, opts)
  end
  
  def despawn_entity(id) do
    Storage.delete_entity(id)
  end
end
```

---

## 7. Integração com Application

```elixir
# lib/rpg_game_server/application.ex - adicionar

def start(_type, _args) do
  children = [
    # ... existentes ...
    
    # ECS Game Server (replaces individual mob GenServers)
    RpgGameServer.ECS.GameServer
  ]
  
  # ...
end
```

---

## 8. Exemplo de Uso Completo

```elixir
# Criar um inimigo
{:ok, enemy_id} = RpgGameServer.ECS.GameServer.spawn_entity(
  "slime_1",
  "slime",
  name: "Slime Lvl 3",
  level: 3,
  zone: "forest_1"
)

# Adicionar componentes
Storage.add_component(enemy_id, :position, 
  Components.Position.new(100, 200))
Storage.add_component(enemy_id, :velocity, 
  Components.Velocity.new(0, 0))
Storage.add_component(enemy_id, :health, 
  Components.Health.new(30, 30, 1))
Storage.add_component(enemy_id, :stats, 
  Components.Stats.new(%{strength: 12, dexterity: 8}))
Storage.add_component(enemy_id, :ai_brain, 
  Components.AIBrain.new())
Storage.add_component(enemy_id, :combat, 
  Components.Combat.new())
Storage.add_component(enemy_id, :animation, 
  Components.Animation.new(270))

# Game loop roda automaticamente a 60 FPS
# Todos os sistemas processam este inimigo
```

---

## 9. Roadmap de Implementação

### Passo 1: Setup Básico
- [ ] Copiar `components.ex`, `storage.ex`, `query.ex`
- [ ] Criar `systems/movement_system.ex`
- [ ] Testar com 100 entidades

### Passo 2: Sistema de IA
- [ ] Implementar `systems/ai_system.ex`
- [ ] Integrar com `PlayerSpatialGrid`
- [ ] Testar com 1000 mobs

### Passo 3: Combate
- [ ] Implementar `systems/combat_system.ex`
- [ ] Integrar com dano e morte
- [ ] Testar com PvP

### Passo 4: Integração Completa
- [ ] Remover `EnemyAI` GenServers
- [ ] Atualizar broadcast para ECS
- [ ] Performance test: 5k+ mobs

---

Este código fornece uma base sólida para migrar gradualmente seu RPG para ECS.
