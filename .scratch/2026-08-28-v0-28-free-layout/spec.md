# Wenshu v0.28 — Free Layout Upgrade (Self-Implemented, No Third-Party Framework) spec

> Boss 2026-08-27 OOB final (this session, 2026-08-27 evening):
> - **"我们出现这个议题是因为，我们的前端框架实现拖拽，功能总是经常丢失"** (= the layout-via-3rd-party discussion started because wenshu's previous frontend-framework drag implementations kept losing drag functionality).
> - **"如果你觉得 C，有源码参考，可以让你实现的可以，我建议跑 C"** (= if C [self-implement everything with reference sources] is feasible, boss recommends C).
> - Earlier same day: "你可以完整复刻这个功能吗，我觉得这样对用户更友好，你也更容易落地" (LayoutPicker + ⌘⇧\ 切换).
> - Even earlier (afternoon, this session): "bonsplit，是这个名字" (boss suggested bonsplit before realizing the structural drag-lost issue, then retracted via the C recommendation above).
>
> v0.28 = pure layout upgrade, **fully self-implemented**, **0 third-party view-framework dependencies**. wenshu owns drag-to-resize / drag-tab-between-pane / split tree / ZoneEditor = no future 3rd-party library can break these for us again.
>
> **Critical history (the issue root cause)**:
> - v0.27 027-24..027-30 tested `stevengharris/SplitView` v3.5 → reverted (boss 8/26: "很久没更新了").
> - v0.27 027-31 added `almonk/bonsplit` twice → reverted (network SSL failed both times) → `eabb0bd6e`.
> - `manaflow-ai/cmux` (GitHub 26.4k★) opened issue #2289 on Mar 28, 2026 — **"Rip out Bonsplit and replace it with a direct AppKit split host"**. Public evidence of drag-lost pain in bonsplit.
> - **Pattern**: every third-party view-framework library we tried has been unreliable for drag UX. **Self-implement once, own forever.**
>
> **Why C** (vs A bonsplit / B partial self-implement):
> 1. **Boss's recommendation** = self-implement with reference sources available.
> 2. **Reference sources**:
>    - **hermes** = `/Volumes/ANAN/.hermes/hermes-agent/apps/desktop/src/components/pane-shell/tree/` (650-line `model.ts` + `renderer/` + `zone-editor.tsx` + `presets.ts` = the entire pane system we are replicating, in TypeScript + React).
>    - **bonsplit source** (reference only, NOT a dependency) = `github.com/almonk/bonsplit/blob/main/Sources/Bonsplit/` (MIT-licensed Swift source — read for SwiftUI drag patterns).
> 3. **Drag UX ownership** = no upstream can break our drag. Every regression lands in our own test surface.
> 4. **Hermes LayoutPicker UX = 100% preserved** (⌘⇧\ palette + 4 builtin presets + Save current as + Reset + Done).
>
> **ADR-0008** = full text at `.scratch/2026-08-28-v0-28-free-layout/ADR-0008-no-3rd-party-view-framework.md`:
> "wenshu does not adopt third-party view-framework / pane / dock / split libraries for the WorkspaceView layer. Drag UX must be self-implemented and verified by automated regression tests. Approved exceptions (e.g. `lucide-swift`) are icon-only and do not affect drag."
>
> **Scope retained** (vs the rejected bonsplit path):
> - ✅ WorkspaceState v1 → v2 split tree (hermes `model.ts:163-417` ported)
> - ✅ `PaneRenderer` recursive view (HStack / VStack + NativeSplitter)
> - ✅ Drag-to-resize (extends v0.27 NativeSplitter to recursive tree weights)
> - ✅ **Drag-tab-between-pane** (SwiftUI 27 `.draggable` + `.dropDestination` on macOS 14+, self-implemented; bonsplit source as reference)
> - ✅ 4 builtin presets registered (Default / Focus / Terminal deck / Quad)
> - ✅ LayoutEditMode + ⌘⇧\ shortcut + Escape exit
> - ✅ LayoutPicker floating palette + TreeEditBar + Reset / Done buttons
> - ✅ **ZoneEditor SwiftUI self-implement** (FancyZones port; hermes `zone-editor.tsx` + `grid-model.ts` + `grid-to-tree.ts` as reference)
> - ✅ User preset persistence + delete button
> - ✅ Drag-lost regression test suite (028-011, 7 cases, pre-commit + CI)
> - ✅ Dual-axis code review per boss 8/25 protocol
>
> **Ticket ordering** (after boss ratifies):
> - 028-001 → default rendering = **b** (WorkspaceView on by default; user can opt-in to legacy via Window menu)
> - 028-002 → builtin shape = **II** (FCP Browser 3-pane; chat/dynamic folded into inspector tabs)
> - **Boss 2026-08-27 late clarification**: "如果是用现代码升级，那要保留现在的基础" (= if it's a modern-code upgrade, keep the existing foundation). **LayoutShellView stays** as the legacy fallback; WorkspaceView is the new default. The two coexist; user toggles between them.
> - 028-003 → data model v1 → v2 split tree + ADR-0008
> - 028-004 → WorkspaceView recursive renderer + drag UX
> - 028-005 → 4 builtin presets
> - 028-006 → LayoutEditMode + ⌘⇧\ shortcut
> - 028-007 → LayoutPicker + TreeEditBar floating palette
> - 028-008 → ZoneEditor SwiftUI self-implement
> - 028-009 → User preset persistence + delete UI
> - 028-011 → Drag-lost regression test suite
> - 028-010 → Dual-axis code review

## Boss 8/27 OOB verbatim

1. "你可以完整复刻这个功能吗，我觉得这样对用户更友好，你也更容易落地"
2. "如果区别是固定 6 区到自由布局，那这是一次大升级，而不是替换"
3. "bonsplit 是我们一次框架大升级，用户体验大升级"
4. "你现在不要想，怎么把六区装进去，而是把六区对应的功能装进去。六区不重要，六区的功能才重要"
5. "所以，不要纠结六区。把功能模块抽象出来，规划好放在哪更重要"
6. "我选 B，把现在的项目搞干净，然后启动升级"
7. (Boss's 6 modules: 库管理 / 编辑器 / 特色工具 / Agent / 明盒 / 长文)
8. (Q1 = A: 模块 1 不拆 = World / Character / Reference / SmartQuery 合一个 pane)
9. (Q2 / Q3 / Q4 = 全不做)

## Problem Statement

wenshu v0.27 ships a `WorkspaceState + WorkspaceStore + WorkspaceView` plumbing layer with **one** built-in layout (the 6-zone default) and the persistence + preset management API (`saveAsPreset` / `loadPreset` / `deletePreset` / `resetToDefault`). But the **user-facing UX is missing**:

- No way to discover that multiple layouts exist
- No way to switch between layouts without code editing
- No way to save the current arrangement as a named preset
- No way to define custom grids via drag
- No shortcut key to enter layout edit mode
- No floating palette (the user can't see the picker unless they read the source code)

Boss confirms: the hermes desktop app's LayoutPicker + TreeEditBar + ZoneEditor triad is the right shape. Replicate it 1:1.

## Solution

Add a hermes-style **layout edit mode palette** to wenshu v0.28, triggered by **⌘⇧\**. The palette hosts:

- 4 built-in presets (Default / Focus / Terminal deck / Quad), each as a thumbnail card
- A "+ 新建网格布局" button that opens a SwiftUI ZoneEditor (= FancyZones port, pure SwiftUI for macOS)
- A "将当前排列保存为模板" affordance (= Save current as)
- A "重置" button (= reset to Default preset)
- A "完成" button (= exit edit mode)

All 4 built-in presets align with hermes's pane-id vocabulary (sessions / workspace / files / review / terminal). wenshu maps these to its existing 6 TabKinds (projectSidebar / projectPreview / editor / specializedTools / aiChat / aiDynamic). The mapping is fixed (= the TabKind enum does not expand).

**Existing foundation is preserved**: `LayoutShellView` (the v0.26 fixed 6-zone layout) stays as the opt-in fallback. WorkspaceView is the new default. Both shells share the same `TabKind` and the same `WorkspaceStore`, so user-saved presets survive shell switches. Per boss 2026-08-27: "如果是用现代码升级，那要保留现在的基础" — modernization adds new functionality; nothing is removed.

## User Stories

1. As a writer, I want to press ⌘⇧\ to enter layout edit mode, so that I can rearrange my workspace without reading source code.
2. As a writer, I want the layout palette to appear in the center of the window, draggable, so that I can position it without it blocking my editor.
3. As a writer, I want 4 built-in layout presets (Default / Focus / Terminal deck / Quad) shown as thumbnail previews, so that I can switch layouts by clicking.
4. As a writer, I want to click a preset and have the workspace snap to that layout instantly, so that I can try different arrangements without committing.
5. As a writer, I want the active preset's card highlighted with the accent border, so that I can see which preset I'm currently on.
6. As a writer, I want a "+ 新建网格布局" button with a dashed border, so that the custom-preset entry point is visually distinct from the built-ins.
7. As a writer, I want clicking "+ 新建网格布局" to open a full-screen grid editor with numbered translucent zones, so that I can define custom layouts by splitting and merging.
8. As a writer, I want to click on a zone and see a splitter preview line, so that I know where the split will land.
9. As a writer, I want to hold SHIFT while clicking a zone to flip the splitter orientation, so that I can do horizontal OR vertical splits.
10. As a writer, I want to drag across multiple zones to rubber-band select them, so that I can merge zones into a single pane.
11. As a writer, I want a Merge button to appear when I have a multi-zone selection, so that I know what action to take.
12. As a writer, I want 4 grid templates (Columns / Rows / Grid / Priority) with a zone-count stepper, so that I can quickly create a starting grid.
13. As a writer, I want to resize zones by dragging shared edges, so that I can fine-tune the grid.
14. As a writer, I want to save my current arrangement as a named preset, so that I can recall it later.
15. As a writer, I want to see my custom presets in a separate "自定义" section, so that they're visually distinct from built-ins.
16. As a writer, I want a delete button on hover for each custom preset, so that I can remove ones I no longer want.
17. As a writer, I want built-in presets to have no delete button, so that I can't accidentally remove them.
18. As a writer, I want a "重置" button in the palette header, so that I can return to the Default preset if I mess up.
19. As a writer, I want a "完成" button in the palette header, so that I can exit edit mode.
20. As a writer, I want Escape to exit edit mode, so that I have a keyboard escape hatch.
21. As a writer, I want the palette header to double as a drag handle, so that I can reposition the palette.
22. As a writer, I want the palette position to persist within a session, so that the palette doesn't jump back to center after each toggle.
23. As a writer, I want my custom presets to persist across app launches (via UserDefaults JSON), so that I don't lose my work.
24. As a writer, I want to see the ⌘⇧\ shortcut hint inside the palette, so that I know how to re-enter edit mode.
25. As a writer, I want the palette to show my current preset's title in the header, so that I know where I am.
26. As a writer, I want 4 built-in preset names: "默认 / Focus / Terminal deck / Quad", so that they match hermes's vocabulary.
27. As a writer, I want ZoneEditor save to be disabled when the arrangement is non-guillotine (pinwheel), so that I know why Save is grey.
28. As a writer, I want ZoneEditor to convert my grid into a guillotine tree and register it as a user preset, so that I can immediately use my custom layout.
29. As a writer, I want the existing 6 TabKinds to be hostable in any pane, so that any layout I pick shows the right modules.
30. As a writer, I want WorkspaceStore to keep tracking which preset is active, so that the picker can highlight the active one.

## Implementation Decisions

### Module mapping (Hermes pane-id → wenshu TabKind)

Hermes 4 builtin presets reference panes `sessions / workspace / files / review / terminal`. wenshu maps:

| Hermes pane-id | wenshu TabKind |
| --- | --- |
| sessions | projectSidebar |
| workspace | editor |
| files | projectPreview |
| review | specializedTools |
| terminal | aiChat |
| (extra for Quad bottom-left) | aiDynamic |

### Builtin presets (4 shapes)

The 4 builtin shapes mirror hermes's `controller.tsx:392-432` literal:

- **Default** (5 panes) = the existing v0.27 `makeBuiltinWorkspace()` (upper band 4 + lower band 2 = 6 panes)
- **Focus** (2 panes) = `[projectSidebar, editor-with-projectPreview-and-aiChat-and-aiDynamic-as-tabs]`
- **Terminal deck** (4 panes) = upper band 3 horizontal `[projectSidebar, editor, projectPreview]`, full-width bottom `[aiChat]`
- **Quad** (4 panes) = 2x2 grid `[projectSidebar+projectPreview | editor; aiChat | aiDynamic]` (= projectSidebar + projectPreview merged as tabs on top-left; editor top-right; aiChat bottom-left; aiDynamic bottom-right)

### Data model extension

WorkspaceState v1 uses a flat pane array. v0.28.0 extends it to a **true tree** (`[PaneNode]` becomes `[SplitNode | PaneNode]` recursive):

- Keep `PaneNode` as the leaf (pane + tabs).
- Add `SplitNode` (orientation + ordered children + parallel weights) modeled after hermes's `SplitNode`.
- Add `normalize()` / `removePane()` / `insertAtGroup()` / `movePane()` pure functions (= hermes's model.ts:163-417 verbatim port, adapted for Swift).
- Add `version: 2` schema + migration in `WorkspaceStore.load()` (drop v1 if user has stale data — same as hermes v1 → v2).

### Storage

- UserDefaults `wenshu.workspace.json` for current workspace (= v0.27 already exists, schema bumped to v2)
- UserDefaults `wenshu.workspace.presets` for saved presets (= v0.27 already exists)
- UserDefaults `wenshu.workspace.currentPresetID` for active preset tracking (= v0.27 already exists)
- UserDefaults `wenshu.workspace.editMode` for edit-mode toggle state (NEW)
- UserDefaults `wenshu.workspace.editPalette.x / .y` for palette position (NEW)

### Shortcut binding

- `⌘⇧\` → enter/exit edit mode. Bind via SwiftUI `.keyboardShortcut("\\\\", modifiers: [.command, .shift])` on a hidden button in `WorkspaceView`.
- Escape → exit edit mode (= `useLayoutEditHotkey` pattern, hermes's edit-mode.tsx:21-59).

### View layer

- `Sources/WenshuApp/Views/Workspace/WorkspaceView.swift` — render via `PaneRenderer` (recursive tree walk)
- `Sources/WenshuApp/Views/Workspace/PaneRenderer.swift` — NEW (recursive `HStack`/`VStack` + `NativeSplitter` from `Views/Layout/NativeSplitter.swift`)
- `Sources/WenshuApp/Views/Workspace/LayoutPicker/LayoutPickerCard.swift` — NEW (the palette)
- `Sources/WenshuApp/Views/Workspace/LayoutPicker/PresetThumbnail.swift` — NEW (= TreeThumbnail hermes layout-picker.tsx:26-51 port)
- `Sources/WenshuApp/Views/Workspace/LayoutPicker/PresetCard.swift` — NEW (= PresetCard hermes layout-picker.tsx:62-109 port)
- `Sources/WenshuApp/Views/Workspace/LayoutPicker/SaveCurrentLayoutButton.swift` — NEW (= "Save current as" hermes layout-picker.tsx:162-200 port)
- `Sources/WenshuApp/Views/Workspace/LayoutPicker/ZoneEditor.swift` — NEW (= hermes zone-editor.tsx:91+ port, SwiftUI pure)
- `Sources/WenshuApp/Views/Workspace/LayoutPicker/GridModel.swift` — NEW (= hermes grid-model.ts port)
- `Sources/WenshuApp/State/LayoutEditMode.swift` — NEW (= `$layoutEditMode` atom port, ObservableObject)

### Tree edit bar (= floating palette)

- `Sources/WenshuApp/Views/Workspace/LayoutPicker/LayoutEditBar.swift` — NEW (= hermes edit-bar.tsx:25-108 port, 26rem wide, centered, draggable header, reset + done buttons, LayoutPicker inside)

### Apple HIG compliance

- All overlays use SwiftUI's native `.popover` / `.sheet` / `Window` chrome
- Buttons follow wenshu's `IconButtonStyle` (Color.clear 28x28 hot area + Lucide icon overlay + .foregroundStyle(.secondary)) from v0.27 toolbar capsules
- "重置" = secondary button (ghost variant), "完成" = primary button (default variant)
- "+ 新建网格布局" = dashed border button (ghost + dashed stroke)
- Drag handle = `cursor` cursor + `.onDrag` modifier

### i18n

wenshu uses SwiftUI's `LocalizedStringKey` for user-facing strings. New strings:

| English (fallback) | 中文 |
| --- | --- |
| "Layout" | "布局" |
| "Choose a layout, or drag panels between zones" | "选择一个布局，或在区域之间拖动面板" |
| "Templates" | "模板" |
| "Custom" | "自定义" |
| "+ New grid layout" | "+ 新建网格布局" |
| "Save current arrangement as template" | "将当前排列保存为模板" |
| "Reset" | "重置" |
| "Done" | "完成" |
| "Default" | "默认" |
| "Focus" | "Focus" (keep English per hermes) |
| "Terminal deck" | "Terminal deck" (keep English per hermes) |
| "Quad" | "Quad" (keep English per hermes) |
| "Delete preset" | "删除模板" |
| "Name this layout" | "为这个布局命名" |
| "Save" | "保存" |
| "Cancel" | "取消" |
| "Columns" | "列" |
| "Rows" | "行" |
| "Grid" | "网格" |
| "Priority" | "优先级" |
| "Zones" | "区域数" |
| "Merge zones" | "合并区域" |
| "Save layout" | "保存布局" |
| "Non-guillotine arrangement cannot be saved" | "非规整分割的布局无法保存" |

## Testing Decisions

- **Unit tests** for `WorkspaceState.normalize()` / `removePane()` / `insertAtGroup()` / `movePane()` (= pure functions, hermes has the same tests; port verbatim).
- **Snapshot tests** for `LayoutEditBar` (= boss 8/27 grill: visual identity matters).
- **Integration tests** for `WorkspaceStore.saveAsPreset(name:)` / `loadPreset(_:)` / `deletePreset(_:)` / `resetToDefault()` (already partially tested in v0.27; extend).
- **Manual smoke test** for ⌘⇧\ shortcut (no automated key shortcut test today; follow v0.27 precedent).
- **Manual smoke test** for ZoneEditor full flow (drag split / merge / resize / save).
- **Round-trip JSON test** for WorkspaceState v2 (= encode → decode → equal).

## Out of Scope

- New TabKind cases (= modules 3 / 6 stay deferred to v0.29+)
- Per-(book) layout overrides (= v0.29+)
- Per-(project) layout sharing across users (= v0.29+)
- Animated transitions between presets (= v0.29+; current spec = instant snap)
- Cross-window layout sharing (= v0.29+)
- Layout import/export (= v0.29+)
- Cmd+G for review pane toggle (= already in v0.27 keybinds; not changed in v0.28)

## Further Notes

- The 4 builtin names ("Focus / Terminal deck / Quad") keep English because they map directly to hermes's vocabulary; 中文 would be "专注 / 终端台 / 四分屏" but wenshu uses hermes's labels for parity.
- ZoneEditor is pure SwiftUI because AGENTS.md §11.1 forbids third-party SwiftUI controls for FancyZones-style editors. Apple has no built-in component; we port the grid model + interactions ourselves.
- Palette position uses absolute PT (lastPalettePos pattern, hermes edit-bar.tsx:17).
- ⌘⇧\ is reserved in macOS for "Toggle Full Keyboard Access" in some locales; wenshu uses it anyway (= matches hermes; macOS allows app-level override).