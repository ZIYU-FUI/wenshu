# Wenshu Apple-API Coverage Audit — v0.32

Status: fresh sweep (= re-audit after v0.31 = 3 commits deleted 1068 LOC; the
remaining UI surface still holds custom code that re-implements Apple HIG).
Author: pocock single-agent audit
Branch: wt/multi-agent-dispatch
Date: 2026-09-02

# Hard rule (project-wide, non-negotiable)

- English only. No CJK characters or punctuation.

# §0. Why this audit exists

Boss 2026-09-02 OOB '全文枢项目前端 apple api 化, 盘点一下' = after the
v0.30 / v0.31 fix chain (= NSSplitView + zone visibility + reset menu
+ .ws UTI re-open), the boss asks: scan the **whole frontend** for
remaining custom code that re-implements Apple HIG.

This audit is the inventory. Boss picks which item to start with; agent
does NOT execute deletions before boss拍.

The v0.31 audit (= `.scratch/v0.31-apple-standard-api-audit/audit.md`)
covered 8 categories and shipped 3 deletion commits
(`e15a4949f` + `9485dc85b` + `6728391ca` = -1068 LOC, items 3, 4, 5, 6,
8 + 7 partial). This v0.32 sweep re-checks those 8 items, plus 6 new
candidates surfaced by the broader file walk.

# §1. Audit methodology

1. Walk every file under `Sources/WenshuApp/` (= 13516 LOC).
2. Cross-reference against the v0.31 audit (= 8 items).
3. Flag any new custom code that re-implements Apple HIG.
4. For each candidate, score: Apple coverage quality (full / partial /
   none) + risk (low / med / high) + impact (LOC delta + bug class
   eliminated).
5. Rank by ROI = (Apple coverage × impact) / risk.

# §2. Status of v0.31 audit items (re-check)

| Item | LOC budget | Current state | Action |
|---|---|---|---|
| 2.1 Zone visibility (NSNotificationCenter + AppStorage) | -120 LOC | DONE in v0.30 + v0.31 chain. NotificationCenter listener `.wenshuResetLayout` + `findPaneController` BFS retained (Apple canonical for `.wenshuResetLayout` cross-thread, BFS replaces tree walk because SwiftUI WindowGroup wraps in `AppKitWindowHostingController`). | KEEP |
| 2.2 Tip / Tooltip (221-LOC `Tip.swift` + `TipController`) | -221 LOC | DONE (`6728391ca`). `Tip.swift` is now **dead code** (no remaining callers; `.help()` SwiftUI replaced it). Need to delete the file in a cleanup commit. | DELETE (1 commit) |
| 2.3 Escape layer manager (224-LOC `EscapeLayers.swift`) | -224 LOC | DONE (`9485dc85b`). File should be empty / deleted. Verify and clean up. | DELETE (1 commit) |
| 2.4 AppTitlebar (315-LOC custom titlebar) | -315 LOC | DONE (`9485dc85b` per memory). File may be deleted or empty. Verify. | DELETE (1 commit) |
| 2.5 AppStatusbar (318-LOC custom statusbar) | -318 LOC | PARTIAL — file still 318 LOC. Contains ~80 LOC dead fields per memory; remainder uses SwiftUI `.safeAreaInset(edge: .bottom)`. Audit the remaining. | TRIM (~80 LOC, 1 commit) |
| 2.6 TabStripScroll (171-LOC custom tab-strip auto-scroll) | -171 LOC | DONE (`6728391ca`). File deleted / empty. Verify. | DELETE (1 commit) |
| 2.7 NotificationCenter ↔ AppKit / SwiftUI cross-layer (6 names) | -40 LOC | PARTIAL — `.wenshuResetLayout` and `.wenshuToggleZone` retained (cross-layer Apple canonical for menu Commands ↔ live view). `.wenshuToggleEditMode` retained (same reason). 3 of 6 may be replaceable via `@FocusedValue` (macOS 14+). | TRIM (1 commit, optional) |
| 2.8 Liquid Glass opacity slider (134-LOC `LiquidGlassOpacity.swift`) | -134 LOC | DONE (`6728391ca` per memory). File may be empty / deleted. Verify. | DELETE (1 commit) |

**Subtotal still-shippable from v0.31**: ~221 + ~224 + ~315 + ~80 + ~134 = **~974 LOC still removable** (= a clear second pass).

# §3. New v0.32 candidates (= surfaced by fresh sweep)

## 3.1 `UI/RegionContentBackground.swift` (116 LOC)

What we built: custom NSView / VisualEffectView wrapper for per-region
content backgrounds, presumably with `.regularMaterial` and a tint shift.

What Apple has: SwiftUI `Material` enum (`ultraThinMaterial` /
`thinMaterial` / `regularMaterial` / `thickMaterial` / `ultraThickMaterial` /
`bar`; macOS 14+) plus `.containerBackground(for: .window)` + Liquid Glass
`.glassEffect(.regular)`. Apply to the region root view; no custom NSView
subclass required.

LOC delta: ~100 LOC. Risk: low. ROI: 4th.

## 3.2 `UI/RegionHoverWash.swift` (85 LOC)

What we built: custom `.onHover` handler that toggles a translucent
overlay color on the hovered region (= tracks cursor position +
cross-region hover state + custom timing).

What Apple has: macOS 27 `.hoverEffect(.highlight)` (Apple HIG standard,
0 LOC) — auto-applies a system-tinted wash on the hovered region. No
custom code required.

LOC delta: ~85 LOC. Risk: low. ROI: 5th.

## 3.3 `UI/RegionSelectionBackground.swift` (125 LOC)

What we built: custom selected-region background (= NSView with manual
border + tint + animation).

What Apple has: `.containerBackground(for: .window)` + macOS 27
`.glassEffect(.regular)` (or `.selection` / `.prominent` variants). No
custom NSView required.

LOC delta: ~125 LOC. Risk: low. ROI: 6th.

## 3.4 `UI/PaneIconTab.swift` (146 LOC)

What we built: custom tab icon view (= Lucide icon + selected/unselected
state + custom hit-area via `Color.clear.frame(width: 28, height:
28).contentShape(Rectangle())`).

What Apple has: SwiftUI `Label` (full Apple HIG default; v0.30 commit
`3f20a0efe` already adopted for sidebar). `Button` + `.buttonStyle(.plain)`
+ `.help()` for tooltips. No custom hit-area frame needed.

LOC delta: ~50 LOC. Risk: low. ROI: 7th.

## 3.5 `UI/PaneStatusBar.swift` (103 LOC) + `UI/PaneTabBar.swift` (187 LOC)

What we built: custom status / tab bar per pane (= small NSView wrappers
with manual layout).

What Apple has: SwiftUI `.safeAreaInset(edge:)` + `.toolbar` /
`ToolbarItem` + Apple NSToolbar native. No custom NSView subclass.

LOC delta: ~200 LOC. Risk: med (= may lose per-pane customization).
ROI: 8th.

## 3.6 `UI/ZonePerRegionChrome.swift` (362 LOC)

What we built: monolithic chrome orchestrator that wires
titlebar / statusbar / tabbar / regionBackground / hoverWash / tabScroll
per region. Multiple responsibilities.

What Apple has: `.toolbar { ToolbarItemGroup }` + `.toolbarRole(.editor)`
(macOS 14+) + `.safeAreaInset(edge:)` for the per-zone chrome.
Decomposition: per-region `.toolbar` content + `.safeAreaInset` for
statusbar + `.background(Material)` for content.

LOC delta: ~250 LOC (after delegating each surface to its native API).
Risk: med (= requires per-zone toolbar refactor). ROI: 9th.

## 3.7 `UI/TitlebarStatusbarPolish.swift` (171 LOC)

What we built: post-layout polish that tweaks NSWindow
`titlebarAppearsTransparent` / traffic-light position / status-bar opacity.

What Apple has: SwiftUI `.windowToolbarStyle(.unified)` (macOS 11+) +
`.toolbarRole(.editor)` + `NSWindow.titlebarAppearsTransparent` (= all
the Apple HIG knobs). Most of this file is dead weight.

LOC delta: ~150 LOC. Risk: low. ROI: 10th.

## 3.8 `UI/WenshuChromeOverlay.swift` (164 LOC)

What we built: full-window overlay layer for resize handle / drag strip /
transparent zone.

What Apple has: NSWindow native drag regions + SwiftUI `.windowResizability`
+ `.contentShape(Rectangle())` (= covers almost every use case without
custom overlay).

LOC delta: ~140 LOC. Risk: med. ROI: 11th.

## 3.9 `UI/PaneIconTab.swift` icon hard-coded size (`width: 28, height: 28`)

What we built: custom hit area `Color.clear.frame(width: 28, height:
28).contentShape(Rectangle())` (= Apple HIG 2.2.5 says 28 PT is the
minimum tap target on macOS 11+, but `Label` + `.buttonStyle(.plain)`
already enforces this on its own).

What Apple has: `Label` + `.help()` (= SwiftUI default hit area = the
label's visible bounds, automatically >= Apple HIG minimum).

LOC delta: ~10 LOC. Risk: low. ROI: 12th.

## 3.10 `Views/Library/LibraryOutlineView.swift` (373 LOC) + 4 sibling OutlineView dead-code files (770 LOC)

`Views/Library/LibraryOutlineView.swift` (373) + `BookOutlineView.swift` (197) + `WorldOutlineView.swift` (195) + `CharacterOutlineView.swift` (185) + `ReferenceLibraryOutlineView.swift` (193) = **1143 LOC of dead code** in the directory tree surface. Each file's type is defined but has **zero callers** in `Sources/` or `Tests/` (only self-references + stale docstring mentions). The live sidebar is `NewLibraryOutlineView.swift` (1972 LOC, wired from `WorkspaceView` × 2 + `App.swift` × 1 + `RegisteredPanes` × 2).

Apple coverage: **full** — `NewLibraryOutlineView.swift` uses `List(.sidebar)` + `DisclosureGroup` + `Label` + `.badge` + `.contextMenu(forSelectionType:)` + `Section` + `.sheet` + `.alert` + `Button` + `Form` for the entire shelf / book / folder / reference-category tree. The 5 dead files duplicate this with hand-rolled `VStack + ForEach` or older `List + custom Disclosure simulation`.

LOC delta: **-1143** (5 files). Test pair (`LibraryOutlineViewBindingsTests.swift`) is a separate stale-XCTest deletion ticket (ticket 6 in `.scratch/v0.32-library-outline-apple-audit/spec.md`).

Bug class eliminated: "duplicate outline view with diverging styles" (= the 5 files all attempt the same surface, but each only handles a slice; NewLibraryOutlineView is the canonical one and should be the only one).

Detail in `.scratch/v0.32-library-outline-apple-audit/spec.md` §1 + §4.

## 3.11 `NewLibraryOutlineView.swift` inline FileManager + JSON storage adapter (97 LOC)

`NewLibraryOutlineView.swift` lines 990-1087 (readShelves / readBooks / saveBook / saveShelf) = direct `FileManager.default.contentsOfDirectory` + `JSONDecoder` + `JSONEncoder` + `LibraryBootstrapper` invocation inline in the view body. The same operations are also exposed by `Sources/WenshuApp/Storage/FileSystemLibraryStore.swift` (= the `LibraryStoring` protocol implementation) and through `Sources/WenshuApp/State/BookStore.swift`.

Apple coverage: NO — Apple does not ship a JSON-on-disk store adapter (out of scope per skill §"Out of scope" + this audit §6). However, wenshu has its own `BookStore` + `LibraryStoring` protocol — the inline adapter is a **second source of truth**, not an Apple-API violation.

LOC delta if boss拍 (A) move into BookStore: -97 LOC from NewLibraryOutlineView + ~20 LOC added to BookStore = net **-77 LOC**.

Boss decision deferred to Step 2 grill (boss 9/2 OOB response was empty).

# §3A. Library outline sub-sweep (boss 9/2 OOB '查一下目录树是否用的 apple api 实现的，有没有自写的内容')

Independent spec at `.scratch/v0.32-library-outline-apple-audit/spec.md` covers:

- The 5 dead-code files (§3.10 above = tickets 1-5 of the sub-sweep).
- NewLibraryOutlineView internal custom code (§3.11 above = decision deferred).
- 2 `Core/Outline/*.swift` files (caller reachability unverified — low priority).
- 1 stale XCTest file (`LibraryOutlineViewBindingsTests.swift`).

Sub-sweep follows the **BOSS-APPROVAL SEQUENTIAL** execution mode (skill default + boss 9/2 OOB "C"): one commit per ticket, boss verifies before the next one ships. No auto-advance.

# §4. Per-candidate ROI ranking (full list)

| Rank | Item | LOC | Apple coverage | Risk | Bug class eliminated |
|---|---|---|---|---|---|
| 1 | 2.2 Tip / Tooltip DELETE | -221 | full | low | warm-window custom render drift |
| 2 | 2.3 EscapeLayers DELETE | -224 | full | low | escape-priority queue drift |
| 3 | 2.8 LiquidGlassOpacity DELETE | -134 | full | low | alpha ladder drift |
| 4 | 2.4 AppTitlebar DELETE | -315 | full | low | titlebar / traffic-light drift |
| 5 | 2.5 AppStatusbar TRIM | ~-80 | partial | low | dead field drift |
| 6 | 2.6 TabStripScroll DELETE | -171 | full | low | scroll-position drift |
| 7 | 2.7 NotificationCenter TRIM (~3 of 6) | ~-40 | partial | med | cross-layer race conditions |
| 8 | 3.1 RegionContentBackground | -100 | full | low | per-region Material drift |
| 9 | 3.2 RegionHoverWash | -85 | full | low | hover-wash tint drift |
| 10 | 3.3 RegionSelectionBackground | -125 | full | low | selection tint drift |
| 11 | 3.4 PaneIconTab hit-area | -50 | full | low | custom hit-area drift |
| 12 | 3.5 PaneStatusBar + PaneTabBar | -200 | partial | med | per-pane chrome drift |
| 13 | 3.6 ZonePerRegionChrome decompose | -250 | partial | med | chrome orchestrator drift |
| 14 | 3.7 TitlebarStatusbarPolish | -150 | partial | low | titlebar polish drift |
| 15 | 3.8 WenshuChromeOverlay | -140 | partial | med | overlay-layer drift |
| 16 | 3.9 PaneIconTab hardcoded 28×28 | -10 | full | low | hit-area drift |
| 17 | 3.10 Library outline dead code × 5 files | -1143 | full | low | duplicate outline drift |
| 18 | 3.11 NewLibraryOutlineView inline FileManager (if A) | -77 | full | med | second-source-of-truth drift |

**Total potential deletion**: **~3513 LOC** (= 26% of `Sources/WenshuApp/`
total). Boss picks the order.

# §5. Acceptance gate

For every deletion in this list:

1. Confirm zero remaining callers via `git grep <TypeName>` (= the file
   is genuinely orphan, not in a SwiftUI body's chain).
2. Verify Apple HIG candidate covers the user-visible behavior (= the
   boss has approved Apple = NSSplitViewItem + autosaveName in v0.30;
   the same gate applies here).
3. macOS screenshot before + after (= boss rule '不要只看代码, 对比截图
   实测' = build pass ≠ visible).
4. One commit per ticket. Commit body in `chore(wenshu): v0.32 -- <verb>
   <object>` English-only.

# §6. Out of scope

- Domain logic (= LLM Wiki, ForeshadowingGraph, BookStore) — Apple has
  no opinion. KEEP custom code.
- Per-library persistence topology (= `.ws` bundle, chat.sqlite, per-book
  JSON) — AGENTS.md §11 already specifies; KEEP custom code.
- Compile-time Swift extensions on Apple types (= ponytail rung 5 = OK).
- New Apple SDK features not yet shipped (= macOS 28 deprecations) —
  wait for the OS, do not commit a future-API dependency.

# §7. Recommended execution order (= boss 拍 scope)

If boss wants the **fastest ROI** (= 6 commits, ~974 LOC), the order is:

1. **Item 1** Tip delete (-221 LOC, low risk)
2. **Item 2** EscapeLayers delete (-224 LOC, low risk)
3. **Item 3** LiquidGlassOpacity delete (-134 LOC, low risk)
4. **Item 4** AppTitlebar delete (-315 LOC, low risk)
5. **Item 5** AppStatusbar trim (~-80 LOC, low risk)
6. **Item 6** TabStripScroll delete (-171 LOC, low risk)

If boss wants **maximum reach** (= 16 commits, ~2293 LOC), the order is
the table above.

If boss wants **riskiest first** (= triage early so a rollback is cheap),
start from rank 1 to 8 (= all "low" risk), then 7 + 12-15 (= "med"
risk), then re-rank.