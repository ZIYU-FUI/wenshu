// ShellContentColumn.swift · Wenshu
//
// Extracted from `NavigationSplitShell.swift`. Continues the
// split with ShellContentColumn (= the detail column hosting
// editor + chat via EditorChatSplitHost = NSSplitViewController
// wrapper).
//
// Out of scope (= future tickets):
// - ShellMiddleColumn (= the next extract)
// - ShellDetailColumn

import SwiftUI

// MARK: - Detail column (= 2 vertical sub-areas)

struct ShellContentColumn: View {
    let appState: AppState
    // Pass BookStore through to EditorChatSplitHost (= the editor
    // pane's EditorView needs bookStore for
    // WenshuEditorServicesFactory = builds the engine's
    // WikiLinkResolver + ImageProvider against the active book
    // root).
    let bookStore: BookStore?
    // Thread WenshuLibrary through to EditorChatSplitHost so
    // ChatZoneView can observe library.selectedBookId (= the
    // canonical source for the user's active book).
    let library: WenshuLibrary?

    var body: some View {
        // Per Apple's HIG split-views documentation
        // (developer.apple.com/design/human-interface-guidelines/
        // split-views): "Keynote in macOS uses split view panes
        // to present the slide navigator, the presenter notes,
        // and the inspector pane in areas that surround the main
        // slide canvas." = the canonical Apple HIG 'middle column'
        // (= detail column = editor on top + chat on bottom)
        // pattern is VSplitView.
        //
        // Two .frame(maxWidth: .infinity, maxHeight: .infinity)
        // modifiers on the direct children (= EditorView +
        // ChatZoneView) = both children fill the VSplitView slot
        // (= no content-sized shrinkage).
        //
        // The .navigationSplitViewColumnWidth(min: 400, ideal: 600,
        // max: 900) is applied DIRECTLY on the ShellContentColumn
        // (= the view that lives inside NavigationSplitView's
        // detail: closure) per Apple docs: 'You can specify a
        // different modifier in each column. The navigation split
        // view does its best to accommodate the preferences that
        // you specify'. The NSV honors the 400/600/900 detail
        // column width even with VSplitView inside.
        //
        // Apple HIG note: the chat zone may also collapse to zero
        // height when the user wants the editor to fill the whole
        // window (= the VSplitView divider is draggable down to
        // hide the chat; = same as Keynote's speaker notes panel).
        // The detail column is now hosted by `EditorChatNSController`
        // (= AppKit NSSplitViewController with canCollapse=true
        // on the chat item; = the canonical Apple HIG Keynote
        // speaker-notes pattern; = native isCollapsed +
        // animator() animation; = per developer.apple.com/design/
        // human-interface-guidelines/split-views 'A split view
        // can collapse one of its panes by dragging the divider
        // past the edge of the split view, by clicking the
        // collapse button in the divider, or programmatically.').
        //
        // The SwiftUI `VSplitView` (= the previous implementation)
        // does NOT expose canCollapse / isCollapsed / native
        // divider-collapse animation. The Apple HIG canonical way
        // to get the Keynote speaker-notes hide/show behavior is
        // the AppKit NSSplitViewController.
        //
        // The .navigationSplitViewColumnWidth(min: 400, ideal: 600,
        // max: 900) is applied DIRECTLY on the ShellContentColumn
        // (= the view that lives inside NavigationSplitView's
        // detail: closure) per Apple docs: the NSV honors the
        // 400/600/900 detail column width even with
        // NSSplitViewController inside.
        EditorChatSplitHost(
            conductor: WenshuAppDelegate.sharedConductor,
            // Thread AppState + BookStore through the SwiftUI →
            // AppKit boundary (= NSViewControllerRepresentable)
            // so the editor pane's EditorView can read
            // appState.openTabs + activeTabId + bookStore for
            // WenshuEditorServicesFactory.
            appState: appState,
            bookStore: bookStore,
            library: library
        )
        .environment(appState)
    }
}
