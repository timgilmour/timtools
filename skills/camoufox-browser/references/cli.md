# `python -m camoufox` CLI reference

The CLI manages browser downloads, version channels, the remote server, and diagnostics. Invocation differs slightly per OS:

- **Windows:** `camoufox <cmd>`
- **macOS / Linux:** `python -m camoufox <cmd>` (or `python3 -m camoufox`)

## Commands

### `fetch`

Download the active version, or a specific version.

```bash
python -m camoufox fetch                              # latest in active channel
python -m camoufox fetch official/stable/135.0-beta.25  # specific version
```

Downloads ~1.2 GB to `~/.cache/camoufox/`. Idempotent — re-running with the same version is a no-op.

### `set`

Pick or pin a version channel. Use without args for an interactive selector.

```bash
python -m camoufox set                              # interactive
python -m camoufox set official/stable              # follow latest stable (default)
python -m camoufox set official/prerelease          # follow latest prerelease
python -m camoufox set official/stable/134.0.2-beta.20   # pin specific version
python -m camoufox set coryking/stable              # follow a different repo
```

After `set`, run `fetch` to download.

### `sync`

Pull the list of release assets from configured remote repositories. Useful after release cuts.

```bash
python -m camoufox sync
```

### `active`

Print the currently selected version/channel.

```bash
python -m camoufox active
# official/stable
```

### `list`

List installed (or all available) Camoufox versions.

```bash
python -m camoufox list           # installed only
python -m camoufox list all       # everything in synced repos
python -m camoufox list --path    # include install paths
```

### `path`

Print the install directory. Useful for scripting.

```bash
python -m camoufox path
# /home/<user>/.cache/camoufox
```

### `remove`

Delete downloaded data.

```bash
python -m camoufox remove                              # everything (prompts)
python -m camoufox remove -y                           # everything, no prompt
python -m camoufox remove official/stable/134.0.2-beta.20   # specific version
python -m camoufox remove --select                     # interactive picker
```

### `version`

Print package version, browser version, channel, geo DB info, install paths, and disk usage.

```bash
python -m camoufox version
```

Sample output:

```
Python Packages
  Camoufox                    v0.5.0
  Browserforge                v1.2.4
  Apify Fingerprints          v0.10.0
  Playwright                  v1.57.1.dev0+g732639b35
Browser
  Active                      official/stable/135.0.1-beta.24
  Current browser             v135.0.1-beta.24
  Installed                   Yes
  Latest in official/stable?  Yes
GeoIP
  Database                    MaxMind GeoLite2
Storage
  Install path                ~/.cache/camoufox
  Browser(s) directory size   1.2 GB
  GeoIP database size         40.7 MB
```

### `server`

Launch a remote Playwright WebSocket server. See [examples.md](examples.md) for client usage.

```bash
python -m camoufox server                # random port + ws_path
```

For configured launches (with proxy, geoip, etc.), use `camoufox.server.launch_server(...)` from Python instead — the CLI form has no kwargs.

### `test`

Open Camoufox with the Playwright Inspector for interactive debugging.

```bash
python -m camoufox test
python -m camoufox test https://example.com
```

### `gui`

Launch the Qt browser-manager UI (requires `pip install 'camoufox[gui]'`).

```bash
python -m camoufox gui
```
