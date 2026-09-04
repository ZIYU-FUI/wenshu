# 01 — EntityPreviewPane (card flow in material management zone)

**What to build:**

Boss 2026-08-30 OOB '实体分类在目录树里是最后一层，点击后，实体文档要用
随心记的卡片流样式显示在素材管理区' = preview pane should show
entity cards when a sidebar category is selected.

Pre-fix: preview pane was `PreviewTabBackground` (= `Color.clear` stub).

Fix: created `EntityPreviewPane` with 3 modes (single entity / category-
scoped / overview).

**Blocked by:** None (= can start independently).

**Status:** ready-for-agent (= already committed as `291487322`, this
ticket documents the commit after-the-fact per Q5.6 partial commit 接管
规范).

## Fix specification

### New file: `Sources/WenshuApp/Views/Workspace/EntityPreviewPane.swift` (~270 LOC)

3 view modes:
1. Single entity detail (= tap card) → show full .md body
2. Category-scoped grid (= sidebar category selected) → show only that
   category's cards
3. Overview grid (= no category selected) → show all cards

Uses `GeometryReader` + `LazyVGrid` (= standard SwiftUI grid pattern).

### Modified: `Sources/WenshuApp/Views/Workspace/WorkspaceView.swift`

- `ZoneModuleView` now wires `selectedEntityCategory` + `selectedEntity`
  binding into the `EntityPreviewPane`.
- Removed `PreviewTabBackground` (= replaced with `EntityPreviewPane`).

## Acceptance

- [x] Click category in sidebar → preview shows that category's cards
- [x] Click card → preview shows entity detail
- [x] Build exit 0
- [x] Screenshot verified: cards visible in preview pane

## Out-of-scope

- Double-click card → open in editor (= boss Ticket 3 future ticket;
  current is preview-only)
