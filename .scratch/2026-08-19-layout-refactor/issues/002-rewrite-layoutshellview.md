# 002 LayoutShellView rewrite to Apple HIG HStack + ZoneModule + NativeSplitter

> 老板 2026-08-19 拍板: use Apple HIG truth paradigm
> Dependency: 001

## Rewrite LayoutShellView.body

```swift
struct LayoutShellView: View {
    @State private var vm = LayoutShellViewModel()
    var body: some View {
        GeometryReader { proxy in
            let totalW = proxy.size.width
            let totalH = proxy.size.height - LayoutTokens.titleBarHeight  // subtract macOS titleBar chrome
            VStack(spacing: 0) {
                UpperBandZone(vm: vm, totalW: totalW, bandH: totalH * LayoutTokens.bandRatio)
                NativeSplitter(orientation: .horizontal, length: totalW, onDrag: { dy in vm.adjustBandSplit(delta: dy, totalHeight: totalH) })
                    .frame(height: 6)  // hit area 6 PT
                LowerBandZone(vm: vm, totalW: totalW, bandH: totalH * LayoutTokens.bandRatio)
            }
        }
        .frame(width: LayoutTokens.designW, height: LayoutTokens.designH)
        .background(Color(nsColor: .windowBackgroundColor))
        .onReceive(NotificationCenter.default.publisher(for: .wenshuResetLayout)) { _ in vm.reset() }
    }
}
```

## Call NativeSplitter(view) not NSView wrapper

- UpperBandZone already exists (L500-527), directly call NativeSplitter(view)
- LowerBandZone already exists (L531-550), directly call NativeSplitter(view)

## Add LayoutShellViewModel.adjustBandSplit

(VM already exists, verify whether this method exists; v0.14.0 D_h draggable already added)

## Acceptance

- `swift build` clean
- `swift run` + screencapture -l true screenshot
- Drag 5 vertical 1 horizontal = 6 splitters hover/drag all restored