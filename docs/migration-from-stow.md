# Migration guide: stow -> chezmoi

## Principles
- Migrate in small batches.
- Keep existing stow setup until each batch is verified.
- Convert machine differences to templates with `role` and `chezmoi.os`.

## Batch workflow
1. Select one family (for example shell).
2. Move files from stow package into this source state using chezmoi naming.
3. Replace hardcoded differences with template conditions.
4. Validate:
   ```bash
   chezmoi diff
   chezmoi apply --dry-run
   ```
5. Apply and smoke test on the current machine.
6. Repeat on other machines.

## Suggested sequence
1. Shell startup files (`.zshrc`, env files)
2. Editor / terminal tools
3. Language/runtime tool configs

## Definition of done for each batch
- `chezmoi diff` only shows intended changes.
- `chezmoi apply --dry-run` succeeds.
- Interactive shell and core tools behave as expected.
- No secret appears in git diff/history.
