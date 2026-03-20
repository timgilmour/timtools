# ecs-architect

A Claude Code skill suite for designing, implementing, and reviewing game systems using **Entity-Component-System (ECS)** architecture. Targets TypeScript/Three.js and Godot/GDScript.

## Skills

| Skill | Trigger | What it does |
|-------|---------|--------------|
| **ecs-design** | "Design a feature using ECS", "Architect this system" | Produces a structured design document: components, systems, resources, channels, and pipeline order |
| **ecs-implement** | "Build the ECS world", "Implement this feature" | Generates working scaffold code from a design — World class, components, systems, pipeline wiring |
| **ecs-review** | "Review this code for ECS violations", "Audit against ECS principles" | Audits existing code against ECS principles with a severity-ranked checklist (critical/warning/suggestion) |

## Core Concepts

The skills enforce these architectural principles (documented in full at `02-Notes/ecs-architect/ecs-architecture-principles.md`):

- **Components** — pure data, no logic. Small, composable structs.
- **Systems** — all logic lives here. One responsibility per system, stateless by default.
- **Resources** — scoped globals (config, caches, managers) tied to a world's lifetime.
- **Channels** — pull-based event queues for cross-system messaging. No callbacks, no event buses.
- **Pipelines** — explicit, sequential system execution order. The order _is_ the data flow.

## Intended Workflow

```
1. ecs-design    →  Produce a design doc for the feature
2. ecs-implement →  Scaffold code from the design
3. ecs-review    →  Audit the result against ECS principles
```

The design skill should always run before implementation. The review skill can be used on any existing codebase, not just code produced by this suite.

## Language Support

- **TypeScript** — default target. Includes Three.js bridge patterns (`RenderSyncSystem`) and Vite/Astro game loop wiring.
- **GDScript** — Godot target. Uses autoload World, node-based components, and group-based queries.

## Key Files

```
ecs-architect/
  ecs-architecture-principles.md   # Full reference document (all seven ECS concepts)
  ecs-design/SKILL.md              # Feature design skill
  ecs-implement/SKILL.md           # Implementation scaffold skill
  ecs-review/SKILL.md              # Code review/audit skill
```

## Anti-Patterns the Skills Flag

- Logic in components (move to a system)
- "Manager" classes mixing state and logic (split into resource + system)
- Callbacks or event buses between systems (use channels)
- Implicit execution order (make the pipeline explicit)
- Deep inheritance hierarchies (compose with components)
- Systems that do more than one job (split and name each piece)
