# Ticket 03 — CONTEXT.md: update Liquid Glass slider scope

> Component of: v0.30-titlebar-liquidglass-follow-slider (= Q34 step 7 =
> domain-modeling commit).

## Scope (= this file only)

`CONTEXT.md`.

## Change

Find the row documenting the Liquid Glass opacity slider and update its
"affects" scope from "per-pane content + per-region chrome + divider" to
the corrected scope:

- **Old scope (v0.30 pre-ticket)**: "per-pane content + per-region
  tab bar + per-region status bar + divider".
- **New scope (post-ticket)**: "per-pane content + per-region tab bar +
  per-region status bar + bottom AppStatusbar (= EVERY wenshu UI
  surface EXCEPT the title bar; the title bar follows macOS System
  Settings)".

## Why this is the right fix

Q34 step 7 = "every change updates the domain glossary so future
sessions don't re-discover the same truth from scratch". The slider
scope is a domain rule (= "what does the wenshu Liquid Glass slider
control?") and the spec changed it (= previously the title bar was
implied; post-ticket the title bar is explicitly out of scope).

## Acceptance criteria

- [ ] CONTEXT.md row for the Liquid Glass slider reflects the corrected
  scope (= affects every wenshu UI except the title bar; title bar
  follows macOS).
- [ ] CJK references in the row follow the H-3 forward-fix protocol
  (= verbatim CJK moves to a code block if it quotes boss OOB).

## Out of scope

- Other CONTEXT.md rows (= this PR touches only the Liquid Glass slider
  row).