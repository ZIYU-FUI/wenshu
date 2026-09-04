# v0.30 preview sort button — Spec-axis code review

**Date:** 2026-08-31
**Branch:** `wt/multi-agent-dispatch`
**Commit:** `adcab7c1b1923c3f583fbd4046849afa5fc6fee9` — `feat(wenshu): v0.30 — preview sort button + editor expand trailing fix`
**Reviewer axis:** Spec compliance (= Q34 step 5). No new-feature proposals, no design opinions.
**Files in scope (per task):**
- `Sources/WenshuApp/UI/PaneTabBar.swift`
- `Sources/WenshuApp/Views/Workspace/WorkspaceView.swift`

**Supporting files read for cross-reference** (= not modified, just to verify wiring):
- `Sources/WenshuApp/Views/Workspace/PreviewPane.swift` (EntitySortOrder enum L108-123)
- `.scratch/v0.30-preview-sort-button/spec.md` (the 7 criteria under review)

---

## Summary

| # | Criterion | Verdict |
|---|---|---|
| 1 | Preview pane top bar shows sort icon at RIGHT edge | **PASS** |
| 2 | Click cycles 3 sort orders: pinyinFirstLetter → createdAt → modifiedAt → pinyinFirstLetter | **PASS** |
| 3 | Sort order change re-renders preview pane cards | **PASS** |
| 4 | Hover on sort icon shows accent color tint | **PASS** |
| 5 | Editor pane top bar shows expand/shrink icon at right edge | **PASS** |
| 6 | Build is clean (`swift build` exit 0) | **PASS** |
| 7 | Sort icon uses Lucide `list-ordered` | **PASS** |

**Overall: 7/7 PASS. No spec gaps. Spec is fully satisfied.**

---

## Detailed findings

### Criterion 1 — Preview pane top bar shows sort icon at RIGHT edge

**Verdict: PASS**

**Spec requirement:** Sort icon must render at the rightmost position of the preview pane's top bar (= pushed there by Spacer consuming extra horizontal space).

**Code evidence:**

- `Sources/WenshuApp/UI/PaneTabBar.swift:160` — `.frame(maxWidth: .infinity)` added to the inner HStack in `PaneTabBar.body`. This forces the inner HStack to fill the outer `RegionTabBar`'s full width, giving the `Spacer(minLength: 0)` at L146 real horizontal space to expand into.
- `Sources/WenshuApp/UI/PaneTabBar.swift:145-148` — conditional `if !(Trailing.self == EmptyView.self) { Spacer(minLength: 0); trailing() }`. The Spacer is what pushes the trailing view to the right edge.
- `Sources/WenshuApp/Views/Workspace/WorkspaceView.swift:246-252` — `ZoneContentView(zoneSlug: "projectPreview", tabs: [...], trailingButton: AnyView(PreviewSortMenuButton(sortOrder: $previewSortOrder)))`. The sort button is wired as the preview pane's `trailingButton`, which feeds into the `trailing:` slot of `PaneTabBar`.
- `Sources/WenshuApp/Views/Workspace/WorkspaceView.swift:251` — `PreviewSortMenuButton(sortOrder: $previewSortOrder)` provides the trailing view.

**Spec gap:** None.

---

### Criterion 2 — Click cycles 3 sort orders

**Verdict: PASS**

**Spec requirement:** Click cycles `pinyinFirstLetter → createdAt → modifiedAt → pinyinFirstLetter`.

**Code evidence:**

- `Sources/WenshuApp/Views/Workspace/WorkspaceView.swift:665-671` — `Button { switch sortOrder { case .pinyinFirstLetter: sortOrder = .createdAt; case .createdAt: sortOrder = .modifiedAt; case .modifiedAt: sortOrder = .pinyinFirstLetter } }`. Exact cycle as specified.
- `Sources/WenshuApp/Views/Workspace/PreviewPane.swift:108-111` — enum cases: `case pinyinFirstLetter = "首字母"; case createdAt = "创建时间"; case modifiedAt = "修改时间"`. All 3 cases exist in `EntitySortOrder` and are covered by the switch (= no implicit fallthrough risk).

**Spec gap:** None.

---

### Criterion 3 — Sort order change re-renders preview pane cards

**Verdict: PASS**

**Spec requirement:** Changing `previewSortOrder` re-renders the preview pane's entity cards in the new order (= `sortEntities` / `sortBookDocs` consume the binding).

**Code evidence:**

- `Sources/WenshuApp/Views/Workspace/WorkspaceView.swift:56` — `@State private var previewSortOrder: EntitySortOrder = .pinyinFirstLetter` (= single source of truth held in WorkspaceView).
- `Sources/WenshuApp/Views/Workspace/WorkspaceView.swift:243` — `PreviewPane(..., previewSortOrder: $previewSortOrder)` passes the `@Binding` down into `PreviewPane`, so changes from the sort button propagate.
- `Sources/WenshuApp/Views/Workspace/WorkspaceView.swift:251` — `PreviewSortMenuButton(sortOrder: $previewSortOrder)` writes back to the same `@State` via `@Binding`, establishing a two-way flow.
- Spec confirms `sortEntities(_:by:)` + `sortBookDocs(_:by:)` already consume `previewSortOrder` (= pre-existing code, not modified by this commit). Cross-check via `git diff HEAD~1 HEAD --stat` shows `PreviewPane.swift` was NOT modified in this commit — sort logic was already wired before this change.

**Spec gap:** None. (No source modification to sort logic was needed; the wiring existed.)

---

### Criterion 4 — Hover on sort icon shows accent color tint

**Verdict: PASS**

**Spec requirement:** Hover tint matches sidebar's `NewButtonWithHover` pattern (= `Color.accentColor.opacity(0.12)` on hover, `Color.clear` otherwise).

**Code evidence:**

- `Sources/WenshuApp/Views/Workspace/WorkspaceView.swift:650` — `@State private var isHover: Bool = false`.
- `Sources/WenshuApp/Views/Workspace/WorkspaceView.swift:682-684` — `.onHover { hovering in isHover = hovering }`.
- `Sources/WenshuApp/Views/Workspace/WorkspaceView.swift:685-688` — `.background(RoundedRectangle(cornerRadius: 4).fill(isHover ? Color.accentColor.opacity(0.12) : Color.clear))`. Exact match for sidebar pattern.
- Pattern parity check: `EditorExpandShrinkTrailingButton` at L522-561 uses the same `.onHover` + `RoundedRectangle(cornerRadius: 4).fill(isHover ? Color.accentColor.opacity(0.12) : Color.clear)` pattern at L552-558. Both trailing buttons are visually consistent.

**Spec gap:** None.

---

### Criterion 5 — Editor pane top bar shows expand/shrink icon at right edge

**Verdict: PASS**

**Spec requirement:** Expand/shrink icon must render at the rightmost position of the editor pane's top bar.

**Code evidence:**

- `Sources/WenshuApp/Views/Workspace/WorkspaceView.swift:264` — `ZoneContentView(zoneSlug: "editor", tabs: [...], trailingButton: AnyView(EditorExpandShrinkTrailingButton()))`. Wired as editor's `trailingButton`.
- `Sources/WenshuApp/Views/Workspace/WorkspaceView.swift:522-561` — `EditorExpandShrinkTrailingButton` body:
  - L534-535: `Button { editorMaximized.toggle() }` (= functional expand/shrink toggle).
  - L538: `if let lucide = Lucide(editorMaximized ? "shrink" : "expand")` — icon swaps based on state.
  - L540: `.frame(width: 28, height: 28)` — fixed-size frame (= intrinsic size preserved through `AnyView` wrapper).
  - L543-548: SF Symbol fallback (`arrow.down.right.and.arrow.up.left` / `arrow.up.left.and.arrow.down.right`).
- Same `.frame(maxWidth: .infinity)` Spacer-pushing layout fix from PaneTabBar applies to this button's right-edge position (= shared `PaneTabBar.trailing` slot).

**Spec gap:** None. Note: criterion 5 doesn't mandate hover tint, but the implementation includes it as a bonus; spec only requires the icon to appear at the right edge.

---

### Criterion 6 — Build is clean (`swift build` exit 0)

**Verdict: PASS**

**Code evidence:**

- Command run: `swift build` from `/Volumes/ANAN/Engineering/wenshu` at 2026-08-31.
- Result: `Build complete! (1.46秒)` with `EXIT=0`.
- Warnings present are all pre-existing third-party deprecations (= `aexml` `Package.swift` watchOS `v4` deprecation, unhandled resource files for `Wenshu.entitlements` + `ComponentIndex.md`) — none are introduced by this commit (`git show --stat HEAD` confirms only 7 files touched, none in `.build/checkouts/`).

**Spec gap:** None.

---

### Criterion 7 — Sort icon uses Lucide `list-ordered`

**Verdict: PASS**

**Spec requirement:** Sort icon = Lucide `list-ordered` (matches Boss 8/30 OOB and `EntitySortOrder.menuIcon`).

**Code evidence:**

- `Sources/WenshuApp/Views/Workspace/WorkspaceView.swift:674` — `LucideIcon(sortOrder.menuIcon, size: 18)`. Reads icon from `EntitySortOrder.menuIcon`.
- `Sources/WenshuApp/Views/Workspace/PreviewPane.swift:115-122` — `var menuIcon: String { switch self { case .pinyinFirstLetter: return "list-ordered"; case .createdAt: return "list-ordered"; case .modifiedAt: return "list-ordered" } }`. All 3 sort orders resolve to `"list-ordered"`.
- LucideIcon wrapping at L674-677 = `LucideIcon("list-ordered", size: 18).frame(width: 28, height: 28).contentShape(Rectangle()).foregroundStyle(.tint)`.

**Spec gap:** None. Note: since all 3 states use the same icon, the icon does NOT visually indicate current sort order (= only `.help("排序方式: \(sortOrder.rawValue)")` tooltip at L689 does). This is the spec's stated behavior (icon = `list-ordered` only); not a spec gap.

---

## Cross-spec checks (defensive)

- **Hard rule §5-6 (English-only comments + commit msgs; Chinese-only UI strings):** PASS. `EntitySortOrder.rawValue` is Chinese (`"首字母"` / `"创建时间"` / `"修改时间"`); `.help("排序方式: ...")` is Chinese; comments are English.
- **§11.1 no new 3rd-party libs:** PASS. Only SwiftUI native (`Button`, `RoundedRectangle`, `Color`, `LucideIcon`) — all already in project.
- **Q5.2 do-not-amend (single commit):** PASS. `git log` confirms `adcab7c1b` is a single commit on top of `9d1f9bf82` (verify via `git log --oneline`).
- **Q29 invariant (.scratch/ committed alongside source):** PASS. `git show --stat HEAD` shows `.scratch/v0.30-preview-sort-button/spec.md` (+ 3 ticket files: `01-panetabbar-spacer-fix.md`, `02-preview-sort-button-rewrite.md`, `03-editor-trailing-button-rewrite.md`) are part of the same commit.

---

## Spec gaps

**None.** All 7 acceptance criteria from `.scratch/v0.30-preview-sort-button/spec.md` are met by the implementation in `adcab7c1b`. The commit scope matches the spec's "Files touched" list exactly; no files modified outside the named scope; no claims in spec are unbacked by code.

---

## Refs (verbatim line citations)

| Criterion | File | Lines |
|---|---|---|
| 1 | `PaneTabBar.swift` | 145-148, 160 |
| 1 | `WorkspaceView.swift` | 234-252 |
| 2 | `WorkspaceView.swift` | 665-671 |
| 2 | `PreviewPane.swift` | 108-111 |
| 3 | `WorkspaceView.swift` | 56, 243, 251 |
| 4 | `WorkspaceView.swift` | 650, 682-688 |
| 5 | `WorkspaceView.swift` | 264, 522-561 |
| 6 | `swift build` output (live) | `Build complete! (1.46秒) EXIT=0` |
| 7 | `WorkspaceView.swift` | 674 |
| 7 | `PreviewPane.swift` | 115-122 |

---

*End of report. No source edits made.*
