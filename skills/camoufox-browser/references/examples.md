# Camoufox code cookbook

Copy-paste-ready patterns for the situations Camoufox is built for. All examples use the sync API for readability; swap `from camoufox.sync_api import Camoufox` → `from camoufox.async_api import AsyncCamoufox` (and add `async`/`await`) for the async version.

## Stealth-defaults baseline

Reasonable starting point for most automation work:

```python
from camoufox.sync_api import Camoufox

with Camoufox(
    os=["windows", "macos", "linux"],     # rotate OS per session
    humanize=True,                         # human-like cursor
    locale="en-US",
) as browser:
    page = browser.new_page()
    page.goto("https://example.com")
```

## Residential proxy + geo-matched identity

```python
with Camoufox(
    geoip=True,                            # derive geo/timezone/locale from proxy IP
    humanize=True,
    proxy={
        "server": "http://res-proxy.example.com:8080",
        "username": "USER",
        "password": "PASS",
    },
) as browser:
    page = browser.new_page()
    page.goto("https://www.browserscan.net")
    print(page.title())
```

If you know the exit IP, pass it explicitly to avoid the auto-lookup roundtrip:

```python
Camoufox(geoip="203.0.113.45", proxy={...})
```

## Linux headless via Xvfb

`headless=True` is detectable; `headless="virtual"` runs in an Xvfb buffer (install xvfb first, see SKILL.md):

```python
with Camoufox(headless="virtual", humanize=True) as browser:
    page = browser.new_page()
    page.goto("https://example.com")
```

## Cloudflare Turnstile checkbox

`disable_coop=True` allows clicking inside the cross-origin iframe. A fixed `window=` is required because the click coordinates are coupled to layout:

```python
with Camoufox(disable_coop=True, window=(1280, 720), humanize=True) as browser:
    page = browser.new_page()
    page.goto("https://target.example/protected")
    page.wait_for_load_state("domcontentloaded")
    page.wait_for_load_state("networkidle")
    page.wait_for_timeout(5000)            # let Turnstile script settle
    page.mouse.click(210, 290)             # checkbox coordinates
    page.wait_for_url(lambda u: "challenge" not in u, timeout=30_000)
```

For sites with always-challenging Turnstile, pair with a captcha-solver service.

## DOM mutation via main-world eval

Default `page.evaluate(...)` is sandboxed and can read but not modify the DOM. Enable main-world eval and prefix with `mw:` to mutate:

```python
with Camoufox(main_world_eval=True) as browser:
    page = browser.new_page()
    page.goto("https://example.com")

    # READ — isolated, undetectable
    title = page.evaluate("document.querySelector('h1').innerText")

    # WRITE — main world, detectable by the page
    page.evaluate("mw:document.querySelector('h1').remove()")

    # Return JSON-serializable values from main world
    info = page.evaluate("mw:({ ua: navigator.userAgent, hw: navigator.hardwareConcurrency })")
```

Main-world execution **can be detected** by the target page. Use sparingly — only when DOM mutation is genuinely needed.

## Persistent profile (cookies, history survive)

```python
from camoufox.sync_api import Camoufox
from pathlib import Path

profile = Path.home() / ".cache" / "camoufox-profiles" / "scraper-1"
profile.mkdir(parents=True, exist_ok=True)

# NOTE: context manager yields a context, NOT a browser, when persistent_context=True
with Camoufox(persistent_context=True, user_data_dir=str(profile)) as context:
    page = context.new_page()
    page.goto("https://example.com")
    # cookies and localStorage persist to `profile/` between runs
```

## Loading custom addons (e.g., uBlock Origin override)

```python
# .xpi addons must be renamed to .zip and EXTRACTED — pass the extracted directory.
addons = [
    "/opt/firefox-addons/ublock-origin",
    "/opt/firefox-addons/decentraleyes",
]
with Camoufox(addons=addons) as browser:
    ...
```

To disable a default addon Camoufox bundles:

```python
from camoufox import DefaultAddons

with Camoufox(exclude_addons=[DefaultAddons.UBO]) as browser:
    ...
```

## Bandwidth-saving: block images

```python
with Camoufox(block_images=True, proxy={...}) as browser:
    page = browser.new_page()
    page.goto("https://heavy-site.example")
    # page.content() returns the HTML; images never fetched
```

## Remote Playwright server (cross-language clients)

Run the server (in Python):

```python
from camoufox.server import launch_server

launch_server(
    headless="virtual",
    geoip=True,
    humanize=True,
    proxy={"server": "...", "username": "...", "password": "..."},
    port=4567,
    ws_path="agent-1",
)
# Server logs: Websocket endpoint: ws://localhost:4567/agent-1
```

Connect from any Playwright client (Python, Node, .NET, Java) using the WS URL:

```python
# Python client (no camoufox import needed)
from playwright.sync_api import sync_playwright

with sync_playwright() as p:
    browser = p.firefox.connect("ws://localhost:4567/agent-1")
    page = browser.new_page()
    page.goto("https://example.com")
```

```javascript
// Node client
const { firefox } = require('playwright');
const browser = await firefox.connect('ws://localhost:4567/agent-1');
```

**Caveat:** The remote server uses one browser instance — fingerprints don't rotate across clients. For scale, run multiple servers and load-balance.

## Async API — full pattern

```python
import asyncio
from camoufox.async_api import AsyncCamoufox

async def fetch(url: str) -> str:
    async with AsyncCamoufox(
        os=["windows", "macos"],
        humanize=True,
        headless="virtual",
        geoip=True,
        proxy={...},
    ) as browser:
        page = await browser.new_page()
        await page.goto(url, timeout=30_000)
        return await page.content()

html = asyncio.run(fetch("https://example.com"))
```

## Diagnostic: dump fingerprint surface

Useful when verifying a new config:

```python
with Camoufox(os="macos", locale="en-GB") as browser:
    page = browser.new_page()
    page.goto("about:blank")
    fp = page.evaluate("""({
        ua: navigator.userAgent,
        platform: navigator.platform,
        languages: navigator.languages,
        timezone: Intl.DateTimeFormat().resolvedOptions().timeZone,
        screen: {w: screen.width, h: screen.height, dpr: devicePixelRatio},
        webgl: (() => {
            const c = document.createElement('canvas').getContext('webgl');
            const i = c && c.getExtension('WEBGL_debug_renderer_info');
            return i ? { vendor: c.getParameter(i.UNMASKED_VENDOR_WEBGL),
                         renderer: c.getParameter(i.UNMASKED_RENDERER_WEBGL) } : null;
        })(),
    })""")
    import json; print(json.dumps(fp, indent=2))
```

Use the [stealth reference](stealth.md) checklist plus a run through [browserscan.net](https://www.browserscan.net) to verify against your real target.
