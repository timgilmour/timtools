#!/usr/bin/env python3
"""Minimal Camoufox smoke test.

Launches Camoufox, navigates to a known-stable test endpoint, prints UA + viewport,
and exits 0 on success / 1 on failure. Uses headless='virtual' on Linux when xvfb is
available, otherwise headless=True. On macOS/Windows uses headless=True.

Useful as a post-install confirmation and as a template for your own scripts.
"""

from __future__ import annotations

import platform
import shutil
import sys


def pick_headless_mode():
    if platform.system() == "Linux" and shutil.which("Xvfb"):
        return "virtual"
    return True


def main() -> int:
    try:
        from camoufox.sync_api import Camoufox
    except ImportError:
        print("ERROR: camoufox not installed. Run: pip install -U 'camoufox[geoip]'", file=sys.stderr)
        return 1

    headless = pick_headless_mode()
    print(f"Launching Camoufox (headless={headless!r})...")

    try:
        with Camoufox(headless=headless, humanize=True) as browser:
            page = browser.new_page()
            page.goto("https://httpbin.org/headers", timeout=30_000)
            ua = page.evaluate("navigator.userAgent")
            viewport = page.evaluate("({w: window.innerWidth, h: window.innerHeight})")
            print(f"  UA:       {ua}")
            print(f"  Viewport: {viewport['w']}x{viewport['h']}")
            print("OK")
            return 0
    except Exception as exc:
        print(f"FAIL: {type(exc).__name__}: {exc}", file=sys.stderr)
        print("Run scripts/doctor.py to diagnose.", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
