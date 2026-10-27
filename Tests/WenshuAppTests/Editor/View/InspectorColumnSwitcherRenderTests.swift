//  InspectorColumnSwitcherRenderTests.swift · Wenshu
//
//  The inspector column's page switcher, rendered.
//
//  The shell test reads the column's SOURCE, which proves the wiring
//  and nothing about what AppKit paints. This suite renders the
//  switcher the way the column configures it and reads the real
//  NSSegmentedControl back, so the three facts a source read cannot
//  reach are measured on the control itself:
//
//  1. The control carries THREE segments, and their labels are the
//     three page titles in the segment order.
//  2. The control's size is the column-top chrome size (.small =
//     20 PT), because AppKit draws the capsule to fill the control's
//     height (= a control at the default .large draws a 28 PT pill
//     and the column's band is 28 PT tall).
//  3. Selecting a segment writes the page back to the shared state,
//     so the column's body swaps.
//
//  swift test --filter InspectorColumnSwitcherRenderTests
//

import Testing
import Foundation
import SwiftUI
import AppKit
@testable import WenshuApp

@Suite("Inspector column switcher, rendered")
struct InspectorColumnSwitcherRenderTests {

    /// The control the column's band hosts, found by walking the
    /// rendered view hierarchy for the NSSegmentedControl.
    @MainActor
    private func renderedControl(
        selection: Binding<InspectorPage>
    ) -> NSSegmentedControl? {
        let host = NSHostingView(rootView: AnyView(
            LabelSegmentedControl(
                selection: selection,
                labels: InspectorPage.allCases,
                displayStrings: InspectorPage.allCases.map(\.localizedTitle),
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
        if let control = view as? NSSegmentedControl { return control }
        for subview in view.subviews {
            if let found = findSegmentedControl(in: subview) { return found }
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

    @Test("the switcher carries three segments in the page order")
    @MainActor
    func theSwitcherCarriesThreeSegments() {
        let state = WorkspaceUIState()
        guard let control = renderedControl(selection: pageBinding(state)) else {
            Issue.record("the rendered column carries no NSSegmentedControl")
            return
        }
        #expect(control.segmentCount == 3,
                "the column's switcher carries one segment per page")
        // The labels are the page titles, in the case order.
        let labels = (0..<control.segmentCount).map { control.label(forSegment: $0) }
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
}
