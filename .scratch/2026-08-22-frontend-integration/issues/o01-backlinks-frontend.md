# 001 — Backlinks (Obsidian replica 12) frontend integration

> Parent spec: `.scratch/2026-08-22-frontend-integration/spec.md`.
> Backend: `Sources/WenshuApp/Core/LinkGraph/BacklinksPanel.swift` + `LinkIndex.swift` + `InternalLinkParser.swift` + `BacklinkResolver.swift` (done 8/19, never mounted).
> 1 commit. Leaf-level change only. No parent component edits.

## What to build

Wire the existing `BacklinksPanel` SwiftUI view into the **Z-NOVEL top toolbar icon switcher**.

Currently Z-NOVEL top toolbar has placeholder SF Symbols (per CONTEXT.md "ZoneBottomToolbar 'placeholder text' truth-source"). The Backlinks panel needs a dedicated icon switch in that toolbar.

## Implementation outline

**Files to touch (leaf only — no parent component edits):**

1. `Sources/WenshuApp/Views/ZoneModule/ZoneTopToolbar/ZoneTopToolbarConfig.swift` (or equivalent config struct) — add a new `.backlinks` toolbar item entry that:
   - Icon: `link` (SF Symbol)
   - Toggles `BacklinksPanel` visibility in Z-NOVEL right pane
2. `Sources/WenshuApp/Views/LinkGraph/BacklinksPanel.swift` — already exists; verify it accepts the current document selection binding (read existing file first, confirm signature)
3. `Sources/WenshuApp/Views/ZoneModule/ZoneContent/ZNovelContentView.swift` (or equivalent) — bind selected document → `LinkIndex` → `BacklinksPanel`

**Do NOT touch:**
- `LayoutShellView.swift` (parent — zone layout)
- `WenshuApp.swift` (root App entry)
- `ZoneModule.swift` (parent switcher)

## Acceptance criteria

- [ ] `swift build` exit 0
- [ ] `swift test` — 338 tests + new test pass
- [ ] macOS binary launches; Z-NOVEL top toolbar shows new `link` icon
- [ ] Clicking the icon toggles a backlinks panel below the toolbar
- [ ] Selecting a document with `[[name]]` links shows the reverse-linked documents in the panel
- [ ] No parent component (`LayoutShellView`, `ZoneModule`) modified
- [ ] Code-review 2 axes: Standards + Spec

## Test plan

- New unit test `Tests/WenshuAppTests/Core/LinkGraph/BacklinksPanelFrontendTests.swift` — verifies panel binds to selected document and renders correct reverse links
- Manual on-machine verification (boss 周一 review)

## Risks

- `ZoneTopToolbar` config struct location unknown — read `LayoutShellView.swift` or sibling files first to locate config
- BacklinksPanel may need a binding param refactor — preserve existing public API if possible