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
//  - that same capsule is the column's VISIBILITY control (= pressing
//    the section that is showing turns the column off, = and pressing
//    any section of a hidden column opens it; = so the column has ONE
//    control, = and a second toggle button is gone (= boss 2026-11-10)),
//  - the dynamic section carries its own chrome band with the three
//    tabs it has always carried (= Todos, Sub-Agents, Tasks),
//  - the column body carries the selected section's content.
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

    var body: some View {
        VStack(spacing: 0) {
            // The column's top row is its own chrome (= the page band, or
            // the format page): the column carries no title row above it.
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
            // ONE control for the column (= the section switch alone).
            //
            // The section switch rides the WINDOW TOOLBAR's rightmost
            // slot (= the Apple answer: = Pages, = Numbers and = Keynote
            // all put their right-column switch in the window titlebar's
            // right-hand button group, = and NOT inside the column
            // itself; = measured on Pages 2026-11-04: = a six-segment
            // capsule whose selected glyph is the accent one).
            //
            // It is ALSO the column's visibility control: = the section
            // that is already showing turns the column off, = and any
            // section of a hidden column opens it (= `pressOutcome`).
            // So a separate center-slot toggle button was a SECOND
            // control for the same one binding (= the boss removed it
            // on 2026-11-10: = "the fold-away button is useless now,
            // because the right-column switch group at the far right
            // already does the same thing").
            //
            // One source of truth: = this switch and any future menu
            // command all write the same `isPresented` binding, = so
            // any of them can bring the column back.
            ToolbarItem(placement: .primaryAction) {
                InspectorSectionSwitch(
                    selection: InspectorView.sectionSwitchSelection(
                        section: $workspaceUI.inspectorSection,
                        visible: $inspectorVisibleBinding
                    )
                )
            }
        }
        .environment(appState)
        // The workspace's UI state rides the same re-injection, = for
        // the same reason: = the format page reads the sidebar's
        // selection from it (= the book whose style sheet the page
        // shows), = and SwiftUI 6 breaks the `@Environment` chain
        // across the NavigationSplitView column boundary.
        .environment(workspaceUI)
    }
}

extension InspectorView {
    /// The binding the window toolbar's section switch writes.
    ///
    /// It carries BOTH the column's section and its visibility: = the
    /// selection is nil while the column is hidden (= nothing wears the
    /// accent), = and a press computes the outcome through
    /// `pressOutcome` (= the section that is showing turns the column
    /// off, = and any section of a hidden column opens it on that
    /// section).
    ///
    /// It is a named function so the test can drive the PRODUCTION
    /// binding rather than a copy of it: = a copy proves nothing about
    /// the wiring that ships.
    static func sectionSwitchSelection(
        section: Binding<InspectorSection>,
        visible: Binding<Bool>
    ) -> Binding<InspectorSection?> {
        Binding(
            get: { visible.wrappedValue ? section.wrappedValue : nil },
            set: { picked in
                guard let picked else { return }
                let outcome = InspectorSection.pressOutcome(
                    picked,
                    current: section.wrappedValue,
                    visible: visible.wrappedValue
                )
                section.wrappedValue = outcome.section
                visible.wrappedValue = outcome.visible
            }
        )
    }
}

/// The inspector column's section switch (= the window toolbar's group).
///
/// It is a SwiftUI `Picker(.segmented)` in a toolbar item: = SwiftUI
/// registers THAT as a real toolbar item, = and a real toolbar item is
/// what makes AppKit draw the toolbar's own segmented shape (= the
/// chosen segment's plate covers the whole segment). = A hand-wrapped
/// `NSSegmentedControl` never receives that context, = and AppKit then
/// draws its ordinary appearance, = whose indicator is a small strip.
///
/// The selection is an OPTIONAL section: = nil = the column is hidden =
/// nothing is chosen.
struct InspectorSectionSwitch: View {
    let selection: Binding<InspectorSection?>

    var body: some View {
        Picker(
            "",
            selection: selection
        ) {
            ForEach(InspectorSection.allCases, id: \.self) { section in
                Label(section.localizedTitle, systemImage: section.icon)
                    .labelStyle(.iconOnly)
                    .help(section.localizedTitle)
                    .accessibilityLabel(section.localizedTitle)
                    .tag(Optional(section))
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }
}
