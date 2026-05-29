# Distro cheat sheet (for the unpacker)

## Detection

```bash
. /etc/os-release   # provides ID, ID_LIKE, VERSION_ID
grep -qi microsoft /proc/version && IS_WSL=1
uname -m            # x86_64 | aarch64
```

## Package install one-liners

| Distro | Command |
|---|---|
| Ubuntu / Debian   | `sudo apt-get update -qq && sudo apt-get install -y zstd openssl rsync jq curl ca-certificates` |
| CachyOS / Arch family | `sudo pacman -Sy --noconfirm --needed zstd openssl rsync jq curl ca-certificates` |
| Other (manual)    | print the package list and abort |

## Node install (no sudo)

```bash
PROFILE=/dev/null bash -c "$(curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.0/install.sh)"
export NVM_DIR="$HOME/.nvm"; . "$NVM_DIR/nvm.sh"
nvm install --lts
```

## Claude Code install

```bash
npm i -g @anthropic-ai/claude-code
```

## WSL specifics

- `/proc/version` contains `microsoft`.
- `/mnt/c/`, `/mnt/d/` etc. are NTFS-mounted Windows drives — slow for many small files but fine for a single read of a tarball.
- `$USER` may not match the Windows username; do not assume identity carries over.
- WSL/CachyOS requires `wsl --import` of a community rootfs; the skill assumes it's already done.

## aarch64 specifics

- nvm picks the correct arch automatically.
- `npm i -g @anthropic-ai/claude-code` is universal.
- Any project that has aarch64-incompatible native deps will need rebuilds — that's user responsibility post-restore.
