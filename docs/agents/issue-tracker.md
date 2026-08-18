# Issue tracker

wenshu uses **local markdown** as its issue tracker.

## Location

Issues live as files under `.scratch/<feature>/issues/`, one file per issue. Naming convention: `<NNN>-<slug>.md` (zero-padded number + kebab-case slug). Example: `.scratch/2026-08-18-skeleton/issues/001-fix-6-zone-layout.md`.

## Workflow

The `to-tickets` skill splits a spec into one issue per file. The `implement` skill claims an issue by reading the file, the `triage` skill moves external issues through the five canonical roles, and `grill-with-docs` writes the result to a new ADR under `docs/adr/`.

## Index

`.scratch/<feature>/issues/_index.md` lists every issue in the feature, with current state and `blocking edges`. A new ticket's `blocked-by` field references other ticket numbers in the same feature; any ticket whose blockers are all `done` becomes `ready` automatically.

## State

- `new` — written, no review
- `needs-triage` — first-pass review needed (external / unclear)
- `ready` — reviewed, ready for `implement`
- `in-progress` — claimed by an agent
- `review` — implementation done, awaiting code review
- `done` — closed (rejected / wontfix / merged)
- `blocked` — human input needed (with a `kanban_block` reason in the comment)
