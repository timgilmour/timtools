---
name: ecs-architect
description: Design, implement, and review game systems using ECS (Entity-Component-System) architecture. Covers TypeScript/Three.js and Godot/GDScript.
---

# ECS Architect

A unified skill for designing, implementing, and reviewing game systems using Entity-Component-System architecture.

## When to use

Use this skill when the user asks to:
- **Design** a game feature, mechanic, or system using ECS principles
- **Implement** ECS world infrastructure or scaffold a feature
- **Review** existing game code against ECS architecture principles

## Workflow

The intended workflow is: Design → Implement → Review. But each phase can be used independently.

## How to proceed

Based on the user's request, read the appropriate resource file from this skill's directory:

| User intent | Resource file to load |
|---|---|
| Design / architect / plan a feature | `ecs-design.md` |
| Build / scaffold / implement code | `ecs-implement.md` |
| Review / audit / critique existing code | `ecs-review.md` |

All three reference `ecs-architecture-principles.md` in this directory for the full ECS principle definitions.

If the user's intent is unclear, ask which phase they need. If they say "build X using ECS", run design first, then implement.

## Quick reference — Core ECS principles

- **Components** = pure data, no logic
- **Systems** = all logic, one responsibility each, stateless by default
- **Resources** = scoped globals (config, caches, managers) tied to world lifetime
- **Channels** = pull-based event queues for cross-system messaging (no callbacks)
- **Pipelines** = explicit sequential system execution order — the order IS the data flow

## Language targets

- **TypeScript** — default; includes Three.js bridge patterns and Vite/Astro wiring
- **GDScript** — for Godot projects; uses autoload World, node-based components
