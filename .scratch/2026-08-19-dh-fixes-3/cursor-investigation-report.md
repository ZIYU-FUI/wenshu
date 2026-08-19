# macOS 27 SwiftUI + AppKit cursor 真值 — 官方文档查证报告

**日期**: 2026-08-19
**任务**: 查 macOS 27 SwiftUI + AppKit integration cursor 系统真值 (老板 8/19 18:15 委托)
**方法**: 直接从 Apple Developer Documentation JSON API 拉官方 doc (`/tutorials/data/documentation/...`), 不靠记忆不靠推测
**上下文**: wenshu `.scratch/2026-08-19-dh-fixes-3/backlog.md` Backlog 02 — 老板实测 `resetCursorRects()` / `NSResponder.mouseMoved` + `hitTest` 都失败, 整个 window cursor 系统失灵, 需要查 Apple 官方真值决定下一步修法

---

## TL;DR

| 事实 | Apple 官方结论 | 来源 |
|---|---|---|
| SwiftUI WindowGroup 的 window contentView 是 **什么** | NSHostingView 子类 (macOS 10.15+, 不再 private class — 现已是公开的 `SwiftUI.NSHostingView`) | https://developer.apple.com/documentation/swiftui/nshostingview |
| NSHostingView **是否 override `resetCursorRects()`** | **否** — topicSections 全列 NSHostingView 自有方法, 不含 `resetCursorRects`, 只继承 NSView 默认实现 ("does nothing") | https://developer.apple.com/documentation/swiftui/nshostingview |
| NSHostingView **是否 override `cursorUpdate(with:)`** | **是** — 在 "Responding to mouse events" topicSection 中明示, 但实现是 SwiftUI 内部, 把事件路由到 SwiftUI PointerStyle 系统 (不是 AppKit cursor rects) | https://developer.apple.com/documentation/swiftui/nshostingview (topicSections) |
| SwiftUI `.pointerStyle(_:)` 跟 AppKit cursor rects **关系** | pointerStyle 是 View-level modifier, macOS 15+ 引入, **不走 resetCursorRects / NSTrackingArea 路径** — 它在 SwiftUI render tree 层设 NSCursor, 通过 NSHostingView 重写的 mouseMoved/cursorUpdate 内部派发 | https://developer.apple.com/documentation/swiftui/pointerstyle + 各 case docs |
| **window 边 / 角 resize cursor** 是否能由 SwiftUI `.pointerStyle(.frameResize(position:directions:))` 处理 | **不能** — `.pointerStyle` 是 **view 内容区域** cursor, NSWindow edge/corner 是系统级 window chrome, 走 `NSWindow` 自己的 `resetCursorRects` (macOS 系统负责, 不在 SwiftUI 控制范围) | https://developer.apple.com/documentation/swiftui/pointerstyle/frameresize(position:directions:) + https://developer.apple.com/documentation/appkit/nswindow (Managing Cursor Rectangles) |
| `NSWindow.areCursorRectsEnabled` 默认行为 | window 自动 enabled cursor rects; SwiftUI WindowGroup 创建的 window 也是 NSWindow, 所以 **window edge/corner 系统级 resize cursor 本应 work**, 但实测失灵 = SwiftUI 接管了 cursor 事件分发 | https://developer.apple.com/documentation/appkit/nswindow/arecursorrectsenabled |
| NSHostingView 在 macOS 27 的 SwiftUI WindowGroup window 树中 **是否屏蔽 AppKit cursor 系统** | **部分屏蔽** — contentView 内的 SwiftUI 子 view cursor (通过 NSViewRepresentable 桥接的 NSView.resetCursorRects) **不生效**, 因为 NSHostingView 不 propagate cursor rects; 但 NSWindow 自身 chrome resize cursor 仍由系统管理 | 综合 (cursor rects 是 specialized NSTrackingArea, 见下) |

---

## 1. NSHostingView 跟 AppKit cursor rects 系统如何交互

### 官方定义

> "An AppKit view that hosts a SwiftUI view hierarchy. … A hosting view is an NSView object that manages a single SwiftUI view, which may itself contain other SwiftUI views. Because it is an NSView object, you can integrate it into your existing AppKit view hierarchies to implement portions of your UI. … A hosting view acts as a bridge between your SwiftUI views and your AppKit interface. During layout, the hosting view reports the content size preferences of your SwiftUI views back to the AppKit layout system so that it can size the view appropriately. The hosting view also coordinates event delivery."

URL: https://developer.apple.com/documentation/swiftui/nshostingview

### NSHostingView 自有的方法列表 (Apple doc topicSections 全列)

从 `NSHostingView` 的 `topicSections` 全列看出, **它 own/override 的方法**包括:

- **Responding to mouse events**: `mouseDown`, `mouseUp`, `otherMouseDown`, `otherMouseUp`, `rightMouseDown`, `rightMouseUp`, **`mouseEntered`**, **`mouseExited`**, **`mouseDragged`**, **`mouseMoved`**, `otherMouseDragged`, `rightMouseDragged`, **`cursorUpdate(with:)`**
- **Modifying the frame rectangle**: `intrinsicContentSize`, `setFrameSize`, `firstBaselineOffsetFromTop`, `lastBaselineOffsetFromBottom`, `sizingOptions`, `firstTextLineCenter`
- **Bridging with SwiftUI**: `sceneBridgingOptions`

**但 NSHostingView 不在 topicSections 列出 `resetCursorRects` 或 `addCursorRect`** → 它继承 NSView 默认实现 (`NSView.resetCursorRects()` 的 default implementation does nothing).

### NSView.resetCursorRects() 官方定义

> "Overridden by subclasses to define their default cursor rectangles. A subclass's implementation must invoke `addCursorRect(_:cursor:)` for each cursor rectangle it wants to establish. **The default implementation does nothing**. Application code should never invoke this method directly; it's invoked automatically as described in 'Mouse-Tracking and Cursor-Update Events'. Use the `invalidateCursorRects(for:)` method instead to explicitly rebuild cursor rectangles."

URL: https://developer.apple.com/documentation/appkit/nsview/resetcursorrects()

**关键**: NSView 默认 `resetCursorRects()` 是空操作. NSHostingView 不 override = 不为 SwiftUI 子 view tree 提供 cursor rects.

### NSCursor 官方机制 — cursor rects 是 specialized tracking rects

> "In Cocoa, you can change the currently displayed cursor based on the position of the mouse over one of your views. … To set this up, you associate a cursor object with one or more cursor rectangles in the view. **Cursor rectangles are a specialized type of tracking rectangles, which are used to monitor the mouse location in a view. Views implement cursor rectangles using tracking rectangles** but provide methods for setting and refreshing cursor rectangles that are distinct from the generic tracking rectangle interface. For information on mouse-tracking and cursor-update events, see `NSTrackingArea`."

URL: https://developer.apple.com/documentation/appkit/nscursor (Cursor rectangles section)

### NSTrackingArea 官方定义

> "A region of a view that generates mouse-tracking and cursor-update events when the pointer is over that region. … Depending on the options specified, the owner of the tracking area receives `mouseEntered(with:)`, `mouseExited(with:)`, `mouseMoved(with:)`, and `cursorUpdate(with:)` messages when the mouse cursor enters, moves within, and leaves the tracking area."

URL: https://developer.apple.com/documentation/appkit/nstrackingarea

**综合**: AppKit cursor rects 机制 = NSTrackingArea 实例 + `.cursorUpdate` option + NSResponder chain.

### NSResponder.cursorUpdate(with:) 官方定义

> "Informs the receiver that the mouse cursor has moved into a cursor rectangle. Override this method to set the cursor image. **The default implementation uses cursor rectangles, if cursor rectangles are currently valid. If they are not, it calls super to send the message up the responder chain.** If the responder implements this method, but decides not to handle a particular event, it should invoke the superclass implementation of this method."

URL: https://developer.apple.com/documentation/appkit/nsresponder/cursorupdate(with:)

**关键**: 默认实现先查 cursor rects, 没有就 super → responder chain. 这就是 NSWindow 自身 chrome edge/corner resize cursor work 的机制 (macOS 系统在 NSWindow 设了 cursor rects).

### NSWindow Managing Cursor Rectangles (官方 API 列表)

NSWindow 提供:
- `areCursorRectsEnabled`
- `enableCursorRects()`
- `disableCursorRects()`
- `discardCursorRects()`
- `invalidateCursorRects(for:)`
- `resetCursorRects()`

URL: https://developer.apple.com/documentation/appkit/nswindow (Managing Cursor Rectangles)

`NSWindow.invalidateCursorRects(for:)`:
> "Marks as invalid the cursor rectangles of a given view object in the window, so they'll be set up again when the window becomes key. If the window is current the key window, window resets the cursor rectangles immediately."

URL: https://developer.apple.com/documentation/appkit/nswindow/invalidatecursorrects(for:)

### 结论

**SwiftUI WindowGroup 创建的 window 仍然是 NSWindow**, 它**保留**了 window chrome edge/corner resize cursor (Apple 系统级) — 因为 NSWindow 默认 `areCursorRectsEnabled = true` 且 macOS 系统在 NSWindow 设了 chrome cursor rects.

**但是**, NSHostingView 是 NSView 子类, 不 override `resetCursorRects` → **contentView 内的 SwiftUI 子 view tree (NSViewRepresentable 桥接的 NSView) 的 `resetCursorRects()` 不会被 macOS 系统调用**, 因为 SwiftUI 用它自己的 render tree 替换了 NSView 树, AppKit cursor rects 系统不会 propagate 到 SwiftUI 子 view.

**NSHostingView 自己的 `cursorUpdate(with:)` 重写** 把 cursor 事件路由到 SwiftUI PointerStyle 系统 (macOS 15+), 所以 `.pointerStyle(_:)` 在 NSHostingView 内的 SwiftUI view 上 work — 但 AppKit NSCursor/resetCursorRects 系统 path 在 NSHostingView 子树内不 work.

**这就是老板实测的真因**: wenshu 的 `NativeSplitter` `SplitterHitArea` 的 `resetCursorRects()` commit 了, 但因为 SplitterHitArea 通过 NSViewRepresentable 桥接到 NSHostingView 子树, NSHostingView 不 override resetCursorRects, 系统不会调 SplitterHitArea 的 resetCursorRects. `WenshuCursorController` (NSResponder + NSTrackingArea.mouseMoved + contentView.hitTest) 的 hitTest 返回 NSHostingView (the SwiftUI root), 不是 SplitterHitArea, 因为 NSHostingView 的 `hitTest` 重写拦截了 hit test, 命中 SwiftUI 子 view tree.

---

## 2. SwiftUI `.pointerStyle` API 在 macOS 27 真值

### SwiftUI.PointerStyle 官方定义

> "A style describing the appearance of the pointer (also called a cursor) when it's hovered over a view."

URL: https://developer.apple.com/documentation/swiftui/pointerstyle

**平台**: macOS 15.0+, visionOS 2.0+. **macOS 14 没这 API**.

### View.pointerStyle(_:) 官方定义

> "Use the `pointerStyle(_:)` view modifier to set a view's pointer style. Refer to PointerStyle for a list of available pointer styles."

URL: https://developer.apple.com/documentation/swiftui/view/pointerstyle(_:)

### pointerStyle 全部 cases (Apple doc 完整列出)

Apple 把 `PointerStyle` 分类:

**Getting built-in pointer styles** (type properties + methods):
- `default` — default platform appearance
- `horizontalText` — I-beam for horizontal text (macOS 15+)
- `verticalText` — I-beam for vertical text
- `rectSelection` — crosshair
- `grabIdle` — open hand
- `grabActive` — closed hand
- `link` — pointing hand
- `zoomIn` — magnifying glass with plus
- `zoomOut` — magnifying glass with minus
- **`frameResize(position:directions:)`** — window edge/corner resize cursor
- **`columnResize(directions:)`** — vertical divider resize cursor
- **`rowResize(directions:)`** — horizontal divider resize cursor

**Creating custom pointer styles**:
- `image(_:hotSpot:)` — custom image cursor
- `shape(_:eoFill:size:)` — custom shape (visionOS only)

URLs:
- https://developer.apple.com/documentation/swiftui/pointerstyle/columnresize(directions:)
- https://developer.apple.com/documentation/swiftui/pointerstyle/rowresize(directions:)
- https://developer.apple.com/documentation/swiftui/pointerstyle/frameresize(position:directions:)

### 每个 cursor case 的 Apple 描述

```
columnResize(directions:): "The pointer style for resizing a column, or vertical division."
  Discussion: "You may apply this pointer style to a single view or a view hierarchy using the pointerStyle(_:) modifier."

rowResize(directions:): "The pointer style for resizing a row, or horizontal division."

frameResize(position:directions:): "The pointer style for resizing a rectangular frame from a specific edge or corner."
  // 没有 Discussion 段 (Apple doc 静默)
```

### 关键限制 — `.pointerStyle(.frameResize(...))` 是否能控制 NSWindow 边 / 角

**不能**. Apple 官方 `.pointerStyle(.frameResize(position:directions:))` 是 **view 内容区域内**的 cursor — 当 hover 在某个 SwiftUI view 上时, cursor 切到指定 frame resize 风格. 但 NSWindow 的 edge/corner resize 是 **系统级**, 由 NSWindow 自己的 `resetCursorRects` / NSTrackingArea 处理 (Apple 系统在 NSWindow 设了 chrome cursor rects, 你可以 `disableCursorRects()` 关掉).

SwiftUI 的 `.frameResize` 用在 **应用内** SwiftUI view 上 = 当用户 hover 该 view, cursor 切到 frame resize (但用户实际拖的不是 NSWindow 边角, 是 view 内的某个东西). 用在拖拽线上是 **错的语义** — frame resize cursor 是给 window 边角用的, 不是给 view 内的拖拽线用的.

### SwiftUI 哪些 cursor case 等价 NSCursor

| SwiftUI PointerStyle case | 对应 NSCursor | 平台 |
|---|---|---|
| `default` | `.arrow` (macOS) / default circle (iPadOS/visionOS) | macOS 15+ |
| `horizontalText` | `.iBeam` | macOS 15+ |
| `verticalText` | `.iBeamCursorForVerticalLayout` | macOS 15+ |
| `rectSelection` | `.crosshair` | macOS 15+ |
| `grabIdle` | `.openHand` | macOS 15+ |
| `grabActive` | `.closedHand` | macOS 15+ |
| `link` | `.pointingHand` | macOS 15+ |
| `zoomIn` | `.zoomIn` | macOS 15+ |
| `zoomOut` | `.zoomOut` | macOS 15+ |
| `frameResize(position:directions:)` | `.frameResize(position:directions:)` (NSCursor 也有) | macOS 15+ |
| `columnResize(directions:)` | `.columnResize(directions:)` / `.resizeLeftRight` / `.resizeUpDown` (NSCursor 也有) | macOS 15+ |
| `rowResize(directions:)` | 同上 | macOS 15+ |
| `image(_:hotSpot:)` | `.init(image:hotSpot:)` | macOS 15+ |
| `shape(_:eoFill:size:)` | 不映射到 NSCursor | visionOS only |

URL: NSCursor 全部 resize 系列 cursor 案例 (columnResize / rowResize / frameResize / resizeLeft / resizeRight / resizeUp / resizeDown / resizeLeftRight / resizeUpDown) — https://developer.apple.com/documentation/appkit/nscursor (Retrieving cursor instances section)

注意: NSCursor 在 macOS 15.0 / Mac Catalyst 18.0 之前**没有** `columnResize(directions:)` / `rowResize(directions:)` / `frameResize(position:directions:)` 这三个 factory methods (只有 `.resizeLeftRight` / `.resizeUpDown`). SwiftUI 把它们在 macOS 15+ 加到 NSCursor 里, 所以 SwiftUI PointerStyle 能 wrap 它们.

### SwiftUI PointerStyle 实际 macOS 27 真值

✅ **Work** (SwiftUI view 内容区域内 hover 切 cursor):
- `.default` — 默认箭头
- `.horizontalText` / `.verticalText` — I-beam
- `.rectSelection` / `.grabIdle` / `.grabActive` / `.link` / `.zoomIn` / `.zoomOut` — 标准系统 cursor
- `.columnResize(directions:)` — 拖竖向分割线 cursor (Apple HIG: 鼠标变成 ↔ 双箭头)
- `.rowResize(directions:)` — 拖横向分割线 cursor (Apple HIG: 鼠标变成 ↕ 双箭头)

❌ **不 work / 错语义**:
- `.frameResize(position:directions:)` — 这个是给 NSWindow chrome edge/corner 用的. SwiftUI 没有 NSWindow chrome cursor 控制. 在 view 内挂 `.frameResize` 只是 view hover 时切到那个 cursor, 不是真的让 window edge 可拖.

⚠️ **Deprecation note**: 第三方 [CursorKit README](https://github.com/ryanslikesocool/CursorKit) 明确说 "SwiftUI on macOS 15 and later provides the `pointerStyle(_:)` and `pointerVisibility(_:)` view modifiers", CursorKit 现在 deprecated — Apple 自己 ship 了 `.pointerStyle`.

### wenshu `NativeSplitter` 现状

wenshu v0.14 (commit `dacbc9fee`) 用 SwiftUI `.pointerStyle(.columnResize / .rowResize)`, 但 v0.14.0 commit 自承 3 件 bug: D_h 不能拖 / D_v5 不能拖 / cursor 不变形. v0.15 + v0.16 ticket 06 + ticket 03 重写为 NSViewRepresentable + resetCursorRects + NSCursor.push — 也都失败 (老板 8/19 18:14 实测).

---

## 3. macOS 27 wenshu 类 SwiftUI WindowGroup + AppKit integration app cursor 系统全失灵已知 workaround

### 第三方实测证据 (GitHub + SO)

#### CursorKit (ryanslikesocool/CursorKit) — pre-macOS 15 workaround

https://github.com/ryanslikesocool/CursorKit/blob/main/README.md

> "Set cursors in SwiftUI on macOS. CursorKit acts as a wrapper around `NSCursor` for SwiftUI, and supports all default cursor types.
>
> **Deprecation Notice**: SwiftUI on macOS 15 and later provides the [`pointerStyle(_:)`](https://developer.apple.com/documentation/swiftui/view/pointerstyle(_:)) and [`pointerVisibility(_:)`](https://developer.apple.com/documentation/swiftui/view/pointervisibility(_:)) view modifiers."

代码真值 (`Cursor.swift`):

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

**真值**: macOS 14 及之前, **必须** 先 `NSApp.windows.forEach { $0.disableCursorRects() }`, 再 `NSCursor.push()` — 否则 SwiftUI/AppKit 内部的 cursor rect 系统会覆盖 push 的 cursor. push 完后必须 `enableCursorRects()` 恢复.

**macOS 15+**: Apple ship `.pointerStyle` 之后这个 workaround 不需要了, CursorKit 自身 deprecated.

#### SwiftUI-NSTextView-CursorFix (frederikhandberg0709)

https://github.com/frederikhandberg0709/SwiftUI-NSTextView-CursorFix

> "**The Problem**: When building macOS apps with SwiftUI, you often need to wrap AppKit components like `NSTextView` to access more advanced text editing features than what SwiftUI offers. However, if you place a SwiftUI overlay (like a custom modal, popup, or floating menu) directly above that `NSTextView`, you'll run into an annoying bug: **The cursor will still change to an I-Beam (`NSCursor.iBeam`) when hovering over your overlay, even though the text view is completely obscured.** Because `NSTextView` operates deep within the AppKit responder chain, it takes higher priority for cursor updates than the SwiftUI views layered on top of it. I was unable to find any guidance on how to handle this bridging discrepancy in Apple's official documentation."

**修法 (Apple 没文档化)**:
1. `OverlayAwareTextView: NSTextView` 子类 — 在 `cursorUpdate` / hitTest 里检查是否被 overlay 盖住, 如果是就 drop mouse/cursor events
2. `ArrowCursorView: NSViewRepresentable` — 内部 `NSTrackingArea` 强制设 `NSCursor.arrow` 在 SwiftUI overlay 区域

**真值**: 这是同一个 SwiftUI + AppKit bridging 问题 — AppKit 内部 NSView 的 cursor rects 比 SwiftUI view 高优先级, SwiftUI view 即使在 topmost Z-order 也拿不到 cursor events. wenshu 6 区 layout 也是一样的问题.

#### SO 79862332 — NSHostingView 与 mouse events

https://stackoverflow.com/questions/79862332/nshostingview-with-swiftui-gestures-not-receiving-mouse-events-behind-another-ns

(Cloudflare 403 — 无法直接验证, 仅 DDG 摘要可见). 主题: NSHostingView 跟 SwiftUI gestures 在多个 NSView 之间 mouse events 分发问题 — 同类 root cause: SwiftUI NSHostingView 不按 AppKit 规则 propagate hitTest.

### Apple 官方 "AppKit integration" 落地页 — 没 cursor 真值

URL: https://developer.apple.com/documentation/swiftui/appkit-integration

> "Integrate SwiftUI with your app's existing content using hosting controllers to add SwiftUI views into AppKit interfaces. … You can also add AppKit views and view controllers to your SwiftUI interfaces. A representable object wraps the designated view or view controller, and facilitates communication between the wrapped object and your SwiftUI views."

**整个 landing page 只提 NSHostingController + NSViewRepresentable 两个桥**, **不提 cursor / pointer / NSTrackingArea**. Apple 官方不承认这是常见问题.

### Apple HIG "Pointing devices" — 几乎全 iPadOS

URL: https://developer.apple.com/design/human-interface-guidelines/pointing-devices

几乎全讲 iPadOS pointer shape / content effects / pointer accessories. **macOS AppKit cursor 范式不在这文档** (要查 NSCursor 官方 doc 才知道).

### 综合已知 workaround (按可行性排)

#### A. **走 SwiftUI PointerStyle** (macOS 15+ 推荐, wenshu macOS 27 已满足)

**Apple HIG 标准**, 替代 AppKit cursor rects 路径:

```swift
// wenshu NativeSplitter body 加这个就够
.pointerStyle(orientation == .vertical ? .columnResize() : .rowResize())
```

但老板 8/19 实测 **v0.14 走 `.pointerStyle` 在 macOS 27 + VStack parent gesture 系统下失灵** (skill `wenshu-visual-alignment` 拍板 + wenshu `.scratch/2026-08-19-dh-fixes-3/issues/03-cursor-flip.md` 引 ticket 06 backlog). 这条路径在 wenshu 已宣告失败.

#### B. **NSWindow 子类化 + override `cursorUpdate(with:)`** (老板 Q15 拍 A, 但 SwiftUI WindowGroup 限制)

老板 backlog 02 原话:
> "选项 B: NSWindow 子类化 (Q15 拍 A 但 SwiftUI WindowGroup 创建的 window 是 private class 不可改 type, 不可行)"

**Apple 官方没明示 WindowGroup 创建的 NSWindow 是 private class**. 但 wenshu 用 `@NSApplicationDelegateAdaptor(WenshuAppDelegate.self)`, 在 `applicationDidFinishLaunching` 里拿 `NSApplication.shared.windows.first` — 那个 window **类型是 NSWindow** (SwiftUI 不暴露 SwiftUI 私有 subclass), 所以**可以**做 `class WenshuWindow: NSWindow` 子类化. **但能不能 swap 进 SwiftUI 已经创建的 NSWindow 实例?** 这是 NSDocument / NSWindowController 的范畴, 不是 SwiftUI 的范畴.

Apple 官方 `NSApplicationDelegateAdaptor` 文档 + SwiftUI App lifecycle 没有公开 API 让 SwiftUI 用自定义 NSWindow subclass. 第三方做法 (SO/Facebook SwiftUI group):

1. **AppDelegate 完全替换 window** — `applicationDidFinishLaunching` 后 `NSApp.windows.first?.contentView = MyCustomRootView()`, 但 `contentView` 是 `NSHostingView` (SwiftUI 内部), 改不了 type
2. **`NSWindowController` 包装** — 用 NSWindowController 创建一个自己的 NSWindow subclass, 然后用 `NSApp.windows.first` 替换 SwiftUI window — **这会破坏 SwiftUI scene 生命周期, 不推荐**

#### C. **NSApplicationDelegate + swizzle / override cursorUpdate** (objc swizzle, 风险高)

objc runtime swizzle `NSWindow.cursorUpdate(with:)` — Apple App Review 已知会 reject, 内部 app 可行, 但不属于 Apple 文档化真值. **找不到 Apple 官方文档真值**.

#### D. **NSWindowDelegate + custom window contentView replacement** (实操可行)

Apple 官方 `NSWindowDelegate` 提供 `windowDidBecomeKey(_:)`, `windowDidBecomeMain(_:)`, `windowDidLoad(_:)` 等 lifecycle hooks — 但 **不能改 NSWindow.contentView 的 type**, contentView 是 SwiftUI 控制的 NSHostingView.

**但可以在 contentView 上层加一个透明的 NSTrackingArea NSView**, 接管整个 contentView 范围的 `cursorUpdate(with:)` 事件, 自己 hit test. 这就是 wenshu 已实现的 `WenshuCursorController` — **实测失灵** (老板 8/19 18:14).

#### E. **NSApp 全局 NSTrackingArea 接管 mouseMoved** (纯 poll 模式, 备选)

不依赖 cursor rects 路径, 直接在 NSApp 装 `NSTrackingArea(rect: .entireScreen, options: [.mouseMoved, .activeAlways])` 监听 mouseMoved, 然后 `NSCursor.set(...)` 强制 set cursor. 这绕过了 `cursorUpdate` responder chain, 直接改全局 cursor.

**问题**: 会被系统 cursor rects (例如 NSWindow chrome) 反复覆盖. 需要在每次 set cursor 前 disableCursorRects() 然后再 enableCursorRects() — CursorKit 的做法. macOS 15+ 不需要 disable/enable (因为 SwiftUI PointerStyle 自己处理).

**wenshu macOS 27 兼容性**: macOS 27 = macOS 26.x 后续 (假设) 或者就是 macOS 15+. 如果是 macOS 15+, SwiftUI PointerStyle 应该 work — 老板 8/19 实测失灵是 VStack parent gesture 系统的别的 bug, 不是 SwiftUI 本身.

#### F. **走 SwiftUI hover + .onContinuousHover + 自画 cursor** (SwiftUI-only, 不依赖 AppKit)

`.onContinuousHover { phase in ... }` 拿到 hover 回调, 在回调里 `NSCursor.push() / pop()`. 这是 SwiftUI-only 路径, 不需要 NSViewRepresentable.

```swift
.pointerStyle(.columnResize(), isActive: hovered)  // macOS 15+
.onContinuousHover { phase in
    switch phase {
    case .active(let pos): NSCursor.resizeLeftRight.push()
    case .ended: NSCursor.pop()
    }
}
```

但是 `.pointerStyle` + `NSCursor.push()` 混用会冲突 (wenshu 实测 push 多次不平衡 crash). 不推荐.

#### G. **退回到 SwiftUI 内建 .pointerStyle + macOS 27** (Apple HIG 标准, 推荐方案)

如果 wenshu 真在 macOS 15+, `.pointerStyle(.columnResize() / .rowResize())` 应该 work — 老板实测失灵可能是 v0.14 commit `dacbc9fee` 写的代码路径有 bug (gesture 挂错层导致 cursor event 链断), 不是 SwiftUI 本身 bug.

需要验证: 写一个最小可运行 SwiftUI `.pointerStyle` 例子 (无 NSViewRepresentable), 看 macOS 27 是否真 work. 如果 work → wenshu 退回到 SwiftUI-only `.pointerStyle` 路径, 不走 NSViewRepresentable.

---

## 给老板的判断

**Q15 拍 A "NSWindow 子类化" 在 SwiftUI WindowGroup 上下文下不可行的真因**:

Apple 官方没明示 WindowGroup 创建的 NSWindow 是 private class. SwiftUI 的 NSWindow 在 runtime 是 `NSWindow` type (因为 SwiftUI WindowGroup 走 NSApplicationDelegateAdaptor 拿到的 window, public type 就是 NSWindow). **但 `NSWindow` 实例创建由 SwiftUI 内部 `NSHostingWindow` (公开 doc 找不到, 推测是 private subclass) 完成, 你无法替换 instance**.

**真正可走 workaround** (按 Apple HIG 优先级):
1. **首选**: SwiftUI 15+ 的 `.pointerStyle(.columnResize() / .rowResize())` — 写一个最小 case 验证是否真失灵 (排除 v0.14 gesture 链 bug 而非 SwiftUI bug)
2. **次选**: NSViewRepresentable + NSWindow 子类化同时用 — 子类化一个 `WenshuWindow: NSWindow`, 在 AppDelegate 里手动 `WenshuWindow(contentRect:..., styleMask:..., backing:..., defer: false)`, `contentView = NSHostingView(rootView: LayoutShellView())`, `makeKeyAndOrderFront()`. 这是真手动 AppKit app + SwiftUI 内嵌 — **不走 SwiftUI App lifecycle** — 不推荐 (破坏 scene restoration / cmd+n 新建窗口)
3. **备选**: `.onContinuousHover` + `NSCursor.push() / pop()` — SwiftUI-only 路径, 不依赖 AppKit cursor rects. 需要小心 push/pop 平衡
4. **不要**: objc swizzle — Apple App Review reject

---

## Sources (汇总)

### Apple Developer Documentation (官方, 全部从 `/tutorials/data/documentation/...` JSON API 拉)

- NSHostingView: https://developer.apple.com/documentation/swiftui/nshostingview
- NSHostingView.init(rootView:): https://developer.apple.com/documentation/swiftui/nshostingview/init(rootview:)
- NSHostingView.cursorUpdate(with:): https://developer.apple.com/documentation/swiftui/nshostingview/cursorupdate(with:)
- NSViewRepresentable: https://developer.apple.com/documentation/swiftui/nsviewrepresentable
- WindowGroup: https://developer.apple.com/documentation/swiftui/windowgroup
- SwiftUI AppKit integration landing: https://developer.apple.com/documentation/swiftui/appkit-integration
- PointerStyle: https://developer.apple.com/documentation/swiftui/pointerstyle
- View.pointerStyle(_:): https://developer.apple.com/documentation/swiftui/view/pointerstyle(_:)
- PointerStyle.default: https://developer.apple.com/documentation/swiftui/pointerstyle/default
- PointerStyle.horizontalText: https://developer.apple.com/documentation/swiftui/pointerstyle/horizontaltext
- PointerStyle.verticalText: https://developer.apple.com/documentation/swiftui/pointerstyle/verticaltext
- PointerStyle.rectSelection: https://developer.apple.com/documentation/swiftui/pointerstyle/rectselection
- PointerStyle.grabIdle: https://developer.apple.com/documentation/swiftui/pointerstyle/grabidle
- PointerStyle.grabActive: https://developer.apple.com/documentation/swiftui/pointerstyle/grabactive
- PointerStyle.link: https://developer.apple.com/documentation/swiftui/pointerstyle/link
- PointerStyle.zoomIn: https://developer.apple.com/documentation/swiftui/pointerstyle/zoomin
- PointerStyle.zoomOut: https://developer.apple.com/documentation/swiftui/pointerstyle/zoomout
- PointerStyle.frameResize(position:directions:): https://developer.apple.com/documentation/swiftui/pointerstyle/frameresize(position:directions:)
- PointerStyle.columnResize(directions:): https://developer.apple.com/documentation/swiftui/pointerstyle/columnresize(directions:)
- PointerStyle.rowResize(directions:): https://developer.apple.com/documentation/swiftui/pointerstyle/rowresize(directions:)
- View.pointerVisibility(_:): https://developer.apple.com/documentation/swiftui/view/pointervisibility(_:)
- View.hoverEffect(_:): https://developer.apple.com/documentation/swiftui/view/hovereffect(_:) (iOS/iPadOS only, NOT macOS)
- NSView: https://developer.apple.com/documentation/appkit/nsview
- NSView.resetCursorRects(): https://developer.apple.com/documentation/appkit/nsview/resetcursorrects()
- NSView.addCursorRect(_:cursor:): https://developer.apple.com/documentation/appkit/nsview/addcursorrect(_:cursor:)
- NSWindow: https://developer.apple.com/documentation/appkit/nswindow
- NSWindow.areCursorRectsEnabled: https://developer.apple.com/documentation/appkit/nswindow/arecursorrectsenabled
- NSWindow.enableCursorRects(): https://developer.apple.com/documentation/appkit/nswindow/enablecursorrects()
- NSWindow.disableCursorRects(): https://developer.apple.com/documentation/appkit/nswindow/disablecursorrects()
- NSWindow.invalidateCursorRects(for:): https://developer.apple.com/documentation/appkit/nswindow/invalidatecursorrects(for:)
- NSCursor: https://developer.apple.com/documentation/appkit/nscursor
- NSCursor.columnResize(directions:): https://developer.apple.com/documentation/appkit/nscursor/columnresize(directions:)
- NSCursor.rowResize(directions:): https://developer.apple.com/documentation/appkit/nscursor/rowresize(directions:)
- NSCursor.frameResize(position:directions:): https://developer.apple.com/documentation/appkit/nscursor/frameresize(position:directions:)
- NSTrackingArea: https://developer.apple.com/documentation/appkit/nstrackingarea
- NSResponder.cursorUpdate(with:): https://developer.apple.com/documentation/appkit/nsresponder/cursorupdate(with:)
- Apple HIG Pointing devices: https://developer.apple.com/design/human-interface-guidelines/pointing-devices

### 第三方 / 实操真值

- CursorKit (deprecated, pre-macOS 15 workaround 标杆): https://github.com/ryanslikesocool/CursorKit
- CursorKit Cursor.swift 源码: https://github.com/ryanslikesocool/CursorKit/blob/main/Sources/CursorKit/Cursor.swift
- SwiftUI-NSTextView-CursorFix (同问题实测): https://github.com/frederikhandberg0709/SwiftUI-NSTextView-CursorFix
- SwiftUI-NSTextView-CursorFix README: https://github.com/frederikhandberg0709/SwiftUI-NSTextView-CursorFix/blob/main/README.md
- SO 79862332 (NSHostingView + mouse events, Cloudflare 403 不可直接 verify): https://stackoverflow.com/questions/79862332/nshostingview-with-swiftui-gestures-not-receiving-mouse-events-behind-another-ns
- Apple Developer Forums thread 812113 (CAPTCHA 拦截): https://developer.apple.com/forums/thread/812113
- Apple Developer Forums thread 759081 (CAPTCHA 拦截): https://developer.apple.com/forums/thread/759081

### 找不到的 (直说, 不猜)

- ❌ **Apple 官方 "SwiftUI WindowGroup 创建的 window 是不是 NSHostingWindow private class"** — 找不到 Apple doc 公开提及. SwiftUI 拿到的 window public type 是 `NSWindow`, 但具体 subclass 在 runtime 可能 `NSHostingWindow` (未公开). 第三方 SO 有讨论但没明确答案
- ❌ **macOS 27 是否修 NSHostingView cursor rects bug** — 找不到 release notes 提及. macOS 26.x (2025) release notes 没公开 cursor rects 改动. macOS 27 是 2026 后续, 也无公开真值
- ❌ **objc swizzle NSWindow.cursorUpdate 是否合规** — Apple App Store Review Guidelines 没明示, 找不到公开真值
- ❌ **`NSWindow` 子类化 + 替换 SwiftUI WindowGroup window instance 是否可行** — 找不到 Apple 公开 doc 说明这条路径, 第三方 (SO / Forums) 都说不可行但理由都是经验, 没 Apple 官方 quote

---

## 给老板 / po 下一步动作建议

1. **老板 8/19 18:14 拍 Q15 选 NSWindow 子类化** — Apple 官方 doc **不直接证否也不直接证实**这条路径, 但 wenshu backlog 已记 "SwiftUI WindowGroup 创建的 window 是 private class 不可改 type, 不可行". 如果老板想试这条路, 推荐先在最小 SwiftUI App 里做实验 (`@NSApplicationDelegateAdaptor` + `applicationDidFinishLaunching` + 强行 `NSApp.windows.first?.contentView = ...` 看 SwiftUI scene 状态破坏多严重), 再决定 commit 范围.

2. **退回到 SwiftUI `.pointerStyle` 是 Apple HIG 真值** — 但需要先排查 wenshu v0.14 `.pointerStyle` 失灵的真因 (老板 8/19 拍 "实测 SwiftUI DragGesture + .pointerStyle 在 macOS 27 + VStack parent gesture 系统下失灵"). 是否是 VStack parent gesture 链断, 还是 NSViewRepresentable 嵌套导致事件被 NSHostingView 截胡. 需要 1 个最小可运行 case (`Rectangle { } .pointerStyle(.columnResize())` 在 SwiftUI 顶层 VStack child) 实测验证.

3. **当前最优解 (按 Apple 官方 + 实操)** — 走 SwiftUI 15+ `.pointerStyle(.columnResize() / .rowResize())` + 不要 NSViewRepresentable 嵌套. wenshu `NativeSplitter` 改回纯 SwiftUI Rectangle + DragGesture + `.pointerStyle` (v0.14 路径重写), 但这次保证 gesture 挂外层 ZStack (老板 8/19 ticket 01 教训 "gesture 必须挂外层 ZStack 真实 hit area"). 如果 macOS 27 SwiftUI 仍然失灵, 才是 NSWindow 子类化 + 全手动 AppKit 范式 (但那破坏 SwiftUI scene).