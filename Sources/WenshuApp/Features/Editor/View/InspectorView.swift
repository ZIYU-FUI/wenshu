//
//  InspectorView.swift
//  wenshu
//
//  The right-hand inspector column (= the trailing column of the
//  detail split; = the Apple HIG `.inspector` surface).
//
//  Layout (= the Apple HIG three-column pattern):
//  - the column's chrome band carries the segmented control that
//    picks the column's page (= Todos, Sub-Agents, Tasks),
//  - the column body carries the selected page's content,
//  - the column's visibility toggle sits in the window toolbar
//    (= ToolbarItemGroup placement .principal).
//
//  The column has three pages (= the todos, the sub-agent tasks and
//  the task board). The page enum stays (= the seam a future page
//  tool plugs into) and each page renders its own content from its
//  own file, so a page can be filled in without the column knowing
//  anything about its contents.
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
            // The column's header names the COLUMN (= the way the
            // left column's header says Library and not the name of
            // the selected section). The header's trailing inset is
            // off, because the chrome band below carries its own row
            // height (= the assets column's header passes the same
            // `trailingInset: false`).
            SectionHeader(
                title: String(localized: "inspector.column.title"),
                trailingInset: false
            )
            // The band's switcher picks the column's page. It is the
            // same control the left column's band carries, at the
            // same size (= the switcher is a column-top chrome
            // control, not a body tab strip; = AppKit's `.small` = 20
            // PT; = the size Apple ships for a compact switcher), so
            // the two columns' controls read as one pair.
            ChromeTopBar(
                horizontalPadding: DesignTokens.spacingRelaxed,
                // The band belongs to the column's body (= it sits inside
                // the column's VStack under the column's own header and
                // holds the column's own page switcher, = not the window
                // toolbar), so the column's background shows through it
                // (= the same opt-out the left column's band and the
                // assets column's band make, = the two columns' bands
                // read as one pair).
                usesMaterial: false
            ) {
                LabelSegmentedControl(
                    selection: $workspaceUI.inspectorPage,
                    labels: InspectorPage.allCases,
                    displayStrings: InspectorPage.allCases.map(\.localizedTitle),
                    iconStyle: .paneTab,
                    controlSize: .small
                )
                // `fixedSize` keeps the control at its own height
                // (= 20 PT) instead of letting the band row's height
                // stretch it (= AppKit draws the capsule to fill the
                // control's height; = a stretched control = a
                // full-height bar with no air). The row below centers
                // it, so the band keeps its 28 PT height with air
                // above and below the capsule.
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .frame(height: DesignTokens.paneTabHotArea)
            }
            // The band's total height (= the content row + its
            // hairline) is clamped to the same 28 PT the left
            // column's band is, so the two columns' chrome bands
            // measure the same.
            .frame(height: DesignTokens.paneTabHotArea)
            // The page content goes here. Each page renders its own
            // content from its own file.
            switch workspaceUI.inspectorPage {
            case .todo:
                // The todo page owns the list of todos the assistant
                // wrote.
                InspectorTodoPageView()
            case .status:
                // The status page owns the column's sub-agent
                // content: it lists the focused chat session's
                // sub-agent tasks.
                InspectorStatusView(appState: appState)
            case .task:
                // The task page owns the board of long-running work.
                InspectorTaskPageView(workspaceUI: workspaceUI)
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
