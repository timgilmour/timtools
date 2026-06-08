# Pose Library

The canonical, **appendable** store of named poses for character/creature subjects. Two sections:

- **Mesh-gen poses** — neutral, limbs-separated, for image-to-3D. Hand-curated, stable.
- **Observed poses** — captured from reference images via `ingest-image.md`. Grows over time.

A pose entry drives two things in a prompt: the `<POSE>` phrase and the recommended aspect ratio.

## Mesh-gen poses (for image-to-3D)

| Pose | `<POSE>` phrase | Aspect | Use |
|------|-----------------|--------|-----|
| **A-pose** (default) | `standing in a symmetrical A-pose with arms relaxed straight down at roughly 45 degrees away from the torso, palms facing the body, fingers slightly spread, legs shoulder-width apart` | `2:3` | Bipeds; frames tall figures, natural read |
| **T-pose** | `standing in a symmetrical T-pose with both arms extended straight out horizontally to the sides at shoulder height, palms down, fingers together, legs shoulder-width apart` | `1:1` | Maximum limb separation |
| **Quadruped stand** | `standing square and symmetrical on all four legs, planted shoulder-width apart, head level` | `4:3` | Beasts, mounts, monsters |

> **Hard requirement for mesh gen:** clear air gaps between arms and torso, and between the legs. Only these neutral poses are safe for reconstruction. Observed/action poses below are for **beauty/concept renders, not mesh gen.**

## Observed poses (captured via ingest)

Beauty/action poses derived from reference images. **Not for mesh gen** — limbs may overlap. Use for posed concept renders, splash art, or as a pose vocabulary reference.

Entry format (append one block per captured pose):

```
### <pose-slug>
- **phrase:** <imperative pose description, body + limbs + head + weight>
- **expression:** <face/attitude, if any>
- **aspect:** <recommended ratio>
- **use:** beauty / action / idle / dramatic
- **source:** <image filename or note>
```

<!-- INGEST APPENDS BELOW THIS LINE -->

### enraged-roar
- **phrase:** standing wide with weight low, torso leaning forward, both arms raised and bent outward with fists clenched, shoulders hunched, head tilted back mid-roar, mouth wide open
- **expression:** screaming, enraged, furious
- **aspect:** 2:3
- **use:** action / dramatic
- **source:** example entry (illustrates the format)

## Adding a pose

1. Run the `ingest-image.md` workflow on a reference image.
2. It derives a pose block in the format above.
3. Append it under the INGEST line. Give it a short, descriptive `pose-slug` (verb-first: `enraged-roar`, `guard-stance`, `casting-spell`).
4. Reuse it later by name: *"render the orc in the `enraged-roar` pose."*
