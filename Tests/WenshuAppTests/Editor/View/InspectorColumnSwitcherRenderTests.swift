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

    /// The column's OWN control (= the major sections), rendered the
    /// way the column configures it.
    @MainActor
    private func renderedControl(
        selection: Binding<InspectorSection>
    ) -> NSSegmentedControl? {
        // The column renders the section capsule the way a macOS window
        // titlebar's button group renders: = ICON segments, = no text,
        // = the names on hover.
        let host = NSHostingView(rootView: AnyView(
            LabelSegmentedControl(
                selection: selection,
                labels: InspectorSection.allCases,
                displayStrings: InspectorSection.allCases.map { _ in "" },
                iconStyle: .paneTab,
                icon: { section in
                    NSImage(
                        systemSymbolName: section.icon,
                        accessibilityDescription: section.localizedTitle
                    )
                },
                tooltips: InspectorSection.allCases.map(\.localizedTitle),
                controlSize: .small
            )
            .fixedSize(horizontal: true, vertical: true)
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

    /// The binding the column's OWN switcher writes (= the shared
    /// state's major-section selection).
    private func sectionBinding(_ state: WorkspaceUIState) -> Binding<InspectorSection> {
        Binding(
            get: { state.inspectorSection },
            set: { newValue in state.inspectorSection = newValue }
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

    @Test("the column's own switcher carries the two major sections")
    @MainActor
    func theColumnCarriesTwoSectionSegments() {
        let state = WorkspaceUIState()
        guard let control = renderedControl(selection: sectionBinding(state)) else {
            Issue.record("the rendered column carries no NSSegmentedControl")
            return
        }
        #expect(control.segmentCount == 2,
                "the column's own switcher carries one segment per major section")
        // The segments are ICONS (= a window titlebar's button group),
        // = so the segments carry no text, = and the names live in the
        // tooltips.
        let labels = (0 ..< control.segmentCount).map { control.label(forSegment: $0) }
        #expect(labels.allSatisfy { ($0 ?? "").isEmpty },
                "the capsule's segments show icons, = not words")
        let tooltips = (0 ..< control.segmentCount).map { control.toolTip(forSegment: $0) }
        #expect(tooltips.compactMap { $0 } == InspectorSection.allCases.map(\.localizedTitle),
                "the capsule's segments carry their names on hover")
        #expect(control.image(forSegment: 0) != nil && control.image(forSegment: 1) != nil,
                "each segment carries an icon")
    }

    @Test("choosing a major section writes it to the shared state")
    @MainActor
    func choosingASectionWritesTheSection() {
        let state = WorkspaceUIState()
        guard let control = renderedControl(selection: sectionBinding(state)) else {
            Issue.record("the rendered column carries no NSSegmentedControl")
            return
        }
        control.selectedSegment = 1
        control.sendAction(control.action, to: control.target)
        #expect(state.inspectorSection == .format,
                "choosing a section must write the section back to the shared state")
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
}
