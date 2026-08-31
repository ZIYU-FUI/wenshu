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
- **Purpose**: Pane content area background (= reads `liquidGlassOpacity` env value, maps to 4-tier Material strength)
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

### 4.1 LiquidGlassOpacity environment value
- **Path**: `Sources/WenshuApp/UI/LiquidGlassOpacity.swift`
- **Purpose**: Read user's Liquid Glass opacity preference (= 0.0 to 1.0, set by Settings slider)
- **Use when**: Any chrome view that should respect the user's opacity preference
- **API**:
  ```swift
  @Environment(\.liquidGlassOpacity) var liquidGlassOpacity: Double  // 0.0 - 1.0
  
  // Apply:
  Color.clear.overlay(liquidGlassOpacity > 0.5 ? AnyShapeStyle(.regularMaterial) : AnyShapeStyle(.ultraThinMaterial))
  ```
- **DON'T**: Use `.regularMaterial` directly (= bypasses user preference)

### 4.2 RegionHoverWash
- **Path**: `Sources/WenshuApp/UI/RegionHoverWash.swift`
- **Purpose**: Standard hover state wash (= Apple HIG .thinMaterial overlay on hover)
- **Use when**: Any tappable view needs hover feedback (= buttons, list rows, etc.)
- **API**:
  ```swift
  view.background(RegionHoverWash(isHovered: isHovered))
  ```

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

### 5.3 Tip
- **Path**: `Sources/WenshuApp/UI/Components/Tip.swift`
- **Purpose**: Apple HIG canonical tooltip (= tiny popup on hover/long-press)
- **Use when**: Adding contextual help to any UI element

### 5.4 DropAffordance / EscapeLayers / NativeControlsInspector / TabStripScroll
- **Path**: `Sources/WenshuApp/UI/Drag/*.swift`
- **Purpose**: Drag-and-drop infrastructure (= drop zone highlight, escape-key dismissal, control inspector, horizontal tab scrolling)

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

## 📋 LEVEL 7: Window chrome (= app-level)

### 7.1 AppTitlebar
- **Path**: `Sources/WenshuApp/UI/AppTitlebar.swift`
- **Purpose**: Custom macOS titlebar (= 32 PT toolbar with model selector + session indicator)
- **Use when**: Building app-level titlebar variants

### 7.2 AppStatusbar
- **Path**: `Sources/WenshuApp/UI/AppStatusbar.swift`
- **Purpose**: Bottom-of-window status bar (= "MiniMax-M3  Idle" + "wenshu v0.28  Sessions")
- **Use when**: Building app-level status bar

### 7.3 TitlebarStatusbarPolish
- **Path**: `Sources/WenshuApp/UI/TitlebarStatusbarPolish.swift`
- **Purpose**: Polish layer for titlebar/statusbar (= hover/pressed state washes, .thinMaterial)
- **Use when**: Adding interactive feedback to titlebar/statusbar buttons

### 7.4 WenshuChromeOverlay
- **Path**: `Sources/WenshuApp/UI/WenshuChromeOverlay.swift`
- **Purpose**: Window-level chrome overlay (= optional unified macOS window chrome wrapper)

---

## 🚫 LEVEL 8: 已删除的废弃实现 (= 不要重新写)

These were removed in Phase 4 (= single source of truth cleanup). **If you find yourself writing these patterns, STOP and use the canonical replacement.**

### 8.1 ❌ ZoneModule
- **Was in**: `Sources/WenshuApp/App.swift`
- **Deleted**: Phase 4
- **Use instead**: `ZonePerRegionChrome` (= already exists in `Sources/WenshuApp/UI/ZonePerRegionChrome.swift`)

### 8.2 ❌ ZoneBottomToolbar
- **Was in**: `Sources/WenshuApp/App.swift`
- **Deleted**: Phase 4
- **Use instead**: `PaneStatusBar` (= new in Phase 5)

### 8.3 ❌ ZoneContentTabBar / DynamicZoneTabBar / ChatZoneTopChrome (custom tab bodies)
- **Was in**: `Sources/WenshuApp/Views/Dynamic/ZoneContentView.swift` + `DynamicZoneView.swift` + `Workspace/PaneRenderer.swift`
- **Refactored**: Phase 2-3
- **Use instead**: `PaneTabBar` + `PaneIconTab` (new generic components)

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