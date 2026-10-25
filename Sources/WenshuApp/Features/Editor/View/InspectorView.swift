//
//  InspectorView.swift
//  wenshu
//
//  The right-hand inspector column (= the trailing column of the
//  detail split; = the Apple HIG `.inspector` surface).
//
//  Layout (= the Apple HIG three-column pattern):
//  - the column body carries the active page's title and content,
//  - the column's visibility toggle sits in the window toolbar
//    (= ToolbarItemGroup placement .principal).
//
//  The column has one page (= the status page; = the focused chat
//  session's sub-agent task cards). The page enum stays (= the seam a
//  future page tool plugs into) and each page renders its own
//  content.
//
//

import SwiftUI

/// The trailing inspector column of the detail split.
struct InspectorView: View {
    /// The app state (= re-injected into the env chain because
    /// SwiftUI 6 breaks the `@Environment` chain across the
    /// NavigationSplitView column boundary).
    @Bindable var appState: AppState
    /// The shared column-local UI state (= owns `inspectorPage`).
    @Bindable var workspaceUI: WorkspaceUIState
    /// Whether the column is visible (= owned by the shell; = the
    /// toolbar toggle writes back through this binding).
    @Binding var inspectorVisibleBinding: Bool

    var body: some View {
        VStack(spacing: 0) {
            SectionHeader(title: workspaceUI.inspectorPage.localizedTitle)
            // The page content goes here. A page that owns a tool
            // renders it in this slot.
            switch workspaceUI.inspectorPage {
            case .status:
                // The status page owns the column's content: it lists
                // the focused chat session's sub-agent tasks.
                InspectorStatusView(appState: appState)
            }
        }
        .toolbar {
            // The column toggle sits in the center area (= the
            // Apple HIG "center toolbar" slot; = the same slot the
            // window's other document-level controls use).
            //
            // One source of truth: the toggle button and any future
            // menu command all write the same `isPresented` binding,
            // so any of them can bring the column back.
            ToolbarItemGroup(placement: .principal) {
                Button {
                    inspectorVisibleBinding.toggle()
                } label: {
                    Label {
                        Text(String(localized: "inspector.toggle.button"))
                    } icon: {
                        SFIcon(inspectorVisibleBinding ? "sidebar.right" : "sidebar.left", style: .paneTab, color: IconColor.tint)
                    }
                }
                .help(String(localized: "inspector.toggle.help"))
            }
        }
        .environment(appState)
    }
}
