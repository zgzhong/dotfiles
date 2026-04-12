# Cold Boot: One-Line Dotfiles Bootstrap

## Summary

Add a minimal cold-boot mechanism so a brand-new machine (macOS or Debian Linux)
can go from zero to a fully deployed dotfiles environment with a single command:

```bash
curl -fsLS https://raw.githubusercontent.com/zgzhong/dotfiles/main/scripts/bootstrap.sh | bash
```

The only prerequisite is `curl`.

## Architecture: Two-Layer Script Separation

Cold boot is split into two layers with distinct responsibilities:

| Layer | File | Shell | Responsibility |
|-------|------|-------|----------------|
| Remote bootstrap | `scripts/bootstrap.sh` | POSIX sh | Install chezmoi, clone repo |
| In-repo init | `scripts/init.sh` | bash | Interactive role selection, generate config, apply |

The remote script does the absolute minimum, then hands off to the in-repo
script which is version-controlled and testable.

### Flow

```
curl bootstrap.sh | bash
  │
  ├─ 1. Verify curl exists
  ├─ 2. Detect OS (darwin / linux)
  ├─ 3. Install chezmoi → ~/bin  (via get.chezmoi.io)
  ├─ 4. chezmoi init zgzhong/dotfiles --apply=false
  │     (clones repo to ~/.local/share/chezmoi)
  └─ 5. exec $(chezmoi source-path)/scripts/init.sh
              │
              ├─ 1. Interactive role selection (office / home)
              │     (skipped if DOTFILES_ROLE env var is set)
              ├─ 2. Generate ~/.config/chezmoi/chezmoi.toml
              │     (prompt before overwriting if file exists)
              ├─ 3. chezmoi apply
              │     (triggers run_once_before_* and run_onchange_after_* chain)
              └─ 4. Print completion summary
```

## scripts/bootstrap.sh — Remote Bootstrap

Pure POSIX sh, approximately 30-40 lines. Only dependency: `curl`.

### Behavior

1. **Pre-checks:**
   - Verify `curl` is available; exit with error if missing.
   - Check if chezmoi is already installed (`command -v chezmoi`); skip
     installation if present.

2. **Install chezmoi:**
   - `sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"`
   - Installs to `~/.local/bin` — no sudo required, consistent with XDG and zshenv PATH.
   - Add `~/.local/bin` to `PATH` for the current session.
   - Verify installation: `"$HOME/.local/bin/chezmoi" --version`.

3. **Clone repository:**
   - `chezmoi init zgzhong/dotfiles --apply=false`
   - Uses HTTPS (public repository), no authentication needed.
   - Repo lands at `~/.local/share/chezmoi` (chezmoi default).

4. **Hand off to init.sh:**
   - `exec "$(chezmoi source-path)/scripts/init.sh"`
   - Uses `exec` to replace the current shell process, avoiding stdin issues
     from the pipe context.

### Error handling

- `set -eu` at the top.
- Each critical step checks return value; failure exits immediately with a
  descriptive error message.

## scripts/init.sh — In-Repo Initialization

Bash script, approximately 60-80 lines.

### Interactive role selection

Presents a numbered menu:

```
Select your machine role:
  1) office
  2) home
Choice [1-2]:
```

- Implemented with `read` + `case`; no external dependencies.
- Invalid input loops until a valid choice is made.
- **Environment variable bypass:** If `DOTFILES_ROLE` is set, skip the
  interactive menu and use its value directly. This supports CI/container
  testing.
- **Non-interactive terminal detection:** If stdin is not a terminal (`! -t 0`)
  and `DOTFILES_ROLE` is not set, exit with an error explaining that
  interactive input is required.

### Generate chezmoi.toml

Creates `~/.config/chezmoi/chezmoi.toml`:

```toml
[data]
role = "<selected-role>"
```

- If the file already exists, prompt: `Config already exists. Overwrite? (y/N)`
  Default: do not overwrite (protects existing configuration).
- With `DOTFILES_ROLE` set (non-interactive), always overwrite without prompting.

### Execute chezmoi apply

- Run `chezmoi apply`.
- This triggers the full existing script chain:
  - `run_once_before_10-validate-data.sh` — validate role
  - `run_once_before_20-install-homebrew.sh` — install Homebrew
  - `run_once_before_25-install-rust.sh` — install Rust
  - `run_onchange_after_30-install-dev-tools.sh` — install dev tools
  - `run_onchange_after_35-setup-go-and-goproxy.sh` — Go + goproxy (office only)
  - `run_once_after_40-set-default-shell.sh` — set default shell to zsh

### Completion summary

On success, print:

```
dotfiles deployed (role=<role>)
Restart your shell or run: exec zsh
```

### Idempotency

The script can be run repeatedly:
- If chezmoi.toml exists and user chooses not to overwrite, skip config
  generation and proceed to apply.
- chezmoi apply is inherently idempotent.

## Changes to Existing Files

### .chezmoiignore — Add scripts/ exclusion

Since `.chezmoiroot` is `.` (repo root = source directory), the `scripts/`
directory would be deployed to `~/scripts/` by chezmoi. Add `scripts/` to
`.chezmoiignore` to prevent this.

### README.md — Update Bootstrap section

Replace the current 5-step manual bootstrap instructions with the one-liner.
Keep manual steps as a fallback in a collapsed `<details>` block.

## Testing Strategy

### Existing e2e tests — No changes

The existing `tests/integration/linux-office/` tests remain untouched. They
continue to test dotfiles deployment with pre-installed chezmoi.

### New cold-boot integration test

New directory: `tests/integration/cold-boot/`

```
tests/integration/cold-boot/
├── Dockerfile           # Debian 12, only curl + ca-certificates, NO chezmoi
├── run-e2e.sh          # Container-side: bootstrap → init → verify
└── run-cold-boot.sh    # Host-side: build image → run container → report
```

**Dockerfile:**
Based on the existing linux-office Dockerfile but without the chezmoi
installation step. Creates a non-root user with sudo access.

**Container-side test (`run-e2e.sh`):**

Since the code is not yet on GitHub main during local testing, the test adapts
the bootstrap flow for local execution:

1. Install chezmoi to `~/bin` using get.chezmoi.io (same as bootstrap.sh).
2. `chezmoi init --source /workspace --apply=false` (use mounted local code
   instead of GitHub clone).
3. Run `/workspace/scripts/init.sh` with `DOTFILES_ROLE=office` to skip
   interactive input.
4. Verify:
   - `~/bin/chezmoi` exists and is executable.
   - `~/.config/chezmoi/chezmoi.toml` contains `role = "office"`.
   - Key dotfiles exist: `.zshrc`, `.gitconfig`, `.zshenv`, `.vimrc`.
   - `chezmoi apply` exit code is 0.
5. Does NOT re-verify Homebrew/tool installation (that is the existing e2e's
   job). Focuses on verifying the cold-boot chain itself works.

**Host-side entry (`run-cold-boot.sh`):**
Follows the same container management pattern as `run-linux-office.sh`:
build image → start container with `/workspace:ro` mount → exec test →
read exit code → report result. Container is kept for debugging.

## Network Assumptions

- The user is responsible for ensuring network connectivity before running the
  bootstrap script. No proxy auto-configuration is performed by the bootstrap
  or init scripts.
- chezmoi's run_* scripts handle proxy setup for office+linux environments
  as before (via proxy-lib.sh.tmpl).

## Scope Exclusions

- macOS-specific pre-requisites (Xcode CLT, Rosetta) — out of scope; assumed
  to be handled separately.
- SSH key setup, GitHub authentication — not needed since repo will be public.
- Modifications to existing e2e tests.
- CI pipeline integration for cold-boot test.
