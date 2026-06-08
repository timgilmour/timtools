# Subject Module — Characters & Creatures

For humanoid and creature subjects: PCs, NPCs, monsters, beasts. Supplies the **pose selector** and the character/creature **detail vocabulary**. Combine with the universal `core/render-rules.md`.

## Vocabulary lookup

For any subject with vocabulary coverage, look up their tags before building the prompt. The structured vocabulary files (`vocabulary/*.json`) are the authoritative source — `prompt_fragments[]` arrays contain pre-tested visual language that generates consistent results.

**Lookup sequence:**

1. **Species** → `vocabulary/species.json` — find entry by `id`, extract `prompt_fragments[]`, `visual`, `palette`. Each species carries `applies_to` (genre/sub-genre ids or `"*"`) — filter by it to suggest genre-appropriate species when the user hasn't named one.
2. **Genre + sub-genre** → `vocabulary/genre.json` (parent) and `vocabulary/subgenres.json` (sub-genre). Resolve the sub-genre's `parent`, merge the parent `visual` with the sub-genre `visual` deltas, and take the sub-genre's `tone`, `descriptors[]`, `prompt_fragments[]`.
3. **Role** → `vocabulary/roles.json` (single tagged pool). Include every role whose `applies_to` contains the chosen genre id, the sub-genre id, or `"*"`; pick by fit and extract `prompt_fragments[]`.
4. **Descriptors** → `vocabulary/descriptors.json` — for each tag applied (size, age, condition, tier, physical, social), extract `prompt_fragments[]`
5. **Intersections** → `vocabulary/intersections.json` — check every entry's `when[]`. If ALL conditions match the subject's tags (species + role + descriptors), apply `visual_override`, `traits_add`, `prompt_fragments_add[]`. Multiple intersections can fire; collect all additions.

Merge all extracted fragments into the `<DETAILS>` slot of the prompt assembly template. Intersection fragments take priority — they represent emergent archetypes, not just additive detail.

For theme, material, environment, and palette language, reference the prose vocabulary files (`vocabulary/*.md`) in the same directory.

### Species coverage

These species have entries in `vocabulary/species.json`:

> human · orc · elf · dwarf · hiver · romulan · tiefling · dragonborn · android · halfling · gnome · half-orc · aasimar · lizardfolk · minotaur · tabaxi · warforged · drow · goliath · githyanki · leonin · klingon

#### Creating a new species (the pool grows as you use it)

If the user wants a species not in the pool, **create it** — same flow as roles:
1. **Draft** the entry: `id`, `taxonomy: "species"`, `label`, `default_size`, `visual` (skin / features / build / palette), `traits`, `prompt_fragments` (2–5 concrete phrases), `applies_to` (genre/sub-genre ids or `"*"`), `ext: {}`.
2. **Confirm** the full drafted JSON with the user.
3. **Append** it to `vocabulary/species.json` — no duplicate `id`.
4. **Validate**: `bun run tools/validate-vocab.mjs` → `OK`.
5. **Use** it for the render.

### Roles

All roles live in a single tagged pool: `vocabulary/roles.json`. Each role's `applies_to` lists the genre ids, sub-genre ids, or `"*"` (universal) where it belongs. To get the candidate roles for a subject, filter the pool by the chosen genre id + sub-genre id + `"*"` (see the lookup sequence above). Coverage spans all 7 genres and 35 sub-genres; `"*"` roles (ruler, merchant, commoner, priest, healer…) appear everywhere.

#### Creating a new role (the pool grows as you use it)

If the user wants an archetype the pool doesn't cover, **create it** — don't force-fit an existing role:

1. **Draft** the role:
   - `id` — kebab-case; prefix with the sub-genre when the bare name could collide (e.g. `wuxia-sword-saint`, `wwii-paratrooper`).
   - `label` — human-readable name.
   - `applies_to` — tag it where it belongs, choosing the narrowest accurate option:
     - **Universal** (fits any setting — ruler, merchant) → `["*"]`.
     - **Whole genre** (all of that genre's sub-genres) → the **genre id** (e.g. `["fantasy"]`). Use this *only* for genres whose sub-genres are tonal variants — Fantasy, Horror, Western, Sci-Fi, Science Fantasy. **Never** for the **era-divided** genres (Historical, and the WWI/WWII split of Modern): a genre-level tag there bleeds the role across mutually-exclusive eras (a legionary must not surface under Samurai; a hacker must not surface under WWII).
     - **Spans several sub-genres but not all** (e.g. a falconer fits `samurai`, `medieval`, `viking`, `ancient` — but not `age-of-sail`) → **list those sub-genre ids explicitly**. This is the right choice inside era-divided genres.
     - **One sub-genre** → that single sub-genre id.
   - `prompt_fragments` — 3–6 concrete visual phrases (silhouette, gear, materials, palette), matte/mesh-friendly, matching the style of existing entries.
2. **Confirm** the draft with the user — show the full drafted JSON object (id, label, applies_to, prompt_fragments) and get approval before writing.
3. **Append** it to `vocabulary/roles.json` — one more object in the array; do not duplicate an existing `id`.
4. **Validate**: run `bun run tools/validate-vocab.mjs` and confirm it prints `OK` (unique ids, valid tags, every node still resolves).
5. **Use** it for the render like any other role.

> Note: roles in the era-divided genres (Historical; Modern's WWI/WWII) are tagged at the **sub-genre** level, so the genre-id part of the lookup filter intentionally matches nothing for them — the sub-genre id and `"*"` carry the result. That is expected, not a bug.

## Prompt assembly

```
[render block from core/render-rules.md, <FRAMING> = "Front-facing orthographic"]
Full-body <character/creature> concept reference of <SUBJECT>, <POSE>. <DETAILS: assembled prompt_fragments + any custom additions>.
```

| Slot | Fill with | Example |
|------|-----------|---------|
| `<SUBJECT>` | the subject, one noun phrase | `a sly tiefling rogue` |
| `<POSE>` | from the pose selector below | `standing in a symmetrical A-pose …` |
| `<DETAILS>` | merged taxonomy fragments + gear, palette, extras | `crimson skin, filed-down horns, fitted dark leathers, tail extended for balance` |

## Pose selector

Poses live in **`core/pose-library.md`** (the appendable store). Pick a `<POSE>` phrase and aspect from there:

- **Mesh-gen poses** (A-pose / T-pose / quadruped stand) — neutral, limbs separated, safe for image-to-3D. **Use these by default.**
- **Observed poses** — captured from reference images via `core/ingest-image.md`. For beauty/action renders, **not** mesh gen.

**The only hard requirement for mesh gen:** clear air gaps between arms and torso, and between the legs — satisfied by A-pose (natural, frames tall figures) and T-pose (maximum separation). New poses are added by ingesting reference images; see `core/ingest-image.md`.

## Worked example — taxonomy-assembled

**Subject:** Tiefling Rogue, fantasy, A-pose mesh-gen

**Step 1 — species** (`vocabulary/species.json`, `id: "tiefling"`):
> crimson or deep purple skin · short curved horns · slender · long prehensile tail · solid-color eyes with no iris or pupil · lean build

**Step 2 — role** (`vocabulary/roles.json`, `id: "rogue"`, `applies_to` includes `fantasy`):
> fitted dark leathers · multiple hidden blades · nimble and low-profile · tools of infiltration · built to vanish

**Step 3 — no descriptors applied**

**Step 4 — intersection check** (`vocabulary/intersections.json`):
> `["tiefling", "rogue"]` matches → adds: tail used for balance or carrying small tools · filed-down horns for mask compatibility · solid eyes made for darkness

**Assembled `<DETAILS>`:**
> crimson skin, short curved horns filed for mask compatibility, slender build, long prehensile tail extended for balance, solid-color eyes made for darkness, fitted dark leathers, multiple hidden blades, built to vanish, no held weapons

**Final prompt:**
```
Clean game concept art style, crisp readable silhouette, clear forms. Front-facing
orthographic view, entire subject in frame, centered with empty margin on all
sides. No perspective distortion, no foreshortening, neutral eye-level camera.
Flat even diffuse studio lighting, soft and shadowless, no rim light, no cast
shadows. Matte surfaces, no reflections, no glossy highlights. Pure white
seamless background, single subject fully isolated. Still, sharp focus, high
detail. Full-body character concept reference of a sly tiefling rogue, standing
in a symmetrical A-pose with arms relaxed straight down at roughly 45 degrees
away from the torso, palms facing the body, legs shoulder-width apart. Crimson
skin, short curved horns filed for mask compatibility, slender build, long
prehensile tail extended for balance, solid-color eyes made for darkness, fitted
dark leathers, multiple hidden blades, built to vanish, no held weapons. Neutral
expression.
```

## Character-specific do / don't

(in addition to the universal table in `core/render-rules.md`)

| Do | Don't |
|----|-------|
| neutral expression, symmetrical | "turning to look", twisted torso, head turned |
| weapons omitted or held *away* from the body | weapon crossing the chest / torso |
| asymmetric *gear* OK (one pauldron, eyepatch) | asymmetric *pose* (hurts reconstruction) |
| "palms facing body / palms down" (defined hands) | clasped or hidden hands |

## Monsters & creatures

For creatures with entries in `vocabulary/species.json` (orc, hiver, lizardfolk, minotaur, tabaxi, etc.) — use the taxonomy lookup above, leaving the role slot empty for pure-creature renders (species fragments alone are sufficient).

For creatures without taxonomy entries, use the reference table below:

| Slug | `<SUBJECT>` | `<DETAILS>` | Pose |
|------|-------------|-------------|------|
| `goblin` | a wiry green-skinned goblin | pointed ears, hooked nose, patchwork leather scraps, bronze + mossy-green | A-pose 2:3 |
| `skeleton` | an animated skeleton warrior | bleached bone, tattered armor remnants, hollow sockets, gaps between bones, bone-white + rust | A-pose 2:3 |
| `mind-flayer` | a sinister mind flayer (illithid) | mauve skin, octopus head with four facial tentacles, ornate robes, mauve + slate | A-pose 2:3 |
| `owlbear` | a hulking owlbear | bear body, owl head + feathered ruff, hooked beak, four clawed legs, brown + tawny | Quadruped 4:3 |
| `beholder` | a floating beholder | spherical body, one massive central eye, fanged maw, ten eyestalks splayed evenly, leathery purple | Floating 1:1 |
| `red-dragon` | a young red dragon | reptilian quadruped, broad spread wings, horned head, long neck + tail, matte crimson scales | Wings spread 4:3 |
| `gelatinous-cube` | a translucent gelatinous cube | perfectly cubic pale ooze, faint suspended debris, matte not glossy, soft green tint | Cube 1:1 |
| `troll` | a gangly regenerating troll | rubbery green hide, long limbs, upright hunch, warty skin, jagged teeth, mottled green | A-pose 2:3 |
| `lich` | a skeletal lich | desiccated undead in tattered archmage robes, skull face + glowing sockets, bone crown, violet + bone | A-pose 2:3 |
| `kobold` | a small kobold | reptilian dog-like head, short horns, scaly hide, ragged tunic, rust-red + ochre | A-pose 2:3 |
| `displacer-beast` | a panther-like displacer beast | six legs, sleek black hide, two barbed shoulder tentacles, glowing eyes, matte black | Quadruped 4:3 |

## Batch render snippet (PowerShell)

```powershell
$out = "<OUTPUT_DIR>/concepts/characters"
$subjects = @{
  "goblin"  = "Clean game concept art style, crisp readable silhouette. Front-facing orthographic view, full body head to toe centered with margin, no foreshortening, neutral camera. Flat even diffuse shadowless lighting, no rim light, no cast shadows. Matte surfaces, no reflections. Pure white seamless background, single subject isolated. Sharp focus, high detail. Full-body character concept reference of a wiry green-skinned goblin, standing in a symmetrical A-pose with arms relaxed straight down at roughly 45 degrees away from the torso, palms facing the body, legs shoulder-width apart. Pointed ears, hooked nose, patchwork leather scraps, bronze and mossy-green palette, no held weapon. Neutral expression."
}
foreach ($s in $subjects.GetEnumerator()) {
  $dir = "$out/$($s.Key)"; New-Item -ItemType Directory -Force -Path $dir | Out-Null
  bun run <ZUUL>/tools/generate-image.ts `
    --prompt $s.Value --model nano-banana-2 --size 2K --aspect-ratio 2:3 `
    --output "$dir/$($s.Key)-01.png"
}
```

Switch `--aspect-ratio` per the pose column (quadrupeds/floating → `1:1` or `4:3`).
