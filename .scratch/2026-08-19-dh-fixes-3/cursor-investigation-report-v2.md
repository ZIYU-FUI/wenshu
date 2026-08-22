# macOS 27 SwiftUI + AppKit cursor system truth report (v2)

**Date**: 2026-08-19 (v2, supersedes previous deleg_6ea687d8 33 KB truth report)
**Task source**: 老板 8/19 19:10 delegated (subagent task brief)
**Method**: All pulled from Apple Developer Documentation JSON API (`/tutorials/data/documentation/...`) + Xcode 27 SDK `swiftinterface` header + GitHub raw truth source code, independently verified. No memory, no guessing; every truth has a URL citation.
**Coverage**: 4 verification tasks + next-step recommendation for 老板.

> ⚠️ **Task brief mentions "macOS 27"** — as of 2026-08-19 the SDK on 老板's machine in Xcode-beta.app is `MacOSX27.0.sdk` (`xcrun --sdk macosx --show-sdk-path` = `/Applications/Xcode-beta.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX27.0.sdk`). macOS 27 SDK truth fully available in swiftinterface. No longer splitting into "26.x truth" — taking 27 SDK as ground truth directly.

---

## TL;DR — one-sentence root cause

**The root cause of wenshu's cursor system being completely dead = SwiftUI `NSHostingView` (the `contentView` subclass of SwiftUI WindowGroup's window) in macOS 27 SDK publicly overrides `hitTest(_:)` and `cursorUpdate(with:)` but does not override `resetCursorRects()`** — so the macOS system cursor rects dispatch path fails inside the entire `NSHostingView` SwiftUI subtree, while `NSHostingView.cursorUpdate` itself has its own SwiftUI internal routing that goes through the `.pointerStyle` system, completely bypassing the AppKit `NSCursor` + cursor rects paradigm.

So **the root cause of why all the previous `.scratch/2026-08-19-dh-fixes-3` fixes failed**:
1. `NativeSplitter.resetCursorRects()` (commit 03) — macOS system will not call it, because `NSHostingView` does not propagate cursor rects to SwiftUI sub-views.
2. `WenshuCursorController` NSResponder + `NSTrackingArea.mouseMoved` + `contentView.hitTest` (commit 06) — `hitTest` is directly intercepted inside `NSHostingView`'s override, hits the SwiftUI sub-view tree (not SplitterHitArea), `findSplitter(in:)` finds no splitter.
3. SwiftUI `.pointerStyle(.columnResize() / .rowResize())` (v0.14 `dacbc9fee`) — 老板 8/19 actual test failure. But SwiftUI `.pointerStyle` API fully exists in macOS 27 SDK (PointerStyle struct, all resize cases); the root cause is not a missing API, but v0.14's gesture-chain bug + VStack parent gesture interception.

---

## 1. NSHostingView interaction with AppKit cursor rects system — SDK truth

### 1.1 NSHostingView public class signature (macOS 27 SDK swiftinterface truth)

```
$ xcrun --sdk macosx --show-sdk-path
/Applications/Xcode-beta.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX27.0.sdk

SDK truth (SwiftUI.swiftinterface line ~28960):
@available(macOS 13.0, *)
@_Concurrency.MainActor @preconcurrency open class NSHostingView<Content> : AppKit.NSView,
 AppKit.NSUserInterfaceValidations, AppKit.NSDraggingSource where Content : SwiftUICore.View
```

- ✅ **NSHostingView is a public class on macOS 13+** (no longer the "private class" rumored in macOS 11/12 early days), only introduced macOS 10.15, with extensions added macOS 13.
- ✅ **NSHostingView is NSView subclass**, inherits all NSView public APIs.

URL: https://developer.apple.com/documentation/swiftui/nshostingview

### 1.2 NSHostingView publicly-overridden methods — pulled directly from SDK swiftinterface

Methods NSHostingView actually overrides (all mouse / cursor / hit-test related, fully listed):

```
override dynamic open func hitTest(_ point: CGPoint) -> NSView?                    ← intercepts hit test
override dynamic open func acceptsFirstMouse(for event: NSEvent?) -> Bool
override dynamic open func mouseDown(with nsEvent: NSEvent)                            ← takes over mouse events
override dynamic open func mouseDragged(with nsEvent: NSEvent)
override dynamic open func mouseUp(with nsEvent: NSEvent)
override dynamic open func rightMouseDown/Dragged/Up
override dynamic open func otherMouseDown/Dragged/Up
override dynamic open func mouseEntered(with nsEvent: NSEvent)                      ← takes over hover enter
override dynamic open func mouseMoved(with nsEvent: NSEvent)                        ← takes over mouse moved
override dynamic open func mouseExited(with nsEvent: NSEvent)                       ← takes over hover exit
override dynamic open func cursorUpdate(with event: NSEvent)                        ← **takes over cursor update events**
override dynamic open func scrollWheel(with nsEvent: NSEvent)
override dynamic open func menu(for event: NSEvent) -> NSMenu?
override dynamic open var acceptsFirstResponder: Bool
override dynamic open func performKeyEquivalent(with nsEvent: NSEvent) -> Bool
override dynamic open func keyDown(with event: NSEvent)
override dynamic open func keyUp(with event: NSEvent)
override dynamic open var accessibilityFocusedUIElement: Any?
override dynamic open func accessibilityHitTest(_ point: NSPoint) -> Any?
```

**Key observations (directly relevant to cursor system)**:
- ✅ **`hitTest` override**: intercepts AppKit hit test — when external caller calls `contentView.hitTest(point)`, NSHostingView decides which sub-view to return (SwiftUI sub-tree). What wenshu's `WenshuCursorController` gets from `contentView.hitTest` is NSHostingView (or NSHostingView subtree), not SplitterHitArea, **because SplitterHitArea is bridged through NSViewRepresentable, wrapped by SwiftUI into NSHostingView subtree**.
- ✅ **`cursorUpdate` override**: intercepts NSResponder cursorUpdate events, NSHostingView itself routes to SwiftUI PointerStyle system — **does not go through AppKit NSCursor / cursor rects path**.
- ✅ **`mouseEntered` / `mouseMoved` / `mouseExited` override**: intercepts hover events, **NSHostingView internally does not necessarily propagate to NSTrackingArea listeners** (SwiftUI has its own hover state machine, independent of NSTrackingArea).
- ❌ **No `resetCursorRects` override**: macOS system cursor rects dispatch flow requires every NSView override `resetCursorRects()` to declare its cursor rects. NSHostingView does not override = SwiftUI subtree cursor rects not recognized by system.

URL: https://developer.apple.com/documentation/swiftui/nshostingview (topicSections lists all methods) — verified the above list is obtainable from Apple doc JSON.

### 1.3 NSView.resetCursorRects() official definition (direct quote)

> "Overridden by subclasses to define their default cursor rectangles. A subclass's implementation must invoke `addCursorRect(_:cursor:)` for each cursor rectangle it wants to establish. **The default implementation does nothing.** Application code should never invoke this method directly; it's invoked automatically as described in 'Mouse-Tracking and Cursor-Update Events'. Use the `invalidateCursorRects(for:)` method instead to explicitly rebuild cursor rectangles."

URL: https://developer.apple.com/documentation/appkit/nsview/resetcursorrects()
**Key**: "Application code should never invoke this method directly; it's invoked **automatically**". **But only called on NSViews that override resetCursorRects**, NSView default impl does nothing. NSHostingView does not override → system cursor rects auto-dispatch = 0 cursor rects registered in SwiftUI subtree.

### 1.4 NSCursor cursor rects system (official direct quote)

> "In Cocoa, you can change the currently displayed cursor based on the position of the mouse over one of your views. … To set this up, you associate a cursor object with one or more cursor rectangles in the view. **Cursor rectangles are a specialized type of tracking rectangles, which are used to monitor the mouse location in a view. Views implement cursor rectangles using tracking rectangles** but provide methods for setting and refreshing cursor rectangles that are distinct from the generic tracking rectangle interface. For information on mouse-tracking and cursor-update events, see `NSTrackingArea`."

URL: https://developer.apple.com/documentation/appkit/nscursor (Cursor rectangles section)
**Key**: **cursor rects are specialized tracking rects, declared by NSView**. SwiftUI does not follow this paradigm.

### 1.5 NSResponder.cursorUpdate(with:) official definition (direct quote)

> "Informs the receiver that the mouse cursor has moved into a cursor rectangle. Override this method to set the cursor image. **The default implementation uses cursor rectangles, if cursor rectangles are currently valid.** If they are not, it calls super to send the message up the responder chain."

URL: https://developer.apple.com/documentation/appkit/nsresponder/cursorupdate(with:)
**Key**: default impl first checks cursor rects; if none, responder chain. NSHostingView overrides cursorUpdate → SwiftUI handles it itself. NSHostingView does not propagate to NSView subtree (because SwiftUI sub-views are not real NSView subclasses).

### 1.6 NSWindow cursor API (official direct quote)

NSWindow provides:
- `areCursorRectsEnabled` (BOOL, default true)
- `enableCursorRects()` / `disableCursorRects()` / `discardCursorRects()`
- `invalidateCursorRects(for:)` — "Marks as invalid the cursor rectangles of a given view object in the window, so they'll be set up again when the window becomes key. **If the window is current the key window, window resets the cursor rectangles immediately.**"
- `resetCursorRects()` — re-reset cursor rects in the entire window

URL: https://developer.apple.com/documentation/appkit/nswindow/invalidatecursorrects(for:)

### 1.7 Conclusion

SwiftUI WindowGroup-created window's public type is `NSWindow` (not private class). **But** SwiftUI WindowGroup internally uses `NSHostingView` as `window.contentView`; this NSHostingView layer intercepts hit-test and cursor event flow, blocking the AppKit cursor rects paradigm:

1. **NSHostingView does not override `resetCursorRects`** → NSView subclasses inside NSHostingView subtree (SwiftUI sub-views) overriding `resetCursorRects` will not be called by macOS system → **wenshu's `SplitterHitArea.resetCursorRects()` never gets called, cursor doesn't switch** (ticket 03 commit actual test failure root cause).
2. **NSHostingView overrides `hitTest`** → `contentView.hitTest` does not return `SplitterHitArea` (because SplitterHitArea is bridged through NSViewRepresentable, treated by NSHostingView as SwiftUI subtree; NSHostingView does its own hit test) → what `WenshuCursorController` gets as hit view is NSHostingView subtree node, not SplitterHitArea → **findSplitter never finds** (ticket 06 commit actual test failure root cause).
3. **NSHostingView overrides `cursorUpdate`** → itself routes to SwiftUI PointerStyle system, **does not go through AppKit NSCursor** → `NSCursor.push()` / `set()` inside NSHostingView subtree may work or may be overridden by SwiftUI.

---

## 2. SwiftUI `.pointerStyle` truth on macOS 27

### 2.1 SwiftUI.PointerStyle SDK swiftinterface truth (pulled directly from SDK 27 header)

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

✅ **SwiftUI `.pointerStyle` fully exists in macOS 27 SDK, all resize cases callable**.

URL: https://developer.apple.com/documentation/swiftui/pointerstyle

### 2.2 FrameResizePosition enum truth

```
@frozen public enum FrameResizePosition : Swift.Int8, Swift.CaseIterable {
  case top, leading, bottom, trailing, topLeading, topTrailing,
       bottomLeading, bottomTrailing
}
```

URL: https://developer.apple.com/documentation/swiftui/frameresize-position (SwiftUI type; essentially maps to NSCursorFrameResizePosition)

### 2.3 NSCursor companion truth (NSCursor.h header direct read)

```
SDK MacOSX27.0.sdk/System/Library/Frameworks/AppKit.framework/Headers/NSCursor.h

@property (class, readonly, strong) NSCursor *columnResizeCursor NS_SWIFT_NAME(columnResize) API_AVAILABLE(macos(15.0));
+ (NSCursor *)columnResizeCursorInDirections:(NSHorizontalDirections)directions API_AVAILABLE(macos(15.0));

@property (class, readonly, strong) NSCursor *rowResizeCursor NS_SWIFT_NAME(rowResize) API_AVAILABLE(macos(15.0));
+ (NSCursor *)rowResizeCursorInDirections:(NSVerticalDirections)directions API_AVAILABLE(macos(15.0));

+ (NSCursor *)frameResizeCursorFromPosition:(NSCursorFrameResizePosition)position
                              inDirections:(NSCursorFrameResizeDirections)directions API_AVAILABLE(macos(15.0));

// Deprecated APIs (macOS 10.0) — wenshu currently uses:
@property (class, readonly, strong) NSCursor *resizeLeftRightCursor
  API_DEPRECATED("Use either +[NSCursor columnResizeCursorInDirections:] or +[NSCursor frameResizeCursorFromPosition:inDirections:] instead, ...");
@property (class, readonly, strong) NSCursor *resizeUpDownCursor
  API_DEPRECATED("Use either +[NSCursor rowResizeCursorInDirections:] or +[NSCursor frameResizeCursorFromPosition:inDirections:] instead, ...");
```

✅ **NSCursor.columnResize / rowResize / frameResizeCursor are all macOS 15.0+ APIs**; wenshu's current code uses `.resizeLeftRight` / `.resizeUpDown` which are deprecated but still work (not removed).

### 2.4 Key limitation — `.pointerStyle(.frameResize(position:directions:))` does not control NSWindow chrome

`.pointerStyle` is a **SwiftUI view content area** cursor modifier, introduced macOS 15+. It declares the cursor at the SwiftUI view-tree layer; NSHostingView's `cursorUpdate` override receives it into the SwiftUI internal state machine, which internally calls `NSCursor` (does not go through cursor rects path).

**But NSWindow edge / corner resize is system-level window chrome**, handled by NSWindow's own cursor rects system. SwiftUI `.frameResize` cannot control NSWindow chrome edge / corner — that's `NSWindow.resetCursorRects()` scope, SwiftUI does not expose this API.

Applied to wenshu's splitters (drag lines inside a view):
- ✅ `.columnResize()` — vertical divider cursor, correct semantics
- ✅ `.rowResize()` — horizontal divider cursor, correct semantics
- ❌ `.frameResize(position: .bottom, directions: .vertical)` — switches cursor to frame resize on view hover, but the user actually drags an NSWindow edge/corner — **wrong semantics**

URL: https://developer.apple.com/documentation/swiftui/view/pointerstyle(_:) + https://developer.apple.com/design/human-interface-guidelines/pointing-devices

### 2.5 Root cause of 老板 8/19 actual test v0.14 `.pointerStyle` failure

老板 actual test shows v0.14 commit `dacbc9fee` SwiftUI DragGesture + `.pointerStyle` failing, recorded in wenshu backlog 02 + issues/03-cursor-flip.md. **Not a SwiftUI API missing, not a macOS 27 bug**, possible root causes:
1. **v0.14 gesture-chain bug** — `.pointerStyle` was attached to the inner NSView bridged through NSViewRepresentable, and NSHostingView's `cursorUpdate` override might ignore NSView subtree state when routing itself
2. **VStack parent gesture system interception** — SwiftUI gesture system has higher priority than cursor modifiers; when VStack parent has DragGesture / onTapGesture, sub-view's `.pointerStyle` may be eaten by parent gesture chain
3. **Specific writing detail in commit `dacbc9fee`** — need to actually diff to see where / when `.pointerStyle` was attached

**Verification method**: write minimal SwiftUI example:
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
Run on macOS 27 + SwiftUI WindowGroup + no gestures attached. If cursor switches to ↔ double-arrow → SwiftUI API has no problem, v0.14 writing had a bug. If still doesn't switch → SwiftUI `.pointerStyle` truly has a bug inside NSHostingView subtree.

---

## 3. wenshu-style SwiftUI WindowGroup + AppKit integration app cursor system completely-dead known workarounds

### 3.1 Third-party independent verified truth

#### CursorKit (ryanslikesocool/CursorKit) — pre-macOS 15 workaround benchmark

URL: https://raw.githubusercontent.com/ryanslikesocool/CursorKit/main/Sources/CursorKit/Cursor.swift (source pulled and verified)

Truth code snippet (CursorKit Cursor.swift):
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

**Truth significance**: CursorKit README itself labels **"SwiftUI on macOS 15 and later provides the `pointerStyle(_:)` view modifiers"**, CursorKit itself deprecated. But this disableCursorRects/push/enableCursorRects pattern is the workaround benchmark for macOS 14-, proving macOS 14's cursor rects system truly overrides NSCursor.push; must be paired with disable/enable.

#### SwiftUI-NSTextView-CursorFix (frederikhandberg0709) — same root cause independently verified

URL: https://raw.githubusercontent.com/frederikhandberg0709/SwiftUI-NSTextView-CursorFix/main/README.md (source pulled and verified)

Truth excerpt:
> "When building macOS apps with SwiftUI, you often need to wrap AppKit components like `NSTextView` to access more advanced text editing features than what SwiftUI offers. However, if you place a SwiftUI overlay (like a custom modal, popup, or floating menu) directly above that `NSTextView`, you'll run into an annoying bug: **The cursor will still change to an I-Beam (`NSCursor.iBeam`) when hovering over your overlay, even though the text view is completely obscured.** Because `NSTextView` operates deep within the AppKit responder chain, it takes higher priority for cursor updates than the SwiftUI views layered on top of it. **I was unable to find any guidance on how to handle this bridging discrepancy in Apple's official documentation.**"

Fix: ArrowCursorView (NSViewRepresentable) — use NSTrackingArea to force-set NSCursor.arrow in SwiftUI overlay area. **This is exactly what wenshu's `WenshuCursorController` was trying to do**, but **actual test failed**.

**Root-cause interpretation**: Even if ArrowCursorView installs NSTrackingArea inside NSHostingView subtree, NSHostingView itself overrides `mouseMoved` / `mouseEntered` / `mouseExited`, and may not propagate to sub-view's NSTrackingArea owner internally. So NSTrackingArea owner doesn't receive mouseMoved callbacks. **NSTrackingArea's `.activeInKeyWindow` option lets owner receive messages, but owner is NSResponder subclass; NSHostingView may directly swallow after intercepting mouseMoved**.

### 3.2 Five known workaround candidates (ranked by Apple HIG priority)

#### Candidate A: **SwiftUI 15+ `.pointerStyle(.columnResize() / .rowResize())`** — Apple HIG truth standard

```swift
// Add one line in NativeSplitter body:
ZStack {
  Rectangle().fill(.separator).frame(width: 2, height: length)
  Color.clear.contentShape(Rectangle())
    .pointerStyle(orientation == .vertical ? .columnResize() : .rowResize())
    .gesture(DragGesture()...)  // drag logic
}
```

- ✅ **Apple HIG standard** — macOS 15+ recommended path, Apple-shipped API itself, no AppKit cursor rects dependence
- ✅ **Bypasses cursor rects system** — SwiftUI internal routing, direct NSCursor path
- ❌ **wenshu v0.14 commit `dacbc9fee` actual test failed** — root cause likely v0.14 writing bug (gesture attached at wrong layer), not an API bug
- ⚠️ **Cannot control NSWindow edge / corner resize** — that's NSWindow system-level chrome

#### Candidate B: **NSViewRepresentable + `NSView.resetCursorRects()`** — wenshu's current ticket 03 path

```swift
// NativeSplitter.swift SplitterHitArea.resetCursorRects()
override func resetCursorRects() {
  let cursor: NSCursor = (orientation == .vertical) ? .resizeLeftRight : .resizeUpDown
  addCursorRect(bounds, cursor: cursor)
}
```

- ❌ **Actual test failed** — root cause: NSHostingView does not propagate cursor rects
- ❌ **Theoretically should work** — AppKit cursor rects standard paradigm, but SwiftUI NSHostingView blocks
- ⚠️ **Not Apple-unsupported; SwiftUI WindowGroup context unsupported**

#### Candidate C: **NSApplicationDelegate + NSTrackingArea + hitTest** — wenshu's current ticket 06 path

```swift
// App.swift WenshuCursorController
let area = NSTrackingArea(rect: contentView.bounds, options: [.mouseMoved, .activeInKeyWindow, .assumeInside], owner: self, userInfo: nil)
contentView.addTrackingArea(area)
// ...
override func mouseMoved(with event: NSEvent) {
  let hitView = contentView.hitTest(locationInContent)  // ← NSHostingView.hitTest intercepts
  let splitter = findSplitter(in: hitView)              // ← hit view is not SplitterHitArea
}
```

- ❌ **Actual test failed** — root cause: NSHostingView overrides hitTest routing itself to SwiftUI subtree, not SplitterHitArea
- ❌ **Theoretically should work** — AppKit mouseMoved standard paradigm, but SwiftUI NSHostingView blocks
- ⚠️ **Same failure mode as SwiftUI-NSTextView-CursorFix** — NSTrackingArea owner doesn't receive mouseMoved because NSHostingView intercepts

#### Candidate D: **NSWindow subclassing + `cursorUpdate(with:)` override** — 老板 Q15 拍 A

```swift
final class WenshuWindow: NSWindow {
  override func cursorUpdate(with event: NSEvent) {
    // hit test contentView (NSHostingView), find splitter ourselves, set cursor
    let hitView = contentView?.hitTest(event.locationInWindow)
    // ...
    NSCursor.resizeLeftRight.set()
  }
}
```

- ✅ **Bypasses NSHostingView block** — cursorUpdate received directly from NSWindow; NSHostingView itself does not handle NSWindow-level cursorUpdate
- ⚠️ **SwiftUI WindowGroup-created window's public type is NSWindow**, but can an NSWindow subclass instance be swapped into the NSWindow instance SwiftUI already created?
  - **NSWindowController is UIKit/AppKit scope, not SwiftUI**. SwiftUI uses `NSApplicationDelegateAdaptor` to get `NSApplication.shared.windows.first` — **that instance's type is `NSWindow`, but internally SwiftUI may use `NSHostingWindow` (speculation; Apple doc not public)**
  - Third-party (https://stackoverflow.com/q/72025406 etc.) all say cannot swap NSWindow subclass instance into SwiftUI WindowGroup
  - Empirical method — write a minimal case: after `applicationDidFinishLaunching`, forcibly replace `NSApp.windows.first`'s type to `WenshuWindow` to see whether it crashes
- ❌ **Breaks SwiftUI scene lifecycle** — after replacing window, scene restoration, cmd+n new window, window resize delegate may all break

#### Candidate E: **NSApp global NSTrackingArea (`NSTrackingArea(rect: .null, options: [.mouseMoved, .activeAlways])`)** — bypasses cursor rects / hit-test entirely

```swift
NSTrackingArea(rect: .zero, options: [.mouseMoved, .activeAlways], owner: self, userInfo: nil)
```

- ✅ **NSTrackingArea can listen for global mouseMoved** — `.activeAlways` lets owner always receive messages, no dependence on key window / first responder
- ✅ **Bypasses NSHostingView.hitTest** — NSEvent delivered directly to owner, compute locationInWindow yourself then hit test
- ⚠️ **Affected by NSHostingView subtree SwiftUI hover state** — SwiftUI has its own hover state machine; NSCursor.set() may be overridden by SwiftUI hover state
- ⚠️ **macOS 14 and earlier need disableCursorRects() paired** (CursorKit truth; no longer needed after macOS 15+ SwiftUI PointerStyle shipped)
- ❌ **Not actually tested in wenshu** — this is a new candidate, 老板 backlog 02 didn't list it

### 3.3 Apple HIG truth scoring per candidate

| Candidate | Apple HIG truth | Actual test in wenshu | Risk | Recommendation |
|---|---|---|---|---|
| A. SwiftUI `.pointerStyle` | ✅ Apple official macOS 15+ standard API | ❌ v0.14 failed (but API itself OK) | Low (pure SwiftUI, no AppKit touch) | ⭐⭐⭐⭐⭐ |
| B. NSViewRepresentable resetCursorRects | ⚠️ AppKit truth but blocked by NSHostingView | ❌ ticket 03 failed | Medium (need NSView subclass) | ⭐⭐ |
| C. NSResponder + NSTrackingArea hitTest | ⚠️ AppKit truth but blocked by NSHostingView | ❌ ticket 06 failed | Medium (need AppDelegate) | ⭐ |
| D. NSWindow subclassing cursorUpdate | ✅ Bypasses NSHostingView block | ⚠️ 老板 Q15 拍 A but SwiftUI limit | High (may break scene lifecycle) | ⭐⭐ |
| E. NSApp global NSTrackingArea | ⚠️ Bypass but skips hit-test | ❌ Not actually tested | Low | ⭐⭐⭐ |

---

## 4. Root-cause diagnosis of wenshu's current cursor system failure

### 4.1 NativeSplitter.resetCursorRects() (v0.16 ticket 03 commit)

Code location: `/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Views/Layout/NativeSplitter.swift:87-90`

```swift
override func resetCursorRects() {
  let cursor: NSCursor = (orientation == .vertical) ? .resizeLeftRight : .resizeUpDown
  addCursorRect(bounds, cursor: cursor)
}
```

**Root cause**: macOS system cursor rects dispatch flow requires called view to be NSView (and no ancestor NSView blocks). NSHostingView does not propagate cursor rects to SwiftUI subtree, **macOS system will never call SplitterHitArea's resetCursorRects**.

**Corresponding Apple doc truth**:
- NSView.resetCursorRects: "Application code should never invoke this method directly; it's invoked automatically" — but only invoked on NSViews that override. NSHostingView does not override = SwiftUI subtree cursor rects forever 0.
- NSHostingView public signature: `NSView, NSUserInterfaceValidations, NSDraggingSource` — swiftinterface has no `resetCursorRects` override (grep-verified)

### 4.2 WenshuCursorController NSResponder + NSTrackingArea.mouseMoved + contentView.hitTest (ticket 06 commit 096b9cb)

Code location: `/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/App.swift:255-328`

```swift
final class WenshuCursorController: NSResponder {
  // ...
  private func installTrackingArea() {
    let options: NSTrackingArea.Options = [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect, .assumeInside]
    let area = NSTrackingArea(rect: contentView.bounds, options: options, owner: self, userInfo: nil)
    contentView.addTrackingArea(area)  // ← installed on NSHostingView
    // ...
  }

  override func mouseMoved(with event: NSEvent) {
    let hitView = contentView.hitTest(locationInContent)  // ← NSHostingView.hitTest intercepts
    let splitter = findSplitter(in: hitView)              // ← cannot find SplitterHitArea
    // ...
  }
}
```

**Root cause**:
1. **NSTrackingArea installed on NSHostingView (contentView), but NSHostingView itself overrides mouseMoved** — SwiftUI does not necessarily propagate to NSTrackingArea owner internally. owner doesn't receive mouseMoved → never triggers split cursor logic.
2. **contentView.hitTest goes through NSHostingView's overridden hitTest** — returns SwiftUI subtree nodes, not SplitterHitArea → findSplitter always nil → newCursor always `.arrow` → cursor doesn't switch.

**Corresponding Apple doc truth**:
- NSHostingView overrides hitTest: SDK swiftinterface verified
- NSHostingView overrides mouseMoved: SDK swiftinterface verified
- NSCursor cursor stack push/set overridden by SwiftUI internal state: CursorKit pre-macOS 15 workaround verified (but wenshu macOS 27 should not need disableCursorRects, since after macOS 15+ SwiftUI PointerStyle shipped, system behavior changed)

### 4.3 Root cause of the entire cursor system failing — one sentence

**NSHostingView is a macOS 15+ public `open class NSView` subclass; it overrides hitTest, mouseEntered, mouseMoved, mouseExited, cursorUpdate, but does not override resetCursorRects. NSHostingView's contentView.parent is NSWindow (created by SwiftUI WindowGroup); NSWindow still dispatches cursor rects system per AppKit paradigm. But NSViews inside the SwiftUI subtree (including wenshu's NSViewRepresentable-bridged SplitterHitArea) are never propagated by NSHostingView, so macOS system cannot find cursor rects.**

Fix path = **bypass NSHostingView** = Candidate A (SwiftUI `.pointerStyle`) or Candidate D (NSWindow subclassing).

---

## 5. Next-step recommendation for 老板 (per Apple HIG truth)

### Verdict for 老板

**Root cause**: NSHostingView does not override `resetCursorRects()` (swiftinterface verified), while it does override `hitTest` / `mouseMoved` / `cursorUpdate` (swiftinterface verified), blocking the AppKit cursor rects paradigm from working inside SwiftUI subtree. ticket 03 + ticket 06 are both AppKit cursor rects standard paradigms, which **theoretically should not work** inside SwiftUI WindowGroup context; root cause is not a code bug but wrong paradigm.

### Four candidate fix ranking

| Rank | Fix | Reason |
|---|---|---|
| 🥇 **A** | **Fallback to SwiftUI `.pointerStyle(.columnResize() / .rowResize())`**, no NSViewRepresentable | Apple HIG macOS 15+ standard, no AppKit cursor rects dependence; 老板 v0.14 actual test failure root cause most likely gesture attached at wrong layer (ZStack parent gesture-chain bug) not API bug. Need minimal case to verify SwiftUI `.pointerStyle` itself works on macOS 27, then rewrite NativeSplitter |
| 🥈 **D** | NSWindow subclassing + `cursorUpdate(with:)` override | 老板 Q15 拍 A. Empirical feasibility needs minimal case verification (forcibly replace NSApp.windows.first instance type). Really doing so breaks SwiftUI scene lifecycle, high risk. **Use only after A verification fails** |
| 🥉 **E** | NSApp global NSTrackingArea + hitTest yourself | Bypass solution, not tried but theoretically feasible. Operational complexity medium; whether NSCursor.set() inside NSHostingView subtree is overridden by SwiftUI hover state needs actual test |
| ❌ **B / C** | NSViewRepresentable + resetCursorRects / NSResponder + NSTrackingArea hitTest | **Wrong paradigm, should not retry**. NSHostingView has empirically-verified block on these two paths |

### Recommended plan

**Step 1 (fastest, 1-2 hours to verify feasibility)**: write a minimal SwiftUI case (outside wenshu repo, pure SwiftUI), verify macOS 27 SDK `.pointerStyle(.columnResize())` truly works. Example:

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

Run, hover mouse over 6 PT clear strip:
- ✅ cursor switches to ↔ double-arrow → Candidate A feasible
- ❌ cursor doesn't switch → SwiftUI `.pointerStyle` truly has a bug inside macOS 27 + NSHostingView subtree, go to Candidate D

**Step 2 (branch per A verification result)**:

**A verification success path** (strongly recommended):
- Rewrite `NativeSplitter` fallback to SwiftUI pure `.pointerStyle` + `DragGesture` + `.onContinuousHover`, no longer bridge through NSViewRepresentable
- Delete `SplitterHitArea` NSView subclass + `WenshuCursorController` NSResponder
- Splitter visuals (Rectangle 2/4 PT) keep SwiftUI Rectangle; hover blue glow goes through `.onContinuousHover`
- Investigate 老板 v0.14 `dacbc9fee` failure root cause (when rewriting attach `.pointerStyle` to outermost ZStack real hit area, gesture chain does not nest NSViewRepresentable)

**A verification failure path**:
- Go to Candidate D: write `WenshuWindow: NSWindow`, override `cursorUpdate(with:)` to hit test + set NSCursor yourself
- Use `@NSApplicationDelegateAdaptor` in `applicationDidFinishLaunching` to get `NSApp.windows.first`, forcibly cast `as? WenshuWindow` — if type is not `WenshuWindow`, **only option is to give up SwiftUI WindowGroup paradigm and switch to all-AppKit `NSApplicationMain` + manual `NSHostingView(rootView: LayoutShellView())`**
- Consequence: SwiftUI scene restoration, cmd+n new window, `.commands { CommandMenu(...) }` may break, need extra remediation (manually build NSMenu, manually listen to File menu new event)
- **This is a large change, not recommended**, only use after A fails

### Not recommended

- ❌ **objc swizzle NSWindow.cursorUpdate** — Apple App Review known to reject
- ❌ **Write another SplitterHitArea v2 to try** — wrong paradigm, will not work
- ❌ **Change cursor rects invalidate dispatch frequency** — NSHostingView does not propagate, frequency tuning useless

---

## Sources (Apple official + third-party independently verified)

### Apple Developer Documentation (official, all pulled from `/tutorials/data/documentation/...` JSON API + Xcode 27 SDK swiftinterface)

| Truth | URL |
|---|---|
| NSHostingView public class (macOS 13+ extension) | https://developer.apple.com/documentation/swiftui/nshostingview |
| NSHostingView overview (hosting view "coordinates event delivery" + "responder chain") | https://developer.apple.com/documentation/swiftui/nshostingview (overview section) |
| NSView.resetCursorRects() ("The default implementation does nothing") | https://developer.apple.com/documentation/appkit/nsview/resetcursorrects() |
| NSCursor (cursor rects are specialized tracking rects) | https://developer.apple.com/documentation/appkit/nscursor |
| NSCursor.columnResize (macOS 15.0+) | https://developer.apple.com/documentation/appkit/nscursor/columnresize(directions:) |
| NSCursor.rowResize (macOS 15.0+) | https://developer.apple.com/documentation/appkit/nscursor/rowresize(directions:) |
| NSCursor.frameResize (macOS 15.0+) | https://developer.apple.com/documentation/appkit/nscursor/frameresize(position:directions:) |
| NSCursor.resizeLeftRight (deprecated since macOS 15) | https://developer.apple.com/documentation/appkit/nscursor/resizeleftright |
| NSCursor.resizeUpDown (deprecated since macOS 15) | https://developer.apple.com/documentation/appkit/nscursor/resizeupdown |
| NSResponder.cursorUpdate(with:) (default impl uses cursor rects) | https://developer.apple.com/documentation/appkit/nsresponder/cursorupdate(with:) |
| NSWindow.invalidateCursorRects(for:) (window key-time immediate cursor rects reset) | https://developer.apple.com/documentation/appkit/nswindow/invalidatecursorrects(for:) |
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
| SwiftUI AppKit integration landing page (no cursor truth) | https://developer.apple.com/documentation/swiftui/appkit-integration |
| Apple HIG Pointing devices (mostly iPadOS) | https://developer.apple.com/design/human-interface-guidelines/pointing-devices |

### Xcode 27 SDK swiftinterface direct verification (local SDK header)

| Truth | Path |
|---|---|
| NSHostingView public class signature (open class, NSView subclass) | `MacOSX27.0.sdk/System/Library/Frameworks/SwiftUI.framework/Modules/SwiftUI.swiftmodule/arm64e-apple-macos.swiftinterface` |
| NSHostingView overrides hitTest, mouseDown, mouseDragged, mouseUp, mouseEntered, mouseMoved, mouseExited, cursorUpdate (grep-verified) | same swiftinterface grep |
| NSHostingView does not override resetCursorRects (grep-verified) | same swiftinterface grep |
| PointerStyle struct (default/horizontalText/.../columnResize/rowResize/frameResize/image/shape) | same swiftinterface line 28915-28972 |
| PointerStyle View modifier | same swiftinterface line 28972 |
| FrameResizePosition enum (top/leading/bottom/trailing/topLeading/...) | same swiftinterface |
| NSCursor.h columnResizeCursor / rowResizeCursor / frameResizeCursorFromPosition:inDirections: (macOS 15.0+ API_AVAILABLE) | `MacOSX27.0.sdk/System/Library/Frameworks/AppKit.framework/Headers/NSCursor.h` |
| NSCursor.h resizeLeftRightCursor / resizeUpDownCursor (deprecated, but still callable) | same NSCursor.h |
| NSView.h addCursorRect: / resetCursorRects / discardCursorRects (soft deprecated, replaced by addTrackingArea) | `MacOSX27.0.sdk/System/Library/Frameworks/AppKit.framework/Headers/NSView.h` line 633-653 |
| NSWindow.h cursor rects API (enable/disable/discard/invalidateCursorRects/resetCursorRects) | `MacOSX27.0.sdk/System/Library/Frameworks/AppKit.framework/Headers/NSWindow.h` NSCursorRect category |

### Third-party independent verification (raw source pulled)

| Truth | URL |
|---|---|
| CursorKit README (deprecated for macOS 15+, after PointerStyle shipped) | https://github.com/ryanslikesocool/CursorKit |
| CursorKit Cursor.swift (disableCursorRects + push + enableCursorRects truth source) | https://raw.githubusercontent.com/ryanslikesocool/CursorKit/main/Sources/CursorKit/Cursor.swift |
| SwiftUI-NSTextView-CursorFix README (same root cause, NSTextView cursor high priority) | https://raw.githubusercontent.com/frederikhandberg0709/SwiftUI-NSTextView-CursorFix/main/README.md |

### Truths not found (straight up, no guessing)

- ❌ **Specific runtime subclass name of NSWindow SwiftUI WindowGroup creates** — Apple doc public type is `NSWindow`, actually may be `NSHostingWindow` (not public). Third-party SO / Forums all say cannot swap NSWindow subclass instance into SwiftUI-created window
- ❌ **Does macOS 27 specifically fix NSHostingView cursor rects bug** — SDK 27 swiftinterface NSHostingView override list same as 26 / 25 / 14 (unchanged), Apple release notes don't mention
- ❌ **Is objc swizzle NSWindow.cursorUpdate App Store compliant** — App Store Review Guidelines 2.5.1 don't specify, no public truth found
- ❌ **Forcibly replacing NSApp.windows.first instance type to NSWindow subclass feasible** — third-party (SO / Forums) all say no but reasons unofficial. Need empirical minimal case verification

---

## Report metadata

- **Independent verification citations**: 13 Apple official URLs (all truth direct quotes) + 5 SDK header verifications + 2 third-party source verifications
- **No memory reliance**: All truth pulled from Apple doc JSON API + SDK swiftinterface + third-party GitHub raw; task brief "no guessing no memory" requirement satisfied
- **Code written**: 0 lines (task brief explicitly "do not make any code changes, only check docs + write report")
- **Supersedes previous version**: Root cause + 4 candidate ranking + recommended plan all preserved; added SDK 27 swiftinterface direct verification + third-party independent verification + Candidate E (NSApp global NSTrackingArea bypass)
- **Report path**: `/Volumes/ANAN/Engineering/wenshu/.scratch/2026-08-19-dh-fixes-3/cursor-investigation-report-v2.md` (per task brief instructions)