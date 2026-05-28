# Camoufox stealth model — what it protects, what it doesn't

This file is what you read **before** building anti-detect logic, to understand what Camoufox actually defends against vs. what it doesn't, and where your code can defeat its protections.

## Project status (2026)

Per upstream docs as of 2026, Camoufox had a gap in maintenance and is under active development again. Performance may have degraded relative to peak; check the camoufox.com stealth page or recent issues for current effectiveness against specific targets.

## What Camoufox hides

### Automation library presence (strong)

Standard Playwright leaks itself onto every page via globals like `window.__playwright__binding__` and inline init scripts. Camoufox runs all Page Agent code in an **isolated scope** that the page cannot see — no `__playwright__`, no `navigator.webdriver`, no inline scripts visible to page JS. This is the single biggest difference from vanilla Playwright Firefox.

### Headless detection (partial)

`navigator.webdriver` is patched out, and Firefox headless detection via pointer type ([upstream #26](https://github.com/daijro/camoufox/issues/26)) is fixed. But: **`headless=True` is increasingly detectable** by sophisticated anti-bot via secondary signals (timing, GPU presence, audio context). Use `headless="virtual"` on Linux (Xvfb) for genuine display backed sessions, or run headful inside an Xvfb-backed container.

### Fingerprint surface (broad)

Spoofed at the engine level (not via JS overrides, which are themselves detectable):

- **Navigator** — userAgent, platform, oscpu, vendor, languages, plugins, hardwareConcurrency, deviceMemory, etc.
- **Screen** — width, height, availWidth, availHeight, colorDepth, pixelDepth
- **Window** — inner/outer dimensions, screenX/screenY
- **WebGL** — vendor, renderer, supported extensions, context attributes, shader precision formats
- **Fonts** — system font list matches the spoofed OS; letter spacing randomly offset to defeat metric-based fingerprinting
- **AudioContext** — sample rate, output latency, max channel count
- **Devices** — speaker / microphone / webcam counts
- **Voices** — speech synthesis voices and playback rates
- **Locale / timezone / geolocation** — coherent triple, optionally derived from proxy IP
- **WebRTC** — IP spoofed at the protocol level (not just JS), preventing WebRTC IP leaks
- **Battery API**
- **Network headers** — `Accept-Language` and `User-Agent` match the spoofed navigator

The fingerprints come from BrowserForge, sampled from real-world distributions, so values aren't just plausible — their joint distribution is plausible.

### Behavior (partial)

Human-like cursor motion (ported from `riflosnake/HumanCursor` to C++) — used when `humanize=True`. It improves over linear/teleport motion but is not perfect — modern anti-bot's behavioral analysis can still flag it with enough samples.

## What Camoufox does NOT defend against

### Captcha solvers themselves

Camoufox keeps you from being **flagged** as a bot. It does not solve captchas. Pair with a captcha-solving service if you need to handle reCAPTCHA / hCaptcha / Turnstile that always challenges.

### IP reputation

A perfect fingerprint on a datacenter IP still looks suspicious. Use **residential proxies** for serious work — Camoufox's geoip integration is built around this.

### Sophisticated behavioral analysis

Mouse movement, scroll cadence, click timing variance, focus/blur patterns, key-press dynamics — anti-bot vendors model these. Camoufox's `humanize=True` helps but does not fully model them.

### Your own code's leaks

The biggest source of "Camoufox didn't work" reports is the calling code defeating its protections:

- **Setting `window=(w,h)` in production.** Camoufox generates a screen-coherent window; fixing it adds a fingerprint signal.
- **Using `main_world_eval=True` for everything.** Main-world JS is visible to the page. Only use `mw:` for actual DOM mutation; default-isolated eval is invisible.
- **Inconsistent OS + locale + timezone + IP.** Manually overriding one of these without the others creates a mismatch worse than no spoofing — anti-bot looks for inconsistency, not just "wrong" values.
- **Same fingerprint across many sessions.** Camoufox rotates per launch, but if you launch once and run many sessions, you're back to one identity. For scale, rotate launches.
- **Datacenter IPs with residential-looking fingerprints.** The mismatch is itself a signal.
- **Calling `add_init_script(...)` with custom JS** — that JS lands in the main world and is visible.

### Remote Server mode caveat

`python -m camoufox server` launches **one browser instance** shared across all clients. Fingerprints don't rotate per client connection. For at-scale use, rotate the server itself (run multiple, load-balance) rather than relying on one shared server.

## Verification

Test sites that expose your fingerprint surface:

- [BrowserScan](https://www.browserscan.net) — comprehensive
- [Browserleaks](https://browserleaks.com) — per-feature deep tests
- [CreepJS](https://github.com/abrahamjuliot/creepjs) — research-grade detection

Run any of these inside a Camoufox session to see what the page can see.

## Practical hardening checklist

Before using Camoufox in production:

1. [ ] Using residential proxies (not datacenter)
2. [ ] `geoip=True` enabled (geo derived from proxy IP)
3. [ ] `humanize=True` enabled
4. [ ] `os` is a list (rotates per session) unless you specifically need one OS
5. [ ] No fixed `window=` size (let Camoufox pick)
6. [ ] No fingerprint overrides via `config=` unless you understand the consequences
7. [ ] `main_world_eval` only enabled when you actually need DOM mutation
8. [ ] Headless mode is `"virtual"` (Linux + Xvfb) or full headful, **not** `True`
9. [ ] One launch per logical session; rotate launches for scale
10. [ ] Verified against BrowserScan or similar before trusting against your real target
