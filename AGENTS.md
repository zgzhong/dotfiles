# AGENTS.md

## Development repo vs deployed source state

This checkout is the **development repo**. It is not what the machine runs.

There are two clones of `zgzhong/dotfiles` on a machine:

| | Path | Role |
|---|---|---|
| Development repo | this checkout (location varies per machine) | Where edits, commits, branches, and PRs happen. |
| Deployed source state | `~/.local/share/chezmoi` | What `chezmoi apply` reads. Tracks `main`, kept clean. |

`chezmoi` resolves its source directory to `~/.local/share/chezmoi`, never to this
checkout. Editing a template here changes nothing on the live machine.

### Change propagation

A change only reaches the live machine after all three steps:

1. Commit and merge into `main` (push to the remote).
2. The deployed clone pulls `main` (`chezmoi update` does pull + apply).
3. `chezmoi apply` runs against the deployed clone.

So "it's committed" does not mean "it's deployed", and "it works in my editor"
means nothing — the rendered file in `$HOME` comes from `main`, not from the
working tree.

### Detect and update a local deployment

At the start of work, determine whether the current machine has this repository
deployed. Treat it as deployed only when all of the following are true:

- `chezmoi` is installed.
- `chezmoi source-path` resolves to `~/.local/share/chezmoi`.
- That source path is a Git checkout whose `origin` is `zgzhong/dotfiles`.

This check is read-only. Record the result for the rest of the task; do not
initialize or apply dotfiles just because the machine is not deployed.

If the task's PR is merged into `main` and this machine was detected as deployed,
finish the task by running `chezmoi update`. This must happen only after the merge
is visible on the remote: `chezmoi update` pulls `main` into the deployed source
state and then applies it to the live machine. Confirm that it succeeds and that
the deployed source state is on the merged `main` revision. If the PR was not
merged, or this machine was not already deployed, do not apply anything.

### Rules

- Never run `chezmoi apply` with this checkout as the source (`chezmoi apply
  --source .`, or any command run with `CHEZMOI_SOURCE_DIR` pointed here). It
  would apply unreviewed work-in-progress to the live home directory.
- Never commit inside `~/.local/share/chezmoi`. It is a deployment artifact; any
  local commit there diverges from `main` and gets clobbered on the next update.
- Files in `$HOME` (`~/.zshrc`, `~/.gitconfig`, ...) are rendered output, not
  source. Do not edit them to make a change — edit the template here. If drift is
  found in a rendered file, sync it back into the template in this repo.
- Verify changes with the Docker integration tests
  (`tests/integration/run-linux-office.sh`, `tests/integration/run-cold-boot.sh`),
  not by applying to the live machine.
- Never use the live machine as a pre-merge test environment. A local deployment
  may be updated only after the PR has merged into `main`, as described above.
- `chezmoi diff` on the machine compares `$HOME` against the **deployed** clone at
  `main`. It will not show unmerged work from this checkout.
