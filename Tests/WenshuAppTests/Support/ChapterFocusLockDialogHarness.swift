//
//  ChapterFocusLockDialogHarness.swift · wenshu
//
//  The view harness the chapter focus lock's dialog tests drive.
//
//  The dialog's request is published from outside the view (= the
//  conductor's actor), so the chat zone only learns about it if
//  reading the presenter's property registers an observation
//  dependency. = the harness measures that, = and it carries the
//  control that proves the harness can observe such a publication at
//  all.
//
//  The harness types live here, apart from the tests that drive them,
//  so the suite file stays under the file-size cap and the two halves
//  of the lock (= the write refusal and the dialog) keep one suite
//  (= one serialized domain, = the request lives in one slot of one
//  singleton, = and two suites running at once would answer each
//  other's request).
//

import AppKit
import Observation
import SwiftUI
@testable import WenshuApp

/// Counts a view's body evaluations.
final class BodyCounter: @unchecked Sendable {
    private(set) var evaluations = 0

    func count() {
        evaluations += 1
    }
}

/// Records that an observation fired.
final class ObservationFlag: @unchecked Sendable {
    private(set) var fired = false

    func fire() {
        fired = true
    }
}

/// The control's holder, = an observed value published from outside.
///
/// It sits at file scope because the `@Observable` macro cannot
/// expand inside a nested private scope.
@Observable
final class ControlHolder {
    var chapterPath: String?
}

/// The chat zone's alert host, = the production wiring:
/// `.alert(item:)` over a binding that reads the presenter's
/// pending request.
struct ChatZoneAlertHost: View {
    let counter: BodyCounter

    var body: some View {
        counter.count()
        return Color.clear
            .alert(
                item: Binding(
                    get: { ChapterFocusLockDialogPresenter.shared.pendingRequest },
                    set: { newValue in
                        ChapterFocusLockDialogPresenter.shared.pendingRequest = newValue
                    }
                ),
                content: { request in
                    ChapterFocusLockDialogAlert.makeAlert(for: request)
                }
            )
    }
}

/// The control's host, = the same shape over an observed holder.
///
/// The body reads the holder, = the read is what registers the
/// dependency the production host's alert binding registers.
struct ControlHost: View {
    let counter: BodyCounter
    let holder: ControlHolder

    var body: some View {
        counter.count()
        _ = holder.chapterPath
        return Color.clear
    }
}

/// Let SwiftUI render (= the run loop's own API is unavailable from
/// an async context).
func pumpSwiftUI(_ seconds: TimeInterval) {
    RunLoop.current.run(until: Date().addingTimeInterval(seconds))
}

/// A window hosting the harness view (= the way the app presents it:
/// the chat zone lives in a window).
@MainActor
func hostHarnessWindow<V: View>(_ root: V) -> (window: NSWindow, host: NSHostingView<V>) {
    let host = NSHostingView(rootView: root)
    host.frame = NSRect(x: 0, y: 0, width: 480, height: 240)
    let window = NSWindow(
        contentRect: host.frame,
        styleMask: [.titled],
        backing: .buffered,
        defer: false
    )
    window.contentView = host
    window.orderFront(nil)
    host.layoutSubtreeIfNeeded()
    pumpSwiftUI(0.4)
    return (window, host)
}
