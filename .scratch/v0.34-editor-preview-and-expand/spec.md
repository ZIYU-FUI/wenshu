# v0.34 Editor Preview/Edit Toggle + Expand Fix = Obsidian-Style Editor Zone

## Boss 2026-09-02 OOB (final, after multi-round grill)

老板原话 (= 按用户原话记录, 不二次解释):

1. **"双击预览区的文件卡片后, 再编辑器区, 打开文档"**
   - 双击 `PreviewPane` 卡片 = 触发 "在编辑器区打开该文档"
   - 编辑器区仍在 6 区中 (= 不放大, 只是从 placeholder 切到文档视图)

2. **"类似 Obsidian 有两种模式, 预览模式, 只看不能编辑, 可以切换编辑模式, 可以打字编辑, 保存文档"**
   - editor zone 内部有 2 模式 toggle:
     - **预览模式** (默认) = 渲染后 MD, 只读不可编辑
     - **编辑模式** = `TextEditor` textarea, 可打字 + 保存
   - 切换 = 顶栏 toggle button (= eye / pencil icon)

3. **"编辑器的功能不超出编辑器区域"**
   - 所有 editor 功能在 editor zone 内 (= 不弹 modal, 不分屏, inline)

4. **"六区状态下, 工具最简, 展开编辑区后, 完整 MD 编辑器全功能"**
   - 6 区默认状态: editor zone 是 placeholder ("选文档后展开"), 无 toolbar
   - 双击 PreviewPane 卡片后: editor zone = preview mode 渲染 + 顶栏 toolbar (mode toggle + save + expand)
   - 展开编辑区 (展开按钮) 后: editor zone = 全屏 + 完整 toolbar (= 同 toolbar 但全屏空间)

5. **"在编辑区顶栏的右边的那个 icon 就是" (展开按钮已存在, 现在有 bug)**
   - 已存在的 `EditorExpandShrinkTrailingButton` (= 今晚 commit `88c2858e2`)
   - 当前 bug: 点击 icon 不响应 (= 只 toggle `@State`, 没联动 layout)

## Bug 定位 (= Q33 答案)

`WorkspaceView.swift:540` 现有代码:
```swift
@State private var editorMaximized: Bool = false
icon: editorMaximized ? "↘" : "↖",
action: { editorMaximized.toggle() }
```

`editorMaximized` 是 View-local `@State`, action 只翻转 bool, **没联动 NSSplitViewItem.isCollapsed** = 其他 5 区不隐藏。

**Bug = (Q33-a + Q33-d 复合)**: icon 视觉有响应 (icon 切了), layout 完全没动。

## Design (走 Q34 8-step chain)

### Q34 decisions (= grill 第 1 轮闭环)

| Q | 决定 |
|---|---|
| Q1 | 双击 PreviewPane = 在编辑区打开文档 (60% 格子); 展开按钮 = 独立 icon, 触发几何放大 |
| Q2 | 编辑器放大 = 联动 5 个 NSSplitViewItem.isCollapsed (其他 5 区隐藏), 不是新窗口 overlay |
| Q15 | 联动路径 = 复用 PaneNSController.handleToggleZone infrastructure (= 今晚 commit `125840d0f`) |
| Q34 | 持久化用 `@AppStorage` (= Rule 11 铁律 + Apple HIG standard) |
| Q38 | snapshot = 全状态 (`zoneVisible: [ZoneSlot: Bool]` + `editorWeight: Double` + `editorMaximized: Bool`) |
| Q43 | snapshot 触发 = 每次 expandEditor() 第一行 snapshot (= 覆盖旧的) |

### User Stories (= Obsidian 风格 editor zone)

1. As an editor user, I want to double-click a PreviewPane card, so that the document opens in the editor zone (= 6 区 default layout, editor zone 60% width).
2. As an editor user, I want the editor zone to show rendered Markdown (= bold / italic / headings / lists), so that I can read the document as it'll appear in Obsidian preview mode.
3. As an editor user, I want the editor zone to NOT show textarea by default, so that I don't accidentally type in read-only mode.
4. As an editor user, I want a single toggle button in the editor top bar (eye ↔ pencil), so that I can switch between preview and edit modes (= 1 click, no menu).
5. As an editor user, I want the toggle button icon to update (= eye in preview, pencil in edit), so that I always know which mode I'm in.
6. As an editor user, I want a Save button in the editor top bar, so that I can persist my edits (= Cmd+S also works).
7. As an editor user, I want the Save button to be highlighted (= .tint color) only when there are unsaved changes, so that I know when saving is needed.
8. As an editor user, I want a Close button (= ×) in the editor top bar, so that I can collapse the editor back to placeholder (= with confirm dialog if dirty).
9. As an editor user, I want `[[wikilink]]` rendered as clickable links in preview mode, so that I can navigate between linked notes (= Obsidian wikilink syntax 1:1).
10. As an editor user, I want the preview mode to render the wikilink destinations using wenshu's `InternalLinkParser`, so that links resolve to the same `[[name]]` syntax that the wiki layer uses (= consistency with LLM Wiki 4-layer pipeline).
11. As an editor user, I want a Backlinks panel at the bottom of the editor zone (in preview mode), so that I can see which other notes reference the current document (= wenshu's `BacklinksPanel` reused).
12. As an editor user, I want preview mode to use wenshu-pinned `swift-markdown 0.4.0` library, so that GFM parsing is consistent with the LLM Wiki layer (= same parser stack).
13. As an editor user, I want edit mode to use Apple SwiftUI `TextEditor` (= not a custom NSTextView wrapper), so that I get standard macOS text editing behaviors for free (= undo, find, accessibility).
14. As an editor user, I want a separate "Expand" button in the editor top bar (= ↗), so that I can dedicate the window to writing (= editor zone goes full window, other 5 zones hidden).
15. As an editor user, I want the Expand button to toggle to "Shrink" (= ↙) when expanded, so that I can collapse back to the 6-zone layout.
16. As an editor user, I want clicking Expand to hide the other 5 zones (= sidebar / preview / tools / chat / dynamic) and let the editor take the full window, so that I can focus on writing without distractions.
17. As an editor user, I want clicking Shrink (= ↙) to restore the other 5 zones to their visibility state from BEFORE I clicked Expand, so that the 6-zone layout comes back exactly as I left it.
18. As an editor user, I want the Expand/Shrink behavior to NOT persist across app launches (= it's a transient focus mode), so that the next launch starts in the default 6-zone layout.
19. As an editor user, I want Cmd+S to save the current document (= works in both 6-zone and expanded modes), so that the standard macOS keyboard shortcut works.
20. As an editor user, I want Cmd+E to toggle preview/edit mode, so that I can switch without reaching for the toolbar.
21. As an editor user, I want Cmd+W (= Close) to collapse the editor to placeholder (= with confirm dialog if dirty), so that I have a standard way to dismiss.
22. As an editor user, I want the dirty detection to be character-level diff (`draft != originalBody`), so that the Save button lights up on any change.
23. As an editor user, I want the editor top bar layout to be: [document name (left)] [mode toggle (center)] [save] [expand] [close (right)], so that the toolbar is consistent across both 6-zone and expanded modes.
24. As an editor user, I want closing the editor to put it back to placeholder mode (= shows hint text "选文档后展开"), so that I have a clear way to "no document selected".
25. As an editor user, I want the editor top bar to disappear (= or be hidden) in placeholder mode, so that there's no confusing toolbar when there's no document loaded.

### Implementation Decisions

**A. Mode toggle**:
- `EditorMode` enum: `.preview` (default), `.edit`
- State owner: `@State private var mode: EditorMode` (View-local, persists only while document is open)
- Initial mode on document open = `.preview` (= boss spec: "默认是预览模式")
- Mode toggle button: PaneTrailingIconButton with icon `eye` ↔ `pencil`, tooltip "预览模式" / "编辑模式"

**B. Preview mode rendering**:
- Library: `swift-markdown 0.4.0` (= AGENTS.md §11.1 pinned dep)
- Entry: `import Markdown` + `Document(parsing: rawBody)` (or `AttributedString(markdown: rawBody)` for SwiftUI Text)
- `[[wikilink]]` rendering: pipe `InternalLinkParser` output into the SwiftUI Text (= wenshu's existing parser, = 1:1 Obsidian wikilink syntax)
- Backlinks panel: integrate `BacklinksPanel` (= wenshu's existing view in `Core/LinkGraph/`) at the bottom of the preview area

**C. Edit mode textarea**:
- Apple SwiftUI `TextEditor(text: $draft)` (= HIG standard, Rule 7 system component)
- `@State private var draft: String` (= View-local, separate from original body snapshot)
- Dirty detection: `draft != originalBody` (character-level)
- Save: `try? body.write(toFile: docPath, atomically: true, encoding: .utf8)`

**D. Expand/Shrink**:
- `EditorExpandShrinkTrailingButton` (already exists at WorkspaceView.swift:540) — REPAIR existing bug
- New `@AppStorage("wenshu.editorMaximized")` (= Rule 11 = standard storage, boss grilled Q35)
- New `@AppStorage("wenshu.editorExpand.snapshot")` (= JSON-encoded snapshot of `[ZoneSlot: Bool]` + `editorWeight`)
- New `WorkspaceStore` method... NO: direct `@AppStorage` access in EditorExpandShrinkTrailingButton (= Rule 11 single source of truth, no WorkspaceStore method)
- New `NotificationCenter` post: `.wenshuEditorMaximizedChanged` (new entry in AppCommands enum per B-04 = commit `95a2d96ba`)
- `PaneNSController.handleEditorMaximizedChanged(_:)` NEW method (= mirrors existing `handleToggleZone(_:)`):
  - When maximized = true: snapshot 6 zone visible + editor weight (= save to UserDefaults JSON BEFORE collapsing)
  - Then trigger 5 `zoneToggle(.projectSidebar / .projectPreview / .specializedTools / .aiChat / .aiDynamic)` animator calls (= hide all 5)
  - Adjust editor zone weight to 1.0 (= Apple NSSplitViewItem default behavior = take remaining space)
  - When maximized = false: read snapshot from UserDefaults JSON, restore 6 zone visible (= call zoneToggle animator for each), restore editor weight

**E. Toolbar layout** (= always same, regardless of expand state):
- 28 PT height (= matches `DesignTokens.paneTabHotArea`)
- Left: `[document basename]` text label (= 12 PT secondary)
- Center: `[mode toggle button]` (= PaneTrailingIconButton with eye / pencil)
- Right: `[save button (highlighted when dirty)] [expand button] [close button]`

**F. State persistence**:
- `@AppStorage("wenshu.editorMaximized")` = `false` (= expanded state = transient, doesn't persist across launches)
- `@AppStorage("wenshu.editorExpand.snapshot")` = snapshot (for shrink restore, but written every expand = transient)
- Document open path = NOT persisted (= boss didn't ask for it = transient, in-memory only)
- Document last-edited contents = persisted via the .md file write (= per Apple HIG)

**G. Notification integration (= B-04 backward-compat)**:
- New `AppCommands.editorMaximizedChanged: Notification` enum case (= added to existing `AppCommands` enum in `AppNotifications.swift` per B-04)
- Backward-compat accessor: `Notification.Name.wenshuEditorMaximizedChanged` (= existing pattern from B-04 commit `95a2d96ba`)

### Testing Decisions

- **External behavior only**: simulate button clicks, verify zone visibility flips, verify editor content updates
- **Unit test target**: PaneNSController.handleEditorMaximizedChanged (= test with mock NSSplitViewItem)
- **Snapshot roundtrip test**: expand → snapshot stored → shrink → snapshot restored (= verify all 6 zone visibility values match)
- **Prior art**: existing `handleToggleZone(_:)` unit tests in `PaneNSControllerTests.swift` (if exist; if not, follow the same manual-test pattern from `v0.30 boss-sidebar-feedback-bundle/spec.md`)
- **Manual verification required**: macOS screencapture of expand state (= editor full window) + shrink state (= 6 zones restored)

### Out of Scope

- Code-fence syntax highlighting in edit mode (= not requested by boss = v0.35+ ticket for HighlighterSwift consumer)
- Multiple documents open in editor (= boss spec = single document; multi-tab = v0.35+ ticket)
- Rename / move / delete document from editor (= boss spec = read + edit; rename = sidebar feature)
- Auto-save (= boss spec = explicit Save button only; auto-save = v0.35+ ticket)
- Format toolbar (bold / italic buttons) (= boss spec = pure TextEditor MD source; rich formatting = v0.35+ ticket)
- External-file-change conflict resolution (= mtime detection = v0.35+ ticket; current = simple overwrite)
- LLM Wiki layer integration in preview (= wenshu's `LLMWikiLayerDeriver` = backend only, not surfaced in editor zone = v0.35+ ticket)
- ForeshadowingGraph visualization (= wenshu has `ForeshadowingGraph` service but no editor integration = v0.35+ ticket)
- JSON Canvas / Obsidian Bases rendering (= boss didn't mention = v0.35+ tickets)
- Smart Connections AI query panel in editor (= wenshu has `SmartQueryView` but no editor integration = v0.35+ ticket)

### Apple HIG compliance (= Rule 8 / Rule 7 / Rule 11)

- **Rule 7 (Buttons / controls)**: `Button` + system `buttonStyle`, no custom-drawn icons (= Lucide only per AGENTS.md §11.1)
- **Rule 8 (Window / scene)**: editor zone stays within `WindowGroup { ... }` scene tree, no new NSWindow (= boss explicitly rejected overlay-window approach in Q16 → Q38)
- **Rule 11 (State persistence)**: `@AppStorage` (= Apple HIG standard storage), not `UserDefaults.standard.set/get` directly, not custom WorkspaceStore methods

### Cross-cutting (= Iron Rules applied)

- **Rule 6 (Layout / spacing)**: editor top bar uses `DesignTokens.paneTabHotArea = 28 PT` (= no magic numbers)
- **Rule 9 (Menu / shortcuts)**: Cmd+E / Cmd+S / Cmd+W standard macOS shortcuts via `.keyboardShortcut()`
- **Rule 10 (Tab / navigation)**: editor zone stays inside the 6-zone `PaneSplitHost` (= no new tab bar; navigation between docs = sidebar click)
- **AGENTS.md §11.1 (3rd-party libs)**: use pinned `swift-markdown 0.4.0` (= NOT add new deps for editor; = NOT use `nodes-app/swift-markdown-engine` per .scratch/2026-08-28-six-module-audit REJECT)

Last line: fact.
