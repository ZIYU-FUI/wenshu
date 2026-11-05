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

    /// Whether the column is showing this section right now.
    ///
    /// A HIDDEN column shows NO section, = so no button in the group
    /// wears the accent (= Apple's shape).
    func isShowing(_ section: InspectorSection) -> Bool {
        InspectorSection.isShowing(
            section,
            current: workspaceUI.inspectorSection,
            visible: inspectorVisibleBinding
        )
    }

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
                // The Apple's OWN button group: = a `ControlGroup` in a
                // toolbar item is the macOS shape (= ONE capsule
                // holding several ROUND buttons), = which is what Pages,
                // = Numbers and = Keynote show at the titlebar's right
                // end.
                //
                // The group's buttons are TOGGLES, = because Apple's own
                // switch carries a CHOICE: = Pages' six titlebar
                // buttons read back as `AXRadioButton`, = so they are
                // radio semantics, = and their chosen one's mark is the
                // system's own (= a segmented control cannot draw that
                // circle: = its largest control size is 28 PT, = and
                // Apple's own button is 38 PT across).
                ControlGroup {
                    ForEach(InspectorSection.allCases, id: \.self) { section in
                        Toggle(
                            isOn: Binding(
                                get: { self.isShowing(section) },
                                set: { _ in
                                    let outcome = InspectorSection.pressOutcome(
                                        section,
                                        current: self.workspaceUI.inspectorSection,
                                        visible: self.inspectorVisibleBinding
                                    )
                                    self.workspaceUI.inspectorSection = outcome.section
                                    self.inspectorVisibleBinding = outcome.visible
                                }
                            ),
                            label: {
                                Image(systemName: section.icon)
                            }
                        )
                        .toggleStyle(.button)
                        .help(section.localizedTitle)
                    }
                }
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
