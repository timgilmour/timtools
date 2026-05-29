---
name: win2lin
description: Migrate a Claude Code environment (selected projects, in-repo Claude config, referenced subset of ~/.claude/, optional encrypted secrets vault) from Windows to a fresh Ubuntu / Debian / Arch-family Linux box (bare metal or WSL2, x86_64 or aarch64). Use when the user is moving from Windows to Linux and wants Claude Code, their projects, and their per-project memory to come along. Detects three modes by platform: `prepare` (Windows source), `ingest` (Linux destination), `doctor` (Linux post-check).
---

# win2lin — Windows → Linux Claude Code project migration

This skill operates in three modes. The mode is determined by the platform you are on and the arguments passed:

- **`prepare`** — invoke on Windows. Discovers projects, asks per-repo policy questions, shells out to the PowerShell bundler. Output: tarball + sibling `unpack-and-bootstrap.sh`.
- **`ingest <staging-path>`** — invoke on Linux after running the unpacker. Confirms detected distro/WSL/arch, asks for project destinations, rewrites Windows paths in `~/.claude.json` / `.mcp.json` / settings, restores projects per their captured policy, lays the referenced subset of `~/.claude/`, prompts the user for the vault-unlock one-liner. Never reads `.env*` content.
- **`doctor`** — idempotent verification of an ingested environment. Re-runnable any time.

See [`references/bundle-format.md`](references/bundle-format.md) for the canonical bundle layout, [`references/path-rewrite-rules.md`](references/path-rewrite-rules.md) for path translation, and [`references/distro-cheats.md`](references/distro-cheats.md) for per-distro install one-liners.

## Boundaries

- The LLM never reads `.env*` files at any phase. The bundler collects them under user consent; the encrypted vault carries them; the user's manual one-liner restores them.
- The LLM never sees the vault passphrase.
- The bundler does not push to git remotes without confirmation.
- The unpacker does not unlock the vault — that is a one-liner the user runs.

## Mode: `prepare` (run on Windows)

When invoked on Windows (detected by `$env:OS -eq "Windows_NT"` or `platform == "win32"`):

### Step 1 — discover projects

Read `~/.claude.json` (Windows path: `$env:USERPROFILE\.claude.json`). Enumerate the `projects` map keys. Also scan `$env:USERPROFILE\projects\*` for directories containing `CLAUDE.md` or `.claude/`. Deduplicate.

Shell out for the discovery list:

```pwsh
pwsh -NoProfile -File <skill>/references/source-bundler.ps1 -DiscoverOnly
```

### Step 2 — present the questionnaire (via AskUserQuestion)

Ask in this exact order, one question per AskUserQuestion call:

1. **Projects** (multiSelect) — show the discovered list; pre-checked if origin = claude.json. Let the user uncheck.
2. **Per-repo policy** — for each selected repo, call `source-bundler.ps1 -InspectRepo <path>`, then ask: `strict-clean` / `capture-state` / `bundle-whole-tree` / `skip`. Pre-fill with the recommendation derived from state:
   - clean + has_remote → `strict-clean`
   - has_uncommitted OR stash_count > 0 → `capture-state`
   - no remote → `bundle-whole-tree`
3. **Secrets vault** (multiSelect) — categories: `env`, `ssh`, `netrc`, `npmrc`, `gh`, `aws`, `gpg`. Pre-checked: `env`, `ssh`, `gh`.
4. **Toolchain manifest fields to capture** — node, pnpm, python, gh, csdx. Pre-checked: node, pnpm, gh.
5. **Output path** — default `$env:USERPROFILE\Desktop\claude-migration-$env:COMPUTERNAME-<yyyymmdd>.tar.zst`. Let the user override.
6. **Confirm summary** — show the full plan rendered as a table; final yes/no.

### Step 3 — write params + invoke bundler

Write `params.json` to `$env:TEMP\win2lin-params.json` matching this shape:

```json
{
  "OutputDir": "<dir>",
  "OutputName": "<name-without-extension>",
  "DryRun": false,
  "HomeClaudePath": "<USERPROFILE>\\.claude",
  "Projects": [
    {"slug":"<slug>", "source_path":"<full-windows-path>", "policy":"<policy>"}
  ],
  "Secrets": {"Enabled": <bool>, "Categories": ["env","ssh"], "Passphrase": "<from prompt>"}
}
```

**Important:** for secrets, prompt the user via AskUserQuestion to enter the passphrase. Pass it into params.json so the bundler can use it directly without re-prompting. **Do NOT log the passphrase anywhere.**

Then shell out:

```pwsh
pwsh -NoProfile -File <skill>/references/source-bundler.ps1 -Params $env:TEMP\win2lin-params.json
```

### Step 4 — print next-step instructions

Tell the user: their two output files are at `<OutputDir>`. To continue on the destination Linux box:

```
scp tim@<windows>:Desktop/claude-migration-*.tar.zst .
scp tim@<windows>:Desktop/unpack-and-bootstrap.sh .
./unpack-and-bootstrap.sh claude-migration-*.tar.zst
```

For WSL on the same machine: skip the scp — run the unpacker directly with `--from-mnt /mnt/c/Users/<user>/Desktop/claude-migration-*.tar.zst`.

## Mode: `ingest <staging-path>` (run on Linux)

When invoked on Linux (detected by `$IsLinux` / `platform == "linux"`). If no `<staging-path>` is given, auto-detect by scanning `~/.claude/win2lin-staging/` for the most recently modified subdirectory containing `manifest.json`.

### Step 1 — read and validate manifest

```bash
ajv validate -s ~/.claude/skills/win2lin/assets/manifest.schema.json -d <staging>/manifest.json
```

If validation fails, abort and show the validation error.

### Step 2 — questionnaire (via AskUserQuestion)

1. **Confirm staging path** — show the auto-detected path; let the user override.
2. **Confirm distro/WSL/arch** — show what the unpacker detected; flag arch mismatch vs `manifest.source.arch`.
3. **Project destinations** — show a table: source path → suggested destination (`$HOME/projects/<source-basename>` per project). Per-project override.
4. **Path-rewrite policy** — `auto` / `interactive` / `dry-run`.
5. **Toolchain reconciliation** — show diff between manifest.toolchain and detected (`node -v`, `gh --version`, `pnpm -v`). Per-tool: install / skip.
6. **Install referenced global skills/plugins** — show `manifest.global_claude_subset.skills` and `.marketplaces`; multi-select to install. Default: all checked.
7. **Vault unlock instructions** — if `manifest.secrets_vault.present == true`, print the one-liner and instruct the user to run it themselves:

   ```bash
   openssl enc -d -aes-256-cbc -pbkdf2 -in <staging>/secrets.tar.gz.enc | tar xz -C ~/
   ```

   (openssl prompts for the passphrase interactively.)

   Ask: "Have you unlocked the vault? (y/n)" — proceed regardless, but record whether secrets are available so git operations can use SSH.

8. **Confirm plan summary** — final go/no-go.

### Step 3 — execute restore

For each project in manifest.projects:

- **strict-clean** — `git clone <git.remote> <dest>` then `git checkout <git.default_branch>`.
- **capture-state** — clone fresh; then `git apply <staging>/<git.captured.dirty_patch>`; for each entry in `stashes.json` apply the captured patch as a stash; extract `untracked.tar.gz` into the working tree; for each entry in `worktrees.json` recreate via `git worktree add`.
- **bundle-whole-tree** — `rsync -a <staging>/projects/<slug>/tree/ <dest>/`.
- **skip** — skip.

Copy in-repo Claude config files into the restored project root from `<staging>/projects/<slug>/`.

### Step 4 — rewrite `~/.claude.json`

Read existing `~/.claude.json` (may be empty on a fresh Linux box). Merge in source projects with rewritten keys:

- Windows key `C:\Users\tim\projects\hawker` → Linux key `/home/<user>/projects/hawker` (or whatever the user chose in Step 2 question 3).
- Preserve any value fields (lastSessionId, history).
- If a Linux key already exists with the same path, prompt before overwrite.

Write back the merged JSON pretty-printed.

### Step 5 — rewrite per-project `.claude/settings*.json` and `.mcp.json`

For each restored project, scan `.claude/settings.json`, `.claude/settings.local.json`, and `.mcp.json`. Use the rewrite rules in [`references/path-rewrite-rules.md`](references/path-rewrite-rules.md). Apply rewrites according to the chosen policy:

- **auto** — apply structured rewrites silently; log to `<staging>/rewrite.log`.
- **interactive** — show each proposed rewrite (file + JSONPath + old → new); user approves or skips.
- **dry-run** — write the rewrite plan to `<staging>/REVIEW.md`; apply nothing.

### Step 6 — restore global subset

For each entry in `manifest.global_claude_subset.skills`: copy from `<staging>/claude-subset/skills/<name>/` to `~/.claude/skills/<name>/`.
For each entry in `.marketplaces`: copy to `~/.claude/plugins/marketplaces/<name>/`.
For each entry in `.settings_files`: prompt before overwrite (since the user may have already touched these on the destination).

### Step 7 — restore per-project memory

For each project: copy `<staging>/claude-subset/projects/<flattened-source-slug>/memory/` to `~/.claude/projects/<flattened-destination-slug>/memory/`. The destination slug is computed from the rewritten project path the same way Claude Code does (forward slashes → dashes, prefix with `-`).

### Step 8 — write REVIEW.md

Scan all CLAUDE.md / AGENTS.md / README.md files in restored projects for residual `C:\` or `/d/` style paths. Emit a markdown checklist at `<staging>/REVIEW.md` listing each match with file:line. Do NOT auto-rewrite free-text markdown — let the user decide.

### Step 9 — print summary

Show: projects restored, paths rewritten, REVIEW.md path, suggestion to run `doctor` mode.

## Mode: `doctor` (run on Linux, post-ingest)

Idempotent. Re-runnable any time. Output: pass/fail per probe with a remediation hint.

Run each probe in order. Continue past failures and report the full list at the end.

### Probe 1 — `~/.claude.json` is healthy

```bash
jq -r '.projects | keys[]' ~/.claude.json | grep -E '^[A-Z]:|^/[dD]/'
```

Expected: empty output. Any line printed is a residual Windows-style key. Remediation: re-run `ingest` with rewrite-policy `auto`, or hand-edit.

### Probe 2 — each migrated project is restorable

For each key in `~/.claude.json.projects`:
- Verify directory exists at the key path.
- Run `git -C <path> status --porcelain` (if a git repo). If manifest.projects[<slug>].policy == "strict-clean", expect empty. If == "capture-state", expect non-empty if the dirty.patch was non-empty.
- Verify `.mcp.json` parses if present.

### Probe 3 — referenced global skills are present

For each entry in `manifest.global_claude_subset.skills`:
```bash
test -f ~/.claude/skills/<name>/SKILL.md
```

### Probe 4 — toolchain matches manifest

```bash
node -v              # compare to manifest.toolchain.node
pnpm -v 2>/dev/null  # compare to manifest.toolchain.pnpm
gh --version 2>/dev/null
```

Mismatches are warnings, not failures.

### Probe 5 — destination arch matches source

```bash
uname -m
```

Compare against `manifest.source.arch`. If mismatched and no `<staging>/.arch-mismatch-accepted` sentinel exists, warn. If sentinel exists, silent pass.

### Probe 6 — REVIEW.md has zero unaddressed items

```bash
grep -c '^- \[ \]' <staging>/REVIEW.md
```

Expected: 0. Each `- [ ]` line is an item the user hasn't checked off yet.

### Output format

```
✓ Probe 1 — ~/.claude.json healthy
✓ Probe 2 — 4/4 projects restored cleanly
✗ Probe 3 — missing skill: gitnexus
        Fix: cp -r <staging>/claude-subset/skills/gitnexus ~/.claude/skills/
✓ Probe 4 — toolchain matches manifest
✓ Probe 5 — arch matches (x86_64)
⚠ Probe 6 — 3 unaddressed items in REVIEW.md
```

Exit 0 only if every probe is `✓` or `⚠`. Exit 1 if any `✗`.
