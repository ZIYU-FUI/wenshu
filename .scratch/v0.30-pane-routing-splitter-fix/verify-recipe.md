# Q34 step 8 — Boss manual NSSplitView verification recipe

> Built 2026-08-31 (= boss 2026-08-31 OOB "verify, and confirm whether there's any garbage code interfering — avoid the case where a fix doesn't take effect")
> PR 1-4 commits: bd565247c + 59bc66d69 + 74c327db9 + f380a2cd4 + 210d042ba + d54451539
> Forward-fix commits: 0b4084c00 (= divider hit-area + display menu bridge) + 3fc9441b5 (= H-3 English-only forward-fix)
> App PID (latest): running wenshu.app at /Volumes/ANAN/Engineering/wenshu/build/Wenshu.app
> Feature flag status (current): useNSSplitView = ON

## What to verify (= Q22 manual checks)

The NSSplitView path is now active (= feature flag ON). Verify each Apple HIG standard behavior lands:

### Check 1: Drag-to-resize (= Apple native split gesture)

- **Action**: Click on the divider line between the sidebar (left) and preview pane. Hold, drag right by ~50 PT.
- **Expected**: Preview pane widens, sidebar narrows. Both panes resize smoothly without lag.
- **Try also**: Drag the divider between preview and editor. Drag the divider between editor and tools.
- **Why this matters**: Verifies the recursive WorkspaceState → NSSplitView translation works (= ticket 03 PaneNSController.installSplit correctly forwards child layouts).

### Check 2: Persistence (= Apple autosaveName)

- **Action**: Quit the app (= cmd+Q), then relaunch.
- **Expected**: Divider positions match where you left them. New pane widths are restored exactly (= Apple autosaves to `UserDefaults` under key `NSSplitView Subview Frames wenshu.split.FCPLayout.<splitID>`).
- **Why this matters**: Verifies autosaveName is set correctly per `PaneNSController.installSplit`. If positions don't persist, the autosave key is wrong (= check splitID is stable across launches).

### Check 3: Collapse / expand (= Apple canCollapse)

- **Action**: Use the the display menu (= View menu, top bar). Click "Show/Hide Project Management zone" to hide the sidebar. Then click again to restore.
- **Expected**: Sidebar collapses to a thin strip (= Apple HIG animation), preview pane expands to fill. Reversing restores the sidebar to its previous width.
- **Why this matters**: Verifies `isCollapsiblePane` correctly identifies sidebar / chat / dynamic / tools as collapsible (= ticket 03 helper). The the display menu wiring is deferred (= currently posts a notification but doesn't drive `NSSplitViewItem.isCollapsed` yet — if not working, that's expected scope, not a regression).

### Check 4: Liquid Glass material

- **Action**: Look at the divider lines and pane backgrounds.
- **Expected**: Divider = 1 PT Apple system separator color (= thin). Pane backgrounds = vibrancy material that respects the dark/light appearance setting. NO hardcoded colors visible.

### Check 5: All 6 panes still render

- **Action**: Visually scan all 6 regions.
- **Expected**: From left to right + top to bottom: Project Management zone (sidebar) + Material Preview zone (preview) + Editor (editor) + Tools zone (tools) + Chat zone (chat) + Dynamic zone (dynamic). All 6 visible and content rendering. The preview pane should show 4 entity cards (Red Cliffs Battle / Du Fu / Hannibal Tactics / Li Bai).

## How to roll back (= if any check fails)

```bash
# Kill app
pkill -9 -f WenshuApp

# Flip flag back to OFF (= reverts to old PaneRenderer path)
defaults delete com.wenshu.app wenshu.useNSSplitView

# Relaunch
open /Volumes/ANAN/Engineering/wenshu/build/Wenshu.app
```

App will then render via the existing `PaneRenderer` (= legacy hand-rolled path). UI matches the pre-PR 1-4 build exactly. The NSSplitView path stays dormant (= no crash; the feature flag simply routes around it).

## Toggling flag without rebuild

```bash
# Enable NSSplitView path
defaults write com.wenshu.app wenshu.useNSSplitView -bool true

# Disable (= revert to legacy)
defaults delete com.wenshu.app wenshu.useNSSplitView
```

Toggling requires app relaunch (= flag is read once in `WorkspaceStore.init`).

## Known limitations (= out of scope per ticket)

These are NOT regressions; they're deferred work tracked elsewhere:

1. **Tree-style drag-rearrange** (= hermes-style free pane placement) — boss confirmed impossible per platform constraints. See spec.md "What this plan does NOT solve".
2. **Per-pane position serialization** — Apple autosaveName handles divider positions; wenshu's own WorkspaceState schema is for preset switching, not individual divider positions.
3. **the display menu → `NSSplitViewItem.isCollapsed` wiring** — menu items currently post a notification but don't drive collapse state. If Check 3 fails because of this, that's the deferred scope, not a regression.

## If you find a bug

Please report:
- Which check failed (= 1/2/3/4/5)
- Screenshot showing the issue
- Console log (`Console.app` filtered on `WenshuApp`)

Per Q5.4 do-not-amend: I'll forward-fix on top of the current branch, never amend.

## Verification status

- [ ] Check 1: drag-to-resize
- [ ] Check 2: persistence
- [ ] Check 3: collapse/expand (deferred; partial OK)
- [ ] Check 4: Liquid Glass material
- [ ] Check 5: all 6 panes render
