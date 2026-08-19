# 002 LayoutShellView 重写为 Apple HIG HStack + ZoneModule + NativeSplitter

> 老板 2026-08-19 拍板: 走 Apple HIG 真值范式
> 依赖: 001

## 重写 LayoutShellView.body

```swift
struct LayoutShellView: View {
    @State private var vm = LayoutShellViewModel()
    var body: some View {
        GeometryReader { proxy in
            let totalW = proxy.size.width
            let totalH = proxy.size.height - LayoutTokens.titleBarHeight  // 减 macOS titleBar chrome
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

## 调 NativeSplitter(view) 不调 NSView wrapper

- UpperBandZone 已存在(L500-527),直接调 NativeSplitter(view)
- LowerBandZone 已存在(L531-550),直接调 NativeSplitter(view)

## 加 LayoutShellViewModel.adjustBandSplit

(VM 已存在,验有没有此方法;v0.14.0 D_h 可拖时已加)

## 验收

- swift build clean
- swift run + screencapture -l 真截图
- 拖拽 5 竖 1 横 = 6 拖拽线 hover/drag 全恢复
