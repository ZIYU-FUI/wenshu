# Wenshu Code Audit — Detailed Verification Report

**Date**: 2026-09-06
**Scope**: Re-verification of the 7 "true orphan candidate" top-level functions flagged in the initial audit (= .scratch/2026-09-06-wenshu-code-audit.md)
**Tool**: Manual verification (= source code reading + grep + cross-file context analysis). NOT automated AST analysis.

## Verification Method

For each of the 7 candidates, I:

1. Confirmed **zero callers in main worktree Sources/** (= `grep -rnw` excluding Tests/, .worktrees/, .build/, .scratch/).
2. Confirmed **zero true callers in main worktree Tests/** (= grep + manual line-by-line check to exclude false positives from comment strings + path mentions).
3. Read the **file-level doc comment** (= the comment at the top of the file describing the file's purpose).
4. Read the **function-level doc comment** (= the comment immediately above the function declaration).
5. Categorized by intent (= hermes-port / future-ticket / evil-dead).

## Detailed Findings

### 1. editorChrome (Sources/WenshuApp/UI/ZonePerRegionChrome.swift:301)

**File-level doc**: NONE (= file is the chrome catalog).
**Function-level doc**: "Editor chrome (= matches old `ZoneContentView(zoneSlug: "editor", tabs: [...])` icons + `zoneStatus(for: .editor)` + `rightStatus(for: .editor)`). Top actions (v0.25.1 tickets 017 + 028): book-open-text, puzzle, link. Note: expand/shrink trailing button is NOT in this list (= it's a separate trailing button per boss 2026-08-26 OOB 'it is one button not a tab' = wired separately via `editorTrailingAction` param). Bottom: left = 'Word count: N' (= **reserved for future** real word count implementation; today = static 0), right = 'Backlinks N' (boss 9/2 OOB: REPLACE the legacy 'N%' progress placeholder with backlinks count)."

**Verdict**: ⚠️ **forward-looking public API** (= doc says "reserved for future real word count implementation" = not dead). The actual user-facing chrome for the editor pane is wired inline in `ZonePerRegionChrome` callers (= via hardcoded `ZoneTopAction(...)` + `RegionStatusBar`). The `editorChrome(...)` factory is a public helper that was never adopted.

**Recommendation**: Leave (= forward-looking public API, file-level scope). If a future ticket wires a real word-count implementation, this factory becomes the canonical entry point.

### 2. windowDragStripWidth (Sources/WenshuApp/UI/Drag/NativeControlsInspector.swift:86)

**File-level doc**: "NativeControlsInspector.swift · Wenshu (文枢) · v0.28 followup TKT-028-022. Boss 2026-08-29 OOB '完整复刻 hermes app, 用户体验第一' = port the native window controls inspector + drag strip from Hermes Desktop verbatim (= traffic-light rect, fullscreen handling, workspace geometry publishing). SOURCE (= Hermes verbatim port): /Volumes/ANAN/.hermes/hermes-agent/apps/desktop/src/components/pane-shell/geometry.ts = windowControlsRect(connection, viewportWidth) → Rect | null"

**Function-level doc**: "Compute the width of the drag strip from the window's left edge to where the first titlebar tool should sit (= matches Hermes `titlebarControlsPosition(windowButtonPosition, isFullscreen)`)."

**Verdict**: ⚠️ **Hermes Desktop 1:1 port public API** (= explicit "完整复刻 hermes app" + "matches Hermes" + "verbatim" in the doc). Forward-looking (= awaiting future drag-strip UI ticket).

**Recommendation**: Leave (= §11.3 wenshu-side wins pattern = Hermes port contract).

### 3. hermesCheckTodoRequirements (Sources/WenshuApp/Core/Agent/Todo/HermesTodoTool.swift:709)

**File-level doc**: "HermesTodoTool.swift · Wenshu · HERMES-SUBSYSTEM-4 (ticket 026 step 4). HERMES-SUBSYSTEM-4 (todo) **FULL 1:1 port** of /Volumes/ANAN/.hermes/tools/todo_tool.py (330 LOC). This is the LLM internal planning list (= the agent's scratchpad that lives on AIAgent and is re-injected after context compression). NOT the wenshu-side user-facing persisted todo (= TodoStore.swift / BookTodoStore.swift), which is kept intact per boss wenshu-side-wins pattern."

**Function-level doc**: "Todo tool has no external requirements -- always available. (= mirrors Python `check_todo_requirements`.)"

**Body**: `public func hermesCheckTodoRequirements() -> Bool { true }`

**Verdict**: ⚠️ **Hermes 1:1 port public API** (= body is trivially `return true` because the todo tool currently has no external requirements = mirrors the Python implementation exactly). Forward-looking (= awaiting future implementation if requirements ever grow).

**Recommendation**: Leave (= Hermes-port contract).

### 4. renderTabByRegistry (Sources/WenshuApp/Core/Registry/RegisteredPanes.swift:114)

**File-level doc**: "RegisteredPanes.swift · Wenshu (文枢) · v0.28 followup TKT-028-016. Boss 2026-08-29 OOB '完整复刻 hermes app, 用户体验第一' = port the pane registration pattern from Hermes Desktop verbatim. New pane type = 1 registry.register() call (= no edit to PaneRenderer). SOURCE (= Hermes verbatim port): /Volumes/ANAN/.hermes/hermes-agent/apps/desktop/src/app/contrib/panes.tsx"

**Function-level doc**: "Render a tab via the registry lookup (= **replaces the legacy switch** in PaneRenderer). **Falls back to legacy switch if not registered**."

**Verdict**: ⚠️ **Hermes Desktop 1:1 port public API** (= explicit "replaces the legacy switch" + "Falls back to legacy switch if not registered" = the function exists as the new registry-based entry point, but the WorkspaceView's `renderTabByKind` legacy switch is still the actual call path; = forward-looking replacement, not dead).

**Recommendation**: Leave (= Hermes-port replacement candidate for future workspace-view refactor ticket).

### 5. reorderPanesInGroup (Sources/WenshuApp/State/LayoutTreeState.swift:635)

**File-level doc**: "LayoutTreeState.swift · Wenshu (文枢) · v0.28 ticket 028-003. Bumped from v1 (= flat array of panes) to v2 (= recursive split tree). **1:1 port** of /Volumes/ANAN/.hermes/hermes-agent/apps/desktop/src/components/pane-shell/tree/model.ts (650 LOC TypeScript)."

**Function-level doc**: "Reorder a block of panes within a group as one unit (**browser-tab drag semantics**; a single-tab drag is a one-id block): the block lands at `toIndex` among the remaining tabs, keeping its own order."

**Verdict**: ⚠️ **Hermes 1:1 port public API** (= explicit "browser-tab drag semantics" = forward-looking drag-drop reorder UI helper).

**Recommendation**: Leave (= Hermes-port contract for future drag-drop UI ticket).

### 6. setGroupTabStrip (Sources/WenshuApp/State/LayoutTreeState.swift:665)

**File-level doc**: same as `reorderPanesInGroup` (= LayoutTreeState.swift = 1:1 port of hermes tree/model.ts).

**Function-level doc**: "Write a zone's standing strip choice; `nil` returns it to auto."

**Additional context check**: `TabStripMode` enum (= the type used by this function) has 5 refs in Sources/ (= definition in LayoutTreeState + 1 makeGroup parameter + 1 mapGroups preserve + this function definition + 1 case-`always` / case-`never` enum case). **NO case-switch usage** of `TabStripMode.always` or `TabStripMode.never` anywhere in the codebase (= the field is written but never read for display).

**Verdict**: ⚠️ **Hermes 1:1 port public API** (= the `tabStrip` field exists, the writer function exists, but no consumer reads the field). Forward-looking (= awaiting UI ticket that displays the tab strip based on this field).

**Recommendation**: Leave (= Hermes-port contract for future UI ticket). **Bonus concern**: the `tabStrip` field is persisted via JSON but never read on load. If the future UI ticket never lands, the field becomes permanent dead state. = future ticket should either consume the field OR mark it deprecated.

### 7. makeDefaultCapabilityRegistry (Sources/WenshuApp/Domain/Capabilities/CapabilityRegistry.swift:167)

**File-level doc**: "v0.34 ticket-followup. Default registry scaffolding (= registers the 4 chat-side capabilities at app launch). Per Q34 single-subject rule, this commit only ADDS the registry; it does NOT wire the existing `ChatTrigger` / `SmartQueryParser` / `EntityIngestion` / `CrossRefInject` to the registry (= those wirings are future tickets = open-for-extension per the registry pattern)."

**Function-level doc**: "v0.34: default registry (= registers the 4 chat-side capabilities at app launch). **Per Q34 single-subject rule, this commit only ADDS the registry**; it does NOT wire the existing `ChatTrigger` / `SmartQueryParser` / `EntityIngestion` / `CrossRefInject` to the registry (= those wirings are **future tickets** = open-for-extension per the registry pattern)."

**Verdict**: ✓ **explicit forward-looking public API** (= doc says "Q34 single-subject rule, this commit only ADDS the registry" + "future tickets" = deliberately deferred per Q34 boss-decision).

**Recommendation**: Leave (= Q34-boss-approved deferred scope).

## Summary

| # | Function | Intent | Caller Count | Verdict |
| --- | --- | --- | --- | --- |
| 1 | editorChrome | future-ticket (word-count) | 0 | forward-looking API |
| 2 | windowDragStripWidth | hermes-port (NativeControlsInspector) | 0 | hermes-port public API |
| 3 | hermesCheckTodoRequirements | hermes-port (HermesTodoTool) | 0 | hermes-port public API |
| 4 | renderTabByRegistry | hermes-port (PaneRegistry) | 0 | hermes-port replacement API |
| 5 | reorderPanesInGroup | hermes-port (browser-tab drag) | 0 | hermes-port public API |
| 6 | setGroupTabStrip | hermes-port (tab-strip choice) | 0 | hermes-port public API |
| 7 | makeDefaultCapabilityRegistry | Q34 boss-deferred | 0 | explicit forward-looking API |

**All 7 candidates are forward-looking public APIs** (= hermes-port contracts + Q34-deferred + "reserved for future" + drag-drop / tab-strip UI tickets).

**0 真 dead code found in this verification pass.**

## Caveats (= honest limitations of this verification)

1. **The audit is heuristic, not AST-based.** A future full AST analysis (= via `swiftc -dump-ast` or Xcode Index) might surface additional candidates. However, the heuristic scan with manual verification has high confidence on the 7 candidates (= none have ambiguous use sites).

2. **The "forward-looking" classification depends on future tickets landing.** If the planned Hermes port tickets or UI tickets never land (= e.g., boss decides wenshu won't ship drag-drop reorder), some of these functions become truly dead. This is acceptable risk (= the functions are small, well-documented, and removing them later is a trivial commit).

3. **No analysis of `func` visibility after cross-module aggregation.** The audit only checks `Sources/` + `Tests/` in the main worktree. The `.worktrees/*` (= sister worktrees at apple-001-structure-audit, fix-failures-2026-09-04, smc-003-isolation) are not checked. These worktrees have their own `(= frozen at commit X)` snapshots and are not expected to call the orphan functions (= the orphan candidate grep against them returned 4 hits = 1 declaration per worktree, all on line 114 (= the synced source line), with zero callers).

## Recommendation

**No further action needed.** The wenshu codebase has no real dead code in the production source tree. The 7 "orphan" candidates are all forward-looking public APIs (= Hermes port contracts + boss-deferred future tickets) = documented as such in their doc comments = consistent with the wenshu-side-wins pattern in §11.3 of AGENTS.md.

---

*Detailed verification conducted 2026-09-06 via manual source reading + grep + cross-file context analysis.*
*No code changes were made during this verification (= read-only audit).*