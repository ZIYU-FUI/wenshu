//  InspectorColumnSwitcherRenderTests.swift · Wenshu
//
//  The inspector column's page switcher, rendered.
//
//  The shell test reads the column's SOURCE, which proves the wiring
//  and nothing about what AppKit paints. This suite renders the
//  switchers the way the column configures them and reads the real
//  NSSegmentedControl back, so the facts a source read cannot reach
//  are measured on the controls themselves:
//
//  1. The dynamic section's control carries THREE segments, and their
//     labels are the three page titles in the segment order; = and the
//     column's own control carries TWO segments, = the major sections.
//  2. The control's size is the column-top chrome size (.small =
//     20 PT), because AppKit draws the capsule to fill the control's
//     height (= a control at the default .large draws a 28 PT pill
//     and the column's band is 28 PT tall).
//  3. Selecting a segment writes the page back to the shared state,
//     so the column's body swaps.
//
//  swift test --filter InspectorColumnSwitcherRenderTests
//

import AppKit
import Foundation
import SwiftUI
import Testing
@testable import WenshuApp

@Suite("Inspector column switcher, rendered")
struct InspectorColumnSwitcherRenderTests {
    private var inspectorPath: String {
        var url = SourceLocator.repoRoot
        url.appendPathComponent("Sources/WenshuApp/Features/Editor/View/InspectorView.swift")
        return url.path
    }

    /// The control the column's band hosts, found by walking the
    /// rendered view hierarchy for the NSSegmentedControl.
    @MainActor
    private func renderedControl(
        selection: Binding<InspectorPage>
    ) -> NSSegmentedControl? {
        renderedControl(
            selection: selection,
            labels: InspectorPage.allCases,
            displayStrings: InspectorPage.allCases.map(\.localizedTitle)
        )
    }

    @MainActor
    private func renderedControl<Selection: Hashable>(
        selection: Binding<Selection>,
        labels: [Selection],
        displayStrings: [String]
    ) -> NSSegmentedControl? {
        let host = NSHostingView(rootView: AnyView(
            LabelSegmentedControl(
                selection: selection,
                labels: labels,
                displayStrings: displayStrings,
                iconStyle: .paneTab,
                controlSize: .small
            )
            .frame(width: 320)
        ))
        host.frame = NSRect(x: 0, y: 0, width: 320, height: 40)
        let window = NSWindow(
            contentRect: host.frame,
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        host.layoutSubtreeIfNeeded()
        return findSegmentedControl(in: host)
    }

    @MainActor
    private func findSegmentedControl(in view: NSView) -> NSSegmentedControl? {
        if let control = view as? NSSegmentedControl {
            return control
        }
        for subview in view.subviews {
            if let found = findSegmentedControl(in: subview) {
                return found
            }
        }
        return nil
    }

    /// The binding the column's switcher writes (= the shared state's
    /// page selection).
    private func pageBinding(_ state: WorkspaceUIState) -> Binding<InspectorPage> {
        Binding(
            get: { state.inspectorPage },
            set: { newValue in state.inspectorPage = newValue }
        )
    }

    @Test("the dynamic section's switcher carries three segments in the page order")
    @MainActor
    func theSwitcherCarriesThreeSegments() {
        let state = WorkspaceUIState()
        guard let control = renderedControl(selection: pageBinding(state)) else {
            Issue.record("the rendered column carries no NSSegmentedControl")
            return
        }
        #expect(control.segmentCount == 3,
                "the dynamic section's switcher carries one segment per page")
        // The labels are the page titles, in the case order.
        let labels = (0 ..< control.segmentCount).map { control.label(forSegment: $0) }
        #expect(labels == InspectorPage.allCases.map(\.localizedTitle),
                "the segments read the three page titles in the page order")
    }

    @Test("the switcher draws at the column-top chrome size")
    @MainActor
    func theSwitcherDrawsAtTheChromeSize() {
        let state = WorkspaceUIState()
        guard let control = renderedControl(selection: pageBinding(state)) else {
            Issue.record("the rendered column carries no NSSegmentedControl")
            return
        }
        #expect(control.controlSize == .small,
                "a column-top chrome control is .small (= 20 PT); = the default .large draws a 28 PT pill")
    }

    @Test("selecting a segment writes the page to the shared state")
    @MainActor
    func selectingASegmentWritesThePage() {
        let state = WorkspaceUIState()
        guard let control = renderedControl(selection: pageBinding(state)) else {
            Issue.record("the rendered column carries no NSSegmentedControl")
            return
        }
        // The task segment is the third one (= the page order is the
        // segment order).
        control.selectedSegment = 2
        control.sendAction(control.action, to: control.target)
        #expect(state.inspectorPage == .task,
                "choosing a segment must write the page back to the shared state")
    }

    @Test("the section switch is the window toolbar's button group (= a ControlGroup, = not a segmented control)")
    @MainActor
    func theSectionSwitchIsAToolbarButtonGroup() throws {
        let source = try String(contentsOfFile: inspectorPath, encoding: .utf8)
        #expect(source.contains("ControlGroup {"),
                "the section switch is a ControlGroup: = the macOS shape is ONE capsule holding several ROUND buttons, = and Apple's own titlebar switch measures 38 PT across, = which a segmented control cannot draw (= its largest control size is 28 PT)")
        #expect(source.contains("ToolbarItem(placement: .primaryAction)"),
                "the group rides the window toolbar's RIGHTMOST slot")
        #expect(source.contains(".toggleStyle(.button)"),
                "the group's buttons are TOGGLES: = Apple's own switch carries a CHOICE, = and the system's own mark is what says which one")
        #expect(source.contains("InspectorSection.pressOutcome("),
                "the section's press goes through the ONE pure function that decides what it does")
    }

    @Test("a hidden column shows no section at all (= nothing wears the accent)")
    func aHiddenColumnShowsNoSection() {
        for section in InspectorSection.allCases {
            #expect(!InspectorSection.isShowing(section, current: .dynamic, visible: false),
                    "a hidden column shows no section, = so no button wears the accent")
        }
    }

    @Test("a visible column shows exactly the section it carries")
    func aVisibleColumnShowsItsSection() {
        #expect(InspectorSection.isShowing(.dynamic, current: .dynamic, visible: true),
                "the carried section is the shown one")
        #expect(!InspectorSection.isShowing(.format, current: .dynamic, visible: true),
                "the other section is not shown")
    }

    @Test("pressing the section that is showing turns the column off")
    func pressingTheShownSectionTurnsTheColumnOff() {
        let outcome = InspectorSection.pressOutcome(.dynamic, current: .dynamic, visible: true)
        #expect(outcome.visible == false,
                "the section that is ALREADY showing turns the column off (= Apple's toggle)")
        #expect(outcome.section == .dynamic,
                "the column's section is remembered, = so reopening shows it again")
    }

    @Test("pressing any section of a hidden column opens the column on that section")
    func pressingAnySectionOfAHiddenColumnOpensIt() {
        for section in InspectorSection.allCases {
            let outcome = InspectorSection.pressOutcome(section, current: .dynamic, visible: false)
            #expect(outcome.visible == true,
                    "a hidden column opens on whichever button the user pressed")
            #expect(outcome.section == section,
                    "and it opens ON that section")
        }
    }

    @Test("pressing the other section of a visible column switches to it")
    func pressingTheOtherSectionSwitches() {
        let outcome = InspectorSection.pressOutcome(.format, current: .dynamic, visible: true)
        #expect(outcome.visible == true,
                "the column stays open when another section is pressed")
        #expect(outcome.section == .format,
                "and it switches to the pressed section")
    }
}
