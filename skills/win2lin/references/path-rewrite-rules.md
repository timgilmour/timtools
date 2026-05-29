# Path rewrite rules

Apply these rules in order during `ingest` mode. Each rule is `(scope, pattern, replacement)`.

## Structured rewrites (apply silently in `auto` mode)

| Scope (file) | JSONPath / field | Pattern → Replacement |
|---|---|---|
| `~/.claude.json` | `projects.<key>` (the key itself) | `C:\Users\<u>\` → `/home/<u>/` |
| `~/.claude.json` | `projects.<key>` | `D:\Work\` → `/home/<u>/work/` (prompt user for non-default drive mappings) |
| `~/.claude/settings.json` | `additionalDirectories[]`, `permissions.allow[]` containing paths | same as above |
| `<project>/.claude/settings.json` | `additionalDirectories[]`, `permissions.allow[]` | same |
| `<project>/.mcp.json` | `mcpServers.<name>.args[]` if value starts with drive letter | same |
| `<project>/.mcp.json` | `mcpServers.<name>.cwd` | same |

## Free-text scan (report only, never auto-rewrite)

| Scope (file glob) | Action |
|---|---|
| `<project>/CLAUDE.md`, `<project>/AGENTS.md`, `<project>/GEMINI.md` | grep for `[A-Z]:\\` or `/[dD]/`; emit to REVIEW.md |
| `<project>/README.md`, `<project>/docs/**/*.md` | same |

Rationale: structured config has a deterministic schema; free-text markdown may legitimately reference Windows paths in code examples, screenshots, or historical context. Let the user judge.

## Drive letter conventions (defaults; user can override)

- `C:\Users\<u>\` → `/home/<u>/`
- `D:\Work\`     → `/home/<u>/work/`
- `D:\` (root)   → prompt
- `E:\`, `F:\`, etc. → prompt
- `/c/...` (Git Bash style on Windows) → `/home/<u>/...` if begins with `/c/Users/<u>/`
- `\\?\C:\...` (UNC) → strip UNC prefix, treat as `C:\...`
