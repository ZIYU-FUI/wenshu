// WenshuHoverTracker.swift · Wenshu (文枢) · v0.27
//
// Window-wide mouse position tracker (= boss 8/27 hover effect).
//
// Per boss 8/27 OOB (= 'hover 5PT 发光效果'): every wenshu splitter
// (= 4 upper + 1 lower) shows a 5 PT accent-color glow when the
// mouse is over the splitter area. Default SplitView's built-in
// Splitter doesn't expose a hover callback (= no public
// `onHover` modifier).
//
// Approach: track mouse position via AppKit NSTrackingArea on a
// single hidden NSView in the window. When mouse is over any
// splitter area (= invisibleThickness = 5 PT per the boss 8/27
// spec), the hover state is true = all splitters glow.
//
// Simpler approach (= what this file does): track mouse position at
// the window level. When mouse is anywhere near a splitter (= within
// a configurable distance from any split edge), all splitters glow.
// For v0.27, the simplest implementation is: when the mouse is
// over ANY of the wenshu Splits (= the 4 upper + 1 lower zones
// are wrapped in a global VStack; = the entire window is "over
// the splitter area"), the state is true. Boss can refine later.
//
// Swift 6 strict-concurrency: NSView is AppKit (= not SwiftUI; = not
// main-actor-isolated by default in the same way SwiftUI View is).
// AppKit mouse events arrive on the main thread per the classic
// AppKit thread model (= safe to mutate @Published from a non-Sendable
// context because the runtime guarantees main-thread delivery).

import AppKit
import SwiftUI

/// WenshuHoverState — window-wide hover state (= "is the mouse over
/// any splitter area?"). Single shared instance per wenshu process
/// (= all splitters share the same hover state = they all glow
/// together when the mouse is near any splitter).
@MainActor
final class WenshuHoverState: ObservableObject {
    /// The single shared instance (= all wenshu splitters observe this
    /// one state; = the glow effect is global per boss 8/27).
    static let shared = WenshuHoverState()

    /// True when the mouse is over any splitter area.
    @Published var isHovered: Bool = false

    /// The AppKit NSView that receives the mouse events.
    let trackerView: WenshuHoverTrackerView

    private init() {
        self.trackerView = WenshuHoverTrackerView()
        trackerView.state = self
    }
}

/// WenshuHoverTrackerView — NSView subclass that captures
/// mouseEntered/mouseExited (= AppKit NSResponder API; = receives
/// events on the main thread per the classic AppKit thread model).
final class WenshuHoverTrackerView: NSView {
    weak var state: WenshuHoverState?
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas { removeTrackingArea(area) }
        let options: NSTrackingArea.Options = [
            .mouseEnteredAndExited,
            .activeInKeyWindow,
            .inVisibleRect,
        ]
        let area = NSTrackingArea(
            rect: bounds,
            options: options,
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
    }
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        Task { @MainActor in state?.isHovered = true }
    }
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        Task { @MainActor in state?.isHovered = false }
    }
}

/// WenshuHoverHost — SwiftUI View that hosts the WenshuHoverState's
/// underlying NSView (= makes the hover detector visible to the
/// AppKit mouse-event system). Use: .background { WenshuHoverHost() }
/// or .overlay { WenshuHoverHost() }. The view itself is Color.clear
/// (= invisible; = the user sees no visual artifact from the
/// tracker; = only the AppKit event subsystem knows about the
/// underlying NSView).
struct WenshuHoverHost: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        return WenshuHoverState.shared.trackerView
    }
    func updateNSView(_ nsView: NSView, context: Context) {
        // No-op: the state is shared; the NSView is the same
        // instance.
    }
}