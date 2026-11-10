//
//  InspectorVisibilityBindingTests.swift · Wenshu
//
//  Structural test for the inspector column's visibility binding.
//
//  The column is shown and hidden through one binding. The toolbar
//  toggle that used to write it is GONE (= the boss removed it on
//  2026-11-10): = the window toolbar's rightmost section switch does
//  that job instead, = because pressing the section that is already
//  showing turns the column off, = and pressing any section of a
//  hidden column opens it.
//
//  So the switch is now the ONE writer of the binding, and this test
//  pins that: = a later refactor cannot split the column's visibility
//  into two sources of truth, = and it cannot leave the column with no
//  way back (= a column that cannot be reopened is a column the user
//  can only lose).
//
//  swift test --filter InspectorVisibilityBindingTests
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("Inspector visibility binding")
struct InspectorVisibilityBindingTests {

    private var inspectorPath: String {
        var url = SourceLocator.repoRoot
        url.appendPathComponent("Sources/WenshuApp/Features/Editor/View/InspectorView.swift")
        return url.path
    }

    @Test("the section switch writes the column's visibility")
    func switchWritesVisibility() throws {
        let source = try String(contentsOfFile: inspectorPath, encoding: .utf8)
        // The switch's binding (= the one the toolbar item installs) is
        // the named function `sectionSwitchSelection`, = and IT carries
        // the visibility write: = it computes the press through
        // `pressOutcome` (= the section that is showing turns the column
        // off, = any section of a hidden column opens it) and writes
        // BOTH the section and the visibility.
        #expect(source.contains("static func sectionSwitchSelection("),
                "the switch's binding must be a named function (= so a test can drive the production one)")
        #expect(source.contains("visible.wrappedValue = outcome.visible"),
                "the section switch must write the column's visibility binding")
        #expect(source.contains("section.wrappedValue = outcome.section"),
                "the section switch must write the column's section")
        #expect(source.contains("InspectorSection.pressOutcome("),
                "the section switch must compute the press through pressOutcome")
        #expect(source.contains("InspectorView.sectionSwitchSelection("),
                "the toolbar item must install the production binding")
    }

    @Test("the column's visibility has one source of truth")
    func oneSourceOfTruth() throws {
        let source = try String(contentsOfFile: inspectorPath, encoding: .utf8)
        // The column takes the visibility as a binding and never holds
        // its own copy, so the shell and the switch agree on whether
        // the column is showing.
        #expect(source.contains("@Binding var inspectorVisibleBinding: Bool"),
                "the column must take the visibility as a binding, not hold its own copy")
        #expect(!source.contains("@State private var inspectorVisible"),
                "the column must not keep a second visibility flag")
    }

    @Test("no second toggle button shares the binding")
    func noSecondToggleButton() throws {
        let source = try String(contentsOfFile: inspectorPath, encoding: .utf8)
        // The old center-slot button was a second control for the same
        // one binding. It is gone, and the switch alone is the writer.
        #expect(!source.contains("ToolbarItemGroup(placement: .principal)"),
                "the column must not carry a second toggle button in the center toolbar slot")
        #expect(!source.contains("inspectorVisibleBinding.toggle()"),
                "the section switch is the one writer of the column's visibility")
    }
}
