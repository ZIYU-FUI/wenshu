//
//  InspectorView.swift
//  wenshu
//
//  The right-hand inspector column (= the trailing column of the
//  detail split; = the Apple HIG `.inspector` surface).
//
//  Layout (= the Apple HIG three-column pattern):
//  - the page picker lives in the window toolbar
//    (= ToolbarItem placement .primaryAction; = the page icons),
//  - the column body carries the active page's title and content.
//
//  The page body is the shared empty state: every specialized tool
//  that used to live in this column was removed, so no page has a
//  tool to show yet. The page enum stays (= 4 pages; = the seam a
//  future page tool plugs into) and each page renders
//  `EmptyStateView` until it owns content.
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
            // renders it in this slot; a page without one renders the
            // shared empty state (= centered, = the Apple HIG
            // "nothing to show" pattern).
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                EmptyStateView(
                    icon: workspaceUI.inspectorPage.icon,
                    title: String(localized: "inspector.empty.title"),
                    body: String(localized: "inspector.empty.body")
                )
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
        }
        .toolbar {
            // The page picker sits in the trailing area (= the
            // Apple HIG inspector tab strip; = Keynote / Pages /
            // Numbers put the right-panel page switcher there).
            ToolbarItem(placement: .primaryAction) {
                Picker("Inspector Page", selection: $workspaceUI.inspectorPage) {
                    ForEach(InspectorPage.allCases, id: \.self) { page in
                        Label {
                            Text(page.localizedTitle)
                        } icon: {
                            SFIcon(page.icon, style: .inlineSmall, color: IconColor.tint)
                        }
                        .tag(page)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .help(String(localized: "inspector.page.help"))
            }
            // The column toggle sits in the center area (= the
            // Apple HIG "center toolbar" slot; = the same slot the
            // window's other document-level controls use).
            ToolbarItemGroup(placement: .principal) {
                Button {
                    inspectorVisibleBinding.toggle()
                } label: {
                    Label {
                        Text(String(localized: "inspector.toggle.button"))
                    } icon: {
                        SFIcon(inspectorVisibleBinding ? "sidebar-right" : "sidebar.left", style: .paneTab, color: IconColor.tint)
                    }
                }
                .help(String(localized: "inspector.toggle.help"))
            }
        }
        .environment(appState)
    }
}
