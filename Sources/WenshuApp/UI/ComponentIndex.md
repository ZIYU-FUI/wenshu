# Wenshu Component Index — Boss 2026-08-30 OOB

Boss instruction: "你需要做一个组件索引, 以后如果有新的地方用到相同的东西, 会自然而然的找到组件, 而不是默认自动写个新的"

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
  DesignTokens.chromePaddingLeading   // 18 PT
  DesignTokens.chromePaddingTrailing  // 18 PT
  DesignTokens.chromePaddingVertical  // 8 PT
  DesignTokens.paneTabHotArea         // 28 PT (= renamed from chatTabHotArea)
  DesignTokens.tabIconSize            // 18 PT
  DesignTokens.tabUnderlineHeight     // 3 PT
  DesignTokens.dividerHeight          // 1 PT
  DesignTokens.statusFont             // .system(size: 13)
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
          // Your tab buttons here (= use PaneIconTab for canonical tabs)
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
          Text("书架: 0").font(DesignTokens.statusFont).foregroundStyle(DesignTokens.statusForeground)
          Spacer()
          Text("书: 5").font(DesignTokens.statusFont).foregroundStyle(DesignTokens.statusForeground)
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
- **Purpose**: Pane content area background (= maps ZoneSlot to 4-tier Material strength via `.regularMaterial` / `.windowBackgroundColor` / Apple canonical NSColor)
- **Use when**: Setting background of any pane's content area
- **API**: `view.background(RegionContentBackground())`

---

## 🎯 LEVEL 3: Tab bar 组件 (= pane 内的 tab UI)

### 3.1 PaneIconTab (NEW, Phase 2)
- **Path**: `Sources/WenshuApp/UI/PaneIconTab.swift` (NEW)
- **Purpose**: Single tab button (= 28×28 hot area + Lucide icon + selected underline + matchGeometry animation)
- **Use when**: Building ANY per-pane tab with icon + selected state
- **Don't use when**: Tab needs label text (= use SwiftUI's native `Picker`)
- **API**:
  ```swift
  PaneIconTab(
      id: item.id,
      icon: item.icon,
      label: item.label,
      isSelected: item.id == selection,
      namespace: tabBarNamespace,
      namespaceID: "tabBarUnderline",
      onTap: { selection = item.id }
  )
  ```
- **Replaces**: Inline `Button { Color.clear.frame(28,28).overlay { LucideIcon }.overlay(.bottom) { Rectangle }` patterns (= 3 implementations, ~90 LOC each)

### 3.2 PaneTabBar (NEW, Phase 3)
- **Path**: `Sources/WenshuApp/UI/PaneTabBar.swift` (NEW)
- **Purpose**: Generic wrapper for a list of PaneIconTab + optional trailing buttons (= 1 line to create a full tab bar)
- **Use when**: Defining a pane's complete top tab bar (= sidebar/preview/editor/tools/chat/dynamic tabs)
- **API**:
  ```swift
  PaneTabBar(
      items: [
          PaneTabItem(id: "library", icon: "square-library", label: "书架"),
          PaneTabItem(id: "preview", icon: "book-open-text", label: "预览"),
      ],
      selection: $selectedTab,
      trailing: {
          Button { ... } label: { Image(systemName: "gear") }
      }
  )
  ```
- **Replaces**: `ZoneContentTabBar` (166 LOC) + `DynamicZoneTabBar` (135 LOC) + `ChatZoneTopChrome` (74 LOC) = 375 LOC → 80 LOC generic

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
- **Replaces**: `Sources/WenshuApp/UI/RegionHoverWash.swift` (= deleted in v0.32 commit `c52f9b190`; the previous self-written `RegionHoverWashStyle: ShapeStyle` wrapper just returned `.thinMaterial` from its `resolve()` method and added no semantic value over the bare Apple Material catalog value).

### 4.3 RegionSelectionBackground
- **Path**: `Sources/WenshuApp/UI/RegionSelectionBackground.swift`
- **Purpose**: Standard selected state background (= Apple HIG .thinMaterial accent overlay)
- **Use when**: Any view has a selected/unselected state (= tabs, list items, etc.)

---

## 🖱️ LEVEL 5: Interaction 组件

> v0.30 boss 2026-09-01 OOB: NativeSplitter + PaneSplitter + VSplitter
> + StaticDividerVertical/Horizontal were deleted as dead code
> (= superseded by the NSSplitView path which provides drag-to-resize
> + autosave + canCollapse natively). Section 5 entries for those
> types are removed from this index.

### 5.3 Tooltip (Apple SwiftUI `.help()`)

- **Path**: N/A (= SwiftUI built-in modifier).
- **Purpose**: Apple HIG canonical tooltip (= tiny popup on hover/long-press). The OS handles the warm-window delay and the popup rendering (= no custom code).
- **Use when**: Any view needs contextual help text. Apply `.help("Toggle sidebar (⌘B)")` to the view (= Apple canonical since macOS 11).
- **Replaces**: `Sources/WenshuApp/UI/Components/Tip.swift` (= 221-LOC custom `TipController` + `TipModifier` with a hand-rolled 300 ms warm-window; deleted in v0.32 commit by Tier-1 rank-1 deletion per `.scratch/v0.32-apple-api-audit/audit.md` §3).

### 5.4 DropAffordance / NativeControlsInspector

- **Path**: `Sources/WenshuApp/UI/Drag/*.swift`
- **Purpose**: Drag-and-drop infrastructure (= drop zone highlight, control inspector). EscapeLayers + TabStripScroll were retired in v0.31 (= deleted; see v0.31 audit §2.3 + §2.6).

---

## 🧩 LEVEL 6: Icon 组件

### 6.1 LucideIconSystemFallback
- **Path**: `Sources/WenshuApp/Views/LucideIcon.swift`
- **Purpose**: Lucide-first icon renderer with SF Symbol fallback (= always try Lucide, fall back to SF if not found)
- **Use when**: Any tab button, button, or icon needs an icon
- **API**:
  ```swift
  LucideIconSystemFallback("square-plus", size: DesignTokens.tabIconSize)
  ```
- **DON'T**: Use `Image(systemName:)` directly (= bypasses Lucide layer)

### 6.2 Lucide (raw)
- **Path**: `Sources/WenshuApp/Views/Lucide.swift` (bring-shrubbery/lucide-swift wrapper)
- **Purpose**: Raw Lucide icon (= when you know the icon exists in Lucide)
- **Use when**: You want strict Lucide-only (no SF fallback)
- **API**:
  ```swift
  if let lucide = Lucide("square-plus") {
      lucide.frame(width: 18, height: 18)
  }
  ```

---

## 📋 LEVEL 7: Window chrome (= Apple-canonical macOS 26)

Window chrome = 100% Apple canonical per macOS 26 Tahoe. LibraryRootView uses SwiftUI `.toolbar { ToolbarItemGroup }` + `.windowToolbarStyle(.unified)` (= the Pages / Xcode / Mail / Finder pattern).

### 7.1 Apple canonical toolbar (= LibraryRootView)
- **Path**: see `Sources/WenshuApp/App.swift:WindowGroup { ... }` around `LibraryRootView()` + `.windowToolbarStyle(.unified)`
- **Purpose**: 1 macOS native .unified 52 PT titlebar (= traffic lights + grouped toolbar items in 1 unified capsule = the macOS 26 Tahoe canonical look)
- **Use when**: ANY new top-level chrome (= use Apple's `.toolbar` API)
- **Replaces**: All 4 deleted wrappers from v0.34 commit `69a43da65`

### 7.2 Apple canonical status bar (= bottom of window)
- **Path**: see `Sources/WenshuApp/App.swift:WindowGroup { ... }` around `LibraryRootView()` + `.toolbar { ToolbarItem(placement: .principal) { ... }` (= Apple macOS 26 status bar pattern)
- **Purpose**: macOS standard window-level status (= model name / session indicator / ready state) without custom chrome

---

## 🚫 LEVEL 8: 已删除的废弃实现 (= 不要重新写)

These were removed in various phases (= v0.32 Apple-API-first sweep + v0.34 boss iron-rules pass). **If you find yourself writing these patterns, STOP and use the canonical replacement.**

### 8.1 ❌ ZoneModule
- **Was in**: `Sources/WenshuApp/App.swift`
- **Deleted**: Phase 4 (= v0.28 followup Boss UX round A)
- **Use instead**: `ZonePerRegionChrome` (= already exists in `Sources/WenshuApp/UI/ZonePerRegionChrome.swift`)

### 8.2 ❌ ZoneBottomToolbar
- **Was in**: `Sources/WenshuApp/App.swift`
- **Deleted**: Phase 4 (= v0.28 followup Boss UX round A)
- **Use instead**: `PaneStatusBar` (= new in Phase 5, file `Sources/WenshuApp/UI/PaneStatusBar.swift`)

### 8.3 ❌ ZoneContentTabBar / DynamicZoneTabBar / ChatZoneTopChrome (custom tab bodies)
- **Was in**: `Sources/WenshuApp/Views/Dynamic/ZoneContentView.swift` + `DynamicZoneView.swift` + `Workspace/TabContentDispatcher.swift`
- **Refactored**: Phase 2-3 + v0.34 commits `dcde7cff5` + `a6b6c75d3`
- **Use instead**: `PaneTabBar` + `PaneIconTab` + `PaneTrailingIconButton` (= new generic components in `Sources/WenshuApp/UI/PaneTabBar.swift`)
- **Note**: `DynamicZoneTabBar` still survives (= enum ↔ string binding shim = SwiftUI Binding limitation; tracked in backlog.md entry B-02)

### 8.4 ❌ zoneContentTabBarIcon / dynamicZoneTabBarIcon / chatZoneTabBarIcon
- **Was in**: same files as 8.3
- **Deleted**: Phase 3
- **Use instead**: `LucideIconSystemFallback(icon, size:)` directly (= call site)

### 8.5 ❌ LayoutTokens.chatTabHotArea
- **Was in**: `Sources/WenshuApp/UI/LayoutTokens.swift`
- **Renamed**: Phase 1 → `DesignTokens.paneTabHotArea`

### 8.6 ❌ DesignColor.zoneSurface / DesignColor.splitterLine
- **Was in**: `Sources/WenshuApp/UI/DesignColor.swift`
- **Replaced**: Phase 1 (= use `.regularMaterial` + `Color.white.opacity(0.25)` respectively)

### 8.7 ❌ Self-written window chrome wrappers (deleted v0.34)
- **Was in**: 4 custom SwiftUI wrappers under `Sources/WenshuApp/UI/` (= 1 fixed-top + 1 fixed-bottom + 1 polish + 1 overlay) — all deleted in v0.34
- **Deleted**: v0.34 commit `69a43da65` (boss OOB 'use the most reasonable approach, should be unified into one component')
- **Use instead**: SwiftUI `.toolbar { ToolbarItemGroup }` + `.windowToolbarStyle(.unified)` (= Apple macOS 26 canonical pattern; see LEVEL 7.1)
- **Why deleted**: All 4 wrappers duplicated Apple HIG behavior Apple provides for free via `.windowToolbarStyle(.unified)` + `.toolbar { ToolbarItem(placement: .principal) }`. The whole 4-file chrome overlay was never rendered in production.

---

## 🎯 使用流程 (= boss 拍 A 的核心要求)

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

- **Round 26** (v0.28): RegionTabBar / RegionStatusBar / RegionContentBackground introduced (= unified 1 PT .separator + Liquid Glass)
- **Round 50-52** (v0.28): NativeSplitter visibility fix (= white 0.25 divider)
- **Round 53** (v0.28): ZoneBottomToolbar → Liquid Glass (= fixes sidebar mismatch)
- **Phase 1-5** (this commit): Style tokens + PaneIconTab + PaneTabBar + delete ZoneBottomToolbar/ZoneModule + PaneStatusBar

---

## 🔗 相关文档

- `Sources/WenshuApp/UI/ZonePerRegionChrome.swift` (= full per-region chrome architecture)
- `Sources/WenshuApp/UI/LiquidGlassOpacity.swift` (= environment value)
- `Sources/WenshuApp/Views/Layout/NativeSplitter.swift` (= drag splitters)
- `.scratch/2026-08-30-component-refactor-plan.md` (= Phase 1-5 plan)

Last updated: 2026-08-30 (Phase 1-5 implementation + index)