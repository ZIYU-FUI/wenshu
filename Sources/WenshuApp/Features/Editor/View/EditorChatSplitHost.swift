// EditorChatSplitHost.swift · Wenshu
//
// The SwiftUI side's entry point to the editor's split
// controller. It was the tail of
// `EditorChatNSController.swift` before that file was split.
//
import AppKit
import SwiftUI
import WenshuAgent

/// SwiftUI wrapper that hosts `EditorChatNSController` inside the
/// `NavigationSplitView` detail closure (= same pattern as
/// `PaneSplitHost`; = AppKit boundary; = SwiftUI @Environment chain
/// breaks at the AppKit boundary; = we thread dependencies explicitly
/// into NSHostingController via `.environment(...)` if/when needed).
struct EditorChatSplitHost: NSViewControllerRepresentable {
    let conductor: WenshuConductor?
    /// The arrangement the user asked for in the View menu. The
    /// controller applies it (= automatic follows the window
    /// width; = the two manual cases pin the arrangement).
    let layoutMode: EditorLayoutMode
    // The SwiftUI environment does not cross into the
    // `NSHostingController`s this wrapper creates, so the three
    // objects the hosted views read are resolved HERE (= the
    // SwiftUI side of the boundary) and handed over as one
    // bundled value.
    //
    // Chat persistence lives in WSChatRepository.shared
    // (= @MainActor SwiftData wrapper).
    @Environment(AppState.self) private var appState
    @Environment(BookStore.self) private var bookStore
    @Environment(WenshuLibrary.self) private var library

    func makeNSViewController(context _: Context) -> EditorChatNSController {
        return EditorChatNSController(
            conductor: conductor,
            environment: EditorChatEnvironment(
                appState: appState,
                bookStore: bookStore,
                library: library
            )
        )
    }

    func updateNSViewController(_ nsViewController: EditorChatNSController, context _: Context) {
        // The layout mode is the one thing the SwiftUI side owns
        // (= the View menu writes it; = the editor + chat content
        // itself is static).
        nsViewController.applyLayoutMode(layoutMode)
    }

    /// Report a size that does NOT depend on the inner split's own layout.
    ///
    /// Why: the default implementation reports the inner
    /// `NSSplitViewController`'s size to the SwiftUI layout engine. The
    /// detail column of the outer `NavigationSplitView` then negotiates
    /// its width against a number the nested split keeps recomputing, and
    /// each negotiation re-arms the window's "Update Constraints in
    /// Window" pass. That pass count is what AppKit's runaway-layout
    /// guard counts, and it is what aborts the app when the window is
    /// dragged narrow (= measured: 10 of 10 trials crashed with
    /// `limit: 342, count: 348`; with this override, 0 of 10 crashed and
    /// the window narrowed past the width the crashing build reached).
    ///
    /// Returning the PROPOSAL (= the size the parent is asking for) makes
    /// the reported size a function of the parent's own layout, so the
    /// nested split stops feeding a second, competing number back up.
    func sizeThatFits(
        _ proposal: ProposedViewSize,
        nsViewController: EditorChatNSController,
        context _: Context
    ) -> CGSize? {
        // The parent's proposal is the only number reported back up.
        // The inner split's own width is never reported: the parent
        // negotiates the detail column's width against what is
        // reported here, and the inner split keeps recomputing its
        // own width (= a second number in the same negotiation).
        //
        // When the parent proposes nothing, the parent's own last
        // proposal is used (= the parent's number, not the inner
        // split's); = with no proposal at all, no size is reported
        // (= the parent keeps its own layout).
        nsViewController.recordParentProposal(proposal)
        guard let width = proposal.width ?? nsViewController.lastParentWidth,
              let height = proposal.height ?? nsViewController.lastParentHeight
        else { return nil }
        return CGSize(width: width, height: height)
    }
}

/// Helper that applies AppState + BookStore to a SwiftUI view
/// IF they're non-nil (= the editor pane's NSHostingController is
/// created in AppKit code where the SwiftUI @Environment chain
/// doesn't propagate; = this helper bridges AppState + BookStore
/// across the boundary without forcing every caller to know the
/// env keys).
///
/// Extended to also inject WenshuLibrary (= the chat zone reads
/// library via @Environment; = reusing the helper means every
/// pane gets the same env chain pattern).
extension View {
    func applyOptionalEnvironment(appState: AppState?, bookStore: BookStore?, library: WenshuLibrary? = nil) -> some View {
        // Apply the union of available objects in one pass (= each
        // .environment modifier is additive; = the order doesn't
        // matter; = a single self is the chain root).
        environment(appState)
            .environment(bookStore)
            .environment(library)
    }
}
