# 022 spec: upper band 4 columns width use .containerRelativeFrame ratio operator write (老板 2026-08-19 拍)

> 老板 2026-08-19 拍: "upper band's four zone module components, use ratio to write the width"
> 老板 拍: not sure if A (.containerRelativeFrame) is correct, you can implement with A
> Truth source: mcp__sketch__run_code `AF7B1C87` (老板 2026-08-19 already confirmed)
> Dead principle: macOS chrome 52 + 932 VStack (upper 465 + D_h 2 + lower 465) = 984
> Already committed: `6588494` (ticket 021 LayoutShellView bandH ratio operator)

## Scope

Only modify UpperBandZone.body + LowerBandZone.body:
- UpperBandZone 4 columns (sidebar / preview / editor / tools) width uses `.containerRelativeFrame(.horizontal, count:, span:, spacing:)`
- LowerBandZone 2 columns (aiChat / aiDynamic) width same

## Apple SwiftUI 27+ API signature (web search confirmed)

```swift
public func containerRelativeFrame(
    _ axes: Axis.Set, 
    count: Int,        // container divided into how many columns
    span: Int = 1,     // this view occupies how many columns (Int, no decimal)
    spacing: CGFloat,  // column spacing
    alignment: Alignment = .center
) -> some View
```

Formula:
```
availableWidth = (containerWidth - (spacing * (count - 1)))
columnWidth = (availableWidth / count)
itemWidth = (columnWidth * span) + ((span - 1) * spacing)
```

## Sketch truth (老板 AF7B1C87 mcp__sketch__run_code)

### Upper band 4 columns

| Column | PT | Ratio (1920 total) |
|---|---|---|
| Project sidebar | 200 | 10.42% (200/1920) |
| Project preview | 520 | 27.08% (520/1920) |
| Editor | 794 | 41.35% (794/1920) |
| Specialized tools | 400 | 20.83% (400/1920) |
| Total zone | 1918 | 99.68% |
| D_v1+D_v2+D_v3 visual line | 2 PT | 0.32% (3 × 2/3 = 2, equivalent to 2/(1920-1918) but actual 3 splitters 2 PT visual total ≈ 2 PT) |

### Lower band 2 columns

| Column | PT | Ratio |
|---|---|---|
| AI chat | 1518 | 79.06% (1518/1920) |
| AI dynamic | 400 | 20.83% (400/1920) |
| Total | 1918 | 99.89% |
| D_v5 visual line | 2 PT | 0.11% |

## Ratio integerization problem

`.containerRelativeFrame`'s `span: Int`, but ratios 200/520/794/400 **cannot be integerized** (not 4 equal parts).

**Fix**:
- **Integerization scaling**: × 100 = 20/52/79/40 (integers, ratio unchanged)
- Use `.containerRelativeFrame(.horizontal, count: 201, span: 20/52/79/40, spacing: 0)` 
  - availableWidth = 1920 - 0 = 1920
  - columnWidth = 1920 / 201 = 9.552
  - Project sidebar width = 9.552 × 20 = 191.04 (off 200 actual 9 PT)
  - Project preview width = 9.552 × 52 = 496.7 (off 520 actual 23 PT)
  - Editor width = 9.552 × 79 = 754.6 (off 794 actual 39 PT)
  - Specialized tools width = 9.552 × 40 = 382.1 (off 400 actual 18 PT)
  - Cumulative off 89 PT, total 1911 PT (off 1918 - 1911 = 7)

**Mismatch**, integerization × 100 cannot be precise.

- **More precise scaling**: × 1000 = 200/520/794/400 (integers!)
  - count: 1920, span: 200/520/794/400 = total span 1914, remaining 6 PT (≈ 3 splitters 2 PT visual line)
  - But count 1920, max span 1920 computationally large
  - Actually usable: count: 1920, span: 200/520/794/400, spacing: 0
  - availableWidth = 1920
  - columnWidth = 1920 / 1920 = 1
  - itemWidth = 1 × span + 0 = span (PT)
  - Perfect 1:1 with Sketch truth

**Integerization × 1000 = `count: 1920, span: 200/520/794/400` = 1:1 PT ratio**

**Actual test**: `count: 1920, span: 200` should expand to 200 PT.

## Implementation

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

## Acceptance

- `swift build` clean (API signature correct)
- `swift run` + Quartz screencapture -l true screenshot
- Upper band 4 columns width 200/520/794/400 PT consistent with commit 012
- Lower band 2 columns width 1518/400 PT consistent with commit 012
- D_v1/D_v2/D_v3/D_v5 splitter positions correct
- D_h splitter responds (vm.adjustBandSplit)

## Untouched

- `.windowStyle(.titleBar)` macOS chrome 52 PT
- ZoneModule 4-section constraint (ticket 018)
- Top/bottom divider 2 PT (ticket 020)
- ICON font size 18 (ticket 017.5)
- ICON spacing 9 (ticket 015)
- Placeholder text left/right 18 (ticket 013)
- Placeholder text distance from bottom 6 (ticket 011/016)
- `LayoutTokens.bandHeight / bandRatio` ratio operator (ticket 021 uses `vm.upperBandH`)
- Editor 4 PT inset
- VSplitter / NativeSplitter(view) / D_h drag

## Risk

- Whether `containerRelativeFrame` API supports on macOS 27 — needs build + true screenshot verify
- Integerization × 1000 ratio vs float ratio — integer more precise (1:1 with Sketch)
- D_v1/D_v2/D_v3/D_v5 splitter visual occupies 2 PT total space, zone total occupies 1918 + 2 = 1920 = 100%, but `.containerRelativeFrame` computes by count 1920, spacing 0, perfect 1:1