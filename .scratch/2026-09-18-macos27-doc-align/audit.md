# 2026-09-18 macOS 27 doc-alignment audit (= boss 9/18 OOB "全都改一下")

Boss 9/18 OOB: "全都改一下" — applies 8 fixes identified in the 2026-09-18
UI audit. Scope = bring wenshu code into alignment with macOS 27 documentation
(`developer.apple.com/documentation/technologyoverviews/liquid-glass` +
WWDC25 Session 323 "Build a SwiftUI app with the new design").

This document is the per-ticket manifest. Each ticket = 1 file = 1 commit.
Order = dependency order (= lower-numbered tickets unblock higher-numbered
tickets = commit each on top of the previous so the diff is per-file).

Authority chain (= per AGENTS.md §11.3 code-duplication-forbidden principle):
- macOS 27 Apple HIG = root authority
- boss 2026-09-02 OOB "默认不加液态玻璃效果的, 我们就不加" = secondary
- skill `wenshu-apple-api-first` v6 + `wenshu-macos26-liquid-glass-pitfalls` v6 =
  tertiary (= they encode boss + Apple decisions)
- this audit = operational plan (= not authority; = ticket list)

## 8 tickets (= 8 commits, sequential)

| # | File | Change | Severity | Source authority |
|---|---|---|---|---|
| 1 | `LibraryRootView.swift` | add `.containerBackground(for: .window) { Color(nsColor: .windowBackgroundColor) }` at the root body | P0 | apple-hig-visual-z-axis-layer-model.md L29-31 + pane-chrome-canonic-pattern.md L56-66 |
| 2 | `ZoneEditor.swift` + `LongFormGuardrailsView.swift` + `BookEditorSheet.swift` + `CommandPaletteView.swift` + `BacklinksPanel.swift` | remove per-pane `.glassEffect(.regular)` (= 5 call sites); replace with `Color(nsColor: .windowBackgroundColor)` | P0 | wenshu-apple-api-first §Boss hard rule + pane-chrome-canonic-pattern.md L88 |
| 3 | `AppRootScene.swift` | strip `.defaultSize(width:height:)` (= macOS 27 NSV auto-sizes when no defaultSize + .unifiedCompact per v0.95/v0.97 boss OOB "NSV probe was working fine before") | P0 | wenshu-visual-alignment 反模式段 + NavigationSplitShell.swift L150-213 historical comments |
| 4 | `NavigationSplitShell.swift` | strip all `.navigationSplitViewColumnWidth(min:ideal:max:)` + `.inspectorColumnWidth(min:ideal:max:)` (= per boss 9/10 "Apple default" OOB = let .automatic style pick columns = Mail / Notes / Finder default) | P0 | wenshu-visual-alignment 反模式段 "NSV column inflation 5 轮翻车" + NavigationSplitShell.swift L182-228 historical |
| 5 | `EditorChatNSController.swift` (= 262 LOC AppKit `NSSplitViewController`) + `PaneNSController.swift` (= 1513 LOC AppKit `NSSplitViewController`) | **DEFERRED to ticket 5a + 5b** — replaces the AppKit NSSplitViewController wrappers with SwiftUI `VSplitView` + `NavigationSplitView`. Scope > 1 ticket per Q112 (1 ticket 1 file). Split into `5a` (= EditorChatNSController → SwiftUI VSplitView, 2 files) and `5b` (= PaneNSController → SwiftUI NavigationSplitView + nested VSplitView, 6+ files incl. `PaneNSController+*` extensions + `WorkspaceView` + `LayoutTreeStore`). Risk: `chatItem.animator().isCollapsed.toggle()` API has no SwiftUI VSplitView equivalent (= VSplitView doesn't expose canCollapse natively = would need a manual `collapsed: Bool` state + `.frame(height: 0)` workaround = visual mismatch with Keynote's native isCollapsed animation). Defer until boss explicitly approves the canCollapse replacement. | P1 | wenshu-apple-api-first §"Apple API first rule" + macOS 27 SwiftUI VSplitView docs |
| 6 | `ShellMiddleColumn.swift` + `EmotionCurveView.swift` + `PresetCard.swift` + `PreviewPane.swift` | replace `Color(nsColor: .separatorColor)` with `HierarchicalShapeStyle.separator` (= Apple semantic ShapeStyle = auto-adapt dark mode + Liquid Glass) | P2 | wenshu-macos26-liquid-glass-pitfalls Pitfall 1 + apple-hig-visual-z-axis-layer-model.md |
| 7 | `LongFormGuardrailsView.swift` + `CharacterLifecycleView.swift` + `BookSettingConstraintsView.swift` + `ForeshadowingView.swift` + `PlaceholderView.swift` + `ChatMessageView.swift` + `ChatPartView.swift` + `EmotionCurveView.swift` + `CharacterRelationshipsView.swift` + `ReaderExperienceView.swift` + `EditorPaperCanvas.swift` + `SettingsView` (= `SettingView.swift`) | replace `Color.red` / `.green` / `.orange` / `.gray` / `.blue` / `.white` with `Color(nsColor: .systemRed/.systemGreen/.systemOrange/.systemBlue/.systemGray)` (= Apple dynamic color = correct dark-mode + Liquid Glass tint behavior) | P2 | wenshu-apple-api-first §"color rule" + Apple HIG Materials |
| 8 | `MemoryEntryRow.swift` + `PaneTabBar.swift` + `RuntimeCWDDisplayChip.swift` + `SkillsSettingsView.swift` + `PreviewSortMenuButton.swift` + `MemorySettingsView` etc. | replace `Color.secondary.opacity(0.X)` with `HierarchicalShapeStyle.tertiary/.quaternary` (= Apple semantic ShapeStyle) | P2 | wenshu-apple-api-first §"color rule" |

## Per-ticket acceptance

After ticket 8 lands:
- [ ] `swift build` clean
- [ ] Per-file screenshots via `vision_analyze` (= boss 9/18 OOB "对比, 找问题" = the changes need to be visible)
- [ ] AGENTS.md §11 baseline unchanged (this is a code-level fix, not a baseline change)

## Ticket 5 = audit.md update only (= no code commit in this round)

Ticket 5 (PaneNSController 1513 LOC + EditorChatNSController 262 LOC →
SwiftUI VSplitView) is a multi-file architecture refactor that exceeds
Q112 "1 ticket 1 file" scope. Boss 8/19 OOB "Q46 stop-rule" + Q186 +
Q173 ponytail + Q57 (3rd-party verdict ≠ authority): do NOT scope-creep
into a multi-file refactor in a "一次性验收" round. The audit.md entry
for ticket 5 documents the deferral + the future split into 5a / 5b so
the next session has the full rationale without re-investigating.

## Out of scope (= future tickets)

- `Color.accentColor` usages (= already canonical Apple HIG)
- `Color(nsColor: .windowBackgroundColor/.controlBackgroundColor/.selectedContentBackgroundColor)` (= already canonical)
- `Color.tertiary` (= canonical ShapeStyle)
- `Material.*` (= canonical)
- NativeSplitter / WenshuSplitView (= already in scope of v0.30 weights-bug沉淀 = separate ticket if needed)

## Files NOT touched

- AGENTS.md (= boss rule: doc-only fix when code is wrong; this audit IS the doc for this round)
- CLAUDE.md / README.md (= not the bug surface)
- .scratch/backlog (= pre-existing project backlog)

*First line = fact. Last line = fact.*
