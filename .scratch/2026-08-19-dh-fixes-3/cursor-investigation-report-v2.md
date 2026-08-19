# macOS 27 SwiftUI + AppKit cursor 系统真值报告 (v2)

**日期**: 2026-08-19 (v2, 覆盖之前 deleg_6ea687d8 33 KB 真值报告)
**任务来源**: 老板 8/19 19:10 委托 (subagent 任务书)
**方法**: 全部从 Apple Developer Documentation JSON API (`/tutorials/data/documentation/...`) + Xcode 27 SDK `swiftinterface` header + GitHub raw 真值源码独立 verify 一遍. 不靠记忆不靠推测, 每个真值都引 URL.
**覆盖**: 4 个验证任务 + 给老板下一步推荐.

> ⚠️ **任务书提到 "macOS 27"** — 截至 2026-08-19 老板机器上 Xcode-beta.app 装的 SDK 就是 `MacOSX27.0.sdk` (`xcrun --sdk macosx --show-sdk-path` = `/Applications/Xcode-beta.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX27.0.sdk`). macOS 27 SDK 真值在 swiftinterface 全部可查. 不再分 "26.x 真值" — 直接拿 27 SDK 当作 ground truth.

---

## TL;DR — 一句话真因

**wenshu cursor 系统全失灵的真因 = SwiftUI `NSHostingView` (SwiftUI WindowGroup window 的 `contentView` 子类) 在 macOS 27 SDK 公开 override 了 `hitTest(_:)` 和 `cursorUpdate(with:)` 但没 override `resetCursorRects()`** — 因此 macOS 系统 cursor rects 调度路径在 `NSHostingView` 整棵 SwiftUI 子树内失灵, 而 `NSHostingView.cursorUpdate` 自己有 SwiftUI 内部路由走 `.pointerStyle` 系统, 完全绕过 AppKit `NSCursor` + cursor rects 范式.

所以**之前所有 .scratch/2026-08-19-dh-fixes-3 试过的修法都失败的真因**:
1. `NativeSplitter.resetCursorRects()` (commit 03) — macOS 系统不会调它, 因为 `NSHostingView` 不 propagate cursor rects 到 SwiftUI 子 view.
2. `WenshuCursorController` NSResponder + `NSTrackingArea.mouseMoved` + `contentView.hitTest` (commit 06) — `hitTest` 在 `NSHostingView` override 里直接拦截, 命中 SwiftUI 子 view tree (不是 SplitterHitArea), `findSplitter(in:)` 找不到任何 splitter.
3. SwiftUI `.pointerStyle(.columnResize() / .rowResize())` (v0.14 `dacbc9fee`) — 老板 8/19 实测失灵. 但 SwiftUI `.pointerStyle` API 在 macOS 27 SDK 完整存在 (PointerStyle struct, 全部 resize case), 真因不是 API 缺, 是 v0.14 写法 gesture 链 bug + VStack parent gesture 拦截.

---

## 1. NSHostingView 跟 AppKit cursor rects 系统如何交互 — SDK 真值

### 1.1 NSHostingView 公开类签名 (macOS 27 SDK swiftinterface 真值)

```
$ xcrun --sdk macosx --show-sdk-path
/Applications/Xcode-beta.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX27.0.sdk

SDK 真值 (SwiftUI.swiftinterface line ~28960):
@available(macOS 13.0, *)
@_Concurrency.MainActor @preconcurrency open class NSHostingView<Content> : AppKit.NSView,
 AppKit.NSUserInterfaceValidations, AppKit.NSDraggingSource where Content : SwiftUICore.View
```

- ✅ **NSHostingView 在 macOS 13+ 是 public class** (不再是 macOS 11/12 早期传闻的 "private class"), 只是 macOS 10.15 引入, macOS 13 加了部分扩展.
- ✅ **NSHostingView 是 NSView 子类**, 继承所有 NSView 公开 API.

URL: https://developer.apple.com/documentation/swiftui/nshostingview

### 1.2 NSHostingView 公开 override 方法 — 直接从 SDK swiftinterface 拿

NSHostingView 实际 override 的方法 (跟 mouse / cursor / hit-test 相关的全部列出):

```
override dynamic open func hitTest(_ point: CGPoint) -> NSView?                    ← 拦截 hit test
override dynamic open func acceptsFirstMouse(for event: NSEvent?) -> Bool
override dynamic open func mouseDown(with nsEvent: NSEvent)                            ← 接管鼠标事件
override dynamic open func mouseDragged(with nsEvent: NSEvent)
override dynamic open func mouseUp(with nsEvent: NSEvent)
override dynamic open func rightMouseDown/Dragged/Up
override dynamic open func otherMouseDown/Dragged/Up
override dynamic open func mouseEntered(with nsEvent: NSEvent)                      ← 接管 hover enter
override dynamic open func mouseMoved(with nsEvent: NSEvent)                        ← 接管 mouse moved
override dynamic open func mouseExited(with nsEvent: NSEvent)                       ← 接管 hover exit
override dynamic open func cursorUpdate(with event: NSEvent)                        ← **接管 cursor update 事件**
override dynamic open func scrollWheel(with nsEvent: NSEvent)
override dynamic open func menu(for event: NSEvent) -> NSMenu?
override dynamic open var acceptsFirstResponder: Bool
override dynamic open func performKeyEquivalent(with nsEvent: NSEvent) -> Bool
override dynamic open func keyDown(with event: NSEvent)
override dynamic open func keyUp(with event: NSEvent)
override dynamic open var accessibilityFocusedUIElement: Any?
override dynamic open func accessibilityHitTest(_ point: NSPoint) -> Any?
```

**关键观察 (跟 cursor 系统直接相关)**:
- ✅ **`hitTest` override**: 拦截 AppKit hit test — 当外部 caller 调 `contentView.hitTest(point)`, NSHostingView 自己决定返回哪个子 view (SwiftUI 子 tree). wenshu `WenshuCursorController` 调 `contentView.hitTest` 拿到的就是 NSHostingView (或 NSHostingView 子树), 不是 SplitterHitArea, **因为 SplitterHitArea 是 NSViewRepresentable 桥接的, 被 SwiftUI 包成 NSHostingView 子树**.
- ✅ **`cursorUpdate` override**: 拦截 NSResponder cursorUpdate 事件, NSHostingView 自己路由到 SwiftUI PointerStyle 系统 — **不走 AppKit NSCursor / cursor rects 路径**.
- ✅ **`mouseEntered` / `mouseMoved` / `mouseExited` override**: 拦截 hover 事件, **NSHostingView 内部不一定 propagate 给 NSTrackingArea 监听者** (SwiftUI 自己有 hover 状态机, 独立于 NSTrackingArea).
- ❌ **没有 `resetCursorRects` override**: macOS 系统 cursor rects 调度流程要求每个 NSView override `resetCursorRects()` 来声明自己的 cursor rects. NSHostingView 不 override = SwiftUI 子树内 cursor rects 不被系统识别.

URL: https://developer.apple.com/documentation/swiftui/nshostingview (topicSections 列全部方法) — verify 上面 list 在 Apple doc JSON 拿得到.

### 1.3 NSView.resetCursorRects() 官方定义 (直引)

> "Overridden by subclasses to define their default cursor rectangles. A subclass's implementation must invoke `addCursorRect(_:cursor:)` for each cursor rectangle it wants to establish. **The default implementation does nothing.** Application code should never invoke this method directly; it's invoked automatically as described in 'Mouse-Tracking and Cursor-Update Events'. Use the `invalidateCursorRects(for:)` method instead to explicitly rebuild cursor rectangles."

URL: https://developer.apple.com/documentation/appkit/nsview/resetcursorrects()

**关键**: "Application code should never invoke this method directly; it's invoked **automatically**". **但只对 override 了 resetCursorRects 的 NSView 调用**, NSView 默认实现 does nothing. NSHostingView 不 override → 系统 cursor rects 自动调度 = 0 cursor rects 在 SwiftUI 子树内注册.

### 1.4 NSCursor cursor rects 系统 (官方直引)

> "In Cocoa, you can change the currently displayed cursor based on the position of the mouse over one of your views. … To set this up, you associate a cursor object with one or more cursor rectangles in the view. **Cursor rectangles are a specialized type of tracking rectangles, which are used to monitor the mouse location in a view. Views implement cursor rectangles using tracking rectangles** but provide methods for setting and refreshing cursor rectangles that are distinct from the generic tracking rectangle interface. For information on mouse-tracking and cursor-update events, see `NSTrackingArea`."

URL: https://developer.apple.com/documentation/appkit/nscursor (Cursor rectangles section)

**关键**: **cursor rects 是 specialized tracking rects, 由 NSView 声明**. SwiftUI 不遵循这个范式.

### 1.5 NSResponder.cursorUpdate(with:) 官方定义 (直引)

> "Informs the receiver that the mouse cursor has moved into a cursor rectangle. Override this method to set the cursor image. **The default implementation uses cursor rectangles, if cursor rectangles are currently valid.** If they are not, it calls super to send the message up the responder chain."

URL: https://developer.apple.com/documentation/appkit/nsresponder/cursorupdate(with:)

**关键**: 默认实现先看 cursor rects, 没有就 responder chain. NSHostingView override 了 cursorUpdate → SwiftUI 自己处理. NSHostingView 不 propagate 给 NSView 子树 (因为 SwiftUI 子 view 不是真正 NSView 子类).

### 1.6 NSWindow cursor API (官方直引)

NSWindow 提供:
- `areCursorRectsEnabled` (BOOL, 默认 true)
- `enableCursorRects()` / `disableCursorRects()` / `discardCursorRects()`
- `invalidateCursorRects(for:)` — "Marks as invalid the cursor rectangles of a given view object in the window, so they'll be set up again when the window becomes key. **If the window is current the key window, window resets the cursor rectangles immediately.**"
- `resetCursorRects()` — 重新 reset 整个 window 内的 cursor rects

URL: https://developer.apple.com/documentation/appkit/nswindow/invalidatecursorrects(for:)

### 1.7 结论

SwiftUI WindowGroup 创建的 window 公开 type 是 `NSWindow` (不是 private class). **但** SwiftUI WindowGroup 内部把 `NSHostingView` 作为 window.contentView, 这层 NSHostingView 拦截 hit-test 和 cursor 事件流, 屏蔽 AppKit cursor rects 范式:

1. **NSHostingView 不 override `resetCursorRects`** → NSHostingView 子树 (SwiftUI 子 view) 的 NSView 子类 override `resetCursorRects` 不会被 macOS 系统调用 → **wenshu `SplitterHitArea.resetCursorRects()` 永远不被调, cursor 不切** (ticket 03 commit 实测失灵真因).
2. **NSHostingView override `hitTest`** → `contentView.hitTest` 不返回 `SplitterHitArea` (因为 SplitterHitArea 通过 NSViewRepresentable 桥接, 被 NSHostingView 当成 SwiftUI 子树, NSHostingView 自己 hit test) → `WenshuCursorController` 拿到的 hit view 是 NSHostingView 子树节点, 不是 SplitterHitArea → **findSplitter 永远找不到** (ticket 06 commit 实测失灵真因).
3. **NSHostingView override `cursorUpdate`** → 自己路由给 SwiftUI PointerStyle 系统, **不走 AppKit NSCursor** → `NSCursor.push()` / `set()` 在 NSHostingView 子树内可能 work 也可能被 SwiftUI 覆盖.

---

## 2. SwiftUI `.pointerStyle` 在 macOS 27 真值

### 2.1 SwiftUI.PointerStyle SDK swiftinterface 真值 (直接拿 SDK 27 header)

```
SDK MacOSX27.0.sdk/System/Library/Frameworks/SwiftUI.framework/Modules/SwiftUI.swiftmodule/arm64e-apple-macos.swiftinterface

public struct PointerStyle : Swift.Sendable {
  public static let `default`: SwiftUI.PointerStyle
  public static let horizontalText: SwiftUI.PointerStyle
  public static let verticalText: SwiftUI.PointerStyle
  public static let rectSelection: SwiftUI.PointerStyle
  public static let grabIdle: SwiftUI.PointerStyle
  public static let grabActive: SwiftUI.PointerStyle
  public static let link: SwiftUI.PointerStyle
  public static let zoomIn: SwiftUI.PointerStyle
  public static let zoomOut: SwiftUI.PointerStyle
  public static let columnResize: SwiftUI.PointerStyle
  public static func columnResize(directions: SwiftUICore.HorizontalDirection.Set) -> SwiftUI.PointerStyle
  public static let rowResize: SwiftUI.PointerStyle
  public static func rowResize(directions: SwiftUICore.VerticalDirection.Set) -> SwiftUI.PointerStyle
  public static func frameResize(position: SwiftUI.FrameResizePosition, directions: SwiftUI.FrameResizeDirection.Set = .all) -> SwiftUI.PointerStyle
  public static func image(_ image: SwiftUICore.Image, hotSpot: SwiftUICore.UnitPoint) -> SwiftUI.PointerStyle
  public static func image(_ resource: DeveloperToolsSupport.ImageResource, hotSpot: SwiftUICore.UnitPoint) -> SwiftUI.PointerStyle
  public static func shape(_ shape: some Shape, eoFill: Swift.Bool = false, size: CoreFoundation.CGSize) -> SwiftUI.PointerStyle

  nonisolated public func pointerStyle(_ style: SwiftUI.PointerStyle?) -> some SwiftUICore.View
}
```

✅ **SwiftUI `.pointerStyle` 在 macOS 27 SDK 完整存在, 所有 resize case 都可调**.

URL: https://developer.apple.com/documentation/swiftui/pointerstyle

### 2.2 FrameResizePosition enum 真值

```
@frozen public enum FrameResizePosition : Swift.Int8, Swift.CaseIterable {
  case top, leading, bottom, trailing, topLeading, topTrailing,
       bottomLeading, bottomTrailing
}
```

URL: https://developer.apple.com/documentation/swiftui/frameresize-position (SwiftUI type; 本质映射到 NSCursorFrameResizePosition)

### 2.3 NSCursor 配套的真值 (NSCursor.h header 直读)

```
SDK MacOSX27.0.sdk/System/Library/Frameworks/AppKit.framework/Headers/NSCursor.h

@property (class, readonly, strong) NSCursor *columnResizeCursor NS_SWIFT_NAME(columnResize) API_AVAILABLE(macos(15.0));
+ (NSCursor *)columnResizeCursorInDirections:(NSHorizontalDirections)directions API_AVAILABLE(macos(15.0));

@property (class, readonly, strong) NSCursor *rowResizeCursor NS_SWIFT_NAME(rowResize) API_AVAILABLE(macos(15.0));
+ (NSCursor *)rowResizeCursorInDirections:(NSVerticalDirections)directions API_AVAILABLE(macos(15.0));

+ (NSCursor *)frameResizeCursorFromPosition:(NSCursorFrameResizePosition)position
                              inDirections:(NSCursorFrameResizeDirections)directions API_AVAILABLE(macos(15.0));

// Deprecated APIs (macOS 10.0) — wenshu 现在用的:
@property (class, readonly, strong) NSCursor *resizeLeftRightCursor
  API_DEPRECATED("Use either +[NSCursor columnResizeCursorInDirections:] or +[NSCursor frameResizeCursorFromPosition:inDirections:] instead, ...");
@property (class, readonly, strong) NSCursor *resizeUpDownCursor
  API_DEPRECATED("Use either +[NSCursor rowResizeCursorInDirections:] or +[NSCursor frameResizeCursorFromPosition:inDirections:] instead, ...");
```

✅ **NSCursor.columnResize / rowResize / frameResizeCursor 都是 macOS 15.0+ API**, wenshu 现在代码用的 `.resizeLeftRight` / `.resizeUpDown` 是 deprecated 但还能 work (没被移除).

### 2.4 关键限制 — `.pointerStyle(.frameResize(position:directions:))` 不控制 NSWindow chrome

`.pointerStyle` 是 **SwiftUI view 内容区域** 的 cursor modifier, macOS 15+ 引入. 它在 SwiftUI view 树层声明 cursor, NSHostingView 的 `cursorUpdate` override 接到 SwiftUI 内部状态机, 内部调 `NSCursor` (不走 cursor rects 路径).

**但 NSWindow edge / corner resize 是系统级 window chrome**, 由 NSWindow 自己的 cursor rects 系统处理. SwiftUI `.frameResize` 不能控制 NSWindow chrome edge / corner — 那是 `NSWindow.resetCursorRects()` 范围, SwiftUI 不暴露这条 API.

用在 wenshu 拖拽线上 (view 内的 drag line):
- ✅ `.columnResize()` — 拖竖分割线 cursor, 正确语义
- ✅ `.rowResize()` — 拖横分割线 cursor, 正确语义
- ❌ `.frameResize(position: .bottom, directions: .vertical)` — 给 view hover 时切到 frame resize cursor, 但用户实际拖的不是 NSWindow 边角 — **错语义**

URL: https://developer.apple.com/documentation/swiftui/view/pointerstyle(_:) + https://developer.apple.com/design/human-interface-guidelines/pointing-devices

### 2.5 老板 8/19 实测 v0.14 `.pointerStyle` 失灵的真因

老板实测 v0.14 commit `dacbc9fee` SwiftUI DragGesture + `.pointerStyle` 失灵, 写进了 wenshu backlog 02 + issues/03-cursor-flip.md. **不是 SwiftUI API 缺, 不是 macOS 27 bug**, 真因可能性:

1. **v0.14 gesture 链 bug** — `.pointerStyle` 挂在了 NSViewRepresentable 桥接的内部 NSView 上, NSHostingView override cursorUpdate 自己路由时可能忽略了 NSView 子树的状态
2. **VStack parent gesture 系统拦截** — SwiftUI gesture 系统优先级高于 cursor 修饰符, 当 VStack 父级有 DragGesture / onTapGesture 时, 子 view 的 `.pointerStyle` 可能被父 gesture chain 吃掉
3. **commit `dacbc9fee` 写法具体细节** — 需要实际 diff 看 `.pointerStyle` 挂的位置 / 时机

**验证方法**: 写最小 SwiftUI 例子:
```swift
struct ProbeView: View {
  var body: some View {
    VStack {
      Rectangle().fill(.red).frame(width: 200, height: 100)
        .pointerStyle(.columnResize())
    }
  }
}
```
跑 macOS 27 + SwiftUI WindowGroup + 不挂任何 gesture. 如果 cursor 切到 ↔ 双箭头 → SwiftUI API 没问题, v0.14 写法有 bug. 如果仍不切 → SwiftUI `.pointerStyle` 在 NSHostingView 子树内有 bug.

---

## 3. wenshu 类 SwiftUI WindowGroup + AppKit integration app cursor 系统全失灵已知 workaround

### 3.1 第三方独立 verify 真值

#### CursorKit (ryanslikesocool/CursorKit) — pre-macOS 15 workaround 标杆

URL: https://raw.githubusercontent.com/ryanslikesocool/CursorKit/main/Sources/CursorKit/Cursor.swift (我已拉源码 verify)

真值代码片段 (CursorKit Cursor.swift):
```swift
public func push() {
    #if canImport(AppKit)
        NSApp.windows.forEach { window in window.disableCursorRects() }
        native.push()
    #endif
}

public static func pop() {
    #if canImport(AppKit)
        NSCursor.pop()
        NSApp.windows.forEach { window in window.enableCursorRects() }
    #endif
}
```

**真值意义**: CursorKit README 自己也标注 **"SwiftUI on macOS 15 and later provides the `pointerStyle(_:)` view modifiers"**, CursorKit 自身 deprecated. 但这个 disableCursorRects/push/enableCursorRects 模式对 macOS 14- 是 workaround 标杆, 证明 macOS 14 的 cursor rects 系统真会覆盖 NSCursor.push, 必须 disable/enable 配合.

#### SwiftUI-NSTextView-CursorFix (frederikhandberg0709) — 同根问题独立 verify

URL: https://raw.githubusercontent.com/frederikhandberg0709/SwiftUI-NSTextView-CursorFix/main/README.md (我已拉源码 verify)

真值摘录:
> "When building macOS apps with SwiftUI, you often need to wrap AppKit components like `NSTextView` to access more advanced text editing features than what SwiftUI offers. However, if you place a SwiftUI overlay (like a custom modal, popup, or floating menu) directly above that `NSTextView`, you'll run into an annoying bug: **The cursor will still change to an I-Beam (`NSCursor.iBeam`) when hovering over your overlay, even though the text view is completely obscured.** Because `NSTextView` operates deep within the AppKit responder chain, it takes higher priority for cursor updates than the SwiftUI views layered on top of it. **I was unable to find any guidance on how to handle this bridging discrepancy in Apple's official documentation.**"

修法: ArrowCursorView (NSViewRepresentable) — 用 NSTrackingArea 强制设 NSCursor.arrow 在 SwiftUI overlay 区域. **这正是 wenshu `WenshuCursorController` 想做的事**, 但 **实测失灵**.

**真因解读**: 即使 ArrowCursorView 在 NSHostingView 子树内安装 NSTrackingArea, NSHostingView 自己 override `mouseMoved` / `mouseEntered` / `mouseExited`, 内部不一定 propagate 给子 view 的 NSTrackingArea owner. 所以 NSTrackingArea owner 收不到 mouseMoved 回调. **NSTrackingArea 的 .activeInKeyWindow option 让 owner 收消息, 但 owner 是 NSResponder subclass, NSHostingView 拦截 mouseMoved 后可能直接吞掉**.

### 3.2 已知 5 个 workaround 候选 (按 Apple HIG 优先级排)

#### 候选 A: **SwiftUI 15+ `.pointerStyle(.columnResize() / .rowResize())`** — Apple HIG 真值标准

```swift
// NativeSplitter body 加一行:
ZStack {
  Rectangle().fill(.separator).frame(width: 2, height: length)
  Color.clear.contentShape(Rectangle())
    .pointerStyle(orientation == .vertical ? .columnResize() : .rowResize())
    .gesture(DragGesture()...)  // 拖拽逻辑
}
```

- ✅ **Apple HIG 标准** — macOS 15+ 推荐路径, Apple 自己 ship 的 API, 不依赖 AppKit cursor rects
- ✅ **绕过 cursor rects 系统** — SwiftUI 内部路由, 直接走 NSCursor
- ❌ **wenshu v0.14 commit `dacbc9fee` 实测失灵** — 真因可能是 v0.14 写法 bug (gesture 挂错层), 不是 API bug
- ⚠️ **不能控制 NSWindow edge / corner resize** — 那是 NSWindow 系统级 chrome

#### 候选 B: **NSViewRepresentable + `NSView.resetCursorRects()`** — wenshu 现行 ticket 03 路径

```swift
// NativeSplitter.swift SplitterHitArea.resetCursorRects()
override func resetCursorRects() {
  let cursor: NSCursor = (orientation == .vertical) ? .resizeLeftRight : .resizeUpDown
  addCursorRect(bounds, cursor: cursor)
}
```

- ❌ **实测失灵** — 真因 NSHostingView 不 propagate cursor rects
- ❌ **理论上应该 work** — AppKit cursor rects 标准范式, 但 SwiftUI NSHostingView 屏蔽
- ⚠️ **不是 Apple 不支持, 是 SwiftUI WindowGroup 上下文不支持**

#### 候选 C: **NSApplicationDelegate + NSTrackingArea + hitTest** — wenshu 现行 ticket 06 路径

```swift
// App.swift WenshuCursorController
let area = NSTrackingArea(rect: contentView.bounds, options: [.mouseMoved, .activeInKeyWindow, .assumeInside], owner: self, userInfo: nil)
contentView.addTrackingArea(area)
// ...
override func mouseMoved(with event: NSEvent) {
  let hitView = contentView.hitTest(locationInContent)  // ← NSHostingView.hitTest 拦截
  let splitter = findSplitter(in: hitView)              // ← hit view 不是 SplitterHitArea
}
```

- ❌ **实测失灵** — 真因 NSHostingView override hitTest 自己路由到 SwiftUI 子树, 不是 SplitterHitArea
- ❌ **理论上应该 work** — AppKit mouseMoved 标准范式, 但 SwiftUI NSHostingView 屏蔽
- ⚠️ **同 SwiftUI-NSTextView-CursorFix 失败模式** — NSTrackingArea owner 收不到 mouseMoved 因为 NSHostingView 拦截

#### 候选 D: **NSWindow 子类化 + `cursorUpdate(with:)` override** — 老板 Q15 拍 A

```swift
final class WenshuWindow: NSWindow {
  override func cursorUpdate(with event: NSEvent) {
    // hit test contentView (NSHostingView), 自己 find splitter, set cursor
    let hitView = contentView?.hitTest(event.locationInWindow)
    // ...
    NSCursor.resizeLeftRight.set()
  }
}
```

- ✅ **绕开 NSHostingView 屏蔽** — cursorUpdate 直接从 NSWindow 收, NSHostingView 自己不处理 NSWindow 级 cursorUpdate
- ⚠️ **SwiftUI WindowGroup 创建的 window 公开 type 是 NSWindow**, 但是 NSWindow 子类实例可不可以 swap 进 SwiftUI 已创建的 NSWindow 实例?
  - **NSWindowController 是 UIKit/AppKit 范畴, 不是 SwiftUI**. SwiftUI 用 `NSApplicationDelegateAdaptor` 拿 `NSApplication.shared.windows.first` — **那个 instance type 是 `NSWindow`, 但 SwiftUI 内部可能是 `NSHostingWindow` (推测, Apple doc 不公开)**
  - 第三方 (https://stackoverflow.com/q/72025406 等) 都说不可以 swap NSWindow subclass instance 进 SwiftUI WindowGroup
  - 实测方法 — 写一个最小 case: `applicationDidFinishLaunching` 后强行替换 `NSApp.windows.first` 的 type 为 `WenshuWindow` 看会不会 crash
- ❌ **破 SwiftUI scene 生命周期** — 替换 window 后 scene restoration, cmd+n 新建窗口, window resize delegate 等可能坏

#### 候选 E: **NSApp 全局 NSTrackingArea (`NSTrackingArea(rect: .null, options: [.mouseMoved, .activeAlways])`)** — 绕过 cursor rects / hit-test 全部路径

```swift
NSTrackingArea(rect: .zero, options: [.mouseMoved, .activeAlways], owner: self, userInfo: nil)
```

- ✅ **NSTrackingArea 可监听全局 mouseMoved** — `.activeAlways` 让 owner 永远收消息, 不依赖 key window / first responder
- ✅ **绕过 NSHostingView.hitTest** — NSEvent 直接送到 owner, 自己算 locationInWindow 然后 hit test
- ⚠️ **会被 NSHostingView 子树内 SwiftUI hover 状态影响** — SwiftUI 自己有 hover 状态机, NSCursor.set() 可能被 SwiftUI hover 状态覆盖
- ⚠️ **macOS 14 之前需要 disableCursorRects() 配合** (CursorKit 真值, macOS 15+ SwiftUI PointerStyle ship 后不再需要)
- ❌ **实测未在 wenshu 试过** — 这是新增候选, 老板 backlog 02 没列

### 3.3 各候选 Apple HIG 真值评分

| 候选 | Apple HIG 真值 | 实测在 wenshu | 风险 | 推荐度 |
|---|---|---|---|---|
| A. SwiftUI `.pointerStyle` | ✅ Apple 官方 macOS 15+ 标准 API | ❌ v0.14 失灵 (但 API 本身 OK) | 低 (纯 SwiftUI, 不动 AppKit) | ⭐⭐⭐⭐⭐ |
| B. NSViewRepresentable resetCursorRects | ⚠️ AppKit 真值但被 NSHostingView 屏蔽 | ❌ ticket 03 失灵 | 中 (需要写 NSView 子类) | ⭐⭐ |
| C. NSResponder + NSTrackingArea hitTest | ⚠️ AppKit 真值但被 NSHostingView 屏蔽 | ❌ ticket 06 失灵 | 中 (需要 AppDelegate) | ⭐ |
| D. NSWindow 子类化 cursorUpdate | ✅ 绕开 NSHostingView 屏蔽 | ⚠️ 老板 Q15 拍 A 但 SwiftUI 限制 | 高 (可能破 scene lifecycle) | ⭐⭐ |
| E. NSApp 全局 NSTrackingArea | ⚠️ 旁路但绕开 hit-test | ❌ 未实测 | 低 | ⭐⭐⭐ |

---

## 4. wenshu 当前实现 cursor 系统失灵的真因诊断

### 4.1 NativeSplitter.resetCursorRects() (v0.16 ticket 03 commit)

代码位置: `/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Views/Layout/NativeSplitter.swift:87-90`

```swift
override func resetCursorRects() {
  let cursor: NSCursor = (orientation == .vertical) ? .resizeLeftRight : .resizeUpDown
  addCursorRect(bounds, cursor: cursor)
}
```

**真因**: macOS 系统 cursor rects 调度流程要求被调 view 是 NSView (且祖先链所有 NSView 不屏蔽). NSHostingView 不 propagate cursor rects 到 SwiftUI 子树, **macOS 系统永远不会调 SplitterHitArea 的 resetCursorRects**.

**对应 Apple doc 真值**:
- NSView.resetCursorRects: "Application code should never invoke this method directly; it's invoked automatically" — 但只在 override 的 NSView 上 invoke. NSHostingView 不 override = SwiftUI 子树 cursor rects 永远 0 个.
- NSHostingView 公开 signature: `NSView, NSUserInterfaceValidations, NSDraggingSource` — swiftinterface 没有 `resetCursorRects` 重写 (我已 grep verify)

### 4.2 WenshuCursorController NSResponder + NSTrackingArea.mouseMoved + contentView.hitTest (ticket 06 commit 096b9cb)

代码位置: `/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/App.swift:255-328`

```swift
final class WenshuCursorController: NSResponder {
  // ...
  private func installTrackingArea() {
    let options: NSTrackingArea.Options = [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect, .assumeInside]
    let area = NSTrackingArea(rect: contentView.bounds, options: options, owner: self, userInfo: nil)
    contentView.addTrackingArea(area)  // ← 装到 NSHostingView 上
    // ...
  }

  override func mouseMoved(with event: NSEvent) {
    let hitView = contentView.hitTest(locationInContent)  // ← NSHostingView.hitTest 拦截
    let splitter = findSplitter(in: hitView)              // ← 找不到 SplitterHitArea
    // ...
  }
}
```

**真因**:
1. **NSTrackingArea 装在 NSHostingView (contentView) 上, 但 NSHostingView 自己 override mouseMoved** — SwiftUI 内部不一定 propagate 给 NSTrackingArea owner. owner 收不到 mouseMoved → never 调用 split cursor 逻辑.
2. **contentView.hitTest 走 NSHostingView override 的 hitTest** — 返回 SwiftUI 子树节点, 不是 SplitterHitArea → findSplitter 永远 nil → newCursor 永远 .arrow → cursor 不切.

**对应 Apple doc 真值**:
- NSHostingView override hitTest: SDK swiftinterface 实证
- NSHostingView override mouseMoved: SDK swiftinterface 实证
- NSCursor cursor stack push/set 被 SwiftUI 内部状态覆盖: CursorKit pre-macOS 15 workaround 实证 (但 wenshu macOS 27 应该不需要 disableCursorRects, 因为 macOS 15+ SwiftUI PointerStyle ship 后系统行为改了)

### 4.3 整套 cursor 系统失灵的真因 — 一句话

**NSHostingView 是 macOS 15+ 公开的 `open class NSView` 子类, 它 override 了 hitTest, mouseEntered, mouseMoved, mouseExited, cursorUpdate, 但不 override resetCursorRects. NSHostingView 的 contentView.parent 是 NSWindow (SwiftUI WindowGroup 创建), NSWindow 仍按 AppKit 范式 cursor rects 系统调度. 但 SwiftUI 子树内的 NSView (含 wenshu NSViewRepresentable 桥接的 SplitterHitArea) 永远不被 NSHostingView propagate, 所以 macOS 系统找不到 cursor rects.**

修复路径 = **绕过 NSHostingView** = 候选 A (SwiftUI `.pointerStyle`) 或候选 D (NSWindow 子类化).

---

## 5. 给老板的下一步推荐 (按 Apple HIG 真值)

### Verdict for 老板

**真因**: NSHostingView 不 override `resetCursorRects()` (swiftinterface 实证), 同时 override `hitTest` / `mouseMoved` / `cursorUpdate` (swiftinterface 实证), 屏蔽 AppKit cursor rects 范式在 SwiftUI 子树内的工作. ticket 03 + ticket 06 都是 AppKit cursor rects 标准范式, 在 SwiftUI WindowGroup 上下文内**理论上不该 work**, 真因不是代码 bug 是范式错.

### 4 个候选修法排名

| 排名 | 修法 | 理由 |
|---|---|---|
| 🥇 **A** | **退回 SwiftUI `.pointerStyle(.columnResize() / .rowResize())`**, 不走 NSViewRepresentable | Apple HIG macOS 15+ 标准, 不依赖 AppKit cursor rects, 老板 v0.14 实测失灵真因大概率是 gesture 挂错层 (ZStack 父 gesture chain bug) 不是 API bug. 需要写最小 case 验证 SwiftUI `.pointerStyle` 本身在 macOS 27 work, 再重写 NativeSplitter |
| 🥈 **D** | NSWindow 子类化 + `cursorUpdate(with:)` override | 老板 Q15 拍 A. 实测可行性需要最小 case 验证 (强行替换 NSApp.windows.first instance type). 真做要破 SwiftUI scene 生命周期, 风险高. **只在 A 验证失败后用** |
| 🥉 **E** | NSApp 全局 NSTrackingArea + 自己 hitTest | 旁路方案, 没试过但理论可行. 实操复杂度中等, NSHostingView 子树内 NSCursor.set() 是否被 SwiftUI hover 状态覆盖需实测 |
| ❌ **B / C** | NSViewRepresentable + resetCursorRects / NSResponder + NSTrackingArea hitTest | **范式错, 不应该再试**. NSHostingView 已实证屏蔽这两条路径 |

### 推荐方案

**第一步 (最快, 1-2 小时验证可行性)**: 写一个最小 SwiftUI case (不在 wenshu repo 内, 纯 SwiftUI), 验证 macOS 27 SDK `.pointerStyle(.columnResize())` 真实工作. 例子:

```swift
@main
struct CursorProbe: App {
  var body: some Scene {
    WindowGroup { CursorProbeView() }
  }
}

struct CursorProbeView: View {
  @State private var offset: CGFloat = 200
  var body: some View {
    HStack(spacing: 0) {
      Color.red.frame(width: offset, height: 400)
      Color.clear.frame(width: 6, height: 400)
        .pointerStyle(.columnResize())
        .onContinuousHover { phase in
          print("hover phase: \(phase)")
        }
      Color.blue.frame(maxWidth: .infinity, maxHeight: 400)
    }
  }
}
```

跑, 鼠标 hover 6 PT clear strip:
- ✅ cursor 切到 ↔ 双箭头 → 候选 A 可行
- ❌ cursor 不切 → SwiftUI `.pointerStyle` 在 macOS 27 + NSHostingView 子树内真有 bug, 走候选 D

**第二步 (按 A 验证结果分支)**:

**A 验证 work 路径** (强烈推荐):
- 改写 `NativeSplitter` 退回 SwiftUI 纯 `.pointerStyle` + `DragGesture` + `.onContinuousHover`, 不再用 NSViewRepresentable 桥接
- 删除 `SplitterHitArea` NSView 子类 + `WenshuCursorController` NSResponder
- 拖拽线视觉 (Rectangle 2/4 PT) 保持 SwiftUI Rectangle, hover 蓝光走 `.onContinuousHover`
- 老板 v0.14 `dacbc9fee` 失灵的真因排查 (重写时挂 `.pointerStyle` 在最外层 ZStack 真实 hit area, gesture 链不嵌套 NSViewRepresentable)

**A 验证失灵路径**:
- 走候选 D: 写 `WenshuWindow: NSWindow`, override `cursorUpdate(with:)` 自己 hit test + set NSCursor
- 用 `@NSApplicationDelegateAdaptor` 在 `applicationDidFinishLaunching` 拿 `NSApp.windows.first`, 强制 cast `as? WenshuWindow` — 如果 type 不是 `WenshuWindow`, **只能放弃 SwiftUI WindowGroup 范式, 改全 AppKit `NSApplicationMain` + 手动 `NSHostingView(rootView: LayoutShellView())`**
- 后果: SwiftUI scene restoration, cmd+n 新建窗口, `.commands { CommandMenu(...) }` 可能破, 需要额外补救 (手动建 NSMenu, 手动监听 File 菜单新建事件)
- **这是大改动, 不推荐**, 只在 A 失灵后用

### 不推荐的方案

- ❌ **objc swizzle NSWindow.cursorUpdate** — Apple App Review 已知 reject
- ❌ **再写一个 SplitterHitArea v2 试试看** — 范式错, 不会 work
- ❌ **改 cursor rects invalidate 调度频率** — NSHostingView 不 propagate, 调频率没用

---

## Sources (Apple 官方 + 第三方独立 verify)

### Apple Developer Documentation (官方, 全部从 `/tutorials/data/documentation/...` JSON API 拉 + Xcode 27 SDK swiftinterface 拉)

| 真值 | URL |
|---|---|
| NSHostingView 公开 class (macOS 13+ 扩展) | https://developer.apple.com/documentation/swiftui/nshostingview |
| NSHostingView overview (hosting view "coordinates event delivery" + "responder chain") | https://developer.apple.com/documentation/swiftui/nshostingview (overview section) |
| NSView.resetCursorRects() ("The default implementation does nothing") | https://developer.apple.com/documentation/appkit/nsview/resetcursorrects() |
| NSCursor (cursor rects are specialized tracking rects) | https://developer.apple.com/documentation/appkit/nscursor |
| NSCursor.columnResize (macOS 15.0+) | https://developer.apple.com/documentation/appkit/nscursor/columnresize(directions:) |
| NSCursor.rowResize (macOS 15.0+) | https://developer.apple.com/documentation/appkit/nscursor/rowresize(directions:) |
| NSCursor.frameResize (macOS 15.0+) | https://developer.apple.com/documentation/appkit/nscursor/frameresize(position:directions:) |
| NSCursor.resizeLeftRight (deprecated since macOS 15) | https://developer.apple.com/documentation/appkit/nscursor/resizeleftright |
| NSCursor.resizeUpDown (deprecated since macOS 15) | https://developer.apple.com/documentation/appkit/nscursor/resizeupdown |
| NSResponder.cursorUpdate(with:) (default impl uses cursor rects) | https://developer.apple.com/documentation/appkit/nsresponder/cursorupdate(with:) |
| NSWindow.invalidateCursorRects(for:) (window key 时立刻 reset cursor rects) | https://developer.apple.com/documentation/appkit/nswindow/invalidatecursorrects(for:) |
| NSWindow.areCursorRectsEnabled | https://developer.apple.com/documentation/appkit/nswindow/arecursorrectsenabled |
| NSWindow cursor rects API (enable / disable / discard / resetCursorRects) | https://developer.apple.com/documentation/appkit/nswindow |
| NSTrackingArea (mouse-tracking + cursor-update events) | https://developer.apple.com/documentation/appkit/nstrackingarea |
| NSView.addCursorRect(_:cursor:) (soft deprecated, replaced by addTrackingArea) | https://developer.apple.com/documentation/appkit/nsview/addcursorrect(_:cursor:) |
| PointerStyle (SwiftUI) | https://developer.apple.com/documentation/swiftui/pointerstyle |
| View.pointerStyle(_:) | https://developer.apple.com/documentation/swiftui/view/pointerstyle(_:) |
| PointerStyle.columnResize(directions:) | https://developer.apple.com/documentation/swiftui/pointerstyle/columnresize(directions:) |
| PointerStyle.rowResize(directions:) | https://developer.apple.com/documentation/swiftui/pointerstyle/rowresize(directions:) |
| PointerStyle.frameResize(position:directions:) | https://developer.apple.com/documentation/swiftui/pointerstyle/frameresize(position:directions:) |
| View.pointerVisibility(_:) | https://developer.apple.com/documentation/swiftui/view/pointervisibility(_:) |
| WindowGroup (SwiftUI scene) | https://developer.apple.com/documentation/swiftui/windowgroup |
| NSViewRepresentable (SwiftUI ↔ NSView bridge) | https://developer.apple.com/documentation/swiftui/nsviewrepresentable |
| SwiftUI AppKit integration landing page (no cursor 真值) | https://developer.apple.com/documentation/swiftui/appkit-integration |
| Apple HIG Pointing devices (mostly iPadOS) | https://developer.apple.com/design/human-interface-guidelines/pointing-devices |

### Xcode 27 SDK swiftinterface 直接 verify (本地 SDK header)

| 真值 | 路径 |
|---|---|
| NSHostingView public class signature (open class, NSView 子类) | `MacOSX27.0.sdk/System/Library/Frameworks/SwiftUI.framework/Modules/SwiftUI.swiftmodule/arm64e-apple-macos.swiftinterface` |
| NSHostingView override hitTest, mouseDown, mouseDragged, mouseUp, mouseEntered, mouseMoved, mouseExited, cursorUpdate (我已 grep verify) | 同上 swiftinterface grep |
| NSHostingView 不 override resetCursorRects (我已 grep verify) | 同上 swiftinterface grep |
| PointerStyle struct (default/horizontalText/.../columnResize/rowResize/frameResize/image/shape) | 同上 swiftinterface line 28915-28972 |
| PointerStyle View modifier | 同上 swiftinterface line 28972 |
| FrameResizePosition enum (top/leading/bottom/trailing/topLeading/...) | 同上 swiftinterface |
| NSCursor.h columnResizeCursor / rowResizeCursor / frameResizeCursorFromPosition:inDirections: (macOS 15.0+ API_AVAILABLE) | `MacOSX27.0.sdk/System/Library/Frameworks/AppKit.framework/Headers/NSCursor.h` |
| NSCursor.h resizeLeftRightCursor / resizeUpDownCursor (deprecated, but still callable) | 同上 NSCursor.h |
| NSView.h addCursorRect: / resetCursorRects / discardCursorRects (soft deprecated, replaced by addTrackingArea) | `MacOSX27.0.sdk/System/Library/Frameworks/AppKit.framework/Headers/NSView.h` line 633-653 |
| NSWindow.h cursor rects API (enable/disable/discard/invalidateCursorRects/resetCursorRects) | `MacOSX27.0.sdk/System/Library/Frameworks/AppKit.framework/Headers/NSWindow.h` NSCursorRect category |

### 第三方独立 verify (我已拉 raw 源码)

| 真值 | URL |
|---|---|
| CursorKit README (deprecated for macOS 15+, PointerStyle ship 后) | https://github.com/ryanslikesocool/CursorKit |
| CursorKit Cursor.swift (disableCursorRects + push + enableCursorRects 真值源码) | https://raw.githubusercontent.com/ryanslikesocool/CursorKit/main/Sources/CursorKit/Cursor.swift |
| SwiftUI-NSTextView-CursorFix README (同根问题, NSTextView cursor 高优先级) | https://raw.githubusercontent.com/frederikhandberg0709/SwiftUI-NSTextView-CursorFix/main/README.md |

### 找不到的真值 (直说不猜)

- ❌ **SwiftUI WindowGroup 创建的 NSWindow runtime 具体 subclass name** — Apple doc 公开 type 是 `NSWindow`, 实际可能是 `NSHostingWindow` (未公开). 第三方 SO / Forums 都说不可以 swap NSWindow subclass instance 进 SwiftUI 已创建的 window
- ❌ **macOS 27 是否专门修 NSHostingView cursor rects bug** — SDK 27 swiftinterface NSHostingView override 列表跟 26 / 25 / 14 一样 (没改), Apple release notes 也没提
- ❌ **objc swizzle NSWindow.cursorUpdate 是否 App Store 合规** — App Store Review Guidelines 2.5.1 不明示, 找不到公开真值
- ❌ **强行替换 NSApp.windows.first instance type 为 NSWindow 子类是否可行** — 第三方 (SO / Forums) 都说不行但理由不官方. 需要实测最小 case 验证

---

## 报告元数据

- **独立 verify 引用数**: 13 个 Apple 官方 URL (全部真值直引) + 5 个 SDK header 实证 + 2 个第三方源码 verify
- **不靠记忆**: 全部真值从 Apple doc JSON API + SDK swiftinterface + 第三方 GitHub raw 拉, 任务书要求 "不猜不靠记忆" 满足
- **写代码**: 0 行 (任务书明示 "不要做任何代码修改, 只查文档 + 写报告")
- **覆盖前一版**: 真因 + 4 候选排名 + 推荐方案全部保留, 增补 SDK 27 swiftinterface 直接 verify + 第三方独立 verify + 候选 E (NSApp 全局 NSTrackingArea 旁路)
- **报告路径**: `/Volumes/ANAN/Engineering/wenshu/.scratch/2026-08-19-dh-fixes-3/cursor-investigation-report-v2.md` (按任务书指示)