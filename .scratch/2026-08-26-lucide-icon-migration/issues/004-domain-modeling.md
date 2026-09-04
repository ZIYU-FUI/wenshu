# 004 — domain-modeling: WenshuIcon / LucideIcon / SPMDependency in CONTEXT.md

First line = fact. Last line = fact.

## goal

Add the new domain words introduced by the Lucide migration to `CONTEXT.md` (= the project domain glossary). Domain-modeling is the final step that closes the loop on this feature.

## deliverables

1. `CONTEXT.md` (= path under `docs/agents/` or project root; verify by `find . -maxdepth 3 -name CONTEXT.md -not -path '*/.scratch/*'`) gets three new 1-line definitions:
   - `WenshuIcon` — Single-source-of-truth enum that maps wenshu's intent (= e.g. `.book`, `.keyFill`) to a Lucide icon name. All UI rendering goes through `WenshuIcon.image(...)`. Future icon swaps only touch this enum.
   - `LucideIcon` — Underlying third-party icon set (= MIT, 1500+ outline glyphs, native SwiftUI `Shape` rendering via `bring-shrubbery/lucide-swift`). Inherits foreground color from `.foregroundStyle(...)` to support Apple system colors.
   - `SPMDependency` — Swift Package Manager dependency (= replaces the prior `no third-party deps` baseline. Owner 2026-08-26 unlocked it; every new dep still requires grill sign-off).
2. If `CONTEXT.md` does not exist at expected path, skip this ticket and ask owner where the glossary lives (= do not invent one).
3. Inline references from existing entries (= e.g. `Toolbar` mentioning `systemName:`) get a one-liner pointing to `WenshuIcon` (= optional polish).

## acceptance

- `grep -c 'WenshuIcon\|LucideIcon\|SPMDependency' CONTEXT.md` >= 3 in `CONTEXT.md`.
- No source code edited (this is docs-only).

## risks

- `CONTEXT.md` location may have shifted between v0.24 and current. Locate via `git log --all --diff-filter=D --name-only | grep -i context | head -5` if not found at `docs/agents/CONTEXT.md`.

## source of truth

- spec: `/Volumes/ANAN/Engineering/wenshu/.scratch/2026-08-26-lucide-icon-migration/spec.md` §4, §6
- ticket 001 + 002 + 003 all merged before this lands

The glossary reflects Lucide migration domain words after ticket 004.
