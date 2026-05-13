# Machines and roles

## Role mapping
- `home` + `darwin` -> personal Mac mini M4 (macOS)
- `office` + `darwin` -> work MacBook Pro (macOS)
- `office` + `linux` -> cloud dev machine (Debian)

## Local private data location
Machine-specific private values must be stored in:
- `~/.config/chezmoi/chezmoi.toml`

## Minimum required data
```toml
[data]
role = "office" # or "home"
```

## Notes
- `machine_name` is not used as a configuration dimension.
- Use `role = "home"` for the personal Mac mini M4.
- Use `role = "office"` for work macOS and office Linux machines.
