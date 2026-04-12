# dotfiles with chezmoi

This repository is the `chezmoi` source state for managing 3 machines with shared defaults and role-based differences.

## Machine model
- `home`: mac mini m4 (macOS)
- `office`: mac book pro (macOS)
- `office`: cloud dev machine (Debian Linux)

## Design rules
- Keep most configs shared across all machines.
- Encode differences with `role` (`office` / `home`) and OS (`darwin` / `linux`).
- Never commit sensitive values.
- Put machine-specific values in local `~/.config/chezmoi/chezmoi.toml`.

## Bootstrap

One-liner for a fresh machine (requires `curl`):

```bash
curl -fsLS https://raw.githubusercontent.com/zgzhong/dotfiles/main/scripts/bootstrap.sh | bash
```

The script will:
1. Install `chezmoi` to `~/.local/bin`
2. Clone this repo
3. Ask you to select a machine role (`office` or `home`)
4. Generate `~/.config/chezmoi/chezmoi.toml`
5. Run `chezmoi apply` (installs Homebrew, dev tools, shell config, etc.)

For non-interactive use (CI, containers):

```bash
curl -fsLS https://raw.githubusercontent.com/zgzhong/dotfiles/main/scripts/bootstrap.sh | DOTFILES_ROLE=office bash
```

<details>
<summary>Manual bootstrap (alternative)</summary>

1. Install chezmoi on the target machine.
2. Initialize from this repo:
   ```bash
   chezmoi init --source /path/to/this/repo
   ```
3. Create local machine config from the example in source state:
   ```bash
   mkdir -p ~/.config/chezmoi
   cp "$(chezmoi source-path)/dot_config/chezmoi/chezmoi.toml.example" ~/.config/chezmoi/chezmoi.toml
   ```
4. Edit `~/.config/chezmoi/chezmoi.toml` and set at least:
   - `data.role = "office"` or `"home"`
5. Preview and apply:
   ```bash
   chezmoi diff
   chezmoi apply --dry-run
   chezmoi apply
   ```

</details>

## Developer tools installation
The old `~/.dotfiles/install.sh` tool installation is migrated to chezmoi scripts:
- `run_once_before_20-install-homebrew.sh.tmpl`: bootstrap Homebrew (macOS + Linuxbrew)
- `run_onchange_after_30-install-dev-tools.sh.tmpl`: install/update dev tools with Homebrew

Current migrated tool list:

Common (`brew --formula`, macOS + Linux):
- `git`
- `ripgrep`
- `eza`
- `bat`
- `zsh`
- `autojump`
- `antidote`
- `lazygit`
- `goenv`
- `pyenv`
- `jq`
- `htop`
- `zstd`
- `vim`
- `unar`

Common (`brew --cask`, macOS + Linux):
- `codex`

macOS only (`brew --cask`):
- `visual-studio-code`
- `iterm2`
- `orbstack`
- `trae`

## Migration from stow
Use incremental migration. Move one config family at a time.

Recommended order:
1. shell
2. editor / terminal / language tools

See:
- `docs/migration-from-stow.md`
- `docs/machines.md`
- `docs/troubleshooting.md`

## Integration test (Linux office via Docker)
Run end-to-end integration checks (real Homebrew bootstrap + tool install + rendered files):

```bash
tests/integration/run-linux-office.sh
```

Optional env vars:
- `IMAGE_TAG`: docker image tag (default: `dotfiles-it:linux-office`)
- `DOTFILES_SRC`: source directory mounted to `/workspace` in the container
- `CONTAINER_NAME`: docker container name (default: `dotfiles-it-linux-office`)
- `STATUS_FILE`: file inside the container used to store the e2e exit code (default: `/tmp/dotfiles-e2e.exitcode`)

The script keeps the latest test container running for debugging and removes any existing container with the same name before starting a new run. The script still exits with the real e2e result code. To inspect the environment after a run:

```bash
docker exec -it dotfiles-it-linux-office bash
```

If the e2e run has already installed Homebrew formulae, `zsh` is also available:

```bash
docker exec -it dotfiles-it-linux-office zsh
```

## Integration test (Cold-boot via Docker)

Run the cold-boot bootstrap test (bare container, no pre-installed chezmoi):

```bash
tests/integration/run-cold-boot.sh
```

Optional env vars:
- `IMAGE_TAG`: docker image tag (default: `dotfiles-it:cold-boot`)
- `DOTFILES_SRC`: source directory mounted to `/workspace` in the container
- `CONTAINER_NAME`: docker container name (default: `dotfiles-it-cold-boot`)
- `STATUS_FILE`: file inside the container used to store the e2e exit code (default: `/tmp/dotfiles-cold-boot.exitcode`)
