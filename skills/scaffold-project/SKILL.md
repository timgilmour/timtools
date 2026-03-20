---
name: scaffold-project
description: Scaffold a new VS Code + Claude Code + Obsidian project from scratch. Creates git repo, folder structure, Claude config, Obsidian vault with plugins, app directory, and enables core plugins.
user-invocable: true
---

# Scaffold Project

Create a fully configured project in the current working directory.

## Prerequisites

- Current directory should be empty (or contain only `.git`)
- Git, Node.js (v18+), and Claude Code must be available on PATH

## Phase 1: Questionnaire

Ask these questions **one at a time**. Wait for each answer before asking the next. Use multiple choice where indicated.

### Q1: Project Name
> What's the project name? (defaults to current directory name)

Free text. Store as `PROJECT_NAME`.

### Q2: Description
> One-line description of this project:

Free text. Store as `DESCRIPTION`.

### Q3: Delivery Method
> How will this project be delivered?
>
> 1. **Web app** — SaaS, hosted service
> 2. **CLI tool** — standalone binary or npm/pip package
> 3. **Library/package** — published to a registry
> 4. **Documentation site** — static, content-focused
> 5. **Plugin/extension** — VS Code, Claude Code, browser extension
> 6. **Internal tool** — not published, team or personal use

Store as `DELIVERY_METHOD`.

### Q4: Primary Language
> What's the primary language?
>
> 1. **TypeScript**
> 2. **Python**
> 3. **Go**
> 4. **Rust**
> 5. **Other** (specify)

Store as `LANGUAGE`.

### Q5: Production Goals
> What does success look like for this project? (1-2 sentences)

Free text. Store as `GOALS`.

### Q6: Installed Plugins

Before asking this question, run `claude plugins list` to discover what plugins the user actually has installed. Parse the output and present only the **non-core** plugins (exclude superpowers, claude-mem, mgrep, and tim-tools — these are assumed). Show each plugin's name, marketplace, and enabled/disabled status.

> Here are the plugins installed on your system:
>
> {numbered list of discovered plugins with name, marketplace, and current status}
>
> Which of these should be enabled for this project? (comma-separated numbers, or "none")

Store as `OPTIONAL_PLUGINS` (list).

### Q7: Marketplace Search

After the user answers Q6, based on what you now know about the project (DELIVERY_METHOD, LANGUAGE, GOALS), suggest 2-3 specific types of plugins that would complement the project but aren't currently installed. Then ask:

> Based on your project goals, you might also benefit from plugins for **{suggestion 1}**, **{suggestion 2}**, etc.
>
> Would you like to browse the plugin marketplace for additional skills? (yes/no)

If yes, run `claude plugins marketplace list` to show available marketplaces, then help the user install any plugins they want using `claude plugins install <plugin>@<marketplace>`. After installing, add them to `OPTIONAL_PLUGINS`.

If no, move on.

---

## Phase 2: Scaffolding

After collecting all answers, announce: "Setting up **{PROJECT_NAME}**..." and execute these steps in order.

### Step 1: Initialize Git

```bash
git init
```

Create `.gitignore`:

```gitignore
# Claude Code
.claude/

# Obsidian workspace state (vault lives in docs/)
docs/.obsidian/workspace.json
docs/.obsidian/workspace-mobile.json
docs/.obsidian/graph.json
docs/.obsidian/backlink.json
docs/.obsidian/canvas.json
docs/.obsidian/hotkeys.json

# Scratch / temp
temp/

# Git worktrees
.worktrees/

# MCP runtime
.playwright-mcp/
.gitnexus/

# Environment
.env
.env.local
.env.*.local

# OS files
Thumbs.db
.DS_Store

# Editor
*.swp
*.swo
*~
```

### Step 2: Obsidian Vault

Create `docs/` as the Obsidian vault root. All Obsidian config goes in `docs/.obsidian/`:

**`docs/.obsidian/app.json`**:
```json
{
  "promptDelete": false,
  "showLineNumber": true,
  "attachmentFolderPath": "10-Attachments",
  "newFileLocation": "folder",
  "newFileFolderPath": "00-Inbox"
}
```

**`docs/.obsidian/core-plugins.json`**:
```json
{
  "file-explorer": true,
  "global-search": true,
  "switcher": true,
  "graph": true,
  "backlink": true,
  "canvas": true,
  "outgoing-link": true,
  "tag-pane": true,
  "footnotes": false,
  "properties": true,
  "page-preview": true,
  "daily-notes": true,
  "templates": true,
  "note-composer": true,
  "command-palette": true,
  "slash-command": false,
  "editor-status": true,
  "bookmarks": true,
  "markdown-importer": false,
  "zk-prefixer": false,
  "random-note": false,
  "outline": true,
  "word-count": true,
  "slides": false,
  "audio-recorder": false,
  "workspaces": false,
  "file-recovery": true,
  "publish": false,
  "sync": true,
  "bases": true,
  "webviewer": false
}
```

**`docs/.obsidian/community-plugins.json`**:
```json
[
  "obsidian-excalidraw-plugin",
  "dataview",
  "templater-obsidian",
  "obsidian-tasks-plugin",
  "table-editor-obsidian",
  "calendar",
  "obsidian-style-settings",
  "obsidian-icon-folder",
  "quickadd",
  "omnisearch",
  "editing-toolbar",
  "obsidian-outliner",
  "homepage",
  "tag-wrangler",
  "obsidian-linter",
  "highlightr-plugin",
  "better-word-count",
  "url-into-selection",
  "obsidian-auto-link-title",
  "folder-notes"
]
```

**`docs/.obsidian/templates.json`** (core Templates plugin config):
```json
{
  "folder": "07-Config/obsidian/templates"
}
```

Create the `docs/` directory and the folder scaffold within it (each subdirectory gets a `.gitkeep`):

```
docs/
├── 00-Inbox/
├── 01-Plans/            # Planning documents AND implementation plans (individual subdirs per plan)
├── 02-Notes/
├── 03-Reference/
├── 04-Tasks/
├── 05-Skills/           # Claude Code picks up skills from here
├── 06-Code/             # Commands, code snippets, reusable scripts
├── 07-Config/           # App configs organized by app name
│   └── obsidian/
│       └── templates/
├── 08-MCP/              # MCP server configs (optional, as needed)
├── 09-Output/           # File outputs, exports, generated artifacts
└── 10-Attachments/      # Images, video, PDF, any file attached to vault notes
```

**`07-Config/` growth policy:** Only `obsidian/` is created at scaffold time. Additional app subdirectories should be created here as the project adopts new tools. Examples:
- `07-Config/git/hooks/` — custom shareable git hooks (not `.git/hooks/`)
- `07-Config/docker/` — Dockerfiles, compose overrides, env templates
- `07-Config/github/` — workflow templates, PR/issue templates (draft/reference copies)
- `07-Config/vscode/` — workspace snippets, task templates, launch configs
- `07-Config/playwright/` — test fixtures, device profiles
- `07-Config/cloudflare/` — wrangler config variants, KV seed data
- `07-Config/shopify/` — theme settings snapshots, locale configs

When creating tool-specific configuration during any project task, place it under `docs/07-Config/{tool-name}/` rather than scattering configs elsewhere in the vault.

### Step 3: Claude Code Configuration

Create `.claude/` directory:

```
.claude/
└── settings.local.json
```

**`.claude/settings.local.json`** — start with minimal permissions, adapt to LANGUAGE.

Read the appropriate language reference file from `languages/{language}.md` in this skill's directory to get the permissions config. Available: `typescript.md`, `python.md`, `go.md`, `rust.md`.

If the user chose "Other" and no matching reference file exists, create sensible defaults by following the same format: language-appropriate CLI permissions, relevant documentation domains for WebFetch, and a conventional app directory structure. Offer to save the new config as a `languages/{language}.md` file for future use.

### Step 4: MCP Servers (Optional)

Only create MCP configuration if the project needs MCP servers (e.g., the user selected plugins that require them, or the delivery method benefits from browser automation).

If MCP is needed, create **`.mcp.json`** and store any MCP-related configs or documentation in `08-MCP/`:

```json
{
  "mcpServers": {
    "playwright": {
      "command": "npx",
      "args": ["@playwright/mcp@latest"]
    }
  }
}
```

If MCP is not needed, skip this step. The `08-MCP/` directory still exists in the scaffold for future use.

### Step 5: App Directory

Create `app/` with language-appropriate scaffolding. Read the app directory structure from the same language reference file used in Step 3 (`languages/{language}.md`).

### Step 6: CLAUDE.md

Write `CLAUDE.md` in project root. Use this template, filling in variables from questionnaire:

```markdown
# {PROJECT_NAME}

{DESCRIPTION}

## Goals

{GOALS}

## Delivery

**Type:** {DELIVERY_METHOD}
**Language:** {LANGUAGE}

## Setup

### Requirements

- {language-specific runtime} (version)
- Git
- Claude Code with plugins (see below)

### Required Plugins

| Plugin | Marketplace | Purpose |
|--------|------------|---------|
| **superpowers** | superpowers-marketplace | Skills framework, brainstorming, debugging workflows |
| **claude-mem** | thedotmack | Persistent cross-session memory |
| **mgrep** | Mixedbread-Grep | Semantic search replacement |
| **oat-design-system** | (project skill) | CSS design system reference |

{Include rows for each OPTIONAL_PLUGIN selected}

## Project Structure

```
{PROJECT_NAME}/
├── .claude/              # Claude Code config
│   └── settings.local.json
├── app/                  # Application code
├── docs/                 # Obsidian vault + project knowledge
│   ├── .obsidian/        # Obsidian vault config
│   ├── 00-Inbox/         # Quick capture
│   ├── 01-Plans/         # Plans (each in its own subdirectory)
│   ├── 02-Notes/         # Working notes
│   ├── 03-Reference/     # Reference material
│   ├── 04-Tasks/         # Task tracking
│   ├── 05-Skills/        # Claude Code skills (portable, picked up here)
│   ├── 06-Code/          # Commands, code snippets, reusable scripts
│   ├── 07-Config/        # App configs organized by app name
│   │   └── obsidian/
│   │       └── templates/
│   ├── 08-MCP/           # MCP server configs (optional)
│   ├── 09-Output/        # File outputs, exports, generated artifacts
│   └── 10-Attachments/   # Images, video, PDF, attached files
└── temp/                 # Scratch (gitignored)
```

## Conventions

- **Skills** live in `docs/05-Skills/` — Claude looks here for all project skills
- **Plans** go in `docs/01-Plans/` with each plan in its own subdirectory
- **Code snippets and commands** go in `docs/06-Code/` — Claude knows to look here
- **App configs** go in `docs/07-Config/{app-name}/` (e.g., `docs/07-Config/obsidian/templates/`)
- **MCP configs** go in `docs/08-MCP/` when needed (optional, not universal)
- **File outputs and exports** go in `docs/09-Output/`
- **Attachments** (images, video, PDF) for any vault note go in `docs/10-Attachments/`
- **Feature branches** use git worktrees in `.worktrees/` (gitignored)
- **Scratch data** goes in `temp/` (gitignored)

## GitNexus

After initial development, index with GitNexus for code intelligence:

```bash
npx gitnexus analyze
```

Then add the GitNexus section to this file (see gitnexus-cli skill).
```

### Step 7: MEMORY.md

Write `MEMORY.md` at the auto-memory path. First create the memory directory:

```bash
mkdir -p ~/.claude/projects/{project-path-hash}/memory/
```

The project path hash is derived from the working directory. Write:

```markdown
# {PROJECT_NAME} — Project Memory

## Overview

**{PROJECT_NAME}** — {DESCRIPTION}

**Delivery:** {DELIVERY_METHOD}
**Language:** {LANGUAGE}
**Goals:** {GOALS}
```

**IMPORTANT:** The MEMORY.md file goes in Claude's memory directory for this project (`~/.claude/projects/<path-hash>/memory/MEMORY.md`), NOT in the project root.

### Step 8: AGENTS.md

Write `AGENTS.md` in project root:

```markdown
# {PROJECT_NAME} — Agent Playbook

Guide for selecting the right subagent type for tasks in this project.

## Agent Types

### Explore
**When:** Understanding unfamiliar code, finding files, searching for patterns.
**Example:** "How does the auth flow work?", "Find all API endpoints"

### Plan
**When:** Designing implementation strategy before writing code.
**Example:** "Plan the database migration", "Design the API layer"

### general-purpose
**When:** Multi-step research tasks, complex searches across the codebase.
**Example:** "Research how other projects handle X", "Find and summarize all TODO comments"

### developer:fullstack-developer
**When:** End-to-end feature implementation spanning frontend, backend, database.
**Example:** "Build the user settings page with API and DB"

### developer:validation-gates
**When:** Running tests, validating implementations, ensuring quality.
**Example:** "Verify the auth changes work correctly"

### developer:documentation-manager
**When:** Updating docs after code changes.
**Example:** "Update README after the API refactor"

### superpowers:code-reviewer
**When:** Reviewing completed work against plans and standards.
**Example:** "Review step 3 implementation against our plan"

## Workflow Patterns

### New Feature
1. **brainstorming** — explore the idea
2. **Plan** agent — design the approach
3. **fullstack-developer** agent — implement
4. **validation-gates** agent — test
5. **code-reviewer** agent — review
6. **documentation-manager** agent — update docs

### Bug Fix
1. **systematic-debugging** skill — diagnose
2. **Explore** agent — understand affected code
3. Fix the bug
4. **validation-gates** agent — verify fix

### Refactor
1. **Explore** agent — map dependencies
2. **Plan** agent — design safe changes
3. Implement changes
4. **validation-gates** agent — run tests
5. **code-reviewer** agent — review
```

### Step 9: Initial Commit

Stage everything and create the initial commit:

```bash
git add -A
git commit -m "chore: scaffold project with Claude Code, Obsidian, and app structure"
```

### Step 10: GitNexus Index

Run the initial GitNexus index:

```bash
npx gitnexus analyze
```

---

## Phase 3: Summary

After all steps complete, print a summary:

```
## {PROJECT_NAME} scaffolded!

### Created
- Git repository initialized
- Obsidian vault in docs/ (21 community plugins configured)
- Claude Code config (.claude/)
- App directory (app/) with {LANGUAGE} scaffold
- Numbered project directories in docs/ (00-Inbox through 10-Attachments)
- docs/07-Config/obsidian/templates/ for Obsidian templates
- CLAUDE.md, AGENTS.md
- Memory initialized

### Core plugins (always enabled)
- superpowers (brainstorming, debugging, plans)
- claude-mem (persistent memory)
- mgrep (semantic search)
- gitnexus (code intelligence)
- oat-design-system (CSS architecture)

### Optional plugins enabled
{list OPTIONAL_PLUGINS}

### Next steps
1. Open this folder in VS Code
2. Open `docs/` as Obsidian vault (install community plugins on first launch)
3. Start building! Try `/brainstorming` to explore your first feature
```

## Notes

- The Obsidian community plugins JSON tells Obsidian which plugins to enable, but the user must install them on first vault open (Community Plugins > Browse)
- GitNexus indexing may take a moment on first run — this is normal
- The `.claude/` directory is gitignored by default; `settings.local.json` stays local
- MCP setup (`.mcp.json`) is only created when the project needs it — not by default
- oat-design-system is referenced as a skill to copy into the project's `docs/05-Skills/` directory if the user needs CSS architecture guidance
