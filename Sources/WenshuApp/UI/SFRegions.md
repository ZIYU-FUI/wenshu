<!--
  SFRegions.md · Wenshu · Apple HIG region view wrappers

  Per (see OOB.md #2026-10-06): "中央工厂保留，但一个区域一个定义，
  中央工厂不是只生产一种东西，按应用位置不同，加工成不同的要求，
  都按苹果的标准走，除非没有办法有苹果的标准".

  This file is the **index** for wenshu's "按区域提需求" workflow.
  When the boss asks for a visual change, name the **region**
  (= sidebar row / toolbar button / empty state / etc.) and the
  corresponding view wrapper changes in one place = every call
  site in that region inherits the change.

  Wrapper names walk the SF{Region}{Role} convention (= SFIcon,
  SFLabelRow, SFStatusBadge, SFCardHero, SFToolbarButton,
  SFListRow, ...) so they sit alongside Apple's SF Symbols in
  autocomplete and code search.
-->

# SF Regions — wenshu 按区域 view 包装器索引

## 老板提需求语法

> "sidebar 行间距改 4 PT" / "empty state 字号改大" / "toolbar
> 按钮 hot area 加 4 PT" / "card icon 缩到 48 PT"

老板只说 **区域名**（sidebar / empty state / toolbar / card /
list / status badge）+ **改什么**（间距 / 字号 / hit area / icon
size）。我按本表找到对应包装器，改 1 处 → 全区域 N 个调用点自动
生效。

## 包装器清单

| 区域（老板用语） | 包装器名 | Apple 内部形态 | wenshu 调用点 |
|---|---|---|---|
| sidebar row | `SFLabelRow` | `Label { ... } icon: { ... }` | `Sources/WenshuApp/Views/Library/SidebarRowView.swift` |
| single icon（通用图标） | `SFIcon` | `Image(systemName:)` 配 IconStyle | 110 处（v3.0 sweep 全量） |
| empty state | `EmptyStateView` | `VStack { icon + title + body }`（自建 = Apple HIG `ContentUnavailableView` 模式） | 12 个 specialized tool tabs + editor + PreviewPane |
| pane tab bar | `PaneTabBar` | 自建 = NSToolbar item pattern | pane tab 系统 |
| section header | `SectionHeader` | 自建 = Apple HIG section header pattern | 多处 |
| memory entry row | `MemoryEntryRow` | 自建 = Apple Mail message-list pattern | memory retrieval panel |
| segmented control | `LabelSegmentedControl` | `NSSegmentedControl`（NSViewRepresentable wrapper） | 设置面板 |
| chip（状态徽章） | `RuntimeCWDDisplayChip` | 自建 = Apple Notes tag chip pattern | runtime cwd display |
| hover effect | `HoverWash` modifier | 自建 = Apple HIG hover highlight | 多处 |
| **status badge** | `SFStatusBadge` | `Label + Capsule()` | 新增骨架，待 sweep |
| **card hero** | `SFCardHero` | `VStack { icon + title + subtitle }` | 新增骨架，待 sweep |
| **toolbar button** | `SFToolbarButton` | `Button { Image } + hitArea` | 新增骨架，待 sweep |
| **general list row** | `SFListRow` | `Label { VStack + trailing } icon:` | 新增骨架，待 sweep |

## 骨架包装器采用准则

`SFStatusBadge` / `SFCardHero` / `SFToolbarButton` / `SFListRow`
是 **2026-10-06 加的骨架**（每个仅 1 处实现），等 boss 提对应区域
需求时再 sweep 到调用点。新增调用时 = 直接 import 骨架包装器，
不要 inline 手写 `Label { ... } icon: { ... }` 链。

## 应用位置规则

每个包装器 doc-comment 第一段都标"Application position: ..."
（= 在 wenshu 里用在哪些地方）。改 wrapper 实现时先确认 doc
-comment 标的位置都对得上 sweep 范围。

## OOB 引用

- (see OOB.md #2026-10-06) — 中央工厂按区域不同加工
- (see OOB.md #2026-10-01) — SFIcon + IconStyle + IconColor v3.0 sweep
- (see OOB.md #2026-10-06) — Apple HIG first 原则（除非没有 Apple 标准）
