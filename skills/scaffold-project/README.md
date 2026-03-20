# scaffold-project

Scaffold a new VS Code + Claude Code + Obsidian project from scratch.

**Usage:** `/scaffold-project`

## What it does

Runs an interactive questionnaire (project name, description, delivery method, language, goals, optional plugins) then automatically sets up:

- **Git repository** with smart `.gitignore`
- **Obsidian vault** in `docs/` with 21 community plugins configured
- **Claude Code config** (`.claude/settings.local.json` with language-appropriate permissions)
- **Language-appropriate app scaffold** in `app/` (TypeScript, Python, Go, or Rust)
- **Numbered project directories** under `docs/` for knowledge management
- **MCP server config** (optional, only when needed)
- **`CLAUDE.md`** and **`AGENTS.md`** in project root
- **Persistent memory** initialized for the project
- **GitNexus** initial index

## Resulting directory structure

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

## Key conventions in scaffolded projects

- **`docs/`** is the Obsidian vault root — open this folder in Obsidian
- **`docs/05-Skills/`** is the canonical location for all project skills
- **`docs/07-Config/`** grows organically — new tool configs go under `docs/07-Config/{tool-name}/`
- **MCP** is opt-in, not default — `.mcp.json` only created when needed
- **`app/`** contains all application code with language-specific scaffolding

## Supported languages

| Language | App scaffold includes |
|----------|----------------------|
| TypeScript | `src/`, `package.json`, `tsconfig.json` |
| Python | `src/{pkg}/`, `tests/`, `pyproject.toml` |
| Go | `cmd/`, `internal/`, `go.mod` |
| Rust | `src/main.rs`, `Cargo.toml` |
