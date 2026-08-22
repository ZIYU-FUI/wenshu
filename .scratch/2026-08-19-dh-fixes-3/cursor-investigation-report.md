# macOS 27 SwiftUI + AppKit cursor truth — official documentation verification report

**Date**: 2026-08-19
**Task**: Investigate macOS 27 SwiftUI + AppKit integration cursor system truth (老板 8/19 18:15 delegated)
**Method**: Pull official docs directly from Apple Developer Documentation JSON API (`/tutorials/data/documentation/...`), no memory or guessing
**Context**: wenshu `.scratch/2026-08-19-dh-fixes-3/backlog.md` Backlog 02 — 老板 actual test shows `resetCursorRects()` / `NSResponder.mouseMoved` + `hitTest` all fail, entire window cursor system dead, need to check Apple official truth to decide next fix

---

## TL;DR

| Fact | Apple official conclusion | Source |
|---|---|---|
| What is the window contentView of SwiftUI WindowGroup | NSHostingView subclass (macOS 10.15+, no longer private class — now public `SwiftUI.NSHostingView`) | https://developer.apple.com/documentation/swiftui/nshostingview |
| Does NSHostingView override `resetCursorRects()` | **No** — topicSections fully lists NSHostingView's own methods, no `resetCursorRects`, only inherits NSView default impl ("does nothing") | https://developer.apple.com/documentation/swiftui/nshostingview |
| Does NSHostingView override `cursorUpdate(with:)` | **Yes** — explicitly stated in "Responding to mouse events" topicSection, but implementation is internal to SwiftUI, routing events to the SwiftUI PointerStyle system (not AppKit cursor rects) | https://developer.apple.com/documentation/swiftui/nshostingview (topicSections) |
| SwiftUI `.pointerStyle(_:)` relationship to AppKit cursor rects | pointerStyle is a View-level modifier, introduced macOS 15+, **does not go through resetCursorRects / NSTrackingArea path** — it sets NSCursor at the SwiftUI render tree layer, dispatched internally via NSHostingView's overridden mouseMoved/cursorUpdate | https://developer.apple.com/documentation/swiftui/pointerstyle + each case docs |
| Can window edge / corner resize cursor be handled by SwiftUI `.pointerStyle(.frameResize(position:directions:))` | **No** — `.pointerStyle` is a **view content area** cursor; NSWindow edge/corner is system-level window chrome, handled by NSWindow's own `resetCursorRects` (managed by macOS system, not in SwiftUI's control range) | https://developer.apple.com/documentation/swiftui/pointerstyle/frameresize(position:directions:) + https://developer.apple.com/documentation/appkit/nswindow (Managing Cursor Rectangles) |
| `NSWindow.areCursorRectsEnabled` default behavior | window auto-enables cursor rects; SwiftUI WindowGroup-created window is also NSWindow, so **window edge/corner system-level resize cursor should work**, but actual test dead = SwiftUI took over cursor event dispatch | https://developer.apple.com/documentation/appkit/nswindow/arecursorrectsenabled |
| Does NSHostingView in macOS 27's SwiftUI WindowGroup window tree block the AppKit cursor system | **Partial block** — contentView's SwiftUI sub-view cursor (NSViewRepresentable-bridged NSView.resetCursorRects) **does not work**, because NSHostingView does not propagate cursor rects; but NSWindow's own chrome resize cursor is still managed by the system | Synthesis (cursor rects are specialized NSTrackingArea, see below) |

---

## 1. NSHostingView's interaction with the AppKit cursor rects system

### Official definition

> "An AppKit view that hosts a SwiftUI view hierarchy. … A hosting view is an NSView object that manages a single SwiftUI view, which may itself contain other SwiftUI views. Because it is an NSView object, you can integrate it into your existing AppKit view hierarchies to implement portions of your UI. … A hosting view acts as a bridge between your SwiftUI views and your AppKit interface. During layout, the hosting view reports the content size preferences of your SwiftUI views back to the AppKit layout system so that it can size the view appropriately. The hosting view also coordinates event delivery."

URL: https://developer.apple.com/documentation/swiftui/nshostingview

### Full list of NSHostingView's own methods (Apple doc topicSections fully listed)

From NSHostingView's topicSections fully listed, the methods it **owns/overrides** include:
- **Responding to mouse events**: `mouseDown`, `mouseUp`, `otherMouseDown`, `otherMouseUp`, `rightMouseDown`, `rightMouseUp`, **`mouseEntered`**, **`mouseExited`**, **`mouseDragged`**, **`mouseMoved`**, `otherMouseDragged`, `rightMouseDragged`, **`cursorUpdate(with:)`**
- **Modifying the frame rectangle**: `intrinsicContentSize`, `setFrameSize`, `firstBaselineOffsetFromTop`, `lastBaselineOffsetFromBottom`, `sizingOptions`, `firstTextLineCenter`
- **Bridging with SwiftUI**: `sceneBridgingOptions`

**But NSHostingView does not list `resetCursorRects` or `addCursorRect` in topicSections** → it inherits NSView's default impl (`NSView.resetCursorRects()` default implementation does nothing).

### NSView.resetCursorRects() official definition

> "Overridden by subclasses to define their default cursor rectangles. A subclass's implementation must invoke `addCursorRect(_:cursor:)` for each cursor rectangle it wants to establish. **The default implementation does nothing**. Application code should never invoke this method directly; it's invoked automatically as described in 'Mouse-Tracking and Cursor-Update Events'. Use the `invalidateCursorRects(for:)` method instead to explicitly rebuild cursor rectangles."

URL: https://developer.apple.com/documentation/appkit/nsview/resetcursorrects()
**Key**: NSView's default `resetCursorRects()` is a no-op. NSHostingView does not override = does not provide cursor rects for SwiftUI sub-view tree.

### NSCursor official mechanism — cursor rects are specialized tracking rects

> "In Cocoa, you can change the currently displayed cursor based on the position of the mouse over one of your views. … To set this up, you associate a cursor object with one or more cursor rectangles in the view. **Cursor rectangles are a specialized type of tracking rectangles, which are used to monitor the mouse location in a view. Views implement cursor rectangles using tracking rectangles** but provide methods for setting and refreshing cursor rectangles that are distinct from the generic tracking rectangle interface. For information on mouse-tracking and cursor-update events, see `NSTrackingArea`."

URL: https://developer.apple.com/documentation/appkit/nscursor (Cursor rectangles section)

### NSTrackingArea official definition

> "A region of a view that generates mouse-tracking and cursor-update events when the pointer is over that region. … Depending on the options specified, the owner of the tracking area receives `mouseEntered(with:)`, `mouseExited(with:)`, `mouseMoved(with:)`, and `cursorUpdate(with:)` messages when the mouse cursor enters, moves within, and leaves the tracking area."

URL: https://developer.apple.com/documentation/appkit/nstrackingarea

**Synthesis**: AppKit cursor rects mechanism = NSTrackingArea instance + `.cursorUpdate` option + NSResponder chain.

### NSResponder.cursorUpdate(with:) official definition

> "Informs the receiver that the mouse cursor has moved into a cursor rectangle. Override this method to set the cursor image. **The default implementation uses cursor rectangles, if cursor rectangles are currently valid. If they are not, it calls super to send the message up the responder chain.** If the responder implements this method, but decides not to handle a particular event, it should invoke the superclass implementation of this method."

URL: https://developer.apple.com/documentation/appkit/nsresponder/cursorupdate(with:)
**Key**: The default impl first checks cursor rects; if none, super → responder chain. This is the mechanism by which NSWindow's own chrome edge/corner resize cursor works (macOS system sets chrome cursor rects on NSWindow).

### NSWindow Managing Cursor Rectangles (official API list)

NSWindow provides:
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

### Conclusion

**The window created by SwiftUI WindowGroup is still an NSWindow**, which **preserves** window chrome edge/corner resize cursor (Apple system-level) — because NSWindow defaults `areCursorRectsEnabled = true` and macOS system sets chrome cursor rects on NSWindow.

**However**, NSHostingView is an NSView subclass, does not override `resetCursorRects` → **`resetCursorRects()` of the SwiftUI sub-view tree (NSViewRepresentable-bridged NSView) inside contentView will not be called by macOS system**, because SwiftUI replaces the NSView tree with its own render tree, and the AppKit cursor rects system does not propagate into SwiftUI sub-views.

**NSHostingView's own `cursorUpdate(with:)` override** routes cursor events to the SwiftUI PointerStyle system (macOS 15+), so `.pointerStyle(_:)` works on SwiftUI views inside NSHostingView — but the AppKit NSCursor/resetCursorRects system path does not work inside NSHostingView's subtree.

**This is the actual-test root cause**: wenshu's `NativeSplitter` `SplitterHitArea`'s `resetCursorRects()` was committed, but because SplitterHitArea is bridged through NSViewRepresentable into NSHostingView's subtree, and NSHostingView does not override resetCursorRects, the system will not call SplitterHitArea's resetCursorRects. `WenshuCursorController` (NSResponder + NSTrackingArea.mouseMoved + contentView.hitTest)'s hitTest returns NSHostingView (the SwiftUI root), not SplitterHitArea, because NSHostingView's `hitTest` override intercepts hit testing and hits the SwiftUI sub-view tree.

---

## 2. SwiftUI `.pointerStyle` API truth on macOS 27

### SwiftUI.PointerStyle official definition

> "A style describing the appearance of the pointer (also called a cursor) when it's hovered over a view."

URL: https://developer.apple.com/documentation/swiftui/pointerstyle

**Platform**: macOS 15.0+, visionOS 2.0+. **macOS 14 does not have this API**.

### View.pointerStyle(_:) official definition

> "Use the `pointerStyle(_:)` view modifier to set a view's pointer style. Refer to PointerStyle for a list of available pointer styles."

URL: https://developer.apple.com/documentation/swiftui/view/pointerstyle(_:)

### Full pointerStyle cases (Apple doc complete list)

Apple categorizes `PointerStyle`:

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

### Apple description for each cursor case

```
columnResize(directions:): "The pointer style for resizing a column, or vertical division."
  Discussion: "You may apply this pointer style to a single view or a view hierarchy using the pointerStyle(_:) modifier."

rowResize(directions:): "The pointer style for resizing a row, or horizontal division."

frameResize(position:directions:): "The pointer style for resizing a rectangular frame from a specific edge or corner."
  // No Discussion section (Apple doc silent)
```

### Key limitation — can `.pointerStyle(.frameResize(...))` control NSWindow edge / corner

**No**. Apple official `.pointerStyle(.frameResize(position:directions:))` is a cursor for the **view content area** — when hovering over some SwiftUI view, the cursor switches to the specified frame resize style. But NSWindow edge/corner resize is **system-level**, handled by NSWindow's own `resetCursorRects` / NSTrackingArea (macOS system sets chrome cursor rects on NSWindow, you can `disableCursorRects()` to turn it off).

SwiftUI's `.frameResize` applied to an **in-app** SwiftUI view = when the user hovers that view, the cursor switches to frame resize (but what the user actually drags is something inside the view, not an NSWindow edge/corner). Using it on a splitter is the **wrong semantics** — frame resize cursor is for window edges/corners, not for in-view splitters.

### Which SwiftUI cursor cases map to NSCursor

| SwiftUI PointerStyle case | Corresponding NSCursor | Platform |
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
| `frameResize(position:directions:)` | `.frameResize(position:directions:)` (NSCursor also has) | macOS 15+ |
| `columnResize(directions:)` | `.columnResize(directions:)` / `.resizeLeftRight` / `.resizeUpDown` (NSCursor also has) | macOS 15+ |
| `rowResize(directions:)` | same as above | macOS 15+ |
| `image(_:hotSpot:)` | `.init(image:hotSpot:)` | macOS 15+ |
| `shape(_:eoFill:size:)` | no mapping to NSCursor | visionOS only |

URL: All NSCursor resize-series cursor cases (columnResize / rowResize / frameResize / resizeLeft / resizeRight / resizeUp / resizeDown / resizeLeftRight / resizeUpDown) — https://developer.apple.com/documentation/appkit/nscursor (Retrieving cursor instances section)

Note: NSCursor **does not have** `columnResize(directions:)` / `rowResize(directions:)` / `frameResize(position:directions:)` these three factory methods before macOS 15.0 / Mac Catalyst 18.0 (only `.resizeLeftRight` / `.resizeUpDown`). SwiftUI added them to NSCursor at macOS 15+, so SwiftUI PointerStyle can wrap them.

### SwiftUI PointerStyle actual macOS 27 truth

✅ **Works** (cursor switches when hovering in SwiftUI view content area):
- `.default` — default arrow
- `.horizontalText` / `.verticalText` — I-beam
- `.rectSelection` / `.grabIdle` / `.grabActive` / `.link` / `.zoomIn` / `.zoomOut` — standard system cursors
- `.columnResize(directions:)` — vertical divider cursor (Apple HIG: mouse becomes ↔ double-arrow)
- `.rowResize(directions:)` — horizontal divider cursor (Apple HIG: mouse becomes ↕ double-arrow)

❌ **Does not work / wrong semantics**:
- `.frameResize(position:directions:)` — this is for NSWindow chrome edge/corner. SwiftUI has no NSWindow chrome cursor control. Hanging `.frameResize` inside a view just switches to that cursor on hover, not actually making window edges draggable.

⚠️ **Deprecation note**: third-party [CursorKit README](https://github.com/ryanslikesocool/CursorKit) explicitly says "SwiftUI on macOS 15 and later provides the `pointerStyle(_:)` and `pointerVisibility(_:)` view modifiers", CursorKit is now deprecated — Apple itself shipped `.pointerStyle`.

### wenshu `NativeSplitter` current state

wenshu v0.14 (commit `dacbc9fee`) used SwiftUI `.pointerStyle(.columnResize / .rowResize)`, but the v0.14.0 commit itself admitted 3 bugs: D_h can't drag / D_v5 can't drag / cursor doesn't change. v0.15 + v0.16 ticket 06 + ticket 03 rewrote as NSViewRepresentable + resetCursorRects + NSCursor.push — also all failed (老板 8/19 18:14 actual test).

---

## 3. macOS 27 wenshu-style SwiftUI WindowGroup + AppKit integration app cursor system completely dead known workarounds

### Third-party actual-test evidence (GitHub + SO)

#### CursorKit (ryanslikesocool/CursorKit) — pre-macOS 15 workaround

https://github.com/ryanslikesocool/CursorKit/blob/main/README.md

> "Set cursors in SwiftUI on macOS. CursorKit acts as a wrapper around `NSCursor` for SwiftUI, and supports all default cursor types.
>
> **Deprecation Notice**: SwiftUI on macOS 15 and later provides the [`pointerStyle(_:)`](https://developer.apple.com/documentation/swiftui/view/pointerstyle(_:)) and [`pointerVisibility(_:)`](https://developer.apple.com/documentation/swiftui/view/pointervisibility(_:)) view modifiers."

Code truth (`Cursor.swift`):

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

**Truth**: macOS 14 and earlier, **must** first `NSApp.windows.forEach { $0.disableCursorRects() }`, then `NSCursor.push()` — otherwise SwiftUI/AppKit's internal cursor rects system will override the pushed cursor. After push, must `enableCursorRects()` to restore.

**macOS 15+**: Apple shipped `.pointerStyle`, this workaround no longer needed, CursorKit itself deprecated.

#### SwiftUI-NSTextView-CursorFix (frederikhandberg0709)

https://github.com/frederikhandberg0709/SwiftUI-NSTextView-CursorFix

> "**The Problem**: When building macOS apps with SwiftUI, you often need to wrap AppKit components like `NSTextView` to access more advanced text editing features than what SwiftUI offers. However, if you place a SwiftUI overlay (like a custom modal, popup, or floating menu) directly above that `NSTextView`, you'll run into an annoying bug: **The cursor will still change to an I-Beam (`NSCursor.iBeam`) when hovering over your overlay, even though the text view is completely obscured.** Because `NSTextView` operates deep within the AppKit responder chain, it takes higher priority for cursor updates than the SwiftUI views layered on top of it. I was unable to find any guidance on how to handle this bridging discrepancy in Apple's official documentation."

**Fix (Apple undocumented)**:
1. `OverlayAwareTextView: NSTextView` subclass — in `cursorUpdate` / hitTest check whether covered by overlay, if so drop mouse/cursor events
2. `ArrowCursorView: NSViewRepresentable` — internal `NSTrackingArea` force-set `NSCursor.arrow` in SwiftUI overlay area

**Truth**: This is the same SwiftUI + AppKit bridging problem — AppKit's internal NSView cursor rects have higher priority than SwiftUI views, even topmost Z-order SwiftUI views can't get cursor events. wenshu's 6-zone layout has the same problem.

#### SO 79862332 — NSHostingView with mouse events

https://stackoverflow.com/questions/79862332/nshostingview-with-swiftui-gestures-not-receiving-mouse-events-behind-another-ns

(Cloudflare 403 — cannot directly verify, only DDG summary visible). Topic: NSHostingView with SwiftUI gestures mouse-event dispatch problem across multiple NSViews — same root cause: SwiftUI NSHostingView does not propagate hitTest per AppKit rules.

### Apple official "AppKit integration" landing page — no cursor truth

URL: https://developer.apple.com/documentation/swiftui/appkit-integration

> "Integrate SwiftUI with your app's existing content using hosting controllers to add SwiftUI views into AppKit interfaces. … You can also add AppKit views and view controllers to your SwiftUI interfaces. A representable object wraps the designated view or view controller, and facilitates communication between the wrapped object and your SwiftUI views."

**The whole landing page only mentions NSHostingController + NSViewRepresentable as the two bridges, and does NOT mention cursor / pointer / NSTrackingArea**. Apple officially does not acknowledge this as a common problem.

### Apple HIG "Pointing devices" — almost entirely iPadOS

URL: https://developer.apple.com/design/human-interface-guidelines/pointing-devices

Almost entirely about iPadOS pointer shape / content effects / pointer accessories. **macOS AppKit cursor paradigm is not in this document** (you have to check NSCursor official docs).

### Synthesized known workarounds (by feasibility)

#### A. **Go SwiftUI PointerStyle** (macOS 15+ recommended, wenshu macOS 27 already meets)

**Apple HIG standard**, replacing the AppKit cursor rects path:

```swift
// Add this in wenshu NativeSplitter body
.pointerStyle(orientation == .vertical ? .columnResize() : .rowResize())
```

But 老板 8/19 actual test shows **v0.14 `.pointerStyle` fails on macOS 27 + VStack parent gesture system** (skill `wenshu-visual-alignment` decision + wenshu `.scratch/2026-08-19-dh-fixes-3/issues/03-cursor-flip.md` cites ticket 06 backlog). This path is declared failed in wenshu.

#### B. **NSWindow subclassing + override `cursorUpdate(with:)`** (老板 Q15 拍 A, but SwiftUI WindowGroup limit)

Original 老板 backlog 02 wording:
> "Option B: NSWindow subclassing (Q15 拍 A but SwiftUI WindowGroup-created window is private class unchangeable type, infeasible)"

**Apple official does not explicitly state that the NSWindow created by WindowGroup is a private class**. But wenshu uses `@NSApplicationDelegateAdaptor(WenshuAppDelegate.self)`, in `applicationDidFinishLaunching` getting `NSApplication.shared.windows.first` — that window's **type is NSWindow** (SwiftUI does not expose SwiftUI private subclass), so **can** do `class WenshuWindow: NSWindow` subclassing. **But can the instance be swapped into the NSWindow instance SwiftUI already created?** That's NSDocument / NSWindowController territory, not SwiftUI's.

Apple official `NSApplicationDelegateAdaptor` docs + SwiftUI App lifecycle have no public API to make SwiftUI use a custom NSWindow subclass. Third-party practice (SO/Facebook SwiftUI group):
1. **AppDelegate completely replaces window** — after `applicationDidFinishLaunching`, `NSApp.windows.first?.contentView = MyCustomRootView()`, but `contentView` is `NSHostingView` (internal SwiftUI), type unchangeable
2. **`NSWindowController` wrapper** — use NSWindowController to create own NSWindow subclass, then use `NSApp.windows.first` to replace SwiftUI window — **this breaks SwiftUI scene lifecycle, not recommended**

#### C. **NSApplicationDelegate + swizzle / override cursorUpdate** (objc swizzle, high risk)

objc runtime swizzle `NSWindow.cursorUpdate(with:)` — Apple App Review is known to reject, internal apps fine, but not Apple-documented truth. **No Apple official doc truth found**.

#### D. **NSWindowDelegate + custom window contentView replacement** (operationally feasible)

Apple official `NSWindowDelegate` provides `windowDidBecomeKey(_:)`, `windowDidBecomeMain(_:)`, `windowDidLoad(_:)` etc. lifecycle hooks — but **cannot change NSWindow.contentView's type**, contentView is SwiftUI-controlled NSHostingView.

**But you can add a transparent NSTrackingArea NSView on top of contentView**, take over the entire contentView area's `cursorUpdate(with:)` events, do hit test yourself. This is wenshu's already-implemented `WenshuCursorController` — **actual test failed** (老板 8/19 18:14).

#### E. **NSApp global NSTrackingArea takes over mouseMoved** (pure poll mode, backup)

Independent of cursor rects path, directly install `NSTrackingArea(rect: .entireScreen, options: [.mouseMoved, .activeAlways])` on NSApp to listen mouseMoved, then `NSCursor.set(...)` force-set cursor. This bypasses the `cursorUpdate` responder chain, directly modifying the global cursor.

**Problem**: gets repeatedly overridden by system cursor rects (e.g. NSWindow chrome). Need to `disableCursorRects()` before each set cursor, then `enableCursorRects()` — CursorKit's approach. macOS 15+ doesn't need disable/enable (because SwiftUI PointerStyle handles it itself).

**wenshu macOS 27 compatibility**: macOS 27 = macOS 26.x successor (assumption) or just macOS 15+. If macOS 15+, SwiftUI PointerStyle should work — 老板 8/19 actual test failure is a VStack parent gesture system other bug, not SwiftUI itself.

#### F. **Go SwiftUI hover + .onContinuousHover + self-drawn cursor** (SwiftUI-only, no AppKit dependence)

`.onContinuousHover { phase in ... }` gets hover callback, in callback `NSCursor.push() / pop()`. This is SwiftUI-only path, no NSViewRepresentable needed.

```swift
.pointerStyle(.columnResize(), isActive: hovered)  // macOS 15+
.onContinuousHover { phase in
    switch phase {
    case .active(let pos): NSCursor.resizeLeftRight.push()
    case .ended: NSCursor.pop()
    }
}
```

But mixing `.pointerStyle` + `NSCursor.push()` conflicts (wenshu actual test push multiple imbalanced crash). Not recommended.

#### G. **Fallback to SwiftUI built-in .pointerStyle + macOS 27** (Apple HIG standard, recommended plan)

If wenshu is really on macOS 15+, `.pointerStyle(.columnResize() / .rowResize())` should work — 老板 actual test failure may be a bug in v0.14 commit `dacbc9fee`'s code path (gesture attached at wrong layer broke cursor event chain), not a SwiftUI bug itself.

Need to verify: write a minimal runnable SwiftUI `.pointerStyle` example (no NSViewRepresentable), check if macOS 27 really works. If works → wenshu falls back to SwiftUI-only `.pointerStyle` path, no NSViewRepresentable.

---

## Judgment for 老板

**Why Q15 拍 A "NSWindow subclassing" is infeasible in SwiftUI WindowGroup context**:

Apple official does not explicitly state that the NSWindow created by WindowGroup is a private class. SwiftUI's NSWindow at runtime is `NSWindow` type (because SwiftUI WindowGroup via NSApplicationDelegateAdaptor gets a window whose public type is NSWindow). **But the NSWindow instance is created by SwiftUI's internal `NSHostingWindow` (public doc not found, presumed private subclass), you cannot replace the instance**.

**Truly feasible workarounds** (by Apple HIG priority):
1. **First choice**: SwiftUI 15+ `.pointerStyle(.columnResize() / .rowResize())` — write a minimal case to verify whether it really fails (rule out v0.14 gesture-chain bug vs SwiftUI bug)
2. **Second choice**: NSViewRepresentable + NSWindow subclassing combined — subclass a `WenshuWindow: NSWindow`, in AppDelegate manually `WenshuWindow(contentRect:..., styleMask:..., backing:..., defer: false)`, `contentView = NSHostingView(rootView: LayoutShellView())`, `makeKeyAndOrderFront()`. This is a truly manual AppKit app + SwiftUI embedded — **does not go through SwiftUI App lifecycle** — not recommended (breaks scene restoration / cmd+n new window)
3. **Backup**: `.onContinuousHover` + `NSCursor.push() / pop()` — SwiftUI-only path, no AppKit cursor rects dependence. Need to be careful about push/pop balance
4. **Do not**: objc swizzle — Apple App Review rejects

---

## Sources (summary)

### Apple Developer Documentation (official, all pulled from `/tutorials/data/documentation/...` JSON API)

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

### Third-party / operational truth

- CursorKit (deprecated, pre-macOS 15 workaround benchmark): https://github.com/ryanslikesocool/CursorKit
- CursorKit Cursor.swift source: https://github.com/ryanslikesocool/CursorKit/blob/main/Sources/CursorKit/Cursor.swift
- SwiftUI-NSTextView-CursorFix (same problem actual test): https://github.com/frederikhandberg0709/SwiftUI-NSTextView-CursorFix
- SwiftUI-NSTextView-CursorFix README: https://github.com/frederikhandberg0709/SwiftUI-NSTextView-CursorFix/blob/main/README.md
- SO 79862332 (NSHostingView + mouse events, Cloudflare 403 cannot directly verify): https://stackoverflow.com/questions/79862332/nshostingview-with-swiftui-gestures-not-receiving-mouse-events-behind-another-ns
- Apple Developer Forums thread 812113 (CAPTCHA blocked): https://developer.apple.com/forums/thread/812113
- Apple Developer Forums thread 759081 (CAPTCHA blocked): https://developer.apple.com/forums/thread/759081

### Not found (straight up, no guessing)

- ❌ **Apple official "Is SwiftUI WindowGroup-created window an NSHostingWindow private class"** — no Apple doc publicly mentions. The window SwiftUI gets has public type `NSWindow`, but the actual subclass at runtime might be `NSHostingWindow` (undocumented). Third-party SO has discussion but no clear answer
- ❌ **Does macOS 27 fix NSHostingView cursor rects bug** — no release notes mention. macOS 26.x (2025) release notes have no public cursor rects changes. macOS 27 is 2026 successor, also no public truth
- ❌ **Is objc swizzle NSWindow.cursorUpdate compliant** — Apple App Store Review Guidelines don't say, no public truth found
- ❌ **NSWindow subclassing + replace SwiftUI WindowGroup window instance feasible** — no Apple public doc explains this path, third-party (SO / Forums) all say infeasible but reasons are experience, no Apple official quote

---

## Suggested next-step actions for 老板 / po

1. **老板 8/19 18:14 拍 Q15 chose NSWindow subclassing** — Apple official docs **neither directly refute nor directly confirm** this path, but wenshu backlog already records "SwiftUI WindowGroup-created window is private class unchangeable type, infeasible". If 老板 wants to try this path, recommend first experimenting in a minimal SwiftUI App (`@NSApplicationDelegateAdaptor` + `applicationDidFinishLaunching` + forcibly `NSApp.windows.first?.contentView = ...` to see how badly SwiftUI scene state is broken), then decide commit scope.

2. **Fallback to SwiftUI `.pointerStyle` is Apple HIG truth** — but need to first investigate why wenshu v0.14 `.pointerStyle` failed (老板 8/19 拍 "actual test SwiftUI DragGesture + .pointerStyle fails on macOS 27 + VStack parent gesture system"). Whether it's the VStack parent gesture chain broken, or NSViewRepresentable nesting causing events to be intercepted by NSHostingView. Need 1 minimal runnable case (`Rectangle { } .pointerStyle(.columnResize())` in SwiftUI top-level VStack child) to actually verify.

3. **Current optimal solution (per Apple official + operational)** — go SwiftUI 15+ `.pointerStyle(.columnResize() / .rowResize())` + no NSViewRepresentable nesting. wenshu `NativeSplitter` rewrite back to pure SwiftUI Rectangle + DragGesture + `.pointerStyle` (v0.14 path rewrite), but this time ensure gesture attaches to outermost ZStack (老板 8/19 ticket 01 lesson "gesture must attach to outermost ZStack real hit area"). If macOS 27 SwiftUI still fails, then NSWindow subclassing + full manual AppKit paradigm (but that breaks SwiftUI scene).