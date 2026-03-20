# ECS Implementation

Use this skill when asked to scaffold, build out, or implement ECS world infrastructure or specific game features using ECS architecture.

## What this skill does

Produces working implementation code for:
- ECS World class (registry, query engine, resource store, system runner)
- Components, systems, resources, channels for a specific feature
- Pipeline configuration wiring it all together

## Reference

See `ecs-architecture-principles.md` for full definitions and examples.

## Language targets

- **TypeScript** — default; use when targeting web, Node, Vite, Astro, or Three.js environments
- **GDScript** — use when targeting Godot
- When implementing for Three.js specifically, include a `RenderSyncSystem` pattern that bridges ECS position/transform data to `Object3D`

Never mix languages in one implementation — pick one per context.

## Minimal TypeScript World scaffold

When asked to build or bootstrap a World, start from this minimal shape and expand as needed. Do not over-engineer — add features only when the use case requires them.

```typescript
type EntityId = number;
type ComponentType<T> = new () => T;

interface System {
  run(world: World, dt: number): void;
}

class World {
  private nextId = 0;
  private components: Map<EntityId, Map<string, unknown>> = new Map();
  private systems: { name: string; system: System | ((w: World, dt: number) => void) }[] = [];
  private startupSystems: ((w: World) => void)[] = [];
  private cleanupSystems: ((w: World) => void)[] = [];
  private resources: Map<string, unknown> = new Map();
  private channels: Map<string, unknown[]> = new Map();

  // Entities
  createEntity(): EntityId {
    const id = this.nextId++;
    this.components.set(id, new Map());
    return id;
  }

  destroyEntity(id: EntityId): void {
    this.components.delete(id);
  }

  // Components
  addComponent<T>(id: EntityId, key: string, value: T): void {
    this.components.get(id)?.set(key, value);
  }

  removeComponent(id: EntityId, key: string): void {
    this.components.get(id)?.delete(key);
  }

  getComponent<T>(id: EntityId, key: string): T | undefined {
    return this.components.get(id)?.get(key) as T | undefined;
  }

  hasComponent(id: EntityId, key: string): boolean {
    return this.components.get(id)?.has(key) ?? false;
  }

  // Queries — yields [entityId, ...requestedComponents]
  *query<T extends string[]>(...keys: T): Generator<[EntityId, ...unknown[]]> {
    for (const [id, comps] of this.components) {
      if (keys.every(k => comps.has(k))) {
        yield [id, ...keys.map(k => comps.get(k))];
      }
    }
  }

  // Resources
  installResource<T>(key: string, value: T): this {
    this.resources.set(key, value);
    return this;
  }

  resource<T>(key: string): T | undefined {
    return this.resources.get(key) as T | undefined;
  }

  // Systems
  installSystem(system: System | ((w: World, dt: number) => void), name = ''): this {
    this.systems.push({ name, system });
    return this;
  }

  installStartupSystem(fn: (w: World) => void): this {
    this.startupSystems.push(fn);
    return this;
  }

  installCleanupSystem(fn: (w: World) => void): this {
    this.cleanupSystems.push(fn);
    return this;
  }

  // Channels
  send<T>(channel: string, event: T): void {
    if (!this.channels.has(channel)) this.channels.set(channel, []);
    this.channels.get(channel)!.push(event);
  }

  drain<T>(channel: string): T[] {
    const events = (this.channels.get(channel) ?? []) as T[];
    this.channels.set(channel, []);
    return events;
  }

  // Lifecycle
  init(): void {
    for (const fn of this.startupSystems) fn(this);
  }

  tick(dt: number): void {
    for (const { system } of this.systems) {
      if (typeof system === 'function') system(this, dt);
      else system.run(this, dt);
    }
  }

  dispose(): void {
    for (const fn of this.cleanupSystems) fn(this);
    this.components.clear();
    this.resources.clear();
    this.channels.clear();
  }
}
```

## Three.js bridge pattern

When the project uses Three.js, the last system in any pipeline should sync ECS position/rotation/scale data to `Object3D`:

```typescript
interface MeshComponent {
  object3D: THREE.Object3D;
}

function renderSyncSystem(world: World): void {
  for (const [eid, position, mesh] of world.query('position', 'mesh') as
       Iterable<[EntityId, PositionComponent, MeshComponent]>) {
    mesh.object3D.position.set(position.x, position.y, position.z);
  }
}
```

The Three.js scene graph should be treated as a **render output sink**, not as the source of truth for game state.

## Minimal Godot World (autoload) scaffold

```gdscript
# res://autoload/World.gd
extends Node

var _resources: Dictionary = {}
var _channels: Dictionary = {}
var _systems: Array[Callable] = []
var _startup_systems: Array[Callable] = []
var _cleanup_systems: Array[Callable] = []

func install_resource(key: String, value: Variant) -> void:
    _resources[key] = value

func resource(key: String) -> Variant:
    return _resources.get(key)

func install_system(fn: Callable) -> void:
    _systems.append(fn)

func install_startup_system(fn: Callable) -> void:
    _startup_systems.append(fn)

func install_cleanup_system(fn: Callable) -> void:
    _cleanup_systems.append(fn)

func send(channel: String, event: Dictionary) -> void:
    if not _channels.has(channel):
        _channels[channel] = []
    _channels[channel].append(event)

func drain(channel: String) -> Array:
    var events: Array = _channels.get(channel, []).duplicate()
    _channels[channel] = []
    return events

# Entities: use get_tree().get_nodes_in_group("tag_name") for queries
# Components: child nodes on entity nodes, retrieved via get_node_or_null()

func _ready() -> void:
    for fn in _startup_systems:
        fn.call()

func _process(delta: float) -> void:
    for fn in _systems:
        fn.call(delta)
```

## Implementation rules

**Always:**
- Start from the minimal scaffold above; expand only what is needed
- Put pipeline configuration in one place (a `buildWorld()` factory function)
- Name systems as verbs: `movementSystem`, `huntSystem`, `renderSyncSystem`
- Name components as nouns + "Component" or tag as nouns + "Tag": `VelocityComponent`, `EnemyTag`
- Name resources as nouns + "Resource" or descriptive key strings: `'settings'`, `'spatialIndex'`

**Never:**
- Add component methods that query or mutate other components
- Add system-to-system references
- Let resources outlive their world
- Use global module state as a substitute for resources

## When asked to implement a specific feature

1. Refer to `ecs-design.md` first — produce or confirm the design before writing code
2. Implement components as plain interfaces/classes (TypeScript) or node scripts (Godot)
3. Implement systems as standalone functions or classes with a single `run` method
4. Wire it all into a pipeline factory function
5. Note any channels needed and show both producer and consumer sides

## Vite/Astro/Node context

In a Vite or Astro project, the game loop typically lives in a canvas component. Wire it like this:

```typescript
// src/game/index.ts
import * as THREE from 'three';

export function startGame(canvas: HTMLCanvasElement): () => void {
  const renderer = new THREE.WebGLRenderer({ canvas });
  const scene = new THREE.Scene();
  const camera = new THREE.PerspectiveCamera(75, canvas.width / canvas.height);

  const world = buildGameplayWorld(scene);
  world.init();

  let animId: number;
  let last = performance.now();

  function loop(now: number) {
    const dt = (now - last) / 1000;
    last = now;
    world.tick(dt);
    renderer.render(scene, camera);
    animId = requestAnimationFrame(loop);
  }

  animId = requestAnimationFrame(loop);

  // Return cleanup function
  return () => {
    cancelAnimationFrame(animId);
    world.dispose();
    renderer.dispose();
  };
}
```
