# Machines and roles

## Role mapping
- `mac mini m4` -> role: `home`, os: `darwin`
- `mac book pro` -> role: `office`, os: `darwin`
- `cloud dev` -> role: `office`, os: `linux` (Debian)

## Local private data location
Machine-specific values must be stored in:
- `~/.config/chezmoi/chezmoi.toml`

## Minimum required data
```toml
[data]
role = "office" # or home
```
