# Bundle format

Tarball is zstd-compressed (`zstd -3` by default). Layout when extracted to `<staging>/`:

```
<staging>/
├── manifest.json                       # validated by assets/manifest.schema.json
├── projects/
│   └── <slug>/
│       ├── tree/                       # bundle-whole-tree only
│       ├── dirty.patch                 # capture-state only
│       ├── stashes.json
│       ├── untracked.tar.gz
│       ├── worktrees.json
│       ├── remote-info.json            # strict-clean only
│       ├── CLAUDE.md                   # if present in source
│       ├── AGENTS.md                   # if present
│       ├── .mcp.json                   # if present
│       └── .claude/                    # if present
├── claude-subset/
│   ├── projects/<flat-slug>/memory/    # per-project memory
│   ├── skills/<name>/                  # referenced global skills
│   ├── plugins/marketplaces/<name>/    # referenced marketplaces
│   ├── settings.json                   # global settings
│   ├── CLAUDE.md                       # global CLAUDE.md
│   └── keybindings.json
├── secrets.tar.gz.enc                  # only if vault.present (openssl AES-256-CBC + PBKDF2)
└── skill-self/
    └── win2lin/                        # this skill, for unpacker to lay down
        ├── SKILL.md
        ├── references/
        ├── assets/
        └── tests/
```

## Naming conventions

- Bundle filename: `claude-migration-<host>-<yyyymmdd>.tar.zst`. Host is `COMPUTERNAME`. Date is UTC.
- Project slug: lowercase basename of source path. Collisions resolved by appending `-N`.
- Flat-slug for memory dirs: the existing Claude Code convention (forward slashes → dashes, prefix `-`). E.g. `C:\Users\tim\projects\hawker` → `-c-users-tim-projects-hawker`.

## Versioning

`manifest.schema_version` is currently `1`. Breaking changes bump to `2`; the unpacker MUST refuse a higher schema version than it knows about and direct the user to update the skill.
