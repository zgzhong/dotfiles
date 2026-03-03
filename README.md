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
- `antigen`
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

Note:
- Unlike the previous `install.sh`, tool installation is unified on Homebrew for both macOS and Debian Linux.
- For `office + linux`, Homebrew bootstrap will temporarily export the same proxy used in the old `install.sh`.
- On Linux, Homebrew bootstrap first runs:
  - `sudo apt -y update`
  - `sudo apt install -y build-essential procps curl file git`

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
- `KEEP_CONTAINER=1`: keep container after failure for debugging
