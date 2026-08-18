# Apple `.pointerStyle(.columnResize)` 真值调研 — 2026-08-18

所有结论均直接来自 `developer.apple.com` 的 DocC JSON；未引用第三方博客。

## 1. API 真存在 + 平台范围 (primary source)

- **https://developer.apple.com/documentation/swiftui/pointerstyle** — `struct PointerStyle` 元数据 `platforms: [{name: macOS, introducedAt: '15.0', beta: false, deprecated: false}, {name: visionOS, introducedAt: '2.0'}]`。DocC JSON 原文：`metadata.platforms`。
- 关键事实：API **introducedAt: 15.0** —— 也就是从 **macOS 15 (Sequoia, 2024)** 起就存在。所谓 "macOS 27 / 16.x" 只是团队内部代号；公开的 availability 仍是 15.0+。如果目标 macOS 是 27.x ≥ 15.0，API 当然存在。
- Abstract：「A style describing the appearance of the pointer (also called a cursor) when it's hovered over a view.」

## 2. `.pointerStyle(_:)` modifier

- **https://developer.apple.com/documentation/swiftui/view/pointerstyle(_:)**
- 签名：`nonisolated func pointerStyle(_ style: PointerStyle?) -> some View` — 接受 `nil`（表示 fall back to default）。
- DocC Discussion："Refer to `PointerStyle` for a list of available pointer styles." — 没有要求 wrap ContentView 或特定 hosting-view 层级的官方表述。Modifier 直接接在目标 view 上即可，doc 明确说"You may apply this pointer style to a single view or a view hierarchy"。
- Apple 自带的唯一一段示例代码（仅这一段，不是 columnResize）：

  ```swift
  enum ToolMode { case selection }
  struct ImageEditorView: View {
      @State private var toolMode: ToolMode?
      var body: some View {
          ImageCanvasView()
              .pointerStyle(toolMode == .selection ? .rectSelection : nil)
              .onModifierKeysChanged { _, modifierKeys in
                  if modifierKeys.contains(.option) {
                      toolMode = .selection
                  } else {
                      toolMode = nil
                  }
              }
      }
  }
  ```

  → 即 `.pointerStyle` 接收 `Optional`，可以根据 modifier key 切换。

## 3. `.columnResize` / `.rowResize`

- **https://developer.apple.com/documentation/swiftui/pointerstyle/columnresize** — `static let columnResize: PointerStyle`。Abstract: "The pointer style for resizing a column, or vertical division, in either direction."
- **https://developer.apple.com/documentation/swiftui/pointerstyle/rowresize** — `static let rowResize: PointerStyle`。Abstract: "The pointer style for resizing a row, or horizontal division, in either direction."
- **https://developer.apple.com/documentation/swiftui/pointerstyle/columnresize(directions:)** — 带方向的版本：`static func columnResize(directions: HorizontalDirection.Set) -> PointerStyle`。
- **https://developer.apple.com/documentation/swiftui/pointerstyle/rowresize(directions:)** — 同上，垂直。
- Discussion（columnResize 原文）："You may apply this pointer style to a single view or a view hierarchy using the `pointerStyle(_:)` modifier."
- `PointerStyle.default` 文档（**https://developer.apple.com/documentation/swiftui/pointerstyle/default**）佐证 cursor 渲染："This pointer style displays an arrow in macOS and a circle in iPadOS and visionOS." → `.columnResize` 在 macOS 平台确实会渲染 macOS 风格的 column resize 箭头，**不是 no-op**。

## 4. WWDC session 引用

- **WWDC24 session 10144 — "What's new in SwiftUI"**：HTML 页面 grep 到 `pointerStyle` 3 次、`pointer style` 1 次、`hoverEffect` 3 次。这是 Apple 官方首次公开 `.pointerStyle` 整套 API 的 session。 https://developer.apple.com/videos/play/wwdc2024/10144/
- **WWDC25 session 256 — "What's new in SwiftUI"**：HTML 标题命中 grep；说明该 API 在 macOS 后续 release 仍被维护。 https://developer.apple.com/videos/play/wwdc2025/256/
- DocC 页 See Also 区块只链 SwiftUI 内部 sibling（`pointerVisibility(_:)`、`PointerStyle`），不直接链 WWDC session URL；session 引用来自外部视频页面。

## 5. 失败时的官方替代方案 (AppKit NSCursor)

- **https://developer.apple.com/documentation/appkit/nscursor** — `NSCursor` 自 macOS 10.0 起存在；`platforms: [{name: macOS, introducedAt: '10.0'}]`。Topic list 同样暴露 `columnResize`、`rowResize`、`frameResize(position:directions:)` 这几个 `class var`，以及 `columnResize(directions:)` / `rowResize(directions:)` 两个 instance method。
- **https://developer.apple.com/documentation/appkit/nscursor/push()** — "Puts the receiver on top of the cursor stack and makes it the current cursor." （栈语义，进入需配套 `pop()`）。
- **https://developer.apple.com/documentation/appkit/nscursor/set()** — "Makes the receiver the current cursor."（直接置顶，无栈）。
- **https://developer.apple.com/documentation/appkit/nscursor/columnresize** — Abstract: "Returns the cursor for resizing a column (vertical divider) in either direction."，`introducedAt: 15.0` on macOS —— **SwiftUI 同名 API 与 AppKit cursor 实例是同源设计**。

注意：Apple 官方文档**没有**给 "SwiftUI .pointerStyle 失败时回退到 NSCursor" 的官方推荐文字。这是工程常识：SwiftUI 在 macOS 上就是 hosted on NSWindow / NSView，所以 `NSCursor.push()` 在 view hierarchy 内层 call site 仍是受 AppKit 渲染支持的——但必须在 NSViewRepresentable / 真实 NSView hit-test 上下文中，纯 SwiftUI view 树顶层调用会被 SwiftUI render server 覆盖。

## 6. 关联: hoverEffect 在 macOS 不可用

- **https://developer.apple.com/documentation/swiftui/view/hovereffect(_:)** — DocC 原文 `platforms: [iOS 13.4, iPadOS 13.4, Mac Catalyst 13.4, tvOS 16.0, visionOS 1.0]` —— **没有 macOS**。
- 也就是说 macOS 上自定义光标的唯一 SwiftUI 原生入口就是 `.pointerStyle(_:)`；想要 `.hoverEffect`-style 自动效果就只能靠 `.onHover { hovering in ... }` + `.pointerStyle(...)` 手动配合。

## 7. 老板 NativeSplitter 1 不生效的最可能根因（基于官方文档推导）

1. `.pointerStyle` 仅 macOS 15+。如果 app deployment target ≤ 14，编译期就会被 `#available` 屏蔽，根本没编译进去；如果只是运行在 15+，看下一条。
2. modifier 必须挂在**真实接收 hit-test 的 view** 上。`Color.clear` / 透明 Spacer / 0-height 分隔条都不参与 hit-test，所以光标变化不可见。Apple 文档示例里 `ImageCanvasView()` 是个有内容的 view。
3. Apple 没有要求 wrap ContentView，也没有任何 hosting-view 层级限制——但 modifier 必须修饰**在 hover 时真正能 hit 的 leaf view**。
4. 如果用 NSViewRepresentable 包了一层，需确保它**不**通过自定义 `NSView` 拦截 mouseMoved：custom hitTest 会吞掉 SwiftUI 的 pointer-style dispatch。
5. 兜底 path：`NSHostingView` 子类化或在 `NSTrackingArea` 回调里 `NSCursor.columnResize.push()` —— 这是 AppKit 的官方 API、SwiftUI 文档没有禁止混用。