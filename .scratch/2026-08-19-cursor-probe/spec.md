# Cursor 最小验证 — 验证 SwiftUI `.pointerStyle` 在 macOS 27 是否真工作

> 老板 2026-08-19 拍 "查官方文档确认 macOS 27 修法"
> 真因报告 v2: cursor-investigation-report-v2.md
> 推荐方案 A: 退回 SwiftUI `.pointerStyle(.columnResize() / .rowResize())`

## 目的

写一个最小 SwiftUI case 验证 SwiftUI `.pointerStyle(.columnResize())` / `.rowResize()` 在 macOS 27 真值 work, 不依赖 NSViewRepresentable / NSResponder / NSTrackingArea.

如果 work → 退回 SwiftUI 范式, 重写 NativeSplitter (删 SplitterHitArea NSView + WenshuCursorController)
如果不 work → 走候选 D NSWindow 子类化

## SwiftUI Cursor Probe (报告 L431-455 完整代码)

```swift
import SwiftUI

@main
struct CursorProbe: App {
    var body: some Scene {
        WindowGroup { CursorProbeView() }
            .windowStyle(.titleBar)
            .defaultSize(width: 800, height: 400)
    }
}

struct CursorProbeView: View {
    @State private var offset: CGFloat = 200
    var body: some View {
        HStack(spacing: 0) {
            Color.red.frame(width: offset, height: 400)
            Color.clear
                .frame(width: 6, height: 400)
                .pointerStyle(.columnResize())
                .onContinuousHover { phase in
                    print("hover phase: \(phase)")
                }
            Color.blue.frame(maxWidth: .infinity, maxHeight: 400)
        }
    }
}
```

## 跑法

1. `swift /Volumes/ANAN/Engineering/wenshu/.scratch/2026-08-19-cursor-probe/CursorProbe.swift`
2. 鼠标 hover 6 PT 透明 strip (中间 clear region)
3. ✅ cursor 切到 ↔ 双箭头 → 候选 A 可行
4. ❌ cursor 不切 → SwiftUI `.pointerStyle` 在 macOS 27 + NSHostingView 子树内真有 bug, 走候选 D NSWindow 子类化

## Acceptance criteria

- [ ] SwiftUI `.pointerStyle(.columnResize())` 在 6 PT clear strip 上 work (cursor变 ↔)
- [ ] SwiftUI `.pointerStyle(.rowResize())` 同样 work (老板 8/19 拍 6 根拖拽线, D_h 用 rowResize)
- [ ] 不依赖 NSViewRepresentable / NSResponder / NSTrackingArea
- [ ] swift build exit 0
- [ ] 老板自己启 binary 验 (本环境无 GUI)

## Out of Scope

- 不动 wenshu NativeSplitter
- 不重写 SplitterHitArea NSView
- 不重写 WenshuCursorController

## Further Notes

- 真因报告 v2 全文: /Volumes/ANAN/Engineering/wenshu/.scratch/2026-08-19-dh-fixes-3/cursor-investigation-report-v2.md
- 报告 L416-475 Verdict for 老板
- 5 个候选修法排名 + 推荐方案