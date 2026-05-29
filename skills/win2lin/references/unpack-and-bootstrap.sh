#!/usr/bin/env bash
# win2lin destination-side unpacker.
# Usage:
#   ./unpack-and-bootstrap.sh <bundle.tar.zst>
#   ./unpack-and-bootstrap.sh --from-mnt /mnt/c/Users/<u>/Desktop/<bundle>.tar.zst
#   ./unpack-and-bootstrap.sh --detect
#   ./unpack-and-bootstrap.sh --continue-from <step>
set -euo pipefail

# ---------------------------------------------------------------------------
# Detection
# ---------------------------------------------------------------------------

detect_env() {
  local distro="other" pkg_mgr="other" is_wsl=0 arch
  arch="$(uname -m)"
  if [[ -r /etc/os-release ]]; then
    # shellcheck source=/dev/null
    . /etc/os-release
    case "${ID:-}" in
      ubuntu)               distro="ubuntu";   pkg_mgr="apt" ;;
      debian)               distro="debian";   pkg_mgr="apt" ;;
      arch|cachyos|endeavouros|manjaro) distro="${ID}"; pkg_mgr="pacman" ;;
      *)
        case "${ID_LIKE:-}" in
          *debian*) distro="$ID"; pkg_mgr="apt" ;;
          *arch*)   distro="$ID"; pkg_mgr="pacman" ;;
        esac
        ;;
    esac
  fi
  if grep -qi microsoft /proc/version 2>/dev/null; then is_wsl=1; fi
  printf 'DISTRO=%s\nPKG_MGR=%s\nIS_WSL=%d\nARCH=%s\n' "$distro" "$pkg_mgr" "$is_wsl" "$arch"
}

ensure_packages() {
  local pkgs=("$@")
  case "$PKG_MGR" in
    apt)
      sudo apt-get update -qq
      sudo apt-get install -y "${pkgs[@]}"
      ;;
    pacman)
      sudo pacman -Sy --noconfirm --needed "${pkgs[@]}"
      ;;
    *)
      printf 'PKG_MGR=other: install manually: %s\n' "${pkgs[*]}" >&2
      exit 3
      ;;
  esac
}

ensure_node_and_claude() {
  if ! command -v node >/dev/null; then
    export NVM_DIR="$HOME/.nvm"
    [[ -d "$NVM_DIR" ]] || PROFILE=/dev/null bash -c \
      "$(curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.0/install.sh)"
    # shellcheck source=/dev/null
    . "$NVM_DIR/nvm.sh"
    nvm install --lts
  fi
  if ! command -v claude >/dev/null; then
    npm i -g @anthropic-ai/claude-code
  fi
}

# ---------------------------------------------------------------------------
# Main dispatch
# ---------------------------------------------------------------------------

if [[ "${1:-}" == "--detect" ]]; then
  detect_env
  exit 0
fi

FROM_MNT=""
CONTINUE_FROM=""
BUNDLE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --from-mnt) FROM_MNT="$2"; shift 2 ;;
    --continue-from) CONTINUE_FROM="$2"; shift 2 ;;
    --detect) detect_env; exit 0 ;;
    -h|--help) sed -n '1,8p' "$0"; exit 0 ;;
    *) BUNDLE="$1"; shift ;;
  esac
done

if [[ -n "$FROM_MNT" ]]; then BUNDLE="$FROM_MNT"; fi
if [[ -z "${BUNDLE:-}" ]]; then
  echo "usage: $0 <bundle.tar.zst>" >&2
  exit 2
fi
if [[ ! -f "$BUNDLE" ]]; then
  echo "bundle not found: $BUNDLE" >&2
  exit 2
fi

eval "$(detect_env)"
echo "[win2lin] detected: DISTRO=$DISTRO PKG_MGR=$PKG_MGR IS_WSL=$IS_WSL ARCH=$ARCH"

# Step 1: install base tools
if [[ -z "$CONTINUE_FROM" || "$CONTINUE_FROM" == "tools" ]]; then
  case "$PKG_MGR" in
    apt)    ensure_packages zstd openssl rsync jq curl ca-certificates ;;
    pacman) ensure_packages zstd openssl rsync jq curl ca-certificates ;;
    *)      echo "Install zstd/openssl/rsync/jq/curl manually for $DISTRO" >&2 ;;
  esac
fi

# Step 2: Node + Claude Code
if [[ -z "$CONTINUE_FROM" || "$CONTINUE_FROM" == "node" || "$CONTINUE_FROM" == "tools" ]]; then
  ensure_node_and_claude
fi

# Step 3: extract bundle
STAGING="${HOME}/.claude/win2lin-staging/$(basename "${BUNDLE%.tar.zst}")"
if [[ -z "$CONTINUE_FROM" || "$CONTINUE_FROM" == "extract" || "$CONTINUE_FROM" == "node" || "$CONTINUE_FROM" == "tools" ]]; then
  mkdir -p "$STAGING"
  zstd -d -c "$BUNDLE" | tar -x -C "$STAGING"
fi

# Step 4: lay skill into ~/.claude/skills/win2lin
if [[ -d "$STAGING/skill-self/win2lin" ]]; then
  mkdir -p "$HOME/.claude/skills"
  rsync -a --delete "$STAGING/skill-self/win2lin/" "$HOME/.claude/skills/win2lin/"
fi

# Step 5: arch mismatch warning
SRC_ARCH="$(jq -r '.source.arch' "$STAGING/manifest.json" 2>/dev/null || echo unknown)"
if [[ "$SRC_ARCH" != "unknown" && "$SRC_ARCH" != "$ARCH" ]]; then
  printf '\n[WARN] source arch %s != destination arch %s. Reinstalling toolchains will pick correct arch automatically.\n\n' "$SRC_ARCH" "$ARCH"
fi

cat <<EOF

✓ Bootstrap complete.
  Distro:  ${DISTRO} (${PKG_MGR})
  WSL:     $([ "$IS_WSL" -eq 1 ] && echo yes || echo no)
  Arch:    ${ARCH}
  Staged:  ${STAGING}
  Skill:   ~/.claude/skills/win2lin/

  Next: run \`claude\` and tell it to ingest the win2lin bundle at:
        ${STAGING}

EOF
