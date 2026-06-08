#!/usr/bin/env bun
// Validates the genre/sub-genre/role vocabulary against the design acceptance criteria.
import { readFile } from "node:fs/promises";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const VOCAB = resolve(dirname(fileURLToPath(import.meta.url)), "../vocabulary");
const load = async (f) => JSON.parse(await readFile(resolve(VOCAB, f), "utf-8"));

const EXPECTED_GENRES = ["fantasy","horror","scifi","modern","science-fantasy","historical","western"];
const EXPECTED_SUBS = {
  fantasy: ["high-fantasy","dark-fantasy","low-fantasy","fairytale","wuxia"],
  horror: ["cosmic-horror","gothic-horror","movie-horror","body-horror","folk-horror"],
  scifi: ["pulp-scifi","cyberpunk","space-opera","hard-scifi","post-human"],
  modern: ["military","superhero","wwii","wwi","noir","espionage"],
  "science-fantasy": ["steampunk","dieselpunk","atompunk","gamma-world","sword-and-planet"],
  historical: ["ancient","viking","medieval","samurai","age-of-sail"],
  western: ["classic-western","spaghetti-western","weird-west","apocalypse-west"],
};

const errors = [];
const E = (m) => errors.push(m);

const genres = await load("genre.json");
const subs = await load("subgenres.json");
const roles = await load("roles.json");

const genreIds = genres.map((g) => g.id);
const subIds = subs.map((s) => s.id);

// Genres
if (genreIds.slice().sort().join() !== EXPECTED_GENRES.slice().sort().join())
  E(`genre.json ids != expected. got: ${genreIds.join(",")}`);
for (const g of genres) if (g.level !== "genre") E(`genre ${g.id} missing level:"genre"`);

// Sub-genres
const allExpectedSubs = Object.values(EXPECTED_SUBS).flat();
if (subIds.slice().sort().join() !== allExpectedSubs.slice().sort().join())
  E(`subgenres.json ids != expected. missing: ${allExpectedSubs.filter((i)=>!subIds.includes(i)).join(",")}; extra: ${subIds.filter((i)=>!allExpectedSubs.includes(i)).join(",")}`);
for (const s of subs) {
  if (s.level !== "subgenre") E(`subgenre ${s.id} missing level:"subgenre"`);
  if (!genreIds.includes(s.parent)) E(`subgenre ${s.id} has invalid parent "${s.parent}"`);
  if (EXPECTED_SUBS[s.parent] && !EXPECTED_SUBS[s.parent].includes(s.id)) E(`subgenre ${s.id} parent ${s.parent} mismatch`);
  if (!s.tone) E(`subgenre ${s.id} missing tone`);
  if (!Array.isArray(s.descriptors) || !s.descriptors.length) E(`subgenre ${s.id} empty descriptors`);
  if (!Array.isArray(s.prompt_fragments) || !s.prompt_fragments.length) E(`subgenre ${s.id} empty prompt_fragments`);
}

// Roles
const validTags = new Set([...genreIds, ...subIds, "*"]);
const seenIds = new Set();
if (!Array.isArray(roles)) E("roles.json is not an array");
for (const r of roles) {
  if (seenIds.has(r.id)) E(`duplicate role id "${r.id}"`);
  seenIds.add(r.id);
  if (!Array.isArray(r.applies_to) || !r.applies_to.length) E(`role ${r.id} empty applies_to`);
  for (const t of r.applies_to || []) if (!validTags.has(t)) E(`role ${r.id} bad tag "${t}"`);
  if (!Array.isArray(r.prompt_fragments) || !r.prompt_fragments.length) E(`role ${r.id} empty prompt_fragments`);
}

// Lookup coverage: every genre and sub-genre must yield >=1 role
const rolesFor = (genreId, subId) =>
  roles.filter((r) => r.applies_to.some((t) => t === genreId || t === subId || t === "*"));
for (const s of subs) {
  if (rolesFor(s.parent, s.id).length === 0) E(`no roles resolve for ${s.parent}/${s.id}`);
}

// Tagged pools (species, vehicles, props): valid array, unique ids, valid tags, non-empty prompt_fragments
const poolCounts = {};
for (const file of ["species.json", "vehicles.json", "props.json"]) {
  let pool;
  try { pool = await load(file); } catch { E(`${file} missing or invalid JSON`); continue; }
  if (!Array.isArray(pool)) { E(`${file} is not an array`); continue; }
  const ids = new Set();
  for (const x of pool) {
    if (ids.has(x.id)) E(`${file}: duplicate id "${x.id}"`);
    ids.add(x.id);
    if (!Array.isArray(x.applies_to) || !x.applies_to.length) E(`${file}: ${x.id} empty applies_to`);
    for (const t of x.applies_to || []) if (!validTags.has(t)) E(`${file}: ${x.id} bad tag "${t}"`);
    if (!Array.isArray(x.prompt_fragments) || !x.prompt_fragments.length) E(`${file}: ${x.id} empty prompt_fragments`);
  }
  poolCounts[file] = pool.length;
}

if (errors.length) {
  console.error(`FAIL — ${errors.length} problem(s):`);
  for (const m of errors) console.error("  - " + m);
  process.exit(1);
}
console.log(`OK — ${genres.length} genres, ${subs.length} sub-genres, ${roles.length} roles, ${poolCounts["species.json"]||0} species, ${poolCounts["vehicles.json"]||0} vehicles, ${poolCounts["props.json"]||0} props; all nodes resolve roles.`);
