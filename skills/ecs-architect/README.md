# ecs-architect

A Claude Code skill for designing, implementing, and reviewing game systems using **Entity-Component-System (ECS)** architecture. Targets TypeScript/Three.js and Godot/GDScript.

## Usage

Invoke `ecs-architect` — it routes to the appropriate phase based on your request:

| Intent | Resource loaded |
|--------|----------------|
| "Design a feature using ECS", "Architect this system" | `ecs-design.md` — structured design document |
| "Build the ECS world", "Implement this feature" | `ecs-implement.md` — working scaffold code |
| "Review this code for ECS violations" | `ecs-review.md` — severity-ranked audit |

## Core Concepts

- **Components** — pure data, no logic. Small, composable structs.
- **Systems** — all logic lives here. One responsibility per system, stateless by default.
- **Resources** — scoped globals (config, caches, managers) tied to a world's lifetime.
- **Channels** — pull-based event queues for cross-system messaging. No callbacks, no event buses.
- **Pipelines** — explicit, sequential system execution order. The order _is_ the data flow.

## Intended Workflow

```
1. Design    →  Produce a design doc for the feature
2. Implement →  Scaffold code from the design
3. Review    →  Audit the result against ECS principles
```

## Language Support

- **TypeScript** — default target. Includes Three.js bridge patterns and Vite/Astro game loop wiring.
- **GDScript** — Godot target. Uses autoload World, node-based components, and group-based queries.

## Files

```
ecs-architect/
  SKILL.md                        # Main skill entry point (router)
  README.md                       # This file
  ecs-architecture-principles.md  # Full reference (all seven ECS concepts)
  ecs-design.md                   # Feature design resource
  ecs-implement.md                # Implementation scaffold resource
  ecs-review.md                   # Code review/audit resource
```
