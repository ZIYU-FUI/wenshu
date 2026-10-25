//
//  InspectorVisibilityBindingTests.swift · Wenshu
//
//  Structural test for the inspector column's visibility binding.
//
//  The column is shown and hidden through one binding, and the
//  toolbar toggle writes it. The column had a page strip once, and
//  that strip wrote the same binding so a hidden column came back
//  when a page tab was pressed (= the Apple tab-strip behavior, =
//  not a platform guarantee: a stock SwiftUI `Picker` in a toolbar
//  does not re-open a collapsed `.inspector(isPresented:)` by
//  itself). The strip is gone with the pages it switched between, so
//  the toggle is the one writer.
//
//  This test pins that the toggle still drives the binding, so a
//  later refactor cannot split the column's visibility into two
//  sources of truth.
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

    @Test("the toolbar toggle writes the column's visibility")
    func toggleWritesVisibility() throws {
        let source = try String(contentsOfFile: inspectorPath, encoding: .utf8)
        #expect(source.contains("inspectorVisibleBinding.toggle()"),
                "the toolbar toggle must drive the column's visibility binding")
    }

    @Test("the column's visibility has one source of truth")
    func oneSourceOfTruth() throws {
        let source = try String(contentsOfFile: inspectorPath, encoding: .utf8)
        // The column takes the visibility as a binding and never holds
        // its own copy, so the shell and the toggle agree on whether
        // the column is showing.
        #expect(source.contains("@Binding var inspectorVisibleBinding: Bool"),
                "the column must take the visibility as a binding, not hold its own copy")
        #expect(!source.contains("@State private var inspectorVisible"),
                "the column must not keep a second visibility flag")
    }
}
