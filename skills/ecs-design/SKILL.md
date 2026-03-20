# Skill: ECS Feature Design

Use this skill when asked to design, architect, or plan a new game feature, mechanic, or system using ECS (Entity-Component-System) architecture principles.

## What this skill does

Guides the design of game features through an ECS lens — producing a structured output of:
- Component shapes (data only)
- System list with execution order
- Resources needed
- Any channels for cross-system messaging

## Reference

See `../ecs-architecture-principles.md` for full principle definitions. Summary:
- **Components** = pure data, no logic
- **Systems** = logic functions, query the world, no side effects beyond world state
- **Resources** = scoped globals (config, caches, managers)
- **Channels** = pull-based event queues between systems
- **Pipeline** = ordered list of systems; order is data-flow order

## Approach

When given a feature to design, work through these steps in order:

### Step 1 — Identify the data

Ask: what state needs to exist for this feature to work?

Each distinct piece of state becomes a **component** if it belongs to individual entities, or a **resource** if it is shared/global.

Rules:
- Components hold only raw values (numbers, vectors, strings, flags, references to assets)
- No methods on components except pure internal recalculation (e.g., recomputing a bounding box from its own fields)
- Prefer many small components over few large ones
- Tag components (empty structs) are valid — they mark entities for inclusion/exclusion in queries

### Step 2 — Identify the transformations

Ask: what happens to that data each tick? What reads what? What writes what?

Each distinct transformation becomes a **system**.

Rules:
- One responsibility per system — if you can't name it in 3–4 words, split it
- A system reads some components/resources and writes others — make this explicit
- Prefer stateless systems (pure functions over world); use stateful systems only for cross-tick internal caches

### Step 3 — Identify shared/global state

Ask: what does more than one system need to read?

Each shared thing becomes a **resource**:
- Config / settings
- Spatial indexes, lookup tables
- Game managers (score, audio, phase state)
- Anything expensive to recompute that multiple systems consume

### Step 4 — Identify cross-system messaging

Ask: does one system need to notify another about an event, without both knowing about each other?

Each such event stream becomes a **channel** (pull-based queue):
- Producer system sends to the channel
- Consumer system drains the channel at its own point in the pipeline
- Never use callbacks or direct system-to-system calls

### Step 5 — Order the pipeline

List all systems in execution order. The order IS the data flow. Make it read like a sentence:

```
Input → VelocityResolver → SpatialIndex → AI/Hunt → Movement → Collision → RenderSync
```

Rules:
- A system must appear after any system that writes data it reads
- Startup systems (run once) first; cleanup systems last
- The pipeline should be fully readable as the authoritative description of the feature's data flow

## Output format

Produce a design document with these sections:

```
## Feature: <name>

### Components
- `ComponentName` — fields and types, one-line purpose

### Resources
- `ResourceName` — type, purpose, lifetime

### Systems (in execution order)
1. `SystemName` — reads: [...], writes: [...], purpose

### Channels
- `channel-name<EventType>` — producer: SystemA, consumer: SystemB, purpose

### Pipeline order
[System1] → [System2] → [System3] → ...

### Notes / open questions
```

## Language guidance

When producing code examples or scaffolding, use:
- **TypeScript** as the default (with Three.js idioms where relevant to rendering/scene)
- **GDScript** for Godot-specific implementations
- Keep examples minimal — illustrate structure, not full implementation

## Common traps to call out

- Feature request embeds logic in a component → refactor to a system
- "Manager" class that both stores state and runs logic → split into resource (state) + system (logic)
- System that does 3 unrelated things → propose a split with named responsibilities
- Event-based design (callbacks, observers) → propose channels instead and explain why
