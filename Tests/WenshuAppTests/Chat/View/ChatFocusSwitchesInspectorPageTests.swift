//
//  ChatFocusSwitchesInspectorPageTests.swift · Wenshu
//
//  The chat input taking focus switches the right-hand column to the
//  Status page.
//
//  Two contracts are locked down here:
//
//  1. The wiring is present in the source: the chat view observes its
//     own input focus and writes the inspector's page to the status
//     case, and does nothing when the focus leaves.
//
//  2. The chat zone and the right-hand column read ONE
//     `WorkspaceUIState` instance. The feature rests on that: the chat
//     writes the page, the column reads it, and two different
//     instances would mean the write goes nowhere.
//
//

import Foundation
import SwiftUI
import Testing
@testable import WenshuApp

@Suite("Chat focus switches the inspector page")
struct ChatFocusSwitchesInspectorPageTests {

    // MARK: - The wiring

    /// The chat view observes its input focus and sends the right-hand
    /// column to the status page.
    @Test("The chat view sends the column to the status page when the input takes focus")
    func focusWritesTheStatusPage() throws {
        let source = try SourceLocator.read("Sources/WenshuApp/Features/Chat/View/ChatView.swift")
        #expect(source.contains(".onChange(of: inputFocused)"),
                "the chat view must observe its input focus")
        #expect(source.contains("workspaceUI.inspectorPage = .status"),
                "the chat view must send the column to the status page")
        #expect(source.contains("@Environment(WorkspaceUIState.self)"),
                "the chat view must read the shared column state")
    }

    /// Focus leaving changes nothing: the user's own tab choice stands
    /// until the chat takes focus again.
    @Test("The chat view leaves the page alone when the focus leaves")
    func defocusDoesNotChangeThePage() throws {
        let source = try SourceLocator.read("Sources/WenshuApp/Features/Chat/View/ChatView.swift")
        let start = try #require(source.range(of: ".onChange(of: inputFocused)"))
        let body = source[start.lowerBound...]
        #expect(body.contains("guard isFocused else { return }"),
                "the page must not be written when the focus leaves")
    }

    // MARK: - One shared instance

    /// The chat zone and the right-hand column resolve the same
    /// `WorkspaceUIState` object.
    ///
    /// The chat zone lives behind the AppKit boundary: its view is
    /// hosted by an `NSHostingController` the editor controller creates
    /// itself, so the shared state has to survive that boundary. The
    /// probe below reproduces that shape exactly.
    @MainActor
    @Test("The chat zone and the right-hand column read one shared state instance")
    func oneSharedStateInstance() {
        let shared = WorkspaceUIState()
        let shell = StateRead()
        let chatZone = StateRead()

        let host = NSHostingView(rootView: AnyView(
            VStack {
                // The shell (= the column that owns the inspector) reads
                // the shared state and hands it to the right-hand column.
                ShellReadView(read: shell)
                // The chat zone (= hosted behind the AppKit boundary).
                ChatZoneBoundaryView(read: chatZone)
            }
            .environment(shared)
        ))
        host.frame = NSRect(x: 0, y: 0, width: 320, height: 200)
        host.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        host.layoutSubtreeIfNeeded()

        #expect(shell.state === shared,
                "the right-hand column must read the shared state instance")
        #expect(chatZone.state === shared,
                "the chat zone must read the shared state instance")
        #expect(shell.state === chatZone.state,
                "the chat zone and the right-hand column must read one instance")
    }
}

// MARK: - The probes

/// What a probe read out of the environment.
@MainActor
final class StateRead {
    var state: WorkspaceUIState?
}

/// The shell's read (= the column that owns the right-hand column).
@MainActor
struct ShellReadView: View {
    let read: StateRead
    @Environment(WorkspaceUIState.self) private var workspaceUI

    var body: some View {
        let _ = read.state = workspaceUI
        Color.clear
    }
}

/// The chat zone's read (= hosted behind the AppKit boundary).
@MainActor
struct ChatZoneReadView: View {
    let read: StateRead
    @Environment(WorkspaceUIState.self) private var workspaceUI

    var body: some View {
        let _ = read.state = workspaceUI
        Color.clear
    }
}

/// The AppKit boundary the chat zone really sits behind: the editor
/// controller creates its own hosting controller, so the shared state
/// has to reach the hosted view on its own.
@MainActor
final class AppKitHostingController: NSViewController {
    let read: StateRead

    init(read: StateRead) {
        self.read = read
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { preconditionFailure() }

    override func viewDidLoad() {
        super.viewDidLoad()
        let hosted = NSHostingController(rootView: ChatZoneReadView(read: read))
        addChild(hosted)
        view = hosted.view
    }
}

/// The bridge into the AppKit boundary.
@MainActor
struct ChatZoneBoundaryView: NSViewControllerRepresentable {
    let read: StateRead

    func makeNSViewController(context: Context) -> NSViewController {
        AppKitHostingController(read: read)
    }

    func updateNSViewController(_ nsViewController: NSViewController, context: Context) {}
}
