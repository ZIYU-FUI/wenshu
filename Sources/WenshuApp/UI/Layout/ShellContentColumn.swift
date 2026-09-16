// ShellContentColumn.swift · Wenshu · v1.39 ticket 001
//
// Extracted from NavigationSplitShell.swift (= v1.0.0-m1-shell boss OOB).
//
// Per boss OOB 2026-09-16 '按优先级推' + '拆了一半' concern.
// v1.38 extracted ShellSidebarColumn (= 34 NLOC). v1.39 (= this ticket)
// continues the NavigationSplitShell split with ShellContentColumn
// (= 80 NLOC = the detail column hosting editor + chat via
// EditorChatSplitHost = NSSplitViewController wrapper).
//
// Per Q34 5.2 + Q173 ponytail + Q186 + Q57 + Q112: extract
// ShellContentColumn (= the column hosting the editor + chat split).
// The struct + the 70-line Apple HIG rationale (= NSV + NSSplitViewController
// behavior + boss OOB context) move verbatim. 0 behavior change.
//
// Out of scope (= explicit, future tickets):
// - ShellMiddleColumn (= 446 NLOC; = next extract)
// - ShellDetailColumn (= ~590 NLOC)

import SwiftUI

// MARK: - Detail column (= 2 vertical sub-areas)

struct ShellContentColumn: View {
    let appState: AppState
    // v1.0.0-m1-shell boss 2026-09-12 OOB 'doc-open pipeline fix':
    // pass BookStore through to EditorChatSplitHost (= the editor
    // pane's EditorPlaceholder needs bookStore for
    // WenshuEditorServicesFactory = builds the engine's
    // WikiLinkResolver + ImageProvider against the active book
    // root).
    let bookStore: BookStore?

    var body: some View {
        // v1.0.0-m1-shell boss 2026-09-10 OOB 'keep grinding on the doc-handling plan': per
        // Apple's HIG split-views documentation
        // (developer.apple.com/design/human-interface-guidelines/
        // split-views): "Keynote in macOS uses split view panes to
        // present the slide navigator, the presenter notes, and
        // the inspector pane in areas that surround the main slide
        // canvas. For developer guidance, see VSplitView and
        // HSplitView." = the canonical Apple HIG 'middle column' (= detail
        // column = editor on top + chat on bottom) pattern is
        // VSplitView.
        //
        // Two .frame(maxWidth: .infinity, maxHeight: .infinity)
        // modifiers on the direct children (= EditorPlaceholder +
        // ChatZoneView) = commit f1b56bfc8 fix; = both children
        // fill the VSplitView slot (= no content-sized shrinkage).
        //
        // The .navigationSplitViewColumnWidth(min: 400, ideal: 600,
        // max: 900) is applied DIRECTLY on the ShellContentColumn
        // (= the view that lives inside NavigationSplitView's
        // detail: closure) per Apple docs: 'You can specify a
        // different modifier in each column. The navigation split
        // view does its best to accommodate the preferences that
        // you specify'. = the NSV honors the 400/600/900 detail
        // column width even with VSplitView inside.
        //
        // Apple HIG note: the chat zone may also collapse to zero
        // height when the user wants the editor to fill the whole
        // window (= the VSplitView divider is draggable down to
        // hide the chat; = same as Keynote's speaker notes panel).
        // v1.0.0-m1-shell boss 2026-09-10 OOB 'switch to NSSplitViewController:
        // native isCollapsed + animation, but rewrite the whole detail column': the
        // detail column is now hosted by `EditorChatNSController`
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
        // detail: closure) per Apple docs: 'You can specify a
        // different modifier in each column. The navigation split
        // view does its best to accommodate the preferences that
        // you specify'. = the NSV honors the 400/600/900 detail
        // column width even with NSSplitViewController inside.
        EditorChatSplitHost(
            conductor: WenshuAppDelegate.sharedConductor,
            // v1.0.0-m1-shell boss 2026-09-12 OOB 'doc-open pipeline fix':
            // thread AppState + BookStore through the SwiftUI →
            // AppKit boundary (= NSViewControllerRepresentable)
            // so the editor pane's EditorPlaceholder can read
            // appState.openTabs + activeTabId + bookStore for
            // WenshuEditorServicesFactory.
            appState: appState,
            bookStore: bookStore
        )
        .environment(appState)
    }
}
