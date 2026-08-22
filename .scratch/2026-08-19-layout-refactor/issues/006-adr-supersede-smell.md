# 006 ADR-0007 supersede ADR-0003 + table-driven adjust

> Dependency: v0.15 ticket 005 commit `4ba2e37`
> Source: code-review two-axis P3 items (S3 / S4 + S6 / S7 smell)
> 老板 2026-08-19 拍板: fix all

## Scope

### 6.1 Write ADR-0007 supersede ADR-0003

ADR-0003 mandates "NSView + NSEvent.delta pipeline", replaced by v0.14 NativeSplitter(view) + v0.15 LayoutShellView HStack paradigm.

New ADR-0007 content:
- Title: "Layout shell paradigm: HStack + self-written NativeSplitter(view)"
- Status: accepted
- Supersedes: ADR-0003 (drag-splitter-nsview)
- Decision: 6-zone layout uses Apple HIG HStack paradigm, splitter = self-written NativeSplitter(view) (DragGesture + .pointerStyle + hover 4 PT accent capsule)
- Context: HSplitView / VSplitView divider color unchangeable (publicly known limitation), NavigationSplitView doesn't match Sketch 6 zones, NSView + NSEvent in SwiftUI top-level window has cursor cross-boundary + drag flicker issues
- Decision-maker: 老板 2026-08-19 拍板 (ticket 005)
- Consequences: change 1 place = 6 splitters all changed (NativeSplitter 1 component + SplitterOrientation enum)

### 6.2 Fix spec §5.2 S1 title bar bottom 1 PT divider

老板 2026-08-19 拍: title bar uses macOS `.windowStyle(.titleBar)` 52 PT unified chrome, no self-write. macOS chrome comes with its own bottom separator (gray background borders dark zone), spec §5.2 S1 change to "title bar bottom separator = macOS chrome built-in (老板 2026-08-19 ticket 005)".

### 6.3 S6 Shotgun Surgery: table-driven adjust

VM already has `adjust(_ index: Int, delta: CGFloat, totalWidth: CGFloat)`, LayoutShellView / UpperBandZone / LowerBandZone change to table-driven:

```swift
private let splitterCallbacks: [(CGFloat, CGFloat) -> Void] = []  // populated per zone
```

Or more concise: write a splitter helper view, accept `orientation + length + splitterIndex`, internally call `vm.adjust(splitterIndex, delta:length:)`.

### 6.4 S7 Repeated Switches: ZoneModule.content slot-keyed theming

Extract slot-keyed theme:
```swift
struct ZoneTheme {
    let background: Color
    let content: (CGFloat, CGFloat, WenshuLibrary) -> AnyView
}
static let themes: [ZoneSlot: ZoneTheme] = [
    .projectSidebar: .init(background: .zoneSurface, content: { _, _, lib in AnyView(LibraryOutlineViewContent(library: lib)) }),
    .editor: .init(background: .zoneSurface, content: { w, h, _ in AnyView(/* editor inset double layer */) }),
    ...
]
```

## Untouched

- P0 / P1 / P2 already fixed (commit `4ba2e37`)
- NativeSplitter / ZoneTopToolbar / ZoneBottomToolbar components

## Acceptance

- `swift build` clean
- `swift run` + screencapture -l true screenshot (visual regression)
- ADR-0007 + spec §5.2 S1 changed, consistent with code

## Risk

- Table-driven adjust refactor signature changes, callers must follow
- ZoneModule.content slot-keyed theming extracting helper is judgement call, 老板 拍

## 老板 拍板 points

- ADR-0007 write or not? Write (P3-1)
- spec §5.2 S1 fix or not? Fix (P3-2)
- S6 table-driven change or not? Change (P3-3)
- S7 slot-keyed theming extract or not? Extract (P3-4, but use static dict, no new type introduced)