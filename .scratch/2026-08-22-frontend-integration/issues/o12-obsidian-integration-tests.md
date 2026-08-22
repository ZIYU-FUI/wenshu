# 012 — Obsidian Integration cross-tool verification (issue 23)

> Parent spec: `.scratch/2026-08-22-frontend-integration/spec.md`.
> Backend: `Tests/WenshuAppTests/Core/Integration/ObsidianFixturesTests.swift` (done 8/19).
> 1 commit. Verification only — no new UI.

## What to build

Run the existing `ObsidianFixturesTests.swift` against the now-mounted frontend modules (issues 001-011) to verify:
- JSON Canvas file round-trip still 1:1 after Canvas mount
- Internal Link parse / encode still works after Backlinks mount
- YAML .base file parse still works after Bases mount
- Markdown frontmatter still works after Composer mount

## Implementation outline

**Files to touch (leaf only):**

1. Run existing `swift test --filter ObsidianFixturesTests`
2. If any test fails due to frontend mount side-effects, fix the leaf component that broke it
3. Add new frontend integration test `Tests/WenshuAppTests/Core/Integration/FrontendMountTests.swift` — verifies each mounted view binds to expected store without crash

**Do NOT touch:** parent components

## Acceptance criteria

- [ ] `swift test` 338 tests + ObsidianFixturesTests + new FrontendMountTests pass
- [ ] Round-trip fidelity 1:1 for all 11 mounted modules
- [ ] Code-review 2 axes

## Risks

- None — pure verification + small test addition