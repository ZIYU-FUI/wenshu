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
            switch workspaceUI.inspectorPage {
            case .status:
                // The status page owns the column's content: it lists
                // the focused chat session's sub-agent tasks.
                InspectorStatusView(appState: appState)
            case .authoringStyle, .authoringCharacters, .projectManagement:
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
        }
        .toolbar {
            // The page picker sits in the trailing area (= the
            // Apple HIG inspector tab strip; = Keynote / Pages /
            // Numbers put the right-panel page switcher there).
            ToolbarItem(placement: .primaryAction) {
                // The selection binding is a CUSTOM binding, not the
                // plain `$workspaceUI.inspectorPage`.
                //
                // Why: selecting a page must also bring the column
                // back when it is hidden. In the Apple apps the
                // inspector's tab strip sits in the window toolbar,
                // OUTSIDE the panel, and tapping a tab re-opens a
                // hidden panel (measured on Pages: hiding the
                // inspector from the menu, then pressing the
                // trailing toolbar segmented control, brings the
                // right column back).
                //
                // That behavior is NOT a platform guarantee. A stock
                // SwiftUI `Picker` in a toolbar does not re-open a
                // collapsed `.inspector(isPresented:)` on its own
                // (= verified against a minimal SwiftUI app with
                // both the stock segmented style and the macOS 27
                // `TabsPickerStyle` = neither re-opened it). The
                // app has to write the visibility itself, which is
                // what this binding does.
                //
                // One source of truth: the toggle button, this
                // picker, and any future menu command all write the
                // same `isPresented` binding, so any of them can
                // bring the column back.
                Picker(
                    "Inspector Page",
                    selection: Binding(
                        get: { workspaceUI.inspectorPage },
                        set: { newPage in
                            // 1. Show the column when it is hidden.
                            if !inspectorVisibleBinding {
                                inspectorVisibleBinding = true
                            }
                            // 2. Then switch the page.
                            workspaceUI.inspectorPage = newPage
                        }
                    )
                ) {
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
                        SFIcon(inspectorVisibleBinding ? "sidebar.right" : "sidebar.left", style: .paneTab, color: IconColor.tint)
                    }
                }
                .help(String(localized: "inspector.toggle.help"))
            }
        }
        .environment(appState)
    }
}
