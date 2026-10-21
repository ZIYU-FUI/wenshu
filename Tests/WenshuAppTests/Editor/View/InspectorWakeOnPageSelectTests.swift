//
//  InspectorWakeOnPageSelectTests.swift · Wenshu
//
//  Structural test for the inspector's page strip waking a hidden
//  column.
//
//  The Apple apps put the inspector's tab strip in the window toolbar,
//  outside the panel, and tapping a tab brings a hidden panel back.
//  That behavior is not a platform guarantee: a stock SwiftUI `Picker`
//  in a toolbar does not re-open a collapsed `.inspector(isPresented:)`
//  by itself, so the app has to write the visibility.
//
//  This test pins that write, so the behavior cannot be lost by a
//  later refactor that puts the picker back on a plain page binding.
//
//  swift test --filter InspectorWakeOnPageSelectTests
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("Inspector wakes when a page tab is selected")
struct InspectorWakeOnPageSelectTests {

    private var inspectorPath: String {
        var url = SourceLocator.repoRoot
        url.appendPathComponent("Sources/WenshuApp/Features/Editor/View/InspectorView.swift")
        return url.path
    }

    @Test("the page picker writes the column's visibility")
    func pagePickerWritesVisibility() throws {
        let source = try String(contentsOfFile: inspectorPath, encoding: .utf8)
        #expect(source.contains("inspectorVisibleBinding = true"),
                "the page picker's selection setter must set the column's visibility, so a hidden column comes back when a page tab is pressed (= the Apple tab-strip behavior)")
    }

    @Test("the page picker is bound through a custom binding")
    func pagePickerUsesACustomBinding() throws {
        let source = try String(contentsOfFile: inspectorPath, encoding: .utf8)
        #expect(source.contains("selection: Binding("),
                "the page picker must bind through a custom Binding whose setter can write the visibility, not through the plain page binding")
    }

    @Test("the visibility binding and the page state are the column's single source of truth")
    func oneSourceOfTruth() throws {
        let source = try String(contentsOfFile: inspectorPath, encoding: .utf8)
        // The toggle button and the page picker must both drive the
        // same visibility binding, so either route can bring the
        // column back.
        #expect(source.contains("inspectorVisibleBinding.toggle()"),
                "the toolbar toggle must drive the same visibility binding the page picker writes")
    }
}
