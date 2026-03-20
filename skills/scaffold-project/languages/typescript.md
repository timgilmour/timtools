# TypeScript / JavaScript

## Claude Code Permissions

```json
{
  "permissions": {
    "allow": [
      "Bash(git *)",
      "Bash(npm *)",
      "Bash(npx *)",
      "Bash(node *)",
      "WebSearch",
      "WebFetch(domain:docs.npmjs.com)",
      "WebFetch(domain:developer.mozilla.org)"
    ]
  }
}
```

## App Directory Structure

```
app/
├── src/
├── package.json    (name: PROJECT_NAME, version: "0.1.0", type: "module")
├── tsconfig.json   (strict, ESNext module, NodeNext resolution)
└── README.md       (project name + description)
```
