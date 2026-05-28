# Camoufox() parameter reference

Full reference for the `Camoufox(...)` / `AsyncCamoufox(...)` constructor. All standard Playwright Firefox launch options (`proxy`, `slow_mo`, `args`, `env`, etc.) are also accepted and passed through.

## Contents

- [Device rotation](#device-rotation) — `os`, `fonts`, `screen`, `webgl_config`, `config`
- [Behavior](#behavior) — `humanize`, `headless`, `addons`, `exclude_addons`, `window`, `main_world_eval`, `enable_cache`, `persistent_context`
- [Location & language](#location--language) — `geoip`, `locale`
- [Toggles](#toggles) — `block_images`, `block_webrtc`, `block_webgl`, `disable_coop`
- [Passed through from Playwright](#passed-through-from-playwright) — `proxy`, `user_data_dir`, etc.

---

## Device rotation

### `os`

- **Type:** `Optional[Union[str, List[str]]]`
- Operating system for fingerprint generation. One of `"windows"`, `"macos"`, `"linux"`, or a list to randomly pick per session. Defaults to a list of all three.

```python
Camoufox(os="windows")
Camoufox(os=["windows", "macos", "linux"])   # rotate per session
```

### `fonts`

- **Type:** `Optional[List[str]]`
- Additional fonts to make available, on top of the default system fonts for the target `os`. Names must match system-installed font families.

```python
Camoufox(fonts=["Arial", "Helvetica", "Times New Roman"])
```

### `screen`

- **Type:** `Optional[browserforge.fingerprints.Screen]`
- Constrains the generated fingerprint's screen dimensions. The actual window may still be larger or smaller.

```python
from browserforge.fingerprints import Screen
Camoufox(screen=Screen(max_width=1920, max_height=1080))
```

### `webgl_config`

- **Type:** `Optional[Tuple[str, str]]`
- Force a specific WebGL `(vendor, renderer)` pair. Must be supported for the target `os` or it creates a detectable inconsistency.

```python
Camoufox(webgl_config=("Apple", "Apple M1, or similar"), os="macos")
```

### `config`

- **Type:** `Optional[Dict[str, Any]]`
- Low-level overrides for individual Camoufox config properties (the JSON dict the patched browser reads at launch). Use only for features the Python library doesn't yet expose; otherwise you risk creating mismatches that Camoufox would normally prevent.

```python
Camoufox(config={
    "webrtc:ipv4": "203.0.113.45",
    "webrtc:ipv6": "e791:d37a:88f6:48d1:2cad:2667:4582:1d6d",
})
```

Camoufox emits a warning if you set a property that the Python library would have managed automatically.

---

## Behavior

### `humanize`

- **Type:** `Optional[Union[bool, float]]`
- Enables human-like cursor motion. `True` uses defaults (~1.5s max move duration); a `float` sets the max duration in seconds.

```python
Camoufox(humanize=True)
Camoufox(humanize=2.0)
```

### `headless`

- **Type:** `Optional[Union[bool, Literal["virtual"]]]`
- `False` (default), `True`, or `"virtual"`. `"virtual"` uses Xvfb on Linux for a headless display buffer — less detectable than true headless. Requires `xvfb` installed.

```python
Camoufox(headless=True)
Camoufox(headless="virtual")     # Linux + Xvfb only
```

### `addons`

- **Type:** `Optional[List[str]]`
- List of paths to **extracted** Firefox addons. To load a `.xpi`, rename it to `.zip`, extract, and pass the extracted folder path.

```python
Camoufox(addons=["/opt/addons/ublock-origin", "/opt/addons/decentraleyes"])
```

### `exclude_addons`

- **Type:** `Optional[List[camoufox.DefaultAddons]]`
- Exclude addons Camoufox loads by default (uBlock Origin etc.).

```python
from camoufox import DefaultAddons
Camoufox(exclude_addons=[DefaultAddons.UBO])
```

### `window`

- **Type:** `Optional[Tuple[int, int]]`
- Force the window to `(width, height)` and center it on the generated screen. **Avoid in production** — Camoufox auto-generates a coherent size, and fixed sizes are themselves a fingerprint. Acceptable when click coordinates require a known window (e.g., Cloudflare Turnstile).

```python
Camoufox(window=(1280, 720))     # debugging / coordinate-dependent only
```

### `main_world_eval`

- **Type:** `Optional[bool]`
- Allow `page.evaluate("mw:...")` to run JS in the page's main world (otherwise eval is isolated and cannot mutate the DOM). See [stealth reference](stealth.md) — main-world execution is observable by the page.

```python
Camoufox(main_world_eval=True)
# then:
page.evaluate("mw:document.querySelector('h1').remove()")
```

### `enable_cache`

- **Type:** `Optional[bool]`
- Cache pages/requests across navigations. Disabled by default to save memory. **Disabling cache breaks `page.go_back()` / `page.go_forward()`.**

```python
Camoufox(enable_cache=True)
```

### `persistent_context`

- **Type:** `Optional[bool]`
- Use a persistent browser context (cookies, storage, history survive across runs). Requires `user_data_dir`. The context manager yields a **context** instead of a browser when this is `True`.

```python
with Camoufox(persistent_context=True, user_data_dir="/path/to/profile") as context:
    page = context.new_page()
```

---

## Location & language

### `geoip`

- **Type:** `Optional[Union[str, bool]]`
- `True` to auto-derive geo from the proxy (or this machine's IP if no proxy). A string IP forces a specific origin. Populates longitude/latitude/timezone/country/locale and spoofs the WebRTC IP. Requires `camoufox[geoip]`.

```python
Camoufox(geoip=True, proxy=...)
Camoufox(geoip="203.0.113.0", proxy=...)
```

### `locale`

- **Type:** `Optional[Union[str, List[str]]]`
- Locale(s) for the browser. List or comma-separated string; the first locale powers the Intl API. A bare two-letter region code (e.g., `"US"`) generates a language matching that region's distribution.

```python
Camoufox(locale="en-US")
Camoufox(locale="US")                            # distribution-weighted pick
Camoufox(locale=["en-US", "fr-FR", "de-DE"])     # multiple accepted
```

---

## Toggles

### `block_images`

- **Type:** `Optional[bool]` — block all image requests. Saves proxy bandwidth.

### `block_webrtc`

- **Type:** `Optional[bool]` — block WebRTC entirely. Stronger than spoofing but eliminates RTC entirely.

### `block_webgl`

- **Type:** `Optional[bool]` — block WebGL. Only for special cases — most modern fingerprints expect WebGL to be present.

### `disable_coop`

- **Type:** `Optional[bool]` — disable Cross-Origin-Opener-Policy. Required to click elements inside cross-origin iframes (e.g., Cloudflare Turnstile checkbox).

---

## Passed through from Playwright

All Playwright Firefox `launch()` / `launch_persistent_context()` kwargs are accepted unchanged. The most relevant:

- **`proxy`** — `{"server": "http://host:port", "username": "...", "password": "..."}`. Combine with `geoip=True` for geo-matched identity.
- **`user_data_dir`** — required for `persistent_context=True`.
- **`slow_mo`** — slow operations by N ms for debugging.
- **`args`** — extra Firefox CLI args.
- **`env`** — environment for the browser subprocess.
- **`timeout`** — launch timeout in ms.

For the complete set, see the [Playwright Python docs](https://playwright.dev/python/docs/api/class-browsertype#browser-type-launch).
