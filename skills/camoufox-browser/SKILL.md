---
name: camoufox-browser
description: |
  Install and use Camoufox — a custom anti-detect Firefox build for browser automation with
  built-in fingerprint spoofing (BrowserForge), human-like cursor movement, geo/locale
  matching from proxy IP, virtual display for Linux headless, and full Playwright API
  compatibility. Use when the user asks to: install camoufox; scrape with anti-bot evasion;
  run a stealth or anti-detect browser; bypass Cloudflare Turnstile or similar challenges;
  set up Playwright with fingerprint rotation; configure residential proxies with geo-matched
  identity; or mentions "camoufox", "browserforge", "stealth browser", "anti-detect", or
  Playwright + bot detection bypass. Includes installer script, install-doctor verifier,
  smoke test, full Camoufox() parameter reference, CLI command reference, stealth model
  documentation, and code cookbook.
---

# camoufox-browser

Camoufox is a custom Firefox build patched for browser automation evasion. It is fully Playwright-compatible: any Playwright Firefox code works by swapping the launcher for `Camoufox(...)` (sync) or `AsyncCamoufox(...)` (async). On top of Playwright, Camoufox auto-generates a realistic fingerprint (OS, fonts, WebGL, screen, navigator, headers) using BrowserForge, can derive geo/locale from the proxy IP, runs human-like cursor motion in C++, and provides a virtual-display headless mode for Linux.

## Install

The one-shot installer handles system deps, the pip package, and the browser download (~1.2 GB on first run):

```bash
bash scripts/install.sh
```

Manual steps if you prefer:

```bash
# Linux system deps (Debian/Ubuntu) — REQUIRED, omitting causes cryptic launch errors
sudo apt install -y libgtk-3-0 libx11-xcb1 libasound2

# Optional but recommended on Linux servers: Xvfb for headless="virtual"
sudo apt install -y xvfb

# Python package + GeoIP dataset (the [geoip] extra is needed for geoip=True)
pip install -U "camoufox[geoip]"

# Download the patched Firefox build (~1.2 GB, one-time)
python -m camoufox fetch
```

Verify the install:

```bash
python scripts/doctor.py
```

## Hello world

Sync API:

```python
from camoufox.sync_api import Camoufox

with Camoufox() as browser:
    page = browser.new_page()
    page.goto("https://example.com")
    print(page.title())
```

Async API:

```python
import asyncio
from camoufox.async_api import AsyncCamoufox

async def main():
    async with AsyncCamoufox() as browser:
        page = await browser.new_page()
        await page.goto("https://example.com")
        print(await page.title())

asyncio.run(main())
```

Any Playwright `page.*` / `context.*` method works exactly as in regular Playwright.

## Common patterns

### Stealth defaults (recommended starting point)

```python
with Camoufox(
    os=["windows", "macos", "linux"],   # randomly pick an OS per session
    humanize=True,                       # human-like cursor motion (max ~1.5s/move)
    locale="en-US",
) as browser:
    ...
```

Camoufox auto-generates a coherent fingerprint matching the chosen OS. **Do not set `window=(w,h)`** in production — fixed window sizes are themselves a fingerprint signal.

### Proxy with geo/locale matching

```python
with Camoufox(
    geoip=True,                          # derive geo/timezone/locale from proxy IP
    proxy={
        "server": "http://proxy.example.com:8080",
        "username": "...",
        "password": "...",
    },
) as browser:
    page = browser.new_page()
    page.goto("https://www.browserscan.net")
```

`geoip=True` requires the `[geoip]` pip extra. **Use residential proxies** — datacenter IPs are flagged independently of fingerprint quality.

### Linux headless via virtual display

`headless=True` is increasingly detectable by modern anti-bot. On Linux, use Xvfb:

```python
with Camoufox(headless="virtual") as browser:
    ...
```

Requires `xvfb` (the installer handles this on Debian/Arch).

### Cloudflare Turnstile

```python
with Camoufox(disable_coop=True, window=(1280, 720)) as browser:
    page = browser.new_page()
    page.goto("https://target.example/protected")
    page.wait_for_load_state("domcontentloaded")
    page.wait_for_load_state("networkidle")
    page.wait_for_timeout(5000)
    page.mouse.click(210, 290)   # click the Turnstile checkbox
```

`disable_coop=True` is what allows clicking inside the cross-origin Turnstile iframe. The fixed `window=` is acceptable here because click coordinates depend on it.

### Modifying the DOM (main world eval)

By default, all `page.evaluate(...)` JavaScript runs in an **isolated world** invisible to the page — meaning you can **read** the DOM but **cannot mutate** it. To mutate, opt into main-world execution and prefix the script with `mw:`:

```python
with Camoufox(main_world_eval=True) as browser:
    page = browser.new_page()
    page.goto("https://example.com")

    # Read (isolated, undetectable)
    title = page.evaluate("document.querySelector('h1').innerText")

    # Write (main world, prefix required, detectable by the page)
    page.evaluate("mw:document.querySelector('h1').remove()")
```

Main-world execution is detectable — only use when DOM mutation is required.

### Persistent profiles

```python
with Camoufox(
    persistent_context=True,
    user_data_dir="/path/to/profile",    # required when persistent_context=True
) as context:
    page = context.new_page()
    ...
```

Note that with `persistent_context=True`, the context manager yields the **browser context** (not a browser), matching Playwright's `launch_persistent_context` semantics.

## Smoke test

```bash
python scripts/smoke.py
```

Launches Camoufox, hits a known test URL, prints UA + viewport, exits 0 on success.

## Deeper references

- **All `Camoufox(...)` parameters** (~30 options, types, examples) — see [references/api.md](references/api.md)
- **CLI commands** (`fetch`, `set`, `list`, `server`, `version`, etc.) — see [references/cli.md](references/cli.md)
- **What stealth actually protects** (and what it doesn't) — see [references/stealth.md](references/stealth.md)
- **Code cookbook** (geoip+proxy, addons, persistent context, remote server, more) — see [references/examples.md](references/examples.md)

## Critical pitfalls

- **Don't set fixed `window=(w,h)`** in production. Camoufox generates a coherent screen-appropriate size; hardcoded values defeat that.
- **`headless=True` is increasingly detectable.** Prefer `headless="virtual"` on Linux, or run headful inside an Xvfb-backed CI.
- **`main_world_eval=True` + `mw:` prefix is the only way to mutate the DOM**, but main-world JS is visible to the page — minimize use.
- **GeoIP needs the `[geoip]` pip extra** AND a residential proxy. Datacenter IPs negate the benefit.
- **Remote server mode uses one browser instance** — fingerprints don't rotate across clients. For scale, rotate the server itself.
- **Linux deps `libgtk-3-0 libx11-xcb1 libasound2`** are easy to omit and produce cryptic launch errors. `scripts/install.sh` handles this.
- **First `python -m camoufox fetch` downloads ~1.2 GB** to `~/.cache/camoufox/`. Plan disk and bandwidth accordingly.
- **`persistent_context=True` yields a context, not a browser** — adjust calling code to match Playwright's persistent-context shape.

## When Camoufox isn't the right tool

- **Need Chrome specifically** (e.g., for CDP-only features) — Camoufox is Firefox-only.
- **Targeting only sites with no anti-bot** — vanilla Playwright is lighter and faster.
- **Need cross-language clients** — use Remote Server mode (see [references/examples.md](references/examples.md)).
- **Bot/captcha solving needed** — Camoufox helps you stay un-flagged but doesn't solve captchas itself.
