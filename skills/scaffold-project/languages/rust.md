# Rust

## Claude Code Permissions

```json
{
  "permissions": {
    "allow": [
      "Bash(git *)",
      "Bash(cargo *)",
      "Bash(rustc *)",
      "WebSearch",
      "WebFetch(domain:docs.rs)",
      "WebFetch(domain:crates.io)"
    ]
  }
}
```

## App Directory Structure

```
app/
├── src/
│   └── main.rs     (empty main func)
├── Cargo.toml      (name, version "0.1.0", edition "2024")
└── README.md
```
