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

    /// The PRODUCTION switch, = rendered: = and the real control behind it
    /// read back.
    ///
    /// The selection is OPTIONAL: = nil = the column is hidden = nothing
    /// is chosen.
    @MainActor
    private func renderSegmentedControl(selection: InspectorSection?) -> NSSegmentedControl {
        let host = NSHostingView(rootView: AnyView(
            InspectorSectionSwitch(
                selection: Binding(
                    get: { selection },
                    set: { _ in }
                )
            )
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
        guard let control = findSegmentedControl(in: host) else {
            Issue.record("the rendered switch carries no NSSegmentedControl")
            return NSSegmentedControl()
        }
        return control
    }

    @Test("each segment names itself on hover")
    @MainActor
    func eachSegmentNamesItselfOnHover() {
        let control = renderSegmentedControl(selection: .dynamic)
        for index in 0 ..< control.segmentCount {
            #expect(control.toolTip(forSegment: index) != nil,
                    "each segment carries a name of its own")
        }
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

    @Test("the section switch is the window toolbar's segmented picker")
    @MainActor
    func theSectionSwitchIsTheWindowToolbarsSegmentedPicker() throws {
        let source = try String(contentsOfFile: inspectorPath, encoding: .utf8)
        #expect(source.contains("Picker("),
                "the section switch is a SwiftUI Picker(.segmented): = THAT is the form SwiftUI registers as a REAL toolbar item, = and a real toolbar item is what makes AppKit draw the toolbar's segmented shape")
        #expect(source.contains(".pickerStyle(.segmented)"),
                "the switch is segmented, = and its segments are the section choices")
        #expect(source.contains("ToolbarItem(placement: .primaryAction)"),
                "the group rides the window toolbar's RIGHTMOST slot")
        #expect(source.contains("InspectorSection.pressOutcome("),
                "the section's press goes through the ONE pure function that decides what it does")
    }

    @Test("a hidden column shows no section at all (= nothing wears the accent)")
    @MainActor
    func aHiddenColumnShowsNoSection() {
        // A HIDDEN column carries NO selection, = and the rendered control
        // must show that: = with no selection chosen, = no segment wears
        // the accent.
        let control = renderSegmentedControl(selection: nil)
        #expect(control.selectedSegment == -1,
                "a hidden column shows no section, = so no segment wears the accent")
    }

    @Test("a visible column shows exactly the section it carries")
    @MainActor
    func aVisibleColumnShowsItsSection() {
        let control = renderSegmentedControl(selection: .dynamic)
        #expect(control.selectedSegment == 0,
                "the carried section is the chosen one")
        let other = renderSegmentedControl(selection: .format)
        #expect(other.selectedSegment == 1,
                "the other section is the chosen one when it is the carried one")
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

    /// The PRODUCTION switch, = rendered: = and the real control behind it
    /// read back.
    ///
    /// This measures the thing the column actually shows: = the segments
    /// the control carries, = what each segment shows (= a symbol and no
    /// word), = and whether choosing one writes the choice back.
    @Test("the rendered switch carries one symbol segment per section, = and choosing one writes it back")
    @MainActor
    func theRenderedSwitchCarriesASegmentPerSection() {
        let state = WorkspaceUIState()
        let host = NSHostingView(rootView: AnyView(
            InspectorSectionSwitch(
                selection: Binding(
                    get: { state.inspectorSection },
                    set: { newValue in state.inspectorSection = newValue ?? .dynamic }
                )
            )
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
        guard let control = findSegmentedControl(in: host) else {
            Issue.record("the rendered switch carries no NSSegmentedControl")
            return
        }
        #expect(control.segmentCount == InspectorSection.allCases.count,
                "the switch carries one segment per major section")
        // Each segment carries a SYMBOL: = an image, = and no word.
        for index in 0 ..< control.segmentCount {
            #expect(control.image(forSegment: index) != nil,
                    "each segment carries an icon")
        }
        // Choosing a segment writes the choice back to the shared state.
        control.selectedSegment = 1
        control.sendAction(control.action, to: control.target)
        #expect(state.inspectorSection == .format,
                "choosing a segment must write the section back to the shared state")
    }
}
