#!/usr/bin/env python3
"""Verify the Camoufox install is complete and report any missing pieces.

Safe to run anywhere; reads state only, never modifies anything.
Exit code 0 = ready to use, 1 = one or more checks failed.
"""

from __future__ import annotations

import importlib.util
import os
import platform
import shutil
import subprocess
import sys
from pathlib import Path


GREEN = "\033[1;32m"
RED = "\033[1;31m"
YELLOW = "\033[1;33m"
DIM = "\033[2m"
RESET = "\033[0m"


def ok(msg: str) -> None:
    print(f"  {GREEN}✓{RESET} {msg}")


def fail(msg: str, hint: str = "") -> None:
    print(f"  {RED}✗{RESET} {msg}")
    if hint:
        print(f"    {DIM}→ {hint}{RESET}")


def warn(msg: str, hint: str = "") -> None:
    print(f"  {YELLOW}!{RESET} {msg}")
    if hint:
        print(f"    {DIM}→ {hint}{RESET}")


def check_python() -> bool:
    v = sys.version_info
    if v >= (3, 9):
        ok(f"Python {v.major}.{v.minor}.{v.micro}")
        return True
    fail(f"Python {v.major}.{v.minor} too old", "Camoufox requires Python 3.9+")
    return False


def check_camoufox_package() -> bool:
    spec = importlib.util.find_spec("camoufox")
    if spec is None:
        fail("camoufox package not installed", "pip install -U 'camoufox[geoip]'")
        return False
    try:
        import camoufox  # noqa: F401
    except Exception as exc:  # pragma: no cover - defensive
        fail(f"camoufox imports but errors: {exc}")
        return False
    ok("camoufox package importable")
    return True


def check_browserforge() -> bool:
    if importlib.util.find_spec("browserforge") is None:
        fail("browserforge missing", "Should install with camoufox; re-run pip install -U 'camoufox[geoip]'")
        return False
    ok("browserforge importable")
    return True


def check_geoip() -> None:
    # The [geoip] extra installs the `geoip2` package and a MaxMind DB on fetch.
    if importlib.util.find_spec("geoip2") is None:
        warn("geoip2 not installed", "geoip=True will not work. pip install -U 'camoufox[geoip]'")
        return
    ok("geoip2 importable")


def check_browser_downloaded() -> bool:
    try:
        result = subprocess.run(
            [sys.executable, "-m", "camoufox", "path"],
            capture_output=True,
            text=True,
            timeout=15,
        )
    except Exception as exc:
        fail(f"could not run 'python -m camoufox path': {exc}")
        return False
    if result.returncode != 0:
        fail("'python -m camoufox path' failed", result.stderr.strip().splitlines()[-1] if result.stderr else "")
        return False
    install_dir = Path(result.stdout.strip())
    if not install_dir.exists():
        fail(f"install dir {install_dir} does not exist", "Run: python -m camoufox fetch")
        return False
    # Look for a downloaded browser folder under the install dir.
    has_browser = any(
        any(p.glob("camoufox*") for p in install_dir.rglob("*") if p.is_dir())
        for _ in (None,)
    ) or any(install_dir.glob("**/camoufox*"))
    if not has_browser:
        fail(f"no browser binary under {install_dir}", "Run: python -m camoufox fetch")
        return False
    ok(f"browser data present at {install_dir}")
    return True


def check_xvfb_if_linux() -> None:
    if platform.system() != "Linux":
        return
    if shutil.which("Xvfb"):
        ok("Xvfb available (headless='virtual' will work)")
    else:
        warn("Xvfb not installed", "Needed for headless='virtual'. apt install xvfb (Debian/Ubuntu) or pacman -S xorg-server-xvfb (Arch)")


def check_linux_libs() -> None:
    if platform.system() != "Linux":
        return
    ldconfig = shutil.which("ldconfig")
    if not ldconfig:
        warn("ldconfig not on PATH — skipping system-lib check")
        return
    try:
        out = subprocess.run([ldconfig, "-p"], capture_output=True, text=True, timeout=5).stdout
    except Exception:
        return
    needed = {
        "libgtk-3.so": "libgtk-3-0 / gtk3",
        "libxcb.so": "libx11-xcb1 / libxcb",
        "libasound.so": "libasound2 / alsa-lib",
    }
    for sofile, pkg in needed.items():
        if sofile in out:
            ok(f"{sofile} present ({pkg})")
        else:
            fail(f"{sofile} missing", f"Install the package providing it: {pkg}")


def report_version_info() -> None:
    print(f"\n{DIM}Camoufox version info:{RESET}")
    try:
        result = subprocess.run(
            [sys.executable, "-m", "camoufox", "version"],
            capture_output=True,
            text=True,
            timeout=15,
        )
        print(result.stdout.rstrip() or result.stderr.rstrip())
    except Exception as exc:
        print(f"  (could not run camoufox version: {exc})")


def main() -> int:
    print("camoufox doctor — checking install state\n")
    print(f"Platform: {platform.system()} {platform.release()}")
    print(f"Python:   {sys.executable}\n")

    checks = []
    checks.append(check_python())
    if not check_camoufox_package():
        # No point checking further if the package itself is missing.
        return 1
    check_browserforge()
    check_geoip()
    checks.append(check_browser_downloaded())
    check_linux_libs()
    check_xvfb_if_linux()

    report_version_info()

    failed = sum(1 for c in checks if not c)
    print()
    if failed == 0:
        print(f"{GREEN}Ready to use.{RESET}")
        return 0
    print(f"{RED}{failed} required check(s) failed.{RESET} Address the hints above.")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
