#!/usr/bin/env bash
# Install Camoufox: system deps + pip package + browser download.
# Idempotent — safe to re-run. Detects Debian/Ubuntu vs Arch; warns on others.

set -euo pipefail

log()  { printf '\033[1;34m[install]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[warn]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[fail]\033[0m %s\n' "$*" >&2; exit 1; }

OS="$(uname -s)"

install_linux_deps() {
    if [ -r /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release
    else
        warn "/etc/os-release missing; skipping system-dep install (you may need to install GTK/X11/ALSA libs manually)"
        return
    fi

    case "${ID:-}${ID_LIKE:-}" in
        *debian*|*ubuntu*)
            log "Detected Debian/Ubuntu — installing libgtk-3-0 libx11-xcb1 libasound2 (+ xvfb for virtual headless)"
            sudo apt-get update -qq
            sudo apt-get install -y libgtk-3-0 libx11-xcb1 libasound2 xvfb
            ;;
        *arch*|*manjaro*)
            log "Detected Arch — installing gtk3 libx11 libxcb cairo libasound alsa-lib xorg-server-xvfb"
            sudo pacman -S --needed --noconfirm gtk3 libx11 libxcb cairo libasound alsa-lib xorg-server-xvfb
            ;;
        *fedora*|*rhel*|*centos*)
            log "Detected RHEL-family — installing gtk3 libX11-xcb alsa-lib xorg-x11-server-Xvfb"
            sudo dnf install -y gtk3 libX11-xcb alsa-lib xorg-x11-server-Xvfb
            ;;
        *)
            warn "Unrecognized distro '${ID:-?}'. You will need to install GTK 3, libx11-xcb, libasound, and xvfb manually."
            ;;
    esac
}

case "$OS" in
    Linux)  install_linux_deps ;;
    Darwin) log "macOS detected — no system deps needed beyond Python" ;;
    *)      warn "Unsupported OS '$OS' — proceeding with pip/fetch only" ;;
esac

# Pick the python executable to use
PY="${PYTHON:-python3}"
command -v "$PY" >/dev/null 2>&1 || die "$PY not found on PATH. Install Python 3.9+ first."

log "Installing camoufox[geoip] via $PY -m pip"
"$PY" -m pip install --upgrade "camoufox[geoip]"

log "Downloading patched Firefox build (~1.2 GB, one-time) via 'python -m camoufox fetch'"
"$PY" -m camoufox fetch

log "Camoufox install complete."
log "Quick verify:"
"$PY" -m camoufox version || true
log "Run scripts/doctor.py for a full readiness check."
