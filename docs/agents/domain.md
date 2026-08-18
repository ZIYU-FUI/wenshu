# Domain docs (single-context)

wenshu uses **single-context** layout for its domain documentation.

## Files

- `CONTEXT.md` (repo root) — current domain glossary: the words and concepts every agent needs to share before working on the project. Read this first.
- `docs/adr/NNNN-<slug>.md` — one Architecture Decision Record per hard-to-reverse decision, in chronological order. Read these to understand *why* the codebase looks the way it does.

## Consumer rules

- New agent context: read `CONTEXT.md`, then skim the last 5 ADRs. Stop there unless the task forces deeper.
- New domain word in code / doc: add it to `CONTEXT.md` glossary section with one-line definition and ADR reference (if any).
- New hard-to-reverse decision: write an ADR (`docs/adr/NNNN-<slug>.md`) using the format in `docs/adr/0000-template.md`. Reference the ADR from `CONTEXT.md` so future readers find it.
- Soft / reversible decisions: do not write an ADR. Keep the change in the commit message.

## Update cadence

- `CONTEXT.md` — update whenever a domain word enters the codebase.
- `docs/adr/` — write on every hard-to-reverse decision. New ADR number = `max(existing) + 1`, zero-padded to 4 digits.
