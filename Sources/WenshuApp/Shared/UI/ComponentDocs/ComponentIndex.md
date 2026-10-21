# Wenshu Component Index — 2026-08-30 directive

Directive: "build a component index, so future work that uses the same kind of thing finds the component instead of writing a new one"

## 设计意图

This file is the **canonical reference** for all reusable Wenshu components. **Before writing any new UI code, search this index first**. If a component exists for what you need, USE IT. If a pattern is repeated 3+ times, ADD a component to this index.

This is the single source of truth for: "which component handles X, where it lives, when to use it."

## 索引结构

Each component has:
- **Name**: Component type name
- **Path**: Absolute file path
- **Purpose**: One-line description
- **Use when**: Specific scenarios where this component is the right choice
- **Don't use when**: Anti-patterns (= when to use something else)
- **Example**: Code snippet showing canonical usage
- **Replaces**: Legacy implementations this component supersedes

---

## 🎨 LEVEL 1: 统一样式常量 (= DesignTokens)

### 1.1 DesignTokens
- **Path**: `Sources/WenshuApp/UI/DesignTokens.swift` (NEW, Phase 1)
- **Purpose**: Single source of truth for all chrome dimensions, paddings, font sizes, dividers
- **Use when**: Any code needs a chrome height, padding, status font, divider thickness
- **Don't use when**: One-off local measurement (= use inline CGFloat literal)
- **API**:
  ```swift
  DesignTokens.chromeHeight           // 30 PT
  DesignTokens.chromePaddingLeading   // 8 PT (= Apple HIG canonical 'Spacing.small')
  DesignTokens.chromePaddingTrailing  // 8 PT (= Apple HIG canonical 'Spacing.small')
  DesignTokens.chromePaddingVertical  // 8 PT
  DesignTokens.paneTabHotArea         // 28 PT (= renamed from chatTabHotArea)
  DesignTokens.tabUnderlineHeight     // 3 PT
  DesignTokens.dividerHeight          // 1 PT
  DesignTokens.statusForeground       // .tertiary
  ```
- **Replaces**: All inline `30`, `18`, `13`, `.tertiary` literals scattered across 16+ files

---

## 🧱 LEVEL 2: Pane chrome 组件 (= per-region UI)

### 2.1 ZonePerRegionChrome
- **Path**: `Sources/WenshuApp/UI/ZonePerRegionChrome.swift`
- **Purpose**: Full wrapper for a pane (= top toolbar + content + bottom toolbar, 3-row VStack)
- **Use when**: Defining any of the 6 panes (sidebar / preview / editor / tools / chat / dynamic)
- **Don't use when**: Building a chrome-less content view (= use plain View)
- **API**:
  ```swift
  ZonePerRegionChrome(
      topActions: [ZoneTopAction(id: "...", label: "...", icon: "...", onSelect: { ... })],
      bottomStatus: ZoneBottomStatus(left: "书架: 3", right: "书: 5"),
      topSkip: false,    // = true for editor (= uses internal ZoneContentTabBar)
      bottomSkip: false, // = true for chat (= uses internal ChatBottomToolbar)
  ) {
      // Your pane content here
      SomeView()
  }
  ```
- **Replaces**: `ZoneModule` (legacy, deleted Phase 4)

### 2.2 ZoneTopAction
- **Path**: `Sources/WenshuApp/UI/ZonePerRegionChrome.swift`
- **Purpose**: Value type describing one top toolbar button (= label + icon + callback)
- **Use when**: Adding icon buttons to the top toolbar of any pane
- **API**:
  ```swift
  ZoneTopAction(id: "new-book", label: "新建书", icon: "square-plus", onSelect: { ... })
  ```

### 2.3 ZoneBottomStatus
- **Path**: `Sources/WenshuApp/UI/ZonePerRegionChrome.swift`
- **Purpose**: Value type for pane bottom status (= left text + right text)
- **Use when**: Showing status info at the bottom of a pane
- **API**:
  ```swift
  ZoneBottomStatus(left: "章节: 5", right: "字数: 1234")
  ```

### 2.4 RegionTabBar
- **Path**: `Sources/WenshuApp/UI/RegionTabBar.swift`
- **Purpose**: Canonical 30 PT top tab bar (= .regularMaterial background + 1 PT .separator bottom)
- **Use when**: Building ANY per-pane top tab bar (= zone tabs, chat tabs, dynamic tabs)
- **Don't use when**: Building a standalone toolbar (= use `RegionTabBar` content as inline HStack)
- **API**:
  ```swift
  RegionTabBar {
      HStack(spacing: 0) {
          // Your tab buttons here (= use the native Picker / LabelSegmentedControl)
      }
      .padding(.leading, DesignTokens.chromePaddingLeading)
  }
  ```
- **Replaces**: All manual `.background(.regularMaterial).overlay(.separator)` patterns

### 2.5 RegionStatusBar
- **Path**: `Sources/WenshuApp/UI/RegionTabBar.swift`
- **Purpose**: Canonical 30 PT bottom status bar (= .regularMaterial background + 1 PT .separator top)
- **Use when**: Building ANY per-pane bottom status bar
- **API**:
  ```swift
  RegionStatusBar {
      HStack(spacing: 0) {
          Text("书架: 0").font(.body).foregroundStyle(DesignTokens.statusForeground)
          Spacer()
          Text("书: 5").font(.body).foregroundStyle(DesignTokens.statusForeground)
      }
      .padding(.horizontal, DesignTokens.chromePaddingLeading)
  }
  ```
- **Replaces**: `ZoneBottomToolbar` (legacy, deleted Phase 4)

### 2.6 PaneStatusBar (NEW, Phase 5)
- **Path**: `Sources/WenshuApp/UI/PaneStatusBar.swift` (NEW)
- **Purpose**: Higher-level wrapper around `RegionStatusBar` with built-in left/right status text + Apple HIG padding
- **Use when**: Showing simple "left status + right status" at pane bottom (= most common pattern)
- **API**:
  ```swift
  PaneStatusBar(
      leftText: "书架: 0",
      rightText: "书: 5"
  )
  ```
- **Replaces**: Inline `RegionStatusBar { HStack { Text + Spacer + Text } }` patterns

### 2.7 RegionContentBackground
- **Path**: `Sources/WenshuApp/UI/RegionContentBackground.swift`
- **Purpose**: Pane content area background (= maps TabKind to 4-tier Material strength via `.regularMaterial` / `.windowBackgroundColor` / Apple canonical NSColor)
- **Use when**: Setting background of any pane's content area
- **API**: `view.background(RegionContentBackground())`

---

## 🎯 LEVEL 3: Tab bar 组件 (= pane 内的 tab UI)

### 3.1 PaneTrailingIconButton
- **Path**: `Sources/WenshuApp/Shared/UI/PaneTrailingIconButton.swift`
- **Purpose**: The trailing-slot action button of a tab bar (= icon-only, 28 PT hot area, `.plain` style, `.hoverWash()` background)
- **Use when**: A tab bar needs a trailing action (= the editor's expand/shrink button)
- **Don't use when**: The button is a selection tab (= use the native `Picker` / `LabelSegmentedControl` instead)
- **API**:
  ```swift
  PaneTrailingIconButton(
      icon: "arrow.up.left.and.arrow.down.right",
      tooltip: String(localized: "editor.zone.expand.help")
  ) { toggleZoneExpanded() }
  ```

---

## 🎨 LEVEL 4: Style + visual effects

### 4.1 Liquid Glass background (Apple canonical `.glassEffect(.regular)`)

- **Path**: N/A (= SwiftUI built-in modifier; macOS 27 Tahoe Liquid Glass).
- **Purpose**: Apple canonical Liquid Glass background for any wenshu chrome. Apple auto-adapts to dark mode / Reduce Transparency / Increase Contrast (= system-managed, no per-app slider).
- **Use when**: Any pane / tab bar / status bar / region background needs the canonical macOS Liquid Glass look. Apply `.glassEffect(.regular)` (= standalone View modifier; requires a View receiver — `Color.clear.glassEffect(.regular)` when the glass IS the background, or `.glassEffect(.regular, in: Shape)` for shape-specific glass).
- **Replaces**: The pre-v0.32 hand-rolled 6-step Material ladder + per-app opacity slider. The previous hand-rolled ladder + UserDefaults opacity key + SwiftUI Environment injection + notification plumbing were all removed in v0.32.
- **DON'T**: Re-implement a per-app opacity slider (= Apple's system-wide Reduce Transparency accessibility setting is the canonical knob). Use Apple `.glassEffect(.regular)` instead.

### 4.2 Hover / pressed wash (= bare `.thinMaterial`)

- **Path**: N/A (= SwiftUI Material catalog value, macOS 27 Tahoe).
- **Purpose**: Apple canonical hover/pressed wash (= light Liquid Glass tint). Use bare `.thinMaterial` directly (= no project-local ShapeStyle wrapper).
- **API**:
  ```swift
  // Hover background (when condition is true)
  Color.clear.overlay(.thinMaterial)
  
  // Hover fill on a shape
  RoundedRectangle(cornerRadius: 4).fill(.thinMaterial)
  ```
- **Replaces**: `Sources/WenshuApp/UI/RegionHoverWash.swift` (= deleted in commit `c52f9b190`; the previous self-written `RegionHoverWashStyle: ShapeStyle` wrapper just returned `.thinMaterial` from its `resolve()` method and added no semantic value over the bare Apple Material catalog value).

### 4.3 RegionSelectionBackground
- **Path**: `Sources/WenshuApp/UI/RegionSelectionBackground.swift`
- **Purpose**: Standard selected state background (= Apple HIG .thinMaterial accent overlay)
- **Use when**: Any view has a selected/unselected state (= tabs, list items, etc.)

---

## 🖱️ LEVEL 5: Interaction 组件

> v0.30 (see OOB.md #2026-09-01) OOB: PaneSplitter + VSplitter
> + StaticDividerVertical/Horizontal were deleted as dead code
> (= superseded by the NSSplitView path which provides drag-to-resize
> + autosave + canCollapse natively). Section 5 entries for those
> types are removed from this index.

### 5.3 Tooltip (Apple SwiftUI `.help()`)

- **Path**: N/A (= SwiftUI built-in modifier).
- **Purpose**: Apple HIG canonical tooltip (= tiny popup on hover/long-press). The OS handles the warm-window delay and the popup rendering (= no custom code).
- **Use when**: Any view needs contextual help text. Apply `.help("Toggle sidebar (⌘B)")` to the view (= Apple canonical since macOS 11).
- **Replaces**: `Sources/WenshuApp/UI/Components/Tip.swift` (= 221-LOC custom `TipController` + `TipModifier` with a hand-rolled 300 ms warm-window; deleted in commit by Tier-1 rank-1 deletion per `.scratch/v0.32-apple-api-audit/audit.md` §3).

### 5.4 DropAffordance / NativeControlsInspector

- **Path**: `Sources/WenshuApp/UI/Drag/*.swift`
- **Purpose**: Drag-and-drop infrastructure (= drop zone highlight, control inspector). EscapeLayers + TabStripScroll were retired in v0.31 (= deleted; see audit §2.3 + §2.6).

---

## 🧩 LEVEL 6: Icon 组件

### 6.1 SFIcon (= canonical SF Symbols 6 renderer; the m1 shell 2026-09-15)
- **Path**: `Sources/WenshuApp/UI/IconStyles.swift`
- **Purpose**: Apple SF Symbols 6 icon renderer (= built into macOS 27 = zero SPM dependency). The 2026-09-15 directive 'use SF Symbols 6 (3rd gen) with palette rendering' replaced the Lucide era.
- **Use when**: Any tab button, button, or icon needs an icon
- **API**:
  ```swift
  SFIcon("books.vertical", size: .medium, color: .secondary)
  SFIcon("wand.and.stars", size: .large, rendering: .palette, color: .tint)
  Image(systemName: "magnifyingglass").iconStyle(.chrome)
  ```
- **Rendering modes**: `.monochrome` / `.hierarchical` (default; = Apple HIG chrome) / `.palette` (= per-layer color depth) / `.paletteLayers(Color, Color)` (= explicit two-layer).
- **Weight**: `.regular` (= the 2026-09-15 '细体' (thin) = canonical macOS 27 toolbar weight).

### 6.2 ~~Lucide (raw)~~ — REMOVED 2026-09-15
- **Path**: `Sources/WenshuApp/Views/Lucide.swift` (~~bring-shrubbery/lucide-swift wrapper~~)
- Replaced by SFIcon (§6.1). All 30 Lucide icon names mapped to SF Symbols 6 equivalents (= verified via `/Applications/SF Symbols Beta.app/Contents/Executables/sfsymbols` CLI). See commit message of `81270abe1` for the full mapping table.
- Additional cleanup commits: `1dd6a51d8` (removal of wrapper files + Package.swift dependency), `885a8c785` (closure of remaining enum-property migration gap = 14 `lucideIcon` enum properties renamed to `icon` and 29 view call sites updated), `ed8872fa8` (stale doc/header comment sweep).

---

## 📋 LEVEL 7: Window chrome (= Apple-canonical macOS 26)

Window chrome = 100% Apple canonical per macOS 26 Tahoe. LibraryRootView uses SwiftUI `.toolbar { ToolbarItemGroup }` + `.windowToolbarStyle(.unified)` (= the Pages / Xcode / Mail / Finder pattern).

### 7.1 Apple canonical toolbar (= LibraryRootView)
- **Path**: see `Sources/WenshuApp/App.swift:WindowGroup { ... }` around `LibraryRootView()` + `.windowToolbarStyle(.unified)`
- **Purpose**: 1 macOS native .unified 52 PT titlebar (= traffic lights + grouped toolbar items in 1 unified capsule = the macOS 26 Tahoe canonical look)
- **Use when**: ANY new top-level chrome (= use Apple's `.toolbar` API)
- **Replaces**: All 4 deleted wrappers from commit `69a43da65`

### 7.2 Apple canonical status bar (= bottom of window)
- **Path**: see `Sources/WenshuApp/App.swift:WindowGroup { ... }` around `LibraryRootView()` + `.toolbar { ToolbarItem(placement: .principal) { ... }` (= Apple macOS 26 status bar pattern)
- **Purpose**: macOS standard window-level status (= model name / session indicator / ready state) without custom chrome

---

## 🚫 LEVEL 8: 已删除的废弃实现 (= 不要重新写)

These were removed in various phases (= Apple-API-first sweep + iron-rules pass). **If you find yourself writing these patterns, STOP and use the canonical replacement.**

### 8.1 ❌ ZoneModule
- **Was in**: `Sources/WenshuApp/App.swift`
- **Deleted**: Phase 4 (= followup UX round A)
- **Use instead**: `ZonePerRegionChrome` (= already exists in `Sources/WenshuApp/UI/ZonePerRegionChrome.swift`)

### 8.2 ❌ ZoneBottomToolbar
- **Was in**: `Sources/WenshuApp/App.swift`
- **Deleted**: Phase 4 (= followup UX round A)
- **Use instead**: `PaneStatusBar` (= new in Phase 5, file `Sources/WenshuApp/UI/PaneStatusBar.swift`)

### 8.3 ❌ ZoneContentTabBar / chat-zone wrapper / DynamicZoneTabBar (custom tab bodies)
- **Was in**: `Sources/WenshuApp/Views/Dynamic/ZoneContentView.swift` + `DynamicZoneView.swift` + `Workspace/TabContentDispatcher.swift` (= the zone system; = `ZoneContentView` itself was deleted with the right rail on 2026-10-21)
- **Refactored**: Phase 2-3 + commits `dcde7cff5` + `a6b6c75d3`
- **Use instead**: `LabelSegmentedControl` (= native macOS 27 `NSSegmentedControl`) + `PaneTrailingIconButton` (= `Sources/WenshuApp/Shared/UI/PaneTrailingIconButton.swift`)
- **Note**: `DynamicZoneTabBar` still survives (= enum↔string binding shim = SwiftUI Binding limitation; tracked in backlog.md entry B-02). The chat-zone wrapper (= the since-deleted wrapper that hard-coded the chat tab + archive trailing button, now inlined into `TabContentDispatcher.aiChat` as a single `PaneTabItem(id:"chat")`) was deleted in commit `a6b6c75d3`.

### 8.3b ❌ PaneTabBar / PaneTabItem / PaneIconTab (generic per-pane tab bar)
- **Was in**: `Sources/WenshuApp/Shared/UI/PaneTabBar.swift`
- **Deleted**: 2026-10-21 (= the right-rail dead-code cleanup; = 0 constructors and 0 non-comment references = the pane system had already been replaced by `ZoneContentView`'s inline tab strip)
- **Use instead**: `LabelSegmentedControl` (= the surviving segmented-control wrapper, against the native macOS 27 `NSSegmentedControl`) + `PaneTrailingIconButton` (= the surviving trailing-slot button, now in its own file)

### 8.3c ❌ The right rail (= InspectorView + its 5 pages + 15 tool views + ZoneContentView)
- **Was in**: `Sources/WenshuApp/Features/Editor/View/InspectorView.swift` + `EditorDocumentToolsView.swift` + `ZoneContentView.swift` + the 14 tool views / 12 ops / 12 view-state mirrors under `Sources/WenshuApp/Features/Agent/` + the 12 right-rail agent-tool / domain files + `BookProjectConfigStore` + `WSBookmarkRepository`
- **Deleted**: 2026-10-21 (= the right-rail removal; = the 5-page picker, the 15 tool views and their agent-tool twins had no live user after the top-window cleanup)
- **Use instead**: the empty rail shell (= 8.3d; = the column came back without its tools); = the top toolbar (`ChromeMainToolbar`) is the single source of truth for the window's toolbar buttons, and it now hosts the ⌘K command-palette button

### 8.3d The right-rail shell (= InspectorView, live, no tools)
- **Path**: `Sources/WenshuApp/Features/Editor/View/InspectorView.swift` (89 LOC)
- **Purpose**: The window's trailing inspector column (= the Apple HIG `.inspector` surface; = the active page's title + the shared `EmptyStateView`; = 4 pages, and no page owns a tool yet)
- **Use when**: Giving one of the 4 pages a tool (= that is a new ticket; = the 15 tools the rail used to hold stay deleted, see 8.3c)
- **Don't use when**: Reaching for a tool the rail used to have (= the removal in 8.3c is deliberate)
- **API**:
  ```swift
  InspectorView(appState:workspaceUI:inspectorVisibleBinding:)
  // 4 pages: authoringFiction / authoringStyle / authoringCharacters / projectManagement
  ```
  The page picker (= the 4 page icons) and the column's visibility toggle live in the window toolbar (`ChromeMainToolbar`), which also hosts the ⌘K command palette.

### 8.4 ❌ zoneContentTabBarIcon / dynamicZoneTabBarIcon / chatZoneTabBarIcon
- **Was in**: same files as 8.3
- **Deleted**: Phase 3
- **Use instead**: `SFIcon(icon, size:)` directly (= call site; see LEVEL 6.1)

### 8.5 ❌ LayoutTokens.chatTabHotArea
- **Was in**: `Sources/WenshuApp/UI/LayoutTokens.swift`
- **Renamed**: Phase 1 → `DesignTokens.paneTabHotArea`

### 8.6 ❌ DesignColor.zoneSurface / DesignColor.splitterLine
- **Was in**: `Sources/WenshuApp/UI/DesignColor.swift`
- **Replaced**: Phase 1 (= use `.regularMaterial` + `Color.white.opacity(0.25)` respectively)

### 8.7 ❌ Self-written window chrome wrappers (deleted v0.34)
- **Was in**: 4 custom SwiftUI wrappers under `Sources/WenshuApp/UI/` (= 1 fixed-top + 1 fixed-bottom + 1 polish + 1 overlay) — all deleted in v0.34
- **Deleted**: commit `69a43da65` ('use the most reasonable approach, should be unified into one component')
- **Use instead**: SwiftUI `.toolbar { ToolbarItemGroup }` + `.windowToolbarStyle(.unified)` (= Apple macOS 26 canonical pattern; see LEVEL 7.1)
- **Why deleted**: All 4 wrappers duplicated Apple HIG behavior Apple provides for free via `.windowToolbarStyle(.unified)` + `.toolbar { ToolbarItem(placement: .principal) }`. The whole 4-file chrome overlay was never rendered in production.

---

## 🎯 使用流程 (= the core 2026-08-26 phase-A requirement)

**When writing ANY new UI code**:

1. **Open this index first** (`Sources/WenshuApp/UI/ComponentIndex.md` = your tool)
2. **Find the closest match** in Levels 1-7
3. **If match exists** → USE IT (no new component)
4. **If 3+ repeated patterns emerge** → ADD to index (don't write 3rd copy)
5. **If 1-off** → write inline (= don't pre-abstract)
6. **PR review**: reviewer should check this index (= "did you check ComponentIndex.md?")

This index is the **single source of truth** for "what's reusable in Wenshu". New components MUST be added here (= discoverable).

---

## 📚 历史 (= 已 ship 的重构)

- **Round 26** (RegionTabBar / RegionStatusBar / RegionContentBackground introduced (= unified 1 PT .separator + Liquid Glass)
- **Round 50-52** (NativeSplitter visibility fix (= white 0.25 divider; = superseded by ADR-0011 in 2026-10-04; = the v0.28 file was deleted from tree in the 2026-10-03 Apple multi-column rewrite)
- **Round 53** (v0.28): ZoneBottomToolbar → Liquid Glass (= fixes sidebar mismatch)
- **Phase 1-5** (this commit): Style tokens + PaneIconTab + PaneTabBar + delete ZoneBottomToolbar/ZoneModule + PaneStatusBar

---

## 🔗 相关文档

- `Sources/WenshuApp/UI/ZonePerRegionChrome.swift` (= full per-region chrome architecture)
- `Sources/WenshuApp/UI/LiquidGlassOpacity.swift` (= environment value)
- (Sources/WenshuApp/Views/Layout/NativeSplitter.swift deleted in 2026-10-03 Apple multi-column rewrite; = see ADR-0011; = layout shell = Apple NavigationSplitView + NSSplitViewItem + NSHostingController per AGENTS.md §11 + wenshu-apple-api-first + wenshu-macos26-liquid-glass-pitfalls skills)
- `.scratch/2026-08-30-component-refactor-plan.md` (= Phase 1-5 plan)

Last updated: 2026-08-30 (Phase 1-5 implementation + index)

---

## ✂️ LEVEL 9: Workspace editor sub-views (apple-001 Q2 split)

The Workspace editor surface is decomposed into 9 single-file sub-views (= extracted in commits 6df2ed769 through 485c0bf80). Each lives in its own file under `Sources/WenshuApp/Views/Workspace/`. **When extending the editor surface, find the closest match in this list first**; only create a new file if none of these match.

### 9.1 FormatToolbarButtons
- **Path**: `Sources/WenshuApp/Views/Workspace/FormatToolbarButtons.swift`
- **Purpose**: The 5 inline-formatting toolbar buttons (bold / italic / heading / code / link). Backed by 2 file-local helpers (wrapSelection + prefixCurrentLine) that mutate the @Binding draft.
- **Use when**: Building any inline text-formatting toolbar (= SwiftUI editor surface, not NSTextView native menus).
- **API**: `FormatToolbarButtons(draft: $editorTab.draft)`

### 9.2 ParagraphAIToolbarButtons
- **Path**: `Sources/WenshuApp/Views/Workspace/ParagraphAIToolbarButtons.swift`
- **Purpose**: The 3 paragraph-AI transform buttons (expand / shorten / rephrase) + 1 dropdown Menu for 3 more (shiftTone / simplify / dramatize). Stateless: 3 let parameters (selectedText + isApplying + onApply callback).
- **Use when**: Building a paragraph-level AI transform toolbar (sibling of 9.1, sits to its right in the editor toolbar).
- **API**: `ParagraphAIToolbarButtons(selectedText:, isApplying:, onApply: applyParagraphAI)`

### 9.3 EditModeBadge
- **Path**: `Sources/WenshuApp/Views/Workspace/EditModeBadge.swift`
- **Purpose**: The floating ⌘⇧\ edit-mode badge (8 PT accent dot + label + key combo, .regularMaterial + .tint.opacity(0.3) stroke).
- **Use when**: Surfacing a layout-edit toggle state in any chrome top bar.
- **API**: `EditModeBadge(isEnabled: $bindableAppState.editMode.isEnabled)`

### 9.4 PreviewSortMenuButton
- **Path**: `Sources/WenshuApp/Views/Workspace/PreviewSortMenuButton.swift`
- **Purpose**: The 3-state cycle sort button on the preview pane top-right (pinyinFirstLetter -> createdAt -> modifiedAt -> ...). 1 @Binding + 1 @State (isHover).
- **Use when**: Building a sort-cycle icon button with .onHover tracking.
- **API**: `PreviewSortMenuButton(sortOrder: $previewSortOrder)`

### 9.5 EditorExpandShrinkTrailingButton
- **Path**: `Sources/WenshuApp/Views/Workspace/EditorExpandShrinkTrailingButton.swift`
- **Purpose**: The trailing button on the editor pane's top-right that toggles "Expand Fullscreen" <-> "Restore Layout". Backed by 2 @AppStorage (= editorMaximized Bool + editorExpandSnapshotJSON; = posts .wenshuEditorMaximizedChanged notification that PaneNSController listens for).
- **Use when**: Building a pane expand/shrink trailing button.
- **API**: `EditorExpandShrinkTrailingButton()`

### 9.6 EditorPreviewContent
- **Path**: `Sources/WenshuApp/Views/Workspace/EditorPreviewContent.swift`
- **Purpose**: The SwiftUI ScrollView-based markdown preview renderer for the editor pane (= parses markdown body into Segment[] via parsedSegments + renders each via renderSegment). 2 let parameters (markdownBody: String + wikilinkTarget: EditorView.WikilinkAction).
- **Use when**: Building a pure-SwiftUI markdown preview (= no live edit; = no NSTextView).
- **API**: `EditorPreviewContent(markdownBody:..., wikilinkTarget:...)`

### 9.7 EditorEditContent
- **Path**: `Sources/WenshuApp/Views/Workspace/EditorEditContent.swift`
- **Purpose**: The SwiftUI live-edit surface for the editor pane (= wraps nodes-app/swift-markdown-engine via WenshuMarkdownEditor NSViewRepresentable; forwards engine-side wiki-link clicks back to the host). 8 parameters total (= 1 @Binding + 7 let: originalBody, onSave, onWordCountChange, onDirtyChange, configuration: MarkdownEditorConfiguration, draftId, onLinkClick).
- **Use when**: Building a markdown live-edit surface (TextKit 2-backed by swift-markdown-engine). Requires `import MarkdownEngine`.
- **API**: `EditorEditContent(draft:..., originalBody:..., onSave:..., onWordCountChange:..., onDirtyChange:..., configuration:..., draftId:..., onLinkClick:...)`

### 9.8 EditorContentPlaceholder
- **Path**: `Sources/WenshuApp/Views/Workspace/EditorContentPlaceholder.swift`
- **Purpose**: Empty Color.clear placeholder for the editor pane (= pane background uniformity is applied by ZonePerRegionChrome; = the placeholder is just empty since v0.28 UX round 37 removed the Color.white.opacity(0.55) overlay).
- **Use when**: Building an empty placeholder pane (= no content yet = show Color.clear + let chrome fill the visual contract).

### 9.9 PreviewTabBackground
- **Path**: `Sources/WenshuApp/Views/Workspace/PreviewTabBackground.swift`
- **Purpose**: Empty Color.clear placeholder for the preview pane tab background. Sibling of 9.8.
- **Use when**: Sibling of EditorContentPlaceholder; = same uniformity story (= pane background uniformity is applied by ZonePerRegionChrome).

### 9.10 PaneTrailingIconButton (helper, also used outside Workspace)
- **Path**: `Sources/WenshuApp/UI/PaneTrailingIconButton.swift`
- **Purpose**: Generic trailing icon button with tooltip (= Color.clear base + 28 PT hot area + icon overlay + hover wash + .help tooltip). Shared by EditorExpandShrinkTrailingButton (9.5) AND the chat-zone archive button.
- **Use when**: Building any trailing icon button (= matches 28 PT pane-chrome visual contract).
- **API**: `PaneTrailingIconButton(icon: "...", tooltip: "...", action: { ... })`
---

## 🎨 STYLES (= (see OOB.md #2026-09-07) 'ui 与功能分离' architecture)

2026-09-07 directive: 'make a styles-component file, for managing control styles, this file is like css, so we can manage it better in the future, separating function from style' = abstract ALL chrome/content/icon styling into CSS-like style files (= single source of truth for visual tokens + modifiers; = zones own only FUNCTIONAL wiring). Ponytail principle 'use stdlib / Apple-native / existing dependencies before writing new code': the 4 STYLES files below all wrap Apple canonical APIs (= SwiftUI .padding, .font, .buttonStyle, SF Symbols 6 Image) = no new abstractions over Apple primitives. (the m1 shell 2026-09-15: replaced Lucide library with SF Symbols 6.)

### The 4 STYLES files (= the "CSS-like" layer)

| File | Layer | Concern |
|------|-------|---------|
| `DesignTokens.swift` | VALUES | All chrome dimensions, paddings, font sizes, divider thicknesses (= raw `static let CGFloat` + `Color`) |
| `ChromeStyles.swift` | CHROME | Background + top bar + bottom bar (= what ZonePerRegionChrome wraps each zone with) |
| `ContentStyles.swift` | CONTENT | Content-level inset / typography / button styles (= what each zone's inner UI applies) |
| `IconStyles.swift` | ICONS | SF Symbols 6 icon size + rendering mode + color presets (= canonical icon appearance; the m1 shell 2026-09-15 replaces Lucide library) |

### STYLES-001 ContentStyles.swift
- **Path**: `Sources/WenshuApp/UI/ContentStyles.swift` (NEW, 2026-09-07 round 3)
- **Purpose**: Content-level style primitives (= the inner zone UI; = not the chrome).
- **API**:
  ```swift
  // Inset (= replaces scattered `.padding(.horizontal, 18)` calls):
  .contentInsetStyle(.standard)  // 18 PT all sides
  .contentInsetStyle(.compact)   // 12 PT
  .contentInsetStyle(.none)      // 0 PT (= for List(.sidebar) which has Apple built-in inset)
  
  // Typography (= Apple canonical 11 text styles per iron-rule 2):
  .sectionTypographyStyle(.heading)  // .headline
  .sectionTypographyStyle(.body)     // .body
  .sectionTypographyStyle(.caption)  // .caption
  // ... 11 cases total
  
  // Button (= Apple canonical 4 button styles):
  .actionButtonStyle(.icon)         // .borderless
  .actionButtonStyle(.secondary)    // .bordered
  .actionButtonStyle(.primary)      // .borderedProminent
  .actionButtonStyle(.glassPrimary) // .glassProminent (macOS 27 Tahoe Liquid Glass)
  ```
- **Use when**: Building any zone's content UI (= want to apply a content inset / text style / button style in one canonical call).
- **Don't use when**: You need a one-off local measurement (= then use inline CGFloat / .padding, but mark it with a comment + TODO ticket).

### STYLES-002 IconStyles.swift
- **Path**: `Sources/WenshuApp/UI/IconStyles.swift` (NEW, 2026-09-07 round 3)
- **Purpose**: Canonical SF Symbols 6 icon size + color presets (= single source of truth for icon appearance; = the m1 shell 2026-09-15 replaced the Lucide library with Apple SF Symbols 6).
- **API**:
  ```swift
  SFIcon("books.vertical", size: .medium, color: .secondary)   // chrome top bar identity
  SFIcon("paperplane", rendering: .palette, color: .accent) // 18 PT + accent (= button action)
  SFIcon("books.vertical", rendering: .palette, color: .tint) // 32 PT + tint (= hero / entity badge)
  Image(systemName: "magnifyingglass").iconStyle(.small, color: .secondary)  // explicit size + color
  ```
- **Use when**: Adding any icon to any view (= .iconStyle replaces scattered `.frame(width:N).foregroundStyle(...)` chains).
- **Rendering modes**: `.monochrome` / `.hierarchical` (default) / `.palette` / `.paletteLayers(Color, Color)`.

### 2026-09-07 round 3 audit (= the doubled-padding bug)
2026-09-07: 'measure again, zones 1-2-4 are visibly too large, zone 3 is correct, zone 6 too small' =
- zone 1 sidebar: 23 PT (= List(.sidebar) built-in 8 PT + my ZONE-INSET-002 18 PT = doubled)
- zone 2 cards: 26 PT (= LazyVGrid built-in 8 PT + my 18 PT = doubled)
- zone 3 editor: 18 PT (correct = no Apple built-in inset)
- zone 4 right top: 0 PT (wrong = doesn't route through ZoneContentView at all)
- zone 6 memory: 28 PT (= own 18 PT + own 10 PT = doubled)

**Fix recipe** (= STYLES-004 followup ticket):
1. Pass `.contentInsetStyle(.none)` (= 0 PT) on zones with Apple built-in insets (= sidebar / cards).
2. Pass `.contentInsetStyle(.standard)` (= 18 PT) on zones with no built-in inset (= editor / tools).
3. Audit DynamicZoneView + MemoryRetrievalPanel for their own inline paddings (= replace with `.contentInsetStyle(.standard)`).
4. Route aiDynamic through ZoneContentView so it gets the parent's chrome top bar (= the 2026-09-07 directive 'group the background + top bar + bottom bar into one parent component').

### Why these files instead of scattered inline styles (= the bigger pattern)
- **Iron-rule 6**: no magic numbers in view code (= `.padding(18)` instead of `.padding(.chromePaddingLeading)` = .chromePaddingLeading changes don't propagate).
- **Iron-rule 1**: no hardcoded colors (= `.foregroundStyle(.secondary)` instead of `Color(red: 0.5, green: 0.5, blue: 0.5)` = doesn't auto-adapt to dark mode).
- **Iron-rule 2**: 11 Apple text styles only (= no `.system(size: 17)` magic numbers).
- **2026-09-07 'separate UI from function'**: zone's source file = business logic only (= which tabs render, which buttons open which sheet); visual styling = in the 4 STYLES files. Change a chrome height in ChromeStyles.swift = all 6 zones update = no per-zone audit needed.

---

## 🪟 LEVEL 9: Chrome + independent windows (= 老板 2026-10-16 OOB)

### 9.1 ChromeMainToolbar
- **Path**: `Sources/WenshuApp/Features/Chrome/View/ChromeMainToolbar.swift` (A92, 146 LOC)
- **Purpose**: The 11 independent-window button row in the unified macOS toolbar (= 1 source of truth for the title bar)
- **Use when**: The main window's `.toolbar { ChromeMainToolbar(...) }` modifier (= the 11 windows: kanban + todo + canvas + composer + foreshadowingGraph + cron + attachments + manifest + summaries + libraryMigration + memoryHistory).
- **Don't use when**: Inside a detail column (= a column is column-specific, not window-list); = use that column's own buttons there.
- **API**:
  ```swift
  .toolbar {
      ChromeMainToolbar(openWindow: openWindow, sheetRequests: sheetRequests)
  }
  ```
- **Replaces**: The 2 inline `.toolbar {}` blocks previously in `LibraryRootView.body` (= the original 11 + 9 duplicate in the right rail were both 1 source of truth; = A95 deleted the 9 from the right rail).

### 9.2 WindowOpenButton
- **Path**: `Sources/WenshuApp/Features/Chrome/View/WindowOpenButton.swift` (A94, 98 LOC)
- **Purpose**: Reusable button format for opening an independent macOS window (= 1 source of truth for the toolbar button shape; = uses `Image(systemName:)` directly per Apple HIG; = A97 dropped the SFIcon wrapper for toolbar since the toolbar's NSToolbar defaults pin the icon style)
- **Use when**: Anywhere a SwiftUI surface needs to open an independent window (= toolbar + sidebar + inspector).
- **Don't use when**: Inside the `Window` body itself (= the window already has a body; = don't recursively open a window from inside).
- **API**:
  ```swift
  WindowOpenButton(
      id: WindowID.memoryHistory,
      icon: "brain",
      title: String(localized: "window.memoryHistory.title"),
      openWindow: openWindow
  )
  ```
- **Replaces**: The 3 duplicate `SFIcon + Button { openWindow } + .help(...)` blocks that were inline in `ChromeMainToolbar` + the right rail + `WenshuAppDelegateSwiftDataMigration`.

### 9.3 The 11 dedicated Feature directories (= 1 per window)

Per boss 2026-10-16 OOB "用不用每一个都像截图一样拆出来" (= each window like the screenshot), the 11 toolbar window buttons each have their own Feature directory (= 1 source of truth for the feature = the future feature code goes here).

| WindowID | Feature dir | Window file |
| --- | --- | --- |
| `kanban` | `Features/Kanban/` (pre-existing) | `View/KanbanWindow.swift` |
| `todo` | `Features/Todo/` (NEW A93) | `View/TodoWindow.swift` |
| `canvas` | `Features/Canvas/` (NEW A93) | `View/CanvasWindow.swift` |
| `composer` | `Features/Composer/` (NEW A93) | `View/ComposerWindow.swift` |
| `foreshadowingGraph` | `Features/Foreshadowing/` (NEW A93) | `View/ForeshadowingGraphWindow.swift` |
| `cron` | `Features/Cron/` (NEW A93) | `View/CronWindow.swift` |
| `attachments` | `Features/Attachments/` (NEW A93) | `View/AttachmentsWindow.swift` |
| `manifest` | `Features/Manifest/` (NEW A93) | `View/ManifestWindow.swift` |
| `summaries` | `Features/Summaries/` (NEW A93) | `View/SummariesWindow.swift` |
| `libraryMigration` | `Features/LibraryMigration/` (NEW A93) | `View/LibraryMigrationPanel.swift` |
| `memoryHistory` | `Features/MemoryHistory/` (NEW A93) | `View/MemoryHistoryView.swift` |

When the underlying feature code lands (= the canvas / composer / cron / etc. content), more files will fill in the per-feature Model/Service/Store slots per the §6.2 4-slot spec.

### 9.4 §6.2/§6.5 spec relax (= 4-slot by-need)

Per boss 2026-10-16 OOB "§6.2 选项 1, 按需来" (= use only what each feature actually needs): the previous §6.2 5-slot Apple Backyard Birds shape (`Views/ / ViewModels/ / UseCases/ / Repositories/ / Models/`) is relaxed to the project's actual 4-slot shape (= `Views/ / Model/ / Service/ / Store/`). Empty slots are allowed; = leaf features with ≤3 files skip `Store/`.

§6.5 file naming also relaxed from the Apple suffixes (`View/ / ViewModel/ / UseCase/ / Repository/ / Service`) to the project's actual suffixes (`View/ / Ops/ / Service/ / State`).

### 9.5 §1.7 NFI (§1.11 nervous file index)

The §1.11 NFI table is the single source of truth for "which file split from which god-class". A107 added 12 new rows documenting the chrome toolbar / window / shared / core extractions; = 16+ extracted files now have discoverable 1-step paths from the parent god-class.
