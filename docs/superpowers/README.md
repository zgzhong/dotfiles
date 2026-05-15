# superpowers — design snapshots

This directory holds **frozen** design and implementation records produced by the
`superpowers` workflow (one file per change cycle, dated in the filename).

## What lives here

- `specs/<date>-<topic>-design.md` — the design decision and rationale at the time
  the change was planned.
- `plans/<date>-<topic>.md` — the task-by-task implementation plan that was
  executed for that change.

## How to read these files

**These are not living documentation.** They describe how things were intended
to work *on the date in the filename*. The repository has continued to evolve
since then, so individual specs and plans may diverge from current code.

Examples of expected drift:
- Tool lists change (e.g. casks added/removed).
- Refactors move logic between files.
- Later specs supersede earlier ones for the same area.

## Source of truth for "what does this repo do today?"

In priority order:

1. The source itself (`*.tmpl`, `run_*.sh.tmpl`, `scripts/`).
2. [`README.md`](../../README.md) at the repo root.
3. [`docs/machines.md`](../machines.md) for the role/OS model.

If a spec contradicts the current source, **trust the source**. Treat the spec
as historical context for *why* a decision was made, not *what* the code looks
like now.

## Each file carries a Status header

Every spec and plan has a `> **Status:**` line near the top stating it is a
frozen snapshot. If you see that header, do not use the file as a checklist
against current state.
