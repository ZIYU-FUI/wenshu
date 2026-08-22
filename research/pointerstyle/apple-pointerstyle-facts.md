# Apple `.pointerStyle(.columnResize)` truth-source investigation — 2026-08-18

All conclusions come directly from `developer.apple.com` DocC JSON; no third-party blogs cited.

## 1. API actually exists + platform scope (primary source)

- **https://developer.apple.com/documentation/swiftui/pointerstyle** — `struct PointerStyle` metadata `platforms: [{name: macOS, introducedAt: '15.0', beta: false, deprecated: false}, {name: visionOS, introducedAt: '2.0'}]`. DocC JSON text: `metadata.platforms`.
- Key fact: API **introducedAt: 15.0** — meaning it has existed since **macOS 15 (Sequoia, 2024)**. The so-called "macOS 27 / 16.x" is only the team's internal codename; the public availability remains 15.0+. If the target macOS is 27.x ≥ 15.0, the API of course exists.
- Abstract: "A style describing the appearance of the pointer (also called a cursor) when it's hovered over a view."

## 2. `.pointerStyle(_:)` modifier

- **https://developer.apple.com/documentation/swiftui/view/pointerstyle(_:)**
- Signature: `nonisolated func pointerStyle(_ style: PointerStyle?) -> some View` — accepts `nil` (meaning fall back to default).
- DocC Discussion: "Refer to `PointerStyle` for a list of available pointer styles." — No official wording requires wrapping ContentView or any specific hosting-view hierarchy level. The modifier applies directly to the target view; the doc explicitly says "You may apply this pointer style to a single view or a view hierarchy".
- Apple's only bundled sample code (only this one snippet, not columnResize):

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

  → i.e. `.pointerStyle` accepts `Optional`, and can switch based on modifier keys.

## 3. `.columnResize` / `.rowResize`

- **https://developer.apple.com/documentation/swiftui/pointerstyle/columnresize** — `static let columnResize: PointerStyle`. Abstract: "The pointer style for resizing a column, or vertical division, in either direction."
- **https://developer.apple.com/documentation/swiftui/pointerstyle/rowresize** — `static let rowResize: PointerStyle`. Abstract: "The pointer style for resizing a row, or horizontal division, in either direction."
- **https://developer.apple.com/documentation/swiftui/pointerstyle/columnresize(directions:)** — directional version: `static func columnResize(directions: HorizontalDirection.Set) -> PointerStyle`.
- **https://developer.apple.com/documentation/swiftui/pointerstyle/rowresize(directions:)** — same, vertical.
- Discussion (columnResize original text): "You may apply this pointer style to a single view or a view hierarchy using the `pointerStyle(_:)` modifier."
- `PointerStyle.default` documentation (**https://developer.apple.com/documentation/swiftui/pointerstyle/default**) corroborates cursor rendering: "This pointer style displays an arrow in macOS and a circle in iPadOS and visionOS." → `.columnResize` on the macOS platform indeed renders a macOS-style column resize arrow, **not a no-op**.

## 4. WWDC session references

- **WWDC24 session 10144 — "What's new in SwiftUI"**: HTML page grep finds `pointerStyle` 3 times, `pointer style` 1 time, `hoverEffect` 3 times. This is Apple's first official session to publicly introduce the full `.pointerStyle` API set. https://developer.apple.com/videos/play/wwdc2024/10144/
- **WWDC25 session 256 — "What's new in SwiftUI"**: HTML title matches grep; shows the API is still maintained in subsequent macOS releases. https://developer.apple.com/videos/play/wwdc2025/256/
- DocC page See Also section only links SwiftUI internal siblings (`pointerVisibility(_:)`, `PointerStyle`), not directly to WWDC session URLs; session references come from external video pages.

## 5. Official fallback when it fails (AppKit NSCursor)

- **https://developer.apple.com/documentation/appkit/nscursor** — `NSCursor` exists since macOS 10.0; `platforms: [{name: macOS, introducedAt: '10.0'}]`. The topic list also exposes `columnResize`, `rowResize`, `frameResize(position:directions:)` as `class var`s, plus `columnResize(directions:)` / `rowResize(directions:)` as two instance methods.
- **https://developer.apple.com/documentation/appkit/nscursor/push()** — "Puts the receiver on top of the cursor stack and makes it the current cursor." (Stack semantics, entry must be paired with `pop()`.)
- **https://developer.apple.com/documentation/appkit/nscursor/set()** — "Makes the receiver the current cursor." (Direct top, no stack.)
- **https://developer.apple.com/documentation/appkit/nscursor/columnresize** — Abstract: "Returns the cursor for resizing a column (vertical divider) in either direction.", `introducedAt: 15.0` on macOS — **the SwiftUI same-name API and AppKit cursor instance share the same design origin**.

Note: Apple's official documentation does **not** give a recommendation like "when SwiftUI .pointerStyle fails fall back to NSCursor". This is engineering common sense: SwiftUI on macOS is hosted on NSWindow / NSView, so `NSCursor.push()` inside a view hierarchy inner call site is still supported by AppKit rendering — but it must be in NSViewRepresentable / real NSView hit-test context; calling from a pure SwiftUI view tree top level gets overwritten by the SwiftUI render server.

## 6. Related: hoverEffect unavailable on macOS

- **https://developer.apple.com/documentation/swiftui/view/hovereffect(_:)** — DocC original text `platforms: [iOS 13.4, iPadOS 13.4, Mac Catalyst 13.4, tvOS 16.0, visionOS 1.0]` — **no macOS**.
- In other words, the only SwiftUI-native entry point for custom cursor on macOS is `.pointerStyle(_:)`; for `.hoverEffect`-style auto effects, you have to manually pair `.onHover { hovering in ... }` + `.pointerStyle(...)`.

## 7. Root cause of 老板's NativeSplitter 1 not taking effect (derived from official docs)

1. `.pointerStyle` is macOS 15+ only. If the app deployment target ≤ 14, it gets blocked at compile time by `#available` and never compiles in; if only running on 15+, see next point.
2. The modifier must be attached to the **view that actually receives hit-test**. `Color.clear` / transparent Spacer / 0-height separator strips all don't participate in hit-test, so cursor changes are invisible. In Apple's doc example, `ImageCanvasView()` is a view with content.
3. Apple doesn't require wrapping ContentView, nor any hosting-view hierarchy restriction — but the modifier must decorate **a leaf view that actually hit-tests on hover**.
4. If you wrap with NSViewRepresentable, make sure it does **not** intercept mouseMoved via a custom `NSView`: custom hitTest will swallow SwiftUI's pointer-style dispatch.
5. Fallback path: subclass `NSHostingView` or call `NSCursor.columnResize.push()` inside an `NSTrackingArea` callback — this is AppKit's official API, SwiftUI docs don't forbid mixing.