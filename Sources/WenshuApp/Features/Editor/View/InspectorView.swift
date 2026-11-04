//
//  InspectorView.swift
//  wenshu
//
//  The right-hand inspector column (= the trailing column of the
//  detail split; = the Apple HIG `.inspector` surface).
//
//  Layout (= the Apple HIG three-column pattern):
//  - the WINDOW TOOLBAR's rightmost slot carries the button group that
//    picks the column's MAJOR SECTION (= the dynamic series, = or the
//    format inspector), = as the macOS window titlebar's right-hand
//    capsule (= the place Pages, = Numbers and = Keynote put it),
//  - the dynamic section carries its own chrome band with the three
//    tabs it has always carried (= Todos, Sub-Agents, Tasks),
//  - the column body carries the selected section's content,
//  - the column's visibility toggle sits in the window toolbar
//    (= ToolbarItemGroup placement .principal).
//
//  The column has TWO major sections, = because it carries two kinds of
//  subject: = the DYNAMIC one (= what the runtime produces: = the todos,
//  = the sub-agent tasks, = the task board) = and the FORMAT one (= the
//  document's own format commands). = The three dynamic tabs are
//  UNCHANGED by that split: = they are the same control, = in the same
//  band, = with the same three pages under them.
//
//  The page enum stays (= the seam a future page tool plugs into) and
//  each page renders its own content from its own file, so a page can be
//  filled in without the column knowing anything about its contents.
//
//

import AppKit
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
            switch workspaceUI.inspectorSection {
            case .dynamic:
                // The dynamic section keeps the three tabs it has always
                // carried: = the same control, = in the same band, =
                // with the same three pages under it. = The split into
                // major sections did not touch them.
                ChromeTopBar(
                    horizontalPadding: DesignTokens.spacingRelaxed,
                    usesMaterial: false
                ) {
                    LabelSegmentedControl(
                        selection: $workspaceUI.inspectorPage,
                        labels: InspectorPage.allCases,
                        displayStrings: InspectorPage.allCases.map(\.localizedTitle),
                        iconStyle: .paneTab,
                        controlSize: .small
                    )
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
                    .frame(height: DesignTokens.paneTabHotArea)
                }
                .frame(height: DesignTokens.paneTabHotArea)
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
                    InspectorTaskPageView(workspaceUI: workspaceUI, appState: appState)
                }
            case .format:
                // The format section owns the document's format commands
                // (= they used to live in the editor zone's icon row).
                InspectorFormatPageView()
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
            // The section switch rides the WINDOW TOOLBAR's rightmost
            // slot (= the Apple answer: = Pages, = Numbers and = Keynote
            // all put their right-column switch in the window titlebar's
            // right-hand button group, = and NOT inside the column
            // itself; = measured on Pages 2026-11-04: = a six-segment
            // capsule whose selected glyph is the accent one).
            ToolbarItem(placement: .primaryAction) {
                LabelSegmentedControl.iconCapsule(
                    // The capsule's selection is the column's VISIBILITY
                    // plus its section: = a hidden column has NO
                    // selected segment (= the Apple shape: = the
                    // titlebar's switch shows nothing chosen until
                    // the column is showing), = and a visible column
                    // shows the section it is carrying.
                    //
                    // The binding is therefore an OPTIONAL section: = nil
                    // = "nothing is selected" (= no segment is drawn as
                    // chosen), = and the control maps nil to AppKit's own
                    // "no segment is selected" (-1).
                    selection: Binding<InspectorSection?>(
                        get: { self.inspectorVisibleBinding ? self.workspaceUI.inspectorSection : nil },
                        set: { picked in
                            guard let picked else { return }
                            // The Apple toggle: = the segment that is
                            // ALREADY showing turns the column off, = and
                            // any other segment turns it on (= and on
                            // that section).
                            if self.inspectorVisibleBinding, self.workspaceUI.inspectorSection == picked {
                                self.inspectorVisibleBinding = false
                            } else {
                                self.workspaceUI.inspectorSection = picked
                                self.inspectorVisibleBinding = true
                            }
                        }
                    ),
                    labels: InspectorSection.allCases.map { Optional($0) },
                    symbolNames: { $0?.icon ?? "" },
                    tooltips: InspectorSection.allCases.map(\.localizedTitle),
                    fixedSegmentWidth: DesignTokens.paneTabHotArea,
                    controlSize: .small
                )
                .frame(width: DesignTokens.paneTabHotArea * CGFloat(InspectorSection.allCases.count))
            }

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
