# Go

## Claude Code Permissions

```json
{
  "permissions": {
    "allow": [
      "Bash(git *)",
      "Bash(go *)",
      "WebSearch",
      "WebFetch(domain:pkg.go.dev)"
    ]
  }
}
```

## App Directory Structure

```
app/
├── cmd/
│   └── main.go     (package main, empty main func)
├── internal/
├── go.mod          (module path based on PROJECT_NAME)
└── README.md
```
