# v0.27 Xcode-paradigm + user-customizable layout spec

**Date**: 2026-08-27
**Status**: spec accepted by 老板; = not yet implemented
**Ticket**: 027-32 onwards

---

## Boss standing goal (2026-08-27 上午)

Boss tested `stevengharris/SplitView` v3.5 (= AGENTS.md §11.1 first approved
exception, commit `1c3685c75`) and said:

> 测试效果不错，只有那个 hover 效果没有实现，其它都很好。你用这个
> 重构吧。这是一个大事，你加载研发全链路方法论。不用拷问我了。一
> 直到重构落地。

The implementation path that emerged from the same-day grill session
(= boss decided the UI paradigm, NOT the library) was:

- **Xcode paradigm** (= tab + split-pane + customizable layout)

- **User can rearrange their own workspace**

- Layout persistence (similar to Hermes' recent " layout" feature)

---

## Boss grill session decisions (= the constraints this spec must satisfy)

### Decision 1: UI paradigm = Xcode-style

Boss 8/27 grill D1: '听起来是第 2 个，我本来是希望，用户是可以按自己
的习惯自由定制自己的工作区的。但有多少个区域可以用于放置 tab 是一
个问题。hermes 最近也出了一个功能，叫布局，就是允许用户自定义布
局，这觉的这个是最理想的.'

Three considered paradigms (= grill D1 options):

| Paradigm | Layout model | Boss verdict |
|---|---|---|
| FCP | fixed 6 zones, all visible | rejected (= too rigid) |
| Xcode | tab + split, user-defined | accepted |
| Hermes | chat-first, floating panes | rejected (= chat isn't the main stage per B1) |
| Hybrid | chat-driven + multi-pane | superseded by Xcode |

### Decision 2: Tab model = wenshu-native (NOT bonsplit or SplitView import)

Per the same-day grill session, the wenshu layout model must be:

- **wenshu-owned** (= implementation lives in `Sources/WenshuApp/Views/
Layout/`)
- User can **add / remove / drag tabs**
- User can **split a pane** (= horizontal / vertical)
- User can **save multiple named layouts** (= "Default", "Editing",
"Researching", etc.) and switch via menu / keyboard

This spec does NOT depend on bonsplit or any third-party library. If a
third-party library becomes available later, it can replace the
internal implementation; = the public types defined here
(`WorkspaceState`, `PaneID`, `TabSpec`, `LayoutPreset`) stay stable.

### Decision 3: Default layout = 6-zone placeholder

Per v0.26 spec (= boss 8/26 OOB) + v0.27 wiring (= commit `40cf77e59`
NewLibraryOutlineView, commit `e44dc9c90` icon 18x18 + tighter
indent, commit `333a28eb1` reference layer font align), the existing
6-zone layout is preserved as a built-in preset named " Default".

The 6 zones are:

- 项目管理区 (= left sidebar; = NewLibraryOutlineView)
- 素材预览区 (= right sidebar; = projectPreview, v0.27 zone)
- 编辑器 (= center; = editor)
- 工具区 (= right of editor; = specializedTools, v0.27 zone)
- 聊天区 (= bottom-left; = aiChat)
- 动态区 (= bottom-right; = aiDynamic)

When the user clears their custom layout (= menu menu → Layout → Reset
to Default, OR `wenshu.workspace.reset` AppStorage flag), the
" Default" preset is restored.

### Decision 4: Layout persistence = per-user JSON in UserDefaults

Per boss 8/27 D1 'hermes 最近也出了一个功能，叫布局，就是允许用户
自定义布局' (= cross-reference with Hermes' recent layout feature):

- Layout state is persisted to UserDefaults under the
  `wenshu.workspace.json` key
- Format: `WorkspaceState` Codable (= paneschema below)
- App-quit-and-relaunch round-trip preserves the user's custom layout
- Multiple named layouts supported (= `wenshu.workspace.presets`
  key, JSON array of `LayoutPreset` records)
- Per user (= NOT per .ws library); = each user has their own
  preferred layout regardless of which library they have open
- Library-scoped overrides deferred to v0.28 (= boss 8/26 OOB
  per-library state is a separate ticket)

### Decision 5: User daily journey = chat-driven, NOT editor-first

Per boss 8/27 B1 / B2 / C2 / C3 (= the chat-first design discussion
before boss corrected to Xcode paradigm in D1):

- User **drives everything via chat** (= mouth = user; =
  conversation is the input)
- AI **auto-detects knowledge gaps** in the reference library
- AI **auto-dispatches Kanban tasks** to sub-agents (= uses the
  existing KanbanStore from v0.25 + ticket 026) for missing research
- AI **auto-produces draft / outline .md files** into the book
  directory (= v0.26 file structure: `drafts/` and `outlines/`)
- User **edits drafts in the editor pane** (= the center pane IS the
  main stage per B1 '聊天驱动但只是辅助，编辑器仍是主舞台')
- User **commits drafts to chapters** (= v0.26 spec physical file
  move: `drafts/<file>.md` -> `chapters/<file>.md`; = NOT metadata
  flag change per C1)
- Reference library **auto-constrains** AI output (= inline
  citation '引自 X 资料' per B3)

This daily journey does NOT change when the layout is customized; = it
just changes which pane hosts which content.

---

## Data model (= the public types)

```swift
/// WorkspaceState — the user's current pane layout + tab assignments.
///
/// Persisted to UserDefaults under `wenshu.workspace.json`.
struct WorkspaceState: Codable, Equatable {
     var panes: [PaneNode]
     var activePaneID: PaneID
     var activeTabIDByPane: [PaneID: TabID]
     var version: Int  // schema version; = bump on breaking changes
}

/// PaneNode — a single pane (= holds 0 or more tabs).
struct PaneNode: Codable, Equatable, Identifiable {
     var id: PaneID
     var split: SplitDirection  // .horizontal (left/right) or .vertical (top/bottom)
     var frame: PaneFrame      // = minWidth / idealWidth / flex
     var tabIDs: [TabID]        // ordered; = first is selected when pane becomes active
}

/// SplitDirection — how this pane relates to its sibling.
enum SplitDirection: String, Codable {
     case horizontal  // pane is to the LEFT or RIGHT of sibling
     case vertical    // pane is ABOVE or BELOW sibling
}

/// PaneFrame — sizing rules for a pane.
struct PaneFrame: Codable, Equatable {
     var minWidth: CGFloat       // = LayoutTokens.zoneMinWidth baseline
     var idealWidth: CGFloat     // = initial width on first show
     var flex: CGFloat           // = ratio share of leftover space (= 1.0 default)
}

/// TabSpec — a tab's identity + the content view it renders.
struct TabSpec: Codable, Equatable, Identifiable {
     var id: TabID
     var kind: TabKind          // = which view to render
     var title: String          // = user-facing label
     var contextBookID: UUID?   // = which book this tab belongs to (nil = library-level)
}

enum TabKind: String, Codable {
     case projectSidebar   // NewLibraryOutlineView
     case projectPreview   // World / Character / Reference preview (= v0.27 zone)
     case editor           // main editor
     case specializedTools // = wenshu Tool panel (= v0.27 zone)
     case aiChat           // ChatView
     case aiDynamic        // DynamicZoneView
}

/// PaneID, TabID — type-safe identifiers.
struct PaneID: Codable, Equatable, Hashable { var raw: UUID }
struct TabID:  Codable, Equatable, Hashable { var raw: UUID }

/// LayoutPreset — a named saved layout (= user can have several).
///
/// Persisted to UserDefaults under `wenshu.workspace.presets`.
struct LayoutPreset: Codable, Equatable, Identifiable {
     var id: UUID
     var name: String          // = "Default", "Editing", "Researching", etc.
     var workspace: WorkspaceState
     var isBuiltIn: Bool       // = true for the "Default" 6-zone preset
}
```

---

## UI plumbing (= the SwiftUI surface that hosts WorkspaceState)

```swift
/// WorkspaceView — the root of the customizable layout. Replaces the
/// current LayoutShellView (= which is the legacy fixed 6-zone shell;
/// = kept as a fallback until the customizable version is shipped).
struct WorkspaceView: View {
     @Binding var workspace: WorkspaceState
     @ObservedObject var bookStore: BookStore
     // Renders the recursive pane tree.
     var body: some View {
          PaneRenderer(
               workspace: workspace,
               renderContent: renderTab,
               onTabMove: { tabID, fromPane, toPane in ... },
               onTabClose: { tabID in ... },
               onSplit: { paneID, direction in ... },
               onClosePane: { paneID in ... }
          )
     }
     @ViewBuilder
     private func renderTab(_ spec: TabSpec) -> some View {
          switch spec.kind {
          case .projectSidebar:   NewLibraryOutlineView()
          case .projectPreview:   ZoneModuleView(slot: .projectPreview, ...)
          case .editor:           EditorView(...)
          case .specializedTools: ZoneModuleView(slot: .specializedTools, ...)
          case .aiChat:           ChatView(...)
          case .aiDynamic:        ZoneModuleView(slot: .aiDynamic, ...)
          }
 }
}

/// PaneRenderer — recursive renderer for the pane tree.
///
/// Uses SplitView (`stevengharris/SplitView`) for the HSplit / VSplit
/// primitives IF the package is fetchable; otherwise falls back to
/// the in-house NativeSplitter (Sources/WenshuApp/Views/Layout/
/// NativeSplitter.swift).
struct PaneRenderer: View { ... }
```

---

## Implementation menu ( = the v0.28 ticket breakdown)

This spec is broken into v0.28 tickets; = the implementation begins
when network is stable and bonsplit (or an alternative) is fetchable.

### 027-32 — Define WorkspaceState / PaneNode / TabSpec public types

Single new file: `Sources/WenshuApp/State/WorkspaceState.swift`. No
runtime behavior change (= just types). Atomic-coupled with the
LayoutPreset type (= same file). 1 commit, 1 file.

### 027-33 — WorkspaceStore = the persistence layer

`Sources/WenshuApp/State/WorkspaceStore.swift` (ObservableObject):
- Loads from `wenshu.workspace.json` UserDefaults key on init
- Falls back to the built-in " Default" preset if missing
- `save()` writes back to UserDefaults on every mutation
- `resetToDefault()` = clears the user's custom layout (= restores the
  built-in 6-zone preset)
- `loadPreset(_ preset: LayoutPreset)` / `saveAsPreset(name:)` for
  named layout support

1 commit, 1 file.

### 027-34 — LayoutShellView -> WorkspaceView shell swap

- `Sources/WenshuApp/Views/Onboarding/LibraryRootView.swift` adds the
  `@AppStorage("wenshu.useWorkspace")` flag (= default false; = the
  legacy LayoutShellView is still the default until boss verifies the
  WorkspaceView renders correctly)
- WiredShell branches on `useWorkspace` (= true -> WorkspaceView;
  false -> LayoutShellView)
- WorkspaceView is a thin shell that constructs a default
  WorkspaceState (= the 6-zone preset) and passes it to PaneRenderer

1 commit, 2 files (atomic-coupled).

### 027-35 — PaneRenderer with NativeSplitter fallback

- `Sources/WenshuApp/Views/Layout/PaneRenderer.swift` (= recursive
  pane renderer)
- If SplitView (= from `stevengharris/SplitView`) is importable (=
  dep present), use HSplit / VSplit with WenshuSplitter for hover
- Else (= dep not present or import fails), fall back to HStack /
  VStack with NativeSplitter (the v0.16 in-house splitter)

1 commit, 1 file.

### 027-36 — Tab drag-and-drop (= move tab from one pane to another)

- `Sources/WenshuApp/Views/Layout/PaneRenderer.swift` extended with
  `.onDrag` / `.onDrop` modifiers on each tab title bar
- Drag payload = `TabID` (= SwiftUI `Transferable`)
- Drop target = the pane background (= accepts any TabID; = inserts
  into the target pane's tab list at the drop X)

1 commit, 1 file.

### 027-37 — Split a pane (= right-click " Split Right" / " Split Down")

- Long-press on a tab title bar (= or right-click on the tab title)
- Show a context menu with: Close Tab, Split Right, Split Down, Close
  Pane (= standard Xcode menu)
- " Split Right" -> creates a new pane adjacent with the same tab
- " Split Down" -> creates a new pane below with the same tab

1 commit, 1 file.

### 027-38 — Layout menu in menubar

- Menu bar `View` menu adds a `Layout` submenu:
  - Default (= builtin 6-zone preset)
  - Empty (= one editor pane)
  - Editing ( (= default but with specialized tools collapsed)
  - Researching (= default but with editor collapsed)
  - ...
- Plus a `Save Layout As...` item (= prompts for name; = creates a new
  LayoutPreset)
- Plus a `Reset to Default` item

1 commit, 1 file.

### 027-39 — Boss UAT (= the boss 8/27 30th OOB decision criterion)

Boss stands in front of wenshu and verifies:

1. Default layout = the 6 zones appear (= no visual change from v0.27)
2. Can drag a tab from one pane to another (= the pane accepts the tab)
3. Can split a pane horizontally (= new pane appears to the right)
4. Can save a layout (= a preset shows up in the menu)
5. Can reset to default (= the 6 zones come back)
6. Quit and relaunch (= the custom layout persists)

Boss's verdict on the 6 = the spec is final.

---

## Constraints (= what's NOT in this spec)

- **NOT a `bonsplit` integration** (= network-unstable today; = when
  network recovers, bonsplit can replace the NativeSplitter
  fallback; = this spec does not depend on bonsplit being available)
- **NOT a layout editor in the sense of " visual designer"** (= this
  spec covers pane + tab manipulation, not pixel-perfect drag-anywhere
  editing; = the latter is a v0.28 follow-up if boss wants it)
- **NOT per-library layouts** (= layouts are per-user; = each user
  has one preferred layout across all libraries; = per-library
  overrides are a v0.28 follow-up)
- **NOT a SwiftUI Mac-native replacement for NSPanelSplitView** (= the
  internal PaneRenderer uses HStack / VStack + NativeSplitter; = if
  boss wants true AppKit-native splitters in the future, we can wrap
  NSSplitViewItem; = not in scope here)

---

## Acceptance criteria (= what boss verifies before this spec is final)

Boss verifies:

1. Default 6-zone layout renders identically to the v0.27 LayoutShellView
2. User can drag a tab between panes
3. User can split a pane horizontally / vertically
4. User can save and load named layouts
5. User can reset to default
6. Custom layouts survive an app restart

If boss says any of the 6 is missing or wrong, the spec is amended; =
no ` v0.27 done` until all 6 pass.

---

## Why this spec exists (= design tree audit trail)

Per the grill skill (`~/.hermes/profiles/pocock/skills/mattpocock/
productivity/grilling/SKILL.md`):

- Root decision: 'wenshu UI paradigm' = answered 'Xcode' (= grill D1)
- Sub-decisions B1-B4 (= chat vs editor main stage, draft placement,
  inline citation, success metric) = answered in the same session
- C1: draft -> chapter promotion = physical file move (= answered C1)
- C2: chat-driven AI with auto-Kanban dispatch (= answered C2)
- C3: many-pane UI for AI transparency (= answered C3)
- C4: success metric = friend tryout, not 300k words (= answered C4)
- D1: UI paradigm itself = Xcode ( = answered D1)

This spec commits those grill decisions to disk so the implementation
(= whatever implementation we) can rely on them.

---

## Atomic-coupling rationale

- 027-32 (WorkspaceState types) + 027-33 (WorkspaceStore) = atomically
  coupled because WorkspaceStore reads / writes the WorkspaceState
  schema; = without one, the other has no purpose
- 027-34 (WorkspaceView shell swap) + 027-35 (PaneRenderer fallback)
  = atomically coupled because WorkspaceView cannot render without
  PaneRenderer

Per boss 8/22 (= '1 commit / 1 file; multi-file requires atomic
justification'), every atomic-coupled commit body documents the
coupling.

---

## Open questions (= boss can decide anytime, no urgency)

- O1: When the user splits a pane, does the new pane get a copy of
  the dragged tab, or does the original tab move (= single-instance)?
- O2: Can the user have multiple `editor` tabs (= one per book)?
- O3: Does ` Reset to Default` also clear saved presets, or just the
  current layout?
- O4: When the user closes the last tab in a pane, does the pane
  collapse, or stay empty?

These are deferred (= not blocking the v0.27 ticket breakdown above).

---

*Spec v1.0 · 2026-08-27 · pocock single agent · English-only · project
root = /Volumes/ANAN/Engineering/wenshu*