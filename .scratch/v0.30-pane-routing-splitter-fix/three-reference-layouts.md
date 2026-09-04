# Three reference layouts - visual partition inventory

> Captured 2026-08-31 23:07:45 CST (= boss 2026-08-31 OOB "use hotkeys to surface every hidden panel in these apps so you can identify their partition design").
> Scope = informational only. v0.30 implementation targets ONLY the FCP-style 6-zone preset (the current wenshu default = builtinDefaultPreset). Other presets deferred to later milestones.

## Method (= how these were captured)

Hermes / Xcode / FCP each launched + foregrounded + hotkeys fired to expose every hidden pane:
- Hermes: default launch (no shortcuts needed - pane layout is single composite, all panels visible by default)
- Xcode: `⌘1` (project navigator), `⌘⌥1` (inspector), `⌘⇧Y` (debug area) - toggles their visibility
- FCP: `⌘1` (browser), `⌘4` (inspector), `⌘5` (effects/sidebar), `⌘6` (audio) - toggles their visibility

All three screens captured via cua-driver `computer_use capture app=...` + AX tree inspected.

## FCP-style 6-zone preset (= current wenshu target)

Captured wenshu.app currently renders ONLY 2 panes (sidebar + preview) - the editor / tools / chat / dynamic panes are NOT in the AX tree. This is the v0.30 framework bug to fix.

### FCP Final Cut Pro Creator Studio (real app, 4 visible pane groups + top/bottom)

```
+-------------------------------------------------------------+
| top toolbar (44 PT)                                         |
+-------+----------------+----------------+-----------------+
| Lib   | Browser        | Viewer         | Effects         | Inspector (4 vertical ~13/24/35/22)
+-------+----------------+----------------+-----------------+
| Timeline (~20%)                                            |
+-------------------------------------------------------------+
| bottom bar (search + 360 items)                                |
+-------------------------------------------------------------+
```

**Total = 4 vertical + 1 timeline + 1 top + 1 bottom = 7 panels (boss calls this "FCP 8-zone layout").**

## Xcode (3 vertical + top + 2 bottom = 6 panels)

```
+-------------------------------------------------------------+
| top toolbar + tabs + right inspector-tab cluster            |
+-------+--------------------------------+-----------+
| Nav   | Editor                          | Inspector |  (3 vertical ~14/64/14)
+-------+--------------------------------+-----------+
| Filter bar                                              |
+-------------------------------------------------------------+
```

**Total = 3 vertical + 1 top + 1 bottom = 5 panels. boss calls this "Xcode Editor-priority" because the central editor pane dominates (~64%).**

## Hermes (1 vertical sidebar + 1 large center + 1 bottom composer + 1 statusbar = 4 panels)

```
+-------------------------------------------------------------+
| top toolbar                                                |
+------+-----------------------------------------------------+
| Side | center top tabs (session + group + plus)            |
| bar  |                                                     |
|      | main conversation content (~85%)                    |
|      |                                                     |
+------+-----------------------------------------------------+
| composer (input + model picker)                            |
+-------------------------------------------------------------+
| statusbar (gateway + profile + version)                     |
+-------------------------------------------------------------+
```

**Total = 1 sidebar + 1 large center + 1 composer + 1 statusbar + 1 top toolbar = 5 panels. boss calls this "Hermes Chat-priority" because the main pane is the chat conversation (~85%).**

## Cross-app design patterns (informational)

| Concept          | FCP             | Xcode            | Hermes        | wenshu v0.30 default |
|------------------|-----------------|------------------|---------------|----------------------|
| Top toolbar      | yes 30 PT       | yes 30 PT        | yes 30 PT     | yes 30 PT (RegionTabBar) |
| Left sidebar     | Library 13%     | Navigator 14%    | Sessions 8-10% | Project Management zone 14%      |
| Center pane      | Viewer 35%      | Editor 64%       | Chat 85%      | Preview 13% (too narrow) |
| Right pane 1     | Effects 13%     | Inspector 14%    | (none)        | Tools (MISSING)     |
| Right pane 2     | Inspector 22%   | (none)           | (none)        | (none - wenshu has no 3rd pane) |
| Bottom timeline  | Timeline 20%    | (none)           | (none)        | Chat + Dynamic (MISSING) |
| Bottom composer  | Search bar      | Filter bar       | Composer + statusbar | Statusbar (MISSING composer) |

## v0.30 scope (= boss 2026-08-31 OOB)

> "We will first solve the default wenshu 6-zone framework BUG; other templates to be implemented later"

**Wenshu default = builtinDefaultPreset = FCP-style 6-zone** (= sidebar + preview + editor + tools top, chat + dynamic bottom). BUG = only 2 panes render (sidebar + preview); editor / tools / chat / dynamic missing from AX tree.

**Fix scope (this commit)**:
1. Restore PaneRenderer tree walk so all 6 panes render (= current rendering truncates to 2 panes - root cause in splitContainer / groupContainer routing)
2. Fix splitter drag persistence (= commit `1b250dd8c` = needs Q22 true verification with real mouse drag, not cliclick)
3. Fix preview pane content fill width (= revert previous .frame(maxWidth: .infinity) hacks; replace with LayoutAPI / HSplitView native)

**Fix scope (NOT this commit, deferred)**:
- FCP / Xcode / Hermes named presets (rename builtin presets to FCP Balanced / Xcode Editor-priority / Hermes Chat-priority) - defer to v0.31+
- 4th preset = Quad - defer
- User custom layout - defer

## Source files

This file = inventory only. No source-code edits.
