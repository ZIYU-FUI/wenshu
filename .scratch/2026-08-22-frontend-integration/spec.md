# Frontend integration — 14 modules (Obsidian replica + Hermes replica)

> 老板 2026-08-22 拍: 把所有 hermes / obsidian 复刻模块接入前端,周一到公司看效果给修改意见.
> Source of truth: `.scratch/2026-08-22-inventory/spec.md` (B-category盘点结果).
> This spec = 14 frontend integration tickets, one per module.

## Business language (老板 understands)

Previously (8/19 evening) 老板拍 "复刻后端, 前端不接入核心项目". Today (8/22) 老板拍 "把所有复刻全都接入前端, 周一看到".

14 modules in scope:
- 12 Obsidian replica modules (8/19 evening shipped, backend done, frontend never mounted)
- 2 Hermes replica modules (8/19 shipped, `MemoryStore` partially dead, `SkillRegistry` fully dead)

After this work: every replica module's SwiftUI view挂载在 App 上, 老板周一可 macOS 启 binary 看效果给修改意见.

## Architecture context (frontend placement decision per 6-zone layout)

wenshu v0.21 layout (per ADR-0001 + `LayoutShellView.swift`):

```
┌─────────────────────────────────────────────────────┐
│ Z-TITLE  (title bar, 28pt)                            │
├─────────────┬────────────────────────┬───────────────┤
│ Z-NOVEL     │ Z-CHAT                 │ (6 zones total)│
│ (Bookshelf) │ (ChatView + chat       │               │
│ left col    │  bottom bar)           │               │
│ ~200pt      │ ~1320pt                │               │
│             │                        │               │
│             │                        │               │
├─────────────┴────────────────────────┴───────────────┤
│ (status / context bar, 6pt)                          │
└─────────────────────────────────────────────────────┘
```

(Note: rough sketch; current 6-zone layout is more complex per LayoutTokens / v0.21. Verify with `LayoutShellView.swift` at implementation time.)

## Frontend placement plan (boss拍 at implementation time)

Each module gets a clear UI entry point. Boss 拍哪 zone 接哪个 module, 暂列建议如下:

| # | Module | Suggested placement | Entry trigger | Notes |
|---|--------|---------------------|---------------|-------|
| 1 | **Backlinks** (issue 12) | Z-NOVEL right pane / Z-CHAT inspector | Click on document → right pane shows reverse links | Highest ROI; writers need it |
| 2 | **Graph view** (issue 14) | New "Graph" button in Z-TITLE toolbar | Click → modal fullscreen graph (Apple HIG Spotlight pattern) | Visual showcase |
| 3 | **Canvas / JSON Canvas** (issue 13) | New "Canvas" button in Z-NOVEL toolbar | Click → fullscreen canvas editor | Power user feature |
| 4 | **Templates** (issue 15) | New "New from Template" item in File menu (Hermes appChrome pattern) | File menu → pick template → create note | Daily driver |
| 5 | **Note Composer** (issue 16) | Right-click on document row → context menu (Merge / Split / Rename) | Same Hermes right-click pattern | Power user |
| 6 | **Full-text Search** (issue 17) | ⌘F or search button in Z-TITLE toolbar | Click → search panel overlay | Universal |
| 7 | **Bases** (issue 18) | New "Bases" view option in Z-NOVEL (replaces card grid when active) | Toggle in toolbar | Database view |
| 8 | **Quick Switcher** (issue 19) | ⌘O (Apple HIG Spotlight) | Global shortcut → modal popup | Universal |
| 9 | **Word Count** (issue 20) | Z-TITLE toolbar tiny badge | Always visible | Must-have for writers |
| 10 | **Outline** (issue 21) | Z-NOVEL inspector / right pane | Click on document → outline panel | Writers need it |
| 11 | **Bookmarks** (issue 22) | New "Bookmarks" item in View menu | Click → modal bookmarks panel | Power user |
| 12 | **Obsidian Integration** (issue 23) | Cross-tool integration test | n/a (not a UI feature) | Already done as test fixture |
| 13 | **MemoryStore** (Hermes replica 01) | WenshuConductor init() | Background — no UI; agent uses for context retention | Already partially wired |
| 14 | **SkillRegistry** (Hermes replica 02) | Background — load SKILL.md files at startup | No UI; agent uses to load wenshu-specific skills | Currently dead |

Boss 拍 these placements when reviewing the spec. Adjust per 老板 intent.

## Tickets (1 module = 1 issue file = 1 commit per po workflow)

Each ticket = 1 SwiftUI view import + minimal app entry point. No backend changes (already done). Each = 1 commit.

### Frontend integration tickets

- `001-backlinks-frontend.md` — import `BacklinksPanel` in Z-NOVEL right pane
- `002-graph-view-frontend.md` — mount `GraphView` via Z-TITLE button
- `003-canvas-frontend.md` — mount `CanvasView` via Z-NOVEL toolbar button
- `004-templates-frontend.md` — add `TemplatePicker` to File menu
- `005-note-composer-frontend.md` — add context menu entries on document rows
- `006-fulltext-search-frontend.md` — add ⌘F shortcut + search panel overlay
- `007-bases-frontend.md` — add Bases view toggle in Z-NOVEL toolbar
- `008-quick-switcher-frontend.md` — add ⌘O shortcut + QuickSwitcherWindow
- `009-word-count-frontend.md` — add `WordCountBadge` to Z-TITLE toolbar
- `010-outline-frontend.md` — mount `OutlinePanel` in right pane (next to Backlinks)
- `011-bookmarks-frontend.md` — add Bookmarks menu item in View menu
- `012-obsidian-integration-tests.md` — verify all 11 frontend integrations + ObsidianFixturesTests
- `013-memorystore-frontend.md` — wire `MemoryStore` to `WenshuConductor.init()` (background)
- `014-skill-registry-frontend.md` — wire `SkillRegistry.scan()` at startup + invoke from WenshuConductor

## Order of execution (boss-determined)

推荐 sequential, 14 commits on one branch:

1. `wt/frontend-integration` branch off main
2. Tickets 013 + 014 (background wiring, no UI) — first, since they're code-only
3. Tickets 001-012 (UI integrations) — boss拍 order or default顺序
4. Final commit = ticket 012 integration test verification

## Acceptance criteria (overall)

- [ ] 14 modules imported in wenshu binary
- [ ] swift build exit 0
- [ ] swift test: 338 tests + new frontend tests pass
- [ ] macOS binary launches, all 14 modules visible / functional
- [ ] Boss 拍 review (周一 on-machine verification)
- [ ] Code-review 2 axes per ticket (Standards + Spec)

## What this spec does NOT cover

- Backend changes (already done 8/19, no changes expected)
- Test changes (existing tests cover backend; new frontend tests = visual verification only)
- AGENTS.md / CONTEXT.md updates (deferred until boss confirms final integration)

## Risks

- **UI conflicts**: 14 modules all wanting Z-NOVEL space. Mitigation: boss拍 placement decisions before implementation.
- **Hotkey collisions**: ⌘F + ⌘O + ⌘⇧P etc. may conflict with system shortcuts. Mitigation: check macOS HIG reserved shortcuts list.
- **Performance**: 12 views mounted at once = startup latency. Mitigation: lazy mount (render only when tab/pane opened).
- **Boss change of mind**: 14 tickets × 1 commit each = 14 commits; if boss调整 design mid-week, refactor cost is high. Mitigation: each ticket small + reversible.
- **Integration test regression**: ObsidianFixturesTests already covers backend; if frontend mount breaks Codable encode/decode, integration tests surface it.

## Out of scope

- Renaming any replica modules (already done in pollution-mitigation ticket 1)
- Changing backend logic (already done)
- Migrating to a new layout (boss拍)

## Follow-up (after boss reviews on 周一)

- CONTEXT.md updates for `ObsidianReplicaScope` + `HermesReplicaScope` glossary entries
- ADR `0008-frontend-integration-plan.md` documenting placement decisions
- Update inventory spec (this file obsoletes the "KEEP all" recommendation)

---

*Spec v0.1 · 2026-08-22 pocock · project root = `/Volumes/ANAN/Engineering/wenshu/`*