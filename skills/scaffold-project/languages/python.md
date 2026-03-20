# Python

## Claude Code Permissions

```json
{
  "permissions": {
    "allow": [
      "Bash(git *)",
      "Bash(python *)",
      "Bash(pip *)",
      "Bash(uv *)",
      "WebSearch",
      "WebFetch(domain:docs.python.org)",
      "WebFetch(domain:pypi.org)"
    ]
  }
}
```

## App Directory Structure

```
app/
├── src/
│   └── {project_name_snake}/
│       └── __init__.py
├── tests/
│   └── __init__.py
├── pyproject.toml  (name, version, requires-python >= "3.11")
└── README.md
```
