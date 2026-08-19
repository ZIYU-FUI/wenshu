# 022 spec: 上半区 4 列宽度用 .containerRelativeFrame 比例算子写 (老板 2026-08-19 拍)

> 老板 2026-08-19 拍: "上半区的四个区域模块组件, 用宽度用比例来写"
> 老板拍: 不确定 A (.containerRelativeFrame) 对不对, 你可以用 A 实现
> 真值源: mcp__sketch__run_code AF7B1C87 (老板 2026-08-19 已确认)
> 死原则: macOS chrome 52 + 932 VStack (上半 465 + D_h 2 + 下半 465) = 984
> 已 commit: 6588494 (ticket 021 LayoutShellView bandH 比例算子)

## 范围

只改 UpperBandZone.body + LowerBandZone.body:
- UpperBandZone 4 列 (sidebar / preview / editor / tools) 宽度用 `.containerRelativeFrame(.horizontal, count:, span:, spacing:)`
- LowerBandZone 2 列 (aiChat / aiDynamic) 宽度同上

## Apple SwiftUI 27+ API 签名 (web search 确认)

```swift
public func containerRelativeFrame(
    _ axes: Axis.Set, 
    count: Int,        // 容器被分成几列
    span: Int = 1,     // 该 view 占几列 (Int, 不能小数)
    spacing: CGFloat,  // 列间距
    alignment: Alignment = .center
) -> some View
```

公式:
```
availableWidth = (containerWidth - (spacing * (count - 1)))
columnWidth = (availableWidth / count)
itemWidth = (columnWidth * span) + ((span - 1) * spacing)
```

## Sketch 真值 (老板 AF7B1C87 mcp__sketch__run_code)

### 上半区 4 列
| 列 | PT | 比例 (1920 总) |
|---|---|---|
| 项目侧栏 | 200 | 10.42% (200/1920) |
| 项目预览 | 520 | 27.08% (520/1920) |
| 编辑器 | 794 | 41.35% (794/1920) |
| 专用工具 | 400 | 20.83% (400/1920) |
| 总 zone | 1918 | 99.68% |
| D_v1+D_v2+D_v3 视觉线 | 2 PT | 0.32% (3 × 2/3 = 2, 等比 2/(1920-1918) 但实际 3 拖拽线 2 PT 视觉合计 ≈ 2 PT) |

### 下半区 2 列
| 列 | PT | 比例 |
|---|---|---|
| AI 聊天 | 1518 | 79.06% (1518/1920) |
| AI 动态 | 400 | 20.83% (400/1920) |
| 总 | 1918 | 99.89% |
| D_v5 视觉线 | 2 PT | 0.11% |

## 比例整数化问题

`.containerRelativeFrame` 的 `span: Int`,但比例 200/520/794/400 **不能整数化**(不是 4 等分)。

**修法**:
- **整数化缩放**: × 100 = 20/52/79/40 (整数, 比例不变)
- 用 `.containerRelativeFrame(.horizontal, count: 201, span: 20/52/79/40, spacing: 0)` 
  - availableWidth = 1920 - 0 = 1920
  - columnWidth = 1920 / 201 = 9.552
  - 项目侧栏 width = 9.552 × 20 = 191.04 (差 200 实测 9 PT)
  - 项目预览 width = 9.552 × 52 = 496.7 (差 520 实测 23 PT)
  - 编辑器 width = 9.552 × 79 = 754.6 (差 794 实测 39 PT)
  - 专用工具 width = 9.552 × 40 = 382.1 (差 400 实测 18 PT)
  - 累计差 89 PT, 总 1911 PT (差 1918 - 1911 = 7)

**不匹配**,整数化 × 100 不能精确。

- **更精确缩放**: × 1000 = 200/520/794/400 (整数!)
  - count: 1920, span: 200/520/794/400 = 总 span 1914, 剩 6 PT (≈ 3 拖拽线 2 PT 视觉线)
  - 但 count 1920, span 最大 1920 算大
  - 实际可用: count: 1920, span: 200/520/794/400, spacing: 0
  - availableWidth = 1920
  - columnWidth = 1920 / 1920 = 1
  - itemWidth = 1 × span + 0 = span (PT)
  - 完美 1:1 跟 Sketch 真值

**整数化 × 1000 = `count: 1920, span: 200/520/794/400` = 1:1 PT 比例**

**实测**: `count: 1920, span: 200` 应该撑出 200 PT。

## 实现

### UpperBandZone.body
```swift
HStack(spacing: 0) {
    ZoneModule(slot: .projectSidebar, ...)
        .containerRelativeFrame(.horizontal, count: 1920, span: 200, spacing: 0)
    VSplitter(...)
    ZoneModule(slot: .projectPreview, ...)
        .containerRelativeFrame(.horizontal, count: 1920, span: 520, spacing: 0)
    VSplitter(...)
    ZoneModule(slot: .editor, ...)
        .containerRelativeFrame(.horizontal, count: 1920, span: 794, spacing: 0)
    VSplitter(...)
    ZoneModule(slot: .specializedTools, ...)
        .containerRelativeFrame(.horizontal, count: 1920, span: 400, spacing: 0)
}
```

### LowerBandZone.body
```swift
HStack(spacing: 0) {
    ZoneModule(slot: .aiChat, ...)
        .containerRelativeFrame(.horizontal, count: 1920, span: 1518, spacing: 0)
    VSplitter(...)
    ZoneModule(slot: .aiDynamic, ...)
        .containerRelativeFrame(.horizontal, count: 1920, span: 400, spacing: 0)
}
```

## 验收

- swift build clean (API 签名正确)
- swift run + Quartz screencapture -l 真截图
- 上半区 4 列宽 200/520/794/400 PT 跟 commit 012 一致
- 下半区 2 列宽 1518/400 PT 跟 commit 012 一致
- D_v1/D_v2/D_v3/D_v5 拖拽线位置正确
- D_h 拖拽线响应 (vm.adjustBandSplit)

## 不动

- .windowStyle(.titleBar) macOS chrome 52 PT
- ZoneModule 4 段约束 (ticket 018)
- 顶/底分割线 2 PT (ticket 020)
- ICON 字号 18 (ticket 017.5)
- ICON 间距 9 (ticket 015)
- 占位文字左/右 18 (ticket 013)
- 占位文字距底 6 (ticket 011/016)
- LayoutTokens.bandHeight / bandRatio 比例算子 (ticket 021 用 vm.upperBandH)
- 编辑器 4 PT inset
- VSplitter / NativeSplitter(view) / D_h 拖拽

## 风险

- `containerRelativeFrame` API 在 macOS 27 实测是否支持 — 需要 build + 真截图验
- 整数化 × 1000 比例 vs 浮点比例 — 整数更精确 (跟 Sketch 1:1)
- D_v1/D_v2/D_v3/D_v5 拖拽线视觉占 2 PT 总空间,zone 总占 1918 + 2 = 1920 = 100%,但 .containerRelativeFrame 是按 count 1920 算,spacing 0,完美 1:1
