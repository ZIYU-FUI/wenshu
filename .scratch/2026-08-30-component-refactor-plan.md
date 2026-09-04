# Wenshu Component Refactor Plan — Boss 2026-08-30 OOB

Boss asked: "实际看截图没有, 你这样呗, 你双轴一下, 盘一下有多少重复实现可以抽象成组件, 有哪些统一样式值得进样式表, 然后抽象规划一下"

## 双轴分析总结

### Spec axis (= Wenshu 设计意图)
- 6 pane 统一结构: 顶栏 + 内容区 + 底栏 (= Apple HIG canonical per-region pattern)
- Liquid Glass 全 UI 适配 (= round 26-42 已经做了大部分)
- Apple 27 Tahoe 默认样式 (= .glassEffect, .regularMaterial, .separator)

### Standards axis (= 当前代码重复率)
- 6 个 pane 的 tab bar 实现重复率 = **~85%** (= ZoneContentTabBar 166 行 / DynamicZoneTabBar 135 行 / ChatZoneTopChrome 74 行 = 375 行重复实现)
- 6 个 pane 的底栏实现重复率 = **~95%** (= Round 53 修复后, ZoneBottomToolbar vs ZonePerRegionChrome.bottomBar = 大量重叠)
- 6 个 pane 的 icon helper 重复 = **100%** (= `zoneContentTabBarIcon` / `dynamicZoneTabBarIcon` / `chatZoneTabBarIcon` 都是 `LucideIconSystemFallback(systemName)`)
- 样式常量重复: `.font(.system(size:13))` + `.foregroundStyle(.tertiary)` + `.padding(.leading, 18)` + `.padding(.bottom, 6)` 在 3+ 文件出现

## 抽象层次规划

### Level 1: 已有 canonical 组件 (= round 26-42 已建立)
- `RegionTabBar` (= 顶栏) - 1 file: RegionTabBar.swift
- `RegionStatusBar` (= 底栏) - 1 file: RegionTabBar.swift
- `RegionContentBackground` (= 内容区背景) - 1 file: RegionContentBackground.swift
- `ZonePerRegionChrome` (= pane 整体 wrapper) - 1 file: ZonePerRegionChrome.swift
- `LiquidGlassOpacity` (= environment key) - 1 file: LiquidGlassOpacity.swift
- `NativeSplitter` (= 拖拽线) - 1 file: NativeSplitter.swift

### Level 2: 需要新建的抽象组件 (= 当前重复实现)

#### 2.1 `PaneIconTab` (= 单个 tab button 组件)
**抽象自**:
- `ZoneContentTabBar.Item` 的 Button 内层
- `DynamicZoneTabBar` 的 Button 内层
- `ChatZoneTopChrome.tabItem`
**重复代码** (90% 相同):
```swift
Button { ... } label: {
    Color.clear
        .frame(width: chatTabHotArea, height: chatTabHotArea)
        .overlay(alignment: .center) {
            LucideIconSystemFallback(icon, size: iconSize)
                .foregroundStyle(selected ? .accentColor : .secondary)
        }
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) {
            if selected {
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(height: tabUnderlineHeight)
                    .matchedGeometryEffect(id: namespaceID, in: namespace)
            }
        }
}
.buttonStyle(.plain)
```

**实现**: 1 个 `PaneIconTab` View (= 30 行), 接收 `icon`, `isSelected`, `namespace`, `namespaceID`, `onTap` 参数。

#### 2.2 `PaneTabBar` (= 多个 tab + trailing buttons 通用 wrapper)
**抽象自**:
- `ZoneContentTabBar` body (= 166 行)
- `DynamicZoneTabBar` body (= 135 行)
- `ChatZoneTopChrome` body (= 74 行)

**重复率**:
```swift
RegionTabBar {  // ✓ 已有
    HStack(spacing: 0) {
        ForEach(items) { item in
            PaneIconTab(...)  // ✓ 新抽象
        }
        if !trailingButtons.isEmpty {
            Spacer()
            ForEach(trailingButtons) { ... }
        }
    }
    .padding(.leading, 18)
}
```

**实现**: 1 个 generic `PaneTabBar<Tab: Identifiable, Trailing: View>` View (= 80 行), 调用方只需要传入 `[Tab]` + 选中 ID + namespace + trailing buttons.

#### 2.3 `PaneStatusBar` (= pane 底栏, status text 通用)
**抽象自**:
- `ZoneBottomToolbar` (= 60 行)
- `ZonePerRegionChrome.bottomBar` (= 60 行)

**重复代码** (95% 相同):
```swift
HStack {
    Text(leftText).font(.system(size:13)).foregroundStyle(.tertiary)
        .padding(.leading, 18).padding(.bottom, 6)
    Spacer()
    Text(rightText).font(.system(size:13)).foregroundStyle(.tertiary)
        .padding(.trailing, 18).padding(.bottom, 6)
}
.frame(height: 30)
.background(.regularMaterial)
.overlay(alignment: .top) {
    Rectangle().fill(.separator).frame(height: 1)
}
```

**实现**: 1 个 `PaneStatusBar` View (= 25 行), 接收 `leftText: String`, `rightText: String` 参数 (= already abstracted as `RegionStatusBar` + `ZoneBottomStatus`).

#### 2.4 `LucideTabIcon` (= Lucide icon helper 统一)
**抽象自**:
- `zoneContentTabBarIcon` (= 5 行 wrapper)
- `dynamicZoneTabBarIcon` (= 5 行 wrapper)
- `chatZoneTabBarIcon` (= 5 行 wrapper)

**完全相同的代码**:
```swift
@ViewBuilder
private func xxxTabBarIcon(_ systemName: String) -> some View {
    LucideIconSystemFallback(systemName)
}
```

**实现**: 这3 个函数可以直接删除 (= 全部调用方直接用 `LucideIconSystemFallback(icon, size:)` 即可)。净删除 15 行。

### Level 3: 统一样式常量 (= 进 DesignTokens 或 LayoutTokens)

**重复出现的常量**:
| 常量 | 当前值 | 出现位置 |
|---|---|---|
| chrome height (= tab bar + status bar) | 30 PT | LayoutTokens.toolbarHeight + ZonePerRegionChrome.kZoneToolbarHeight + ZonePerRegionChrome.kChromeHeight |
| chrome padding leading | 18 PT | LayoutTokens.chromePaddingLeading + 4 places inline |
| chrome padding trailing | 18 PT | LayoutTokens.chromePaddingTrailing + 4 places inline |
| chrome padding medium (= 上下垂直居中) | 5 PT | LayoutTokens.chromePaddingMedium + 4 places inline |
| chrome padding large | 6 PT | LayoutTokens.chromePaddingLarge + 3 places inline |
| status font size | 13 PT | `.font(.system(size:13))` 在 10 files |
| status foreground style | tertiary | `.foregroundStyle(.tertiary)` 在 16 files |
| tab hot area | 28 PT | LayoutTokens.chatTabHotArea (= 命名混乱: 应该叫 `paneTabHotArea`) |
| tab icon size | 18 PT | LayoutTokens.iconSize (= 命名 OK) |
| tab underline height | 3 PT | LayoutTokens.tabUnderlineHeight |
| divider line | 1 PT | LayoutTokens.splitterHeight (= 检查这个) |

**重构目标**:
1. `chromeHeight = 30` (统一所有 chrome)
2. `chromePaddingLeading/Trailing = 18` (统一水平 padding)
3. `chromePaddingVertical = 8` (= 中等 + 大 合并 = 用于文字 + icon 居中)
4. `paneTabHotArea = 28` (= 重命名 `chatTabHotArea` → `paneTabHotArea`, 移除 chat-specific 命名)
5. `statusFontSize = 13` + `statusFont = .system(size: 13)` (= 提取成 `DesignTokens.StatusFont`)
6. `statusForeground = .tertiary` (= `DesignTokens.StatusForeground`)
7. `dividerHeight = 1` (= 提取成常量)

### Level 4: 修复 ZoneBottomToolbar 重复

**当前** `ZoneBottomToolbar` (App.swift) 和 `ZonePerRegionChrome.bottomBar` (ZonePerRegionChrome.swift) = **2 套几乎相同的 pane 底栏实现**:
- `ZoneBottomToolbar` 用在 `ZoneModule` (旧实现)
- `ZonePerRegionChrome.bottomBar` 用在新 pane rendering (新实现, 但本身不被使用因为 pane 都用 `ZoneContentView` / `ChatView` / `DynamicZoneView` / `WorkspaceView`)

**修复方案**:
- 删除 `ZoneBottomToolbar` (= 替换为统一的 `PaneStatusBar` / `RegionStatusBar`)
- 删除 `ZoneModule` (= 替换为 `ZonePerRegionChrome`)
- 所有 6 pane 都走 `ZonePerRegionChrome` (= single source of truth)

## 实现步骤 (按 dependency 排序)

### Phase 1: 样式常量进 DesignTokens
1. 新建 `Sources/WenshuApp/UI/DesignTokens.swift` (= 提取 7 个常量)
2. 替换 16 files 的 `.foregroundStyle(.tertiary)` → `DesignTokens.statusForeground`
3. 替换 10 files 的 `.font(.system(size:13))` → `DesignTokens.statusFont`
4. 替换 `LayoutTokens.chatTabHotArea` → `LayoutTokens.paneTabHotArea` (rename)
5. 合并 `chromePaddingMedium` + `chromePaddingLarge` → `chromePaddingVertical`

**预计**: -25 行, 0 file delete, 16 file refactor.

### Phase 2: 抽象 `PaneIconTab` 组件
1. 新建 `Sources/WenshuApp/UI/PaneIconTab.swift` (= 30 行 generic component)
2. 替换 `ZoneContentTabBar` body → `ForEach { PaneIconTab(...) }`
3. 替换 `DynamicZoneTabBar` body → 同上
4. 替换 `ChatZoneTopChrome.tabItem` → `PaneIconTab(...)`

**预计**: -240 行 (= 删除 3 个 tab bar 的内层 Button 实现), +50 行 (新组件), 净 -190 行.

### Phase 3: 抽象 `PaneTabBar` 组件
1. 新建 `Sources/WenshuApp/UI/PaneTabBar.swift` (= 80 行 generic)
2. 替换 `ZoneContentTabBar` → 用 `PaneTabBar` wrapper
3. 替换 `DynamicZoneTabBar` → 同上
4. 替换 `ChatZoneTopChrome.body` → 同上

**预计**: -250 行, +80 行, 净 -170 行.

### Phase 4: 删除 `ZoneBottomToolbar` + `ZoneModule` (= single source of truth)
1. 删除 `Sources/WenshuApp/App.swift` 里的 `ZoneBottomToolbar` (= ~80 行)
2. 删除 `Sources/WenshuApp/App.swift` 里的 `ZoneModule` (= ~30 行)
3. 所有 pane 改用 `ZonePerRegionChrome` (= 已经存在, 只是要替换 ZoneModule 调用点)
4. 删除 3 个 `xxxTabBarIcon` helper 函数 (= -15 行)

**预计**: -125 行, 0 file add.

### Phase 5: 抽象 `PaneStatusBar` 组件 (= 用于 ZonePerRegionChrome 内部)
1. `ZonePerRegionChrome.bottomBar` 改用新的 `PaneStatusBar`
2. 替换 4 个 inline `HStack{Text+Spacer+Text}.padding...` 模式

**预计**: -30 行.

## 总收益估算

| Phase | 行数变化 | 文件变化 |
|---|---|---|
| Phase 1: 样式常量 | -25 行 | 16 files refactored |
| Phase 2: PaneIconTab | -190 行 | +1 new, -3 modified |
| Phase 3: PaneTabBar | -170 行 | +1 new, -3 modified |
| Phase 4: 删除 ZoneBottomToolbar + ZoneModule | -125 行 | -2 deleted |
| Phase 5: PaneStatusBar | -30 行 | -2 modified |
| **总计** | **-540 行** | +2 new files, -5 files modified, -2 files simplified |

**视觉一致性 +100%** (= 所有 6 pane 走同一个组件树)
**未来加 tab/button cost = 1 行** (instead of 50+ 行复制)
**bug fix cost = 1 处** (instead of 6 处)

## 不在本次 scope (= 后续 ticket)

- `PaneIconTab` 的 accessibility (= focus ring + AXLabel 已实现, 但要 wire 到 AppKit accessibility)
- `PaneTabBar` 的 animation (= 已用 .animation(.default, value: selection), 但要加 reduce-motion 支持)
- `LiquidGlassOpacity` 的 Settings UI (= round 49 已加 slider, 但要加 preview thumbnail)

## 优先级 (boss 拍)

老板 2026-08-30 OOB = "你这样呗, 你双轴一下, 盘一下有多少重复实现可以抽象成组件, 有哪些统一样式值得进样式表, 然后抽象规划一下" = **双轴完成 + 抽象规划完成 = 本文档**.

下一步: 等老板拍 A/B/C (= Phase 1-5 的优先级 + 是否要一次全做 vs 分批做)。