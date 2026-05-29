# Secrets policy

## What can go in the vault

- In-project `.env*` files (per opt-in)
- `~/.ssh/` (private keys + known_hosts)
- `~/.netrc`
- `~/.npmrc` (auth tokens)
- `~/.config/gh/hosts.yml`
- `~/.aws/credentials`, `~/.aws/config`
- GPG keyring (`~/.gnupg/`) — opt-in only
- Custom user-added paths (questionnaire prompt)

## What never goes in the vault

- Anything under `.git/` (history can leak inside diffs — the bundler refuses)
- Database files (`*.db`, `*.sqlite`)
- Cookies/jar files from browsers
- Files larger than 10 MB (warn; user can override per file)

## Boundary rules

- The LLM never reads or writes vault contents. Period.
- The bundler reads `.env*` (etc.) only because the user explicitly enabled the secrets category.
- The vault is encrypted with `openssl enc -aes-256-cbc -pbkdf2` using a passphrase the user supplies once via the prepare questionnaire. The passphrase is passed to openssl on stdin — never written to disk, never on the process command line, never logged.
- On the destination, the user runs the unlock one-liner themselves. The skill prints the command; it does not run it. openssl prompts for the passphrase interactively at that point.
- If the user wants extra paranoia, they can `--exclude-vault` entirely and copy secrets manually after the migration.

## Failure modes

- `openssl` is part of the base install on virtually every Linux distro, so the destination almost never needs to install anything for decryption. If it is somehow absent, the unpacker installs it via the distro package manager.
- Wrong passphrase: `openssl` exits with a "bad decrypt" error; the user retries.
- Lost passphrase: there is no recovery. User starts a fresh migration.
