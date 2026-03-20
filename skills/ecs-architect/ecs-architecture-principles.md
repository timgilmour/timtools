# ECS Architecture Principles

Distilled from *Systems: Modular and Scalable Game Architecture for Orthogonal Game Logic* (originally Unreal-focused). All examples rewritten for TypeScript/Three.js and Godot (GDScript).

> Inspired by: Bevy, hecs (Rust), Oxygengine, Rust's lazy-iterator and channel APIs.

---

## Core Philosophy

Three rules above all:

1. **Make it flat** — explicit, sequential data processing; no hidden dependency graphs
2. **Make it small** — focused, single-responsibility systems
3. **Make it compact and disconnected** — minimal interdependencies between systems

The fundamental mental model: *"All a game is, is a bunch of data in memory that gets transformed from one form to another."* Model data transformations, not real-world objects.

---

## The Seven Concepts

### 1. World

The **World** is the central registry — a database holding all entities, their components, all systems, and all resources. Nothing lives outside of it.

- Systems execute sequentially each tick in registration order (explicit, not event-driven)
- The world is acquired/released in response to game phase changes (startup, level load, menu, etc.)
- Multiple named worlds can coexist (e.g., one for gameplay, one for UI)

**TypeScript:**
```typescript
class World {
  private entities: Map<EntityId, ComponentMap> = new Map();
  private systems: System[] = [];
  private resources: Map<string, unknown> = new Map();

  registerComponent<T>(type: ComponentType<T>): this { ... }
  installResource<T>(key: string, value: T): this { ... }
  installSystem(system: System, name: string): this { ... }

  tick(dt: number): void {
    for (const system of this.systems) system.run(this, dt);
  }
}

// Setup
const world = new World();
world
  .registerComponent(VelocityComponent)
  .registerComponent(EnemyTag)
  .installResource('settings', { timeScale: 1.0 })
  .installSystem(movementSystem, 'Movement')
  .installSystem(huntSystem, 'Hunt');
```

**Godot:**
```gdscript
# res://autoload/World.gd  (registered as autoload "World")
class_name GameWorld extends Node

var _systems: Array[Callable] = []
var _resources: Dictionary = {}

func install_resource(key: String, value: Variant) -> void:
    _resources[key] = value

func install_system(fn: Callable) -> void:
    _systems.append(fn)

func resource(key: String) -> Variant:
    return _resources.get(key)

func _process(delta: float) -> void:
    for system in _systems:
        system.call(delta)
```

---

### 2. Entities

An entity is just an **identifier** — a key that components hang off of. It has no behaviour of its own.

In Three.js/TypeScript you can use integers, UUIDs, or wrap `Object3D` as an entity key. In Godot, `Node` instances typically serve as entities; the node itself holds no game logic.

```typescript
type EntityId = number;
let nextId = 0;
const createEntity = (): EntityId => nextId++;
```

---

### 3. Components

Components are **pure data containers** — structs or plain objects. No methods. No side effects beyond recalculating their own internal state.

- Add/remove components to opt entities in/out of systems without touching any other code
- Use empty/tag components to mark entities for system queries (e.g., `EnemyTag`, `DeadTag`)

**TypeScript:**
```typescript
// Data component
interface VelocityComponent {
  x: number;
  y: number;
  z: number;
}

// Tag component (no data, just presence)
interface EnemyTag {}

// Internal recalculation is acceptable
interface BoundsComponent {
  min: Vector3;
  max: Vector3;
  // ok: recomputes own internal state only
  recompute(position: Vector3, size: Vector3): void;
}
```

**Godot:**
```gdscript
# res://components/VelocityComponent.gd
class_name VelocityComponent extends Node

var value: Vector3 = Vector3.ZERO

# res://components/EnemyTag.gd
class_name EnemyTag extends Node
# (empty — presence alone marks the entity)
```

---

### 4. Systems

Systems contain **all game logic**. A system queries the world for entities matching a component set, then transforms their data.

Keep systems:
- Small — one responsibility per system
- Orthogonal — independent of each other
- Stateless by default; stateful only when cross-tick state cannot live in a resource

**Stateless system — TypeScript:**
```typescript
function movementSystem(world: World, dt: number): void {
  const settings = world.resource<Settings>('settings');
  const scale = settings?.timeScale ?? 1;

  for (const [, velocity, position] of world.query(VelocityComponent, PositionComponent)) {
    position.x += velocity.x * dt * scale;
    position.y += velocity.y * dt * scale;
    position.z += velocity.z * dt * scale;
  }
}
```

**Stateful system — TypeScript (tracks cross-tick state):**
```typescript
class BirdCountLogSystem implements System {
  private lastCount = 0;

  run(world: World): void {
    const count = world.query(BirdTag).count();
    const diff = count - this.lastCount;
    this.lastCount = count;

    if (diff > 0) console.log(`Added ${diff} birds`);
    else if (diff < 0) console.log(`Removed ${-diff} birds`);
  }
}
```

**Stateless system — Godot:**
```gdscript
# res://systems/movement_system.gd
func movement_system(delta: float) -> void:
    var settings = World.resource("settings")
    var scale: float = settings.time_scale if settings else 1.0

    for entity in get_tree().get_nodes_in_group("has_velocity"):
        var vel: VelocityComponent = entity.get_node_or_null("VelocityComponent")
        var pos: PositionComponent = entity.get_node_or_null("PositionComponent")
        if vel and pos:
            pos.value += vel.value * delta * scale
```

**Example: decomposing movement orthogonally**

Rather than one `PlayerMovementSystem`, split:
1. `inputSystem` — reads input, writes to `InputComponent`
2. `velocityResolverSystem` — reads `InputComponent`, writes to `VelocityComponent`
3. `movementSystem` — reads `VelocityComponent`, writes to `PositionComponent`

Each can be toggled, replaced, or tested independently.

---

### 5. Resources

Resources are **scoped globals** — data shared across all systems within a world, tied to the world's lifetime. Not singletons; they're released when the world is released.

Use resources for:
- **Config/settings** — values systems read each tick
- **Shared caches** — spatial indexes, precomputed lookup tables
- **Game managers** — score trackers, audio managers, third-party wrappers

**TypeScript:**
```typescript
interface GameSettings {
  timeScale: number;
  gravity: number;
}

world.installResource<GameSettings>('settings', { timeScale: 1.0, gravity: 9.8 });

// Inside any system:
const settings = world.resource<GameSettings>('settings');
```

**Godot:**
```gdscript
# Setup
World.install_resource("settings", { "time_scale": 1.0, "gravity": 9.8 })

# In any system
var settings = World.resource("settings")
var gravity: float = settings["gravity"]
```

---

### 6. Pipelines (Configuration)

A pipeline is the **declarative config** for a world: which components are registered, which resources are installed, and which systems run in what order.

Order matters — systems execute in registration sequence. Treat the pipeline as the authoritative document of your game's data flow.

**TypeScript:**
```typescript
function buildGameplayWorld(): World {
  return new World()
    // components
    .registerComponent(PositionComponent)
    .registerComponent(VelocityComponent)
    .registerComponent(PlayerTag)
    .registerComponent(EnemyTag)
    // resources
    .installResource<GameSettings>('settings', loadSettings())
    .installResource<SpatialIndex>('spatialIndex', new RTree())
    // systems — ORDER IS EXECUTION ORDER
    .installSystem(inputSystem,         'Input')
    .installSystem(velocityResolver,    'VelocityResolver')
    .installSystem(spatialIndexSystem,  'SpatialIndex')   // rebuild index
    .installSystem(huntSystem,          'Hunt')           // reads index
    .installSystem(movementSystem,      'Movement')
    .installSystem(renderSyncSystem,    'RenderSync');    // push to Three.js
}
```

**Startup vs Persistent vs Cleanup:**
```typescript
world
  .installStartupSystem(spawnInitialEnemies)   // runs once on init
  .installSystem(huntSystem)                   // runs every tick
  .installCleanupSystem(despawnAll);           // runs on world release
```

---

### 7. Iterators (Lazy Query Chains)

Queries return **lazy iterators** — they do nothing until consumed. Chain filters, maps, and transforms without allocating intermediate arrays.

**TypeScript:**
```typescript
// Functional query chains
const nearest = world
  .query(EnemyTag, PositionComponent)
  .map(([, , pos]) => ({ pos, dist: playerPos.distanceTo(pos.vec3()) }))
  .minBy(e => e.dist);

// Range iteration
const evens = iterRange(0, 10)
  .filter(n => n % 2 === 0)
  .map(n => n * n)
  .collect();  // [0, 4, 16, 36, 64]
```

Key operations: `filter`, `map`, `flatMap`, `take`, `skip`, `find`, `count`, `minBy`, `maxBy`, `forEach`, `collect`

Lazy means: a `take(5)` on a large query stops after 5 — no full scan.

---

### 8. Channels (Pull-Based Messaging)

Channels solve cross-system communication without callbacks or event buses. They are **Single-Producer, Multiple-Consumer** queues where messages are stored but not acted on until a receiver explicitly pulls them.

- **No immediate dispatch** — sending a message doesn't execute any code
- **Pull timing is explicit** — receivers decide when to process
- **Prevents event cycles** — no stack overflows, no cascading re-calculations
- **Bound lifetime** — receiver existence = subscription; no manual unsubscribe

**TypeScript:**
```typescript
// Create a channel
const [sender, receiver] = createChannel<DamageEvent>();

// Producer system — just enqueues
function combatSystem(world: World): void {
  for (const hit of detectHits(world)) {
    sender.send({ targetId: hit.entity, amount: hit.damage });
  }
}

// Consumer system — explicitly drains at its own tick point
function healthSystem(world: World): void {
  for (const event of receiver.drain()) {
    const health = world.getComponent(event.targetId, HealthComponent);
    if (health) health.current -= event.amount;
  }
}
```

**Godot:**
```gdscript
# Channels can be implemented as simple queues on the World autoload
# Producer
World.send("damage_events", { "target": entity, "amount": 10 })

# Consumer (drains at a deterministic point in the pipeline)
for event in World.drain("damage_events"):
    var health = event["target"].get_node_or_null("HealthComponent")
    if health:
        health.current -= event["amount"]
```

---

## Archetypes (Internal Optimization)

When multiple component types are registered, the world internally buckets entities by their component signature — this is called an **archetype**. Queries only scan buckets matching their signature, giving efficient linear iteration. You don't implement this manually; it's an internal detail of the World implementation. Relevant when building a custom ECS engine.

---

## World Lifecycle

Worlds should be **acquired** when a game phase begins and **released** when it ends. This scopes system and resource lifetimes cleanly.

```typescript
// Phase-scoped worlds
class GameApp {
  private worlds = new WorldRegistry();

  onMenuStart() {
    this.worlds.acquire('menu', buildMenuWorld());
  }
  onMenuEnd() {
    this.worlds.release('menu');
  }
  onGameplayStart() {
    this.worlds.acquire('gameplay', buildGameplayWorld());
  }
  onGameplayEnd() {
    this.worlds.release('gameplay');
  }
}
```

---

## Anti-Patterns to Avoid

| Anti-pattern | Fix |
|---|---|
| Logic in components | Move to a system |
| Systems referencing other systems directly | Use a shared resource or channel |
| One giant "GameManager" system | Split into small orthogonal systems |
| Callbacks/event buses between systems | Use channels (pull-based) |
| System reads result of another system out of band | Enforce order in the pipeline; use resources as the hand-off |
| Components holding entity references for "manager" purposes | Use resources for shared handles |
| Deep inheritance hierarchies | Compose via multiple components instead |

---

## Quick Reference: Decision Guide

**Is this data or behaviour?**
- Data → component
- Behaviour → system

**Is this shared across many systems?**
- Yes → resource
- No (belongs to one entity) → component

**Does this need to communicate across system boundaries?**
- One-shot event → channel
- Persistent shared state → resource

**Is a system getting large?**
- Split it. Each split piece should have a single, nameable job.

**Should this system run this frame?**
- Gate on a resource flag, or move it to a startup/cleanup slot in the pipeline.
