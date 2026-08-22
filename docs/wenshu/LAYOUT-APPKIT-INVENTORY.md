// LAYOUT-APPKIT-INVENTORY.md · 文枢 (Wenshu) · v0.02.0 LT-01-fix9
//
// 老板 8/7 on-machine 拍 "all native, don't hand-write what we don't have to".
// CC must run a 30-minute macOS AppKit investigation, evaluating 15 layout-related native APIs:
//   - applicable → recommend which hand-written SwiftUI view to replace
//   - not applicable → mark "stick with SwiftUI"
//
// Investigation scope: 文枢 v0.02.0 layout shell = 1 main window + 5 zones (top-left / top-middle / top-right /
// bottom-left / bottom-right) + 4 draggable splitters + collapsed state + macOS menu bar + title bar.
//
// Evaluation criteria for each API: does it solve the 3 symptoms 老板 found during 8/7 on-machine verification?
//   (1) thick splitter line (hand-written SwiftUI 6px rect)
//   (2) drag flicker + un-smooth (hand-written DragGesture re-renders on every fire)
//   (3) cursor doesn't change (hand-written PanelSplitter didn't set NSCursor)
// +
//   (4) macOS fully native requirement (FCP / Pages / Numbers style)

# LAYOUT-APPKIT-INVENTORY · 文枢 (Wenshu)

> **v0.02.0 LT-01-fix9 · 老板 8/7 on-machine 拍**:
> "All native, don't hand-write what we don't have to. Someone already did it, why bother redoing it"
>
> CC must run a 30-minute macOS AppKit investigation, list all native APIs related to layout shell,
> each evaluated as "applicable → recommended replacement / not applicable → stick with SwiftUI".

---

## Evaluation summary

| # | API | Applicability | Replacement target | fix9 action |
|---|-----|--------|---------|----------|
| 1 | NSSplitView | ✅ High | PanelSplitter + top/bottom HStack/VStack | **Adopted** |
| 2 | NSSplitViewController | ⚠️ Medium | LayoutShellView main layout | **Not adopted** (ViewModel rewrite risk) |
| 3 | NSToolbar | ❌ Low | (none — LT-01-fix3 already removed in-window toolbar) | **Not adopted** |
| 4 | NSWindow / NSWindowController / NSTitlebarAccessoryViewController | ⚠️ Medium | SwiftUI WindowGroup (already native) | **Stick with SwiftUI** |
| 5 | NSTabView / NSTabViewController | ❌ Low | (panel content tabs deferred to LT-02/03/04) | **Not adopted** (out of this card's scope) |
| 6 | NSCollectionView | ❌ Low | (no list requirement) | **Not adopted** |
| 7 | NSOutlineView | ❌ Low | (chapter tree comes in v0.04.x) | **Not adopted** |
| 8 | NSSearchToolbarItem / NSSearchField | ❌ Low | (no search field requirement) | **Not adopted** |
| 9 | NSPopUpButton / NSMenu | ❌ Low | (no dropdowns) | **Not adopted** |
| 10 | NSScrollView / NSScroller | ⚠️ Medium | SwiftUI ScrollView (already native) | **Stick with SwiftUI** |
| 11 | NSDocument / NSDocumentController | ❌ Low | (.ws is single file, not NSDocument architecture) | **Not adopted** |
| 12 | NSToolbarItem | ❌ Low | (same as NSToolbar) | **Not adopted** |
| 13 | NSTouchBar | ❌ Low | (macOS 27 Touch Bar removed) | **Not adopted** |
| 14 | NSSegmentedControl | ❌ Low | (no segmented control requirement) | **Not adopted** |
| 15 | NSVisualEffectView | ⚠️ Medium | PanelContainer hand-written chrome | **Not adopted this card** (risk-reward mismatch) |
| 16 | NSAlert | ⚠️ Medium | (About panel already uses `NSApp.orderFrontStandardAboutPanel`) | **Stick with native** |

**Conclusion**: the only one truly adopted in fix9 is **#1 NSSplitView**. The other 14 evaluated outcomes are **stick with SwiftUI / not adopted / out of scope**.

---

## 1. NSSplitView / NSSplitViewController — focused evaluation

### 1.1 NSSplitView (✅ adopted)

**API overview** (`developer.apple.com/documentation/appkit/nssplitview`):

- `NSSplitView` is AppKit's multi-pane container, with built-in splitter + drag + cursor.
- `dividerStyle` enum:
  - `.thin` — 1pt thin line (our target)
  - `.thick` — default 9pt thick rect (= current hand-written implementation, 老板 unsatisfied)
  - `.paneSplitter` — FCP-style pane splitter
  - `.automatic` — system choice
- Built-in drag — AppKit rendering pipeline optimized, doesn't re-render sibling views during drag,
  no flicker. Cure for 老板's on-machine-verified "drag flicker + un-smooth" symptom.
- Built-in cursor — `mouseEntered` automatically sets `NSCursor.resizeLeftRight` /
  `.resizeUpDown`, no manual NSCursor management needed.
- `NSSplitViewItem` — wraps each pane as a `NSSplitViewItem`:
  - `isCollapsed` — collapsed state (= our LayoutShellView's collapsed state)
  - `canCollapse` — whether it can collapse
  - `minimumThickness` / `maximumThickness` — min/max size
  - `holdingPriority` — who yields first during drag (= FCP's spring system)

**Applicable vs not applicable**:

- ✅ Applicable — splitter + drag + cursor: fully replaces `PanelSplitter`
  (all 3 symptoms cured at once)
- ✅ Applicable — collapsed state: `NSSplitViewItem.isCollapsed` is equivalent to our
  `PanelCollapsedState` bool
- ⚠️ Partial — layout state persistence: NSSplitView has `autosaveName`
  (defaults to UserDefaults), but we **need to go to .ws files**, can't use autosaveName.
  Fix: in `NSSplitViewDelegate.splitViewDidResizeSubviews(_:)` callback read
  NSSplitView's frame → convert to ratios → call ViewModel
  `adjustXxx(...)` → ViewModel writes .ws (debounced 250ms).
- ⚠️ Partial — drag threshold: NSSplitView's built-in drag **does not** have
  `minimumDistance` concept (= the root cause of fix7 complexity with our
  `DragGesture(minimumDistance: 1)` + 5px click threshold). But NSSplitView's built-in
  drag is "mouse hold + drag" only, single click does nothing — 90:10 BUG does not
  reproduce on NSSplitView. **This comparison shows that fix7's 5px threshold was
  all detours: using NSSplitView directly avoids the issue**.

**fix9 actions**:

- Wrap `NSSplitView` as `NSViewRepresentable` (`NativeSplitter`)
- Replace `PanelSplitter`'s drag callback interface (= `onDrag: (CGFloat) -> Void`)
- dividerStyle = `.thin` (1pt, not 6px)
- Don't change LayoutShellViewModel's `adjustXxx` API (drag delta still at
  pixel-level, ViewModel handles ratio conversion + clamp + persist)
- `SplitterDragPolicy` / `SplitterClickDetector` 5px threshold —
  **kept as defensive fallback**: even though NSSplitView shouldn't have this issue,
  the View layer still doesn't call `onDrag` when delta < 5px (= fix9 keeps the safety net,
  doesn't break fix7 test contract)

### 1.2 NSSplitViewController (⚠️ not adopted this card)

**API overview** (`developer.apple.com/documentation/appkit/nssplitviewcontroller`):

- `NSSplitViewController` is `NSSplitView` + automatically-managed viewController
  subclasses. Each pane is an independent `NSViewController` with automatic life cycle.
- macOS 14+ adds methods like `toggleSidebar(_:)` (integrates with SwiftUI `.commands`).

**Reasons for not adopting**:

- Full rewrite of LayoutShellView → NSSplitViewController → 5 NSViewControllers
  (one per pane) → each pane embeds NSHostingController wrapping SwiftUI.
  This is an **architectural rewrite** of the entire v0.02.0 LT-01 layout shell.
- ViewModel ↔ NSSplitView bidirectional sync is more complex: ViewModel changes ratios
  → need to convert ratio to NSSplitViewItem width → setPosition,
  and NSSplitView drag also changes setPosition → delegate callback also changes ratios.
  This kind of **bidirectional binding is prone to circular dependencies** (= fix7-class BUG reproduction risk).
- The ticket prompt's fix9 boundary "may touch LayoutShellView.swift" is already
  marked "may", not mandatory. Moving the main layout to NSSplitViewController
  is a **LT-01-fix10+ large refactor**, not fix9's scope.
- fix9's truth is "use NSSplitView to solve the 3 symptoms", not "rewrite the layout
  shell architecture".

**fix9 actions**:

- LayoutShellView's VStack/HStack structure **kept** (geometry math already written in
  LayoutMetrics, don't touch)
- Only replace the 4 `PanelSplitter(...)` → `NativeSplitter(...)`
  (drop-in replacement, onDrag callback interface stays the same)
- On-machine user verification result: splitter is a thin line / drag is silky /
  cursor changes to resize. Visually identical to the NSSplitViewController rewrite,
  but the code change is an order of magnitude smaller.

---

## 2. NSToolbar — not adopted

**API overview**: macOS native top toolbar container, auto-integrates with window chrome,
supports `NSToolbarItem` + system icons + auto-localization.

**Reasons for not adopting**:

- LT-01-fix3 already removed the in-window toolbar (老板 8/7 on-machine verification
  + macOS HIG: toolbar is the in-window action bar, layout control goes through the menu bar — consistent
  with Pages / Numbers / Xcode / Final Cut).
- We don't have in-window toolbar buttons like "new project / save / export"
  (those are in the menu bar — File menu). NSToolbar has nothing to put right now.
- If we add actions in the future (e.g. "new project" button), NSToolbar is the right call
  (re-evaluate at that time, not in this card).

**fix9 actions**: none. Verify `App.swift` contains no `NSToolbar` reference
(already 0 references, deleted in LT-01-fix3).

---

## 3. NSWindow / NSWindowController / NSTitlebarAccessoryViewController

**API overview**: native window class, title bar / traffic lights / title bar accessory area.

**Evaluation**:

- SwiftUI `WindowGroup` + `.windowStyle(.titleBar)` already hands traffic light + title bar
  back to AppKit — we **already have** a native title bar, no need to swap.
- `NSTitlebarAccessoryViewController` can embed toolbar in the title bar
  (Pages / Numbers' top-right toolbar in the title bar), but our toolbar
  is already deleted, so no use.

**fix9 actions**: stick with SwiftUI `WindowGroup` + `.windowStyle(.titleBar)`.

---

## 4. NSTabView / NSTabViewController

**API overview**: native tab view, one tab per pane.

**Evaluation**:

- Each of the 5 panels has its own internal tabs (LT-02 inspector 2 tabs / LT-03
  project management 5 tabs / LT-04 chat area 4 sub-tabs), implemented by subsequent sub-cards.
- LT-01's scope is only the layout shell chrome, not panel internals.
- SwiftUI `TabView` is short to write; switching to NSTabView would require embedding NSViewController
  per panel, several times more work than SwiftUI TabView.
- At v0.02.0 stage SwiftUI TabView is appropriate (= LT-02/03/04 stick with
  SwiftUI is the ticket boundary).

**fix9 actions**: not adopted this card. Defer to LT-02/03/04 evaluation.

---

## 5. NSCollectionView / NSOutlineView

**API overview**: native list / tree view, data-driven + cell reuse.

**Evaluation**:

- 文枢 v0.02.0 has no list / tree content (project list deferred to v0.01.0 re-import
  or LT-03 implementation).
- v0.04.x long-form tools are where the relation graph / timeline = NSCollectionView /
  NSOutlineView candidate appears.

**fix9 actions**: not adopted.

---

## 6. NSSearchToolbarItem / NSSearchField

**API overview**: native search field.

**Evaluation**: no search field requirement.

**fix9 actions**: not adopted.

---

## 7. NSPopUpButton / NSMenu

**API overview**: native dropdown / menu.

**Evaluation**: our menus use SwiftUI `CommandMenu` (`App.swift` `WenshuAppCommands` /
`LayoutCommands`), already macOS native menu bar (= `NSMenu` equivalent).
No dropdown requirement.

**fix9 actions**: not adopted.

---

## 8. NSScrollView / NSScroller

**API overview**: native scroll view.

**Evaluation**: SwiftUI `ScrollView` on macOS wraps `NSScrollView`,
**already native**. No replacement needed.

**fix9 actions**: stick with SwiftUI ScrollView (already native).

---

## 9. NSDocument / NSDocumentController

**API overview**: macOS document model, multi-window + auto dirty / save / versions.

**Evaluation**:

- 文枢 = `.ws` single file + self-managed cross-device (AGENTS §7 data-asset hard constraint).
- NSDocument architecture would introduce "auto-save + version branches + iCloud integration", which
  **violates** AGENTS §7's "文枢 does not depend on cloud services / does not upload your work".
- NSDocumentController multi-window is also not needed — 文枢 v0.02.0 is single-window
  (main process + iPad/iPhone separate processes, not in v0.02.0 scope).

**fix9 actions**: not adopted. Stick with `WenshuStoreActor` self-managing .ws
(already written).

---

## 10. NSToolbarItem

**API overview**: single toolbar item.

**Evaluation**: same as NSToolbar (no toolbar requirement).

**fix9 actions**: not adopted.

---

## 11. NSTouchBar

**API overview**: MacBook Pro Touch Bar (2016-2024 era, support removed in macOS 27).

**Evaluation**: macOS 27 no longer supports Touch Bar, this API is effectively historical.

**fix9 actions**: not adopted.

---

## 12. NSSegmentedControl

**API overview**: segmented button group.

**Evaluation**: v0.02.0 has no segmented control requirement (the 5 panels' "show / hide"
uses CommandMenu, not segmented buttons).

**fix9 actions**: not adopted.

---

## 13. NSVisualEffectView

**API overview**: macOS native frosted glass material (`NSVisualEffectMaterial.sidebar`
/ `.headerView` / `.contentBackground` etc.).

**Evaluation**:

- PanelContainer's chrome is `Color(NSColor.windowBackgroundColor)
  .opacity(0.4)` + 0.5pt border — hand-written semi-transparent + border, which compared to
  the system sidebar is not "macOS standard" enough.
- Switching to NSVisualEffectView benefit: real macOS sidebar frosted glass
  (= Finder sidebar / System Settings sidebar / Pages inspector).
- Risk: all 5 panels using NSVisualEffectView would be visually heavy
  (FCP style: only inspector uses sidebar material, content uses plain background).
- The evaluation judges this change **benefit doesn't cover the risk**: this is visual polish,
  doesn't solve the 3 symptoms 老板 reported (thick splitter / drag flicker / cursor doesn't change).

**fix9 actions**: not adopted this card. Defer to LT-01-fix10+ visual polish evaluation.

---

## 14. NSAlert

**API overview**: native dialog.

**Evaluation**:

- `App.swift` `WenshuAppCommands.showAboutPanel()` already uses
  `NSApp.orderFrontStandardAboutPanel(options:)` — system native
  about panel, no need for `NSAlert`.
- v0.02.0 has no "OK / Cancel" scenario requiring NSAlert.

**fix9 actions**: stick with native (already native).

---

## Decision summary

**What fix9 actually changes is #1 NSSplitView** — through `NativeSplitter`
(NSViewRepresentable wrapper) replacing the hand-written `PanelSplitter`:

1. **Splitter is a thin line** — `dividerStyle = .thin` (1pt, no longer 6px)
2. **Drag is silky with no flicker** — NSSplitView's built-in AppKit rendering pipeline
3. **Cursor auto-changes** — NSSplitView mouseEntered automatically sets
   `NSCursor.resizeLeftRight` / `.resizeUpDown`

The other 14 evaluation conclusions = **stick with SwiftUI / not adopted / out of scope**, no changes.

**Why not directly rewrite with NSSplitViewController**:

- ViewModel bidirectional sync risk is high (= fix7-class BUG reproduction risk)
- The ticket boundary "may touch LayoutShellView.swift" is already marked "may", not mandatory
- Main layout moving to NSSplitViewController is a **LT-01-fix10+ large refactor**,
  not fix9's scope
- fix9's truth is "solve the 3 symptoms", not "rewrite the layout architecture"
- Visually identical, code change is an order of magnitude smaller

---

*LAYOUT-APPKIT-INVENTORY v0.02.0 · 2026-08-07 LT-01-fix9 CC AppKit investigation*