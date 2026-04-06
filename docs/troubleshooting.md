# Troubleshooting

## Error: missing or invalid role
Symptom:
- apply fails with role validation error.

Fix:
1. Edit `~/.config/chezmoi/chezmoi.toml`.
2. Set:
   ```toml
   [data]
   role = "office" # or "home"
   ```

## brew not found during apply
Symptom:
- `run_onchange_after_30-install-dev-tools.sh.tmpl` fails with `brew not found`.

Fix:
1. Run `chezmoi apply` once to trigger `run_once_before_20-install-homebrew.sh.tmpl`.
2. Open a new `zsh` so the managed `~/.zshenv` can load `brew shellenv`.
3. Run `chezmoi apply` again.

## Linux bootstrap asks for sudo
Symptom:
- Homebrew bootstrap prompts for sudo password on Linux.

Why:
- `run_once_before_20-install-homebrew.sh.tmpl` installs Linuxbrew prerequisites with apt:
  - `build-essential`
  - `procps`
  - `curl`
  - `file`
  - `git`

## office + linux proxy behavior
Symptom:
- Network access to Homebrew resources fails on office Linux.

Behavior:
- During Homebrew bootstrap, the script exports these env vars (same as old `install.sh`):
  - `http_proxy=http://sys-proxy-rd-relay.byted.org:8118`
  - `https_proxy=http://sys-proxy-rd-relay.byted.org:8118`
  - `no_proxy=.byted.org`

## Check rendered data quickly
```bash
chezmoi data
```

## Check generated files without applying
```bash
chezmoi execute-template '{{ .role }} {{ .chezmoi.os }}'
chezmoi cat ~/.config/shell/env
```
