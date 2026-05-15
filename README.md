# dotfiles with chezmoi

This repository is the `chezmoi` source state for managing personal and work machines with shared defaults and role/OS-based differences.

## Machine model
- `home` + `darwin`: personal Mac mini M4 (macOS)
- `office` + `darwin`: work MacBook Pro (macOS)
- `office` + `linux`: cloud dev machine (Debian Linux)

See [`docs/machines.md`](docs/machines.md) for the role/OS model in detail.

## Design rules
- Keep most configs shared across all machines.
- Encode differences with `role` (`office` / `home`) and OS (`darwin` / `linux`).
- Never commit sensitive values.
- Put local private values in `~/.config/chezmoi/chezmoi.toml`.
- The only required local data field today is `data.role`.

## Bootstrap

One-liner for a fresh machine (requires `curl`):

```bash
curl -fsLS https://raw.githubusercontent.com/zgzhong/dotfiles/main/scripts/bootstrap.sh | bash
```

The script installs `chezmoi`, clones this repo, asks for a machine role, and runs `chezmoi apply`.

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
3. Copy `dot_config/chezmoi/chezmoi.toml.example` to `~/.config/chezmoi/chezmoi.toml` and edit it to set `data.role`.
4. Preview and apply:
   ```bash
   chezmoi diff
   chezmoi apply --dry-run
   chezmoi apply
   ```

</details>

## Developer tools installation

Homebrew formulae and casks are installed by chezmoi's `run_onchange_after_30-install-dev-tools.sh.tmpl`. The authoritative tool list lives in the `common_formulae`, `common_casks`, `macos_formulae`, and `macos_casks` arrays at the top of that script.

## Integration test (Linux office via Docker)
Run end-to-end integration checks (real Homebrew bootstrap + tool install + rendered files):

```bash
tests/integration/run-linux-office.sh
```

Optional env vars (image tag, mount source, container name, status file path) can be set; see the top of `tests/integration/run-linux-office.sh`.

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

Optional env vars (image tag, mount source, container name, status file path) can be set; see the top of `tests/integration/run-cold-boot.sh`.
