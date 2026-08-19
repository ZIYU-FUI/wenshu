# 006 ADR-0007 supersede ADR-0003 + table-driven adjust

> 依赖: v0.15 ticket 005 commit 4ba2e37
> 来源: code-review 两轴 P3 项 (S3 / S4 + S6 / S7 smell)
> 老板 2026-08-19 拍板: 全修

## 范围

### 6.1 写 ADR-0007 supersede ADR-0003

ADR-0003 mandate "NSView + NSEvent.delta pipeline", v0.14 NativeSplitter(view) + v0.15 LayoutShellView HStack 范式 替代。

新 ADR-0007 内容:
- Title: "Layout shell 范式: HStack + 自写 NativeSplitter(view)"
- Status: accepted
- Supersedes: ADR-0003 (drag-splitter-nsview)
- Decision: 6 区 layout 用 Apple HIG HStack 范式, 拖拽线 = 自写 NativeSplitter(view) (DragGesture + .pointerStyle + hover 4 PT accent capsule)
- Context: HSplitView / VSplitView divider 颜色改不了 (公开已知限制), NavigationSplitView 跟 Sketch 6 区不对应, NSView + NSEvent 在 SwiftUI 顶层 window 有 cursor 跨边界 + drag 闪烁问题
- Decision-maker: 老板 2026-08-19 拍板 (ticket 005)
- Consequences: 改 1 处 = 6 拖拽线全改 (NativeSplitter 1 组件 + SplitterOrientation enum)

### 6.2 改 spec §5.2 S1 标题栏底 1 PT 分割线

老板 2026-08-19 拍: 标题栏走 macOS .windowStyle(.titleBar) 52 PT unified chrome, 不自写。macOS chrome 自带底部分隔(灰色背景跟深色 zone 交界),spec §5.2 S1 改为"标题栏底分隔 = macOS chrome 自带 (老板 2026-08-19 ticket 005)"。

### 6.3 S6 Shotgun Surgery: 表驱动 adjust

VM 已有 `adjust(_ index: Int, delta: CGFloat, totalWidth: CGFloat)`, LayoutShellView / UpperBandZone / LowerBandZone 改成表驱动:

```swift
private let splitterCallbacks: [(CGFloat, CGFloat) -> Void] = []  // populated per zone
```

或更简洁: 写一个 splitter helper view, 接受 `orientation + length + splitterIndex`, 内部调 `vm.adjust(splitterIndex, delta:length:)`.

### 6.4 S7 Repeated Switches: ZoneModule.content slot-keyed theming

抽 slot-keyed theme:
```swift
struct ZoneTheme {
    let background: Color
    let content: (CGFloat, CGFloat, WenshuLibrary) -> AnyView
}
static let themes: [ZoneSlot: ZoneTheme] = [
    .projectSidebar: .init(background: .zoneSurface, content: { _, _, lib in AnyView(LibraryOutlineViewContent(library: lib)) }),
    .editor: .init(background: .zoneSurface, content: { w, h, _ in AnyView(/* editor inset 双层 */) }),
    ...
]
```

## 不动

- P0 / P1 / P2 已修 (commit 4ba2e37)
- NativeSplitter / ZoneTopToolbar / ZoneBottomToolbar 组件

## 验收

- swift build clean
- swift run + screencapture -l 真截图 (视觉回归)
- ADR-0007 + spec §5.2 S1 改完, 跟代码一致

## 风险

- 表驱动 adjust 重构签名变, 调用方要跟
- ZoneModule.content slot-keyed theming 抽 helper 是 judgement call, 老板拍

## 老板拍板点

- ADR-0007 写不写? 写 (P3-1)
- spec §5.2 S1 改不改? 改 (P3-2)
- S6 表驱动改不改? 改 (P3-3)
- S7 slot-keyed theming 抽不抽? 抽 (P3-4, 但用静态 dict, 不引入新类型)
