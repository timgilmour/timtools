# Skill: ECS Code Review

Use this skill when asked to review, audit, or critique existing game code against ECS architecture principles.

## What this skill does

Reviews code for violations of ECS principles and produces prioritised, actionable feedback. Does not rewrite the code unless asked — produces a review report first.

## Reference

See `../ecs-architecture-principles.md` for full definitions. The three core laws:
1. **Components = data only** — no logic, no side effects beyond internal state
2. **Systems = logic only** — small, orthogonal, explicit read/write surface
3. **Flat and deterministic** — no hidden dependencies, no callback webs, explicit execution order

## Review checklist

Work through each category. Flag violations with severity: **critical** (breaks the architecture), **warning** (degrades it over time), or **suggestion** (improvement opportunity).

### Components

- [ ] Does any component contain methods with external side effects? **(critical)**
- [ ] Does any component hold a reference to another component or system? **(critical)**
- [ ] Is any component doing work that belongs in a system? **(critical)**
- [ ] Is a component storing derived state that could be recomputed from other components? **(warning)**
- [ ] Is a large component mixing unrelated fields that could be split? **(suggestion)**

### Systems

- [ ] Does a system do more than one clearly nameable job? **(warning — split it)**
- [ ] Does a system directly call or reference another system? **(critical)**
- [ ] Does a system mutate state it didn't declare as a write? **(critical)**
- [ ] Is a stateful system holding state that should be a resource? **(warning)**
- [ ] Is a system too large to reason about in one reading? **(warning)**
- [ ] Are there multiple systems doing overlapping work? **(warning)**

### Resources

- [ ] Is shared mutable state stored outside the world (e.g., module-level globals, singletons)? **(critical)**
- [ ] Are resources leaking beyond their world lifetime? **(warning)**
- [ ] Is expensive computed data being recalculated per-system instead of cached as a resource? **(warning)**

### Pipeline / execution order

- [ ] Is the execution order implicit (e.g., driven by event dispatch, async callbacks)? **(critical)**
- [ ] Does a system read data that hasn't been written yet this tick? **(critical — ordering bug)**
- [ ] Are there circular dependencies between systems? **(critical)**
- [ ] Is the pipeline config scattered across multiple files/classes instead of declared in one place? **(warning)**

### Messaging

- [ ] Are systems communicating via callbacks, observers, or event buses? **(warning — prefer channels)**
- [ ] Are events dispatched and consumed in the same tick without a defined ordering guarantee? **(warning)**
- [ ] Is there any risk of event cycles (A fires B fires A)? **(critical)**

### General

- [ ] Is the code replicating deep OOP inheritance where composition via components would work? **(warning)**
- [ ] Are there "manager" objects that mix state storage with game logic? **(warning)**
- [ ] Would toggling a feature require touching many files? **(warning — poor orthogonality)**

## Output format

Produce a structured review report:

```
## ECS Review: <file or feature name>

### Summary
One paragraph: overall health, biggest risks.

### Critical issues
- [location] Description of violation and why it breaks the architecture.
  Suggested fix: ...

### Warnings
- [location] Description of degradation risk.
  Suggested fix: ...

### Suggestions
- [location] Optional improvement.

### What's working well
- List things that correctly follow ECS principles (important for balance).
```

## Language guidance

When suggesting fixes, use the same language as the reviewed code. If producing example rewrites:
- **TypeScript** by default (with Three.js idioms where relevant)
- **GDScript** for Godot-specific code
- Keep examples minimal — show the pattern, not the full implementation

## Tone

- Direct and specific — point to exact locations, not vague categories
- Explain *why* each violation matters, not just that it violates a rule
- Acknowledge pragmatic exceptions (e.g., bridging third-party APIs may require component methods)
