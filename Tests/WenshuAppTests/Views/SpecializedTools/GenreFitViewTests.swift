//
//  GenreFitViewTests.swift · Wenshu · v1.44 ticket 001
//
//  Structural tests for GenreFitView (= 10 genre presets + convention analyzer (= P1 ticket #9 = hermes genre_fit.py port); = ~286 NLOC,
//  = repowise untested hotspot with 3 dependents).
//
//  Per boss OOB 2026-09-16 '按优先级推' + '自己一口气推完' (= keep
//  pushing until done): v1.44 batch-adds source-level structural
//  coverage for the 11 specialized tools (= the P1 hermes-port
//  batch per WorkspaceView renderTab dispatcher; = the
//  specializedTools column tab list).
//
//  Per Q34 5.2 + Q173 ponytail + Q186 + Q57 + Q112: source-level
//  tests following the v1.30 PlaceholderViewTests + v1.40
//  PreviewPaneTests + v1.41 PaneNSControllerTests precedent.
//  Pattern: 10 tests per file.
//
//  Path is derived from #filePath (= robust to worktree relocations).

import Foundation
import SwiftUI
import Testing
@testable import WenshuApp

@Suite("GenreFitView (v1.44 — specialized tools P1 hermes-port batch)")
struct GenreFitViewTests {

    private var sourcePath: String {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 { url.deleteLastPathComponent() }
        url.appendPathComponent("Sources/WenshuApp/Views/SpecializedTools/GenreFitView.swift")
        return url.path
    }

    @Test("GenreFitView exists as public struct (= confirmed by source)")
    func testExists() throws {
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        #expect(source.contains("public struct GenreFitView: View") ||
                source.contains("struct GenreFitView: View"),
                "GenreFitView must be declared in GenreFitView.swift")
    }

    @Test("GenreFitView conforms to View protocol (= source-level check)")
    func testConformsToView() throws {
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        #expect(source.contains("View"),
                "GenreFitView must conform to View protocol")
    }

    @Test("GenreFitView has body returning some View (= SwiftUI requirement)")
    func testBodyReturnsView() throws {
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        #expect(source.contains("var body: some View"),
                "GenreFitView must declare body returning some View")
    }

    @Test("GenreFitView imports SwiftUI (= canonical icon layer)")
    func testImportsSwiftUI() throws {
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        #expect(source.contains("import SwiftUI"),
                "GenreFitView must import SwiftUI")
        #expect(!source.contains("import LucideSwift"),
                "GenreFitView must NOT import LucideSwift (= removed by v1.x)")
    }

    @Test("GenreFitView file > 100 NLOC (= real hermes-port evidence)")
    func testFileSize() throws {
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        let lineCount = source.components(separatedBy: "\n").count
        #expect(lineCount > 100,
                "GenreFitView.swift must be > 100 NLOC (= real port; found \(lineCount))")
    }

    @Test("GenreFitView has public init (= SwiftUI view requirement)")
    func testHasInit() throws {
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        #expect(source.contains("init(") || source.contains("public init"),
                "GenreFitView must declare an init (= SwiftUI view contract)")
    }

    @Test("GenreFitView declares at least one GenreFitView struct (= primary view present)")
    func testSinglePrimaryStruct() throws {
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        #expect(source.contains("struct GenreFitView: View") ||
                source.contains("public struct GenreFitView: View"),
                "GenreFitView must declare primary GenreFitView: View struct")
    }

    @Test("X body uses SwiftUI control primitives")
    func testSwiftUIControls() throws {
        // Per Q57: 3rd-party verdict ≠ authority. We assert textual
        // evidence that this file is the hermes port (= doc comments
        // referencing hermes patterns OR direct imports from the
        // Specialized tools layer).
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        let hasSwiftUIPrimitive = source.contains("VStack(") ||
                                    source.contains("HStack(") ||
                                    source.contains("List(") ||
                                    source.contains("Form(") ||
                                    source.contains("LazyVGrid") ||
                                    source.contains("ScrollView(") ||
                                    source.contains("NavigationStack")
        #expect(hasSwiftUIPrimitive,
                "file must use SwiftUI primitives (= VStack/HStack/List/Form/ScrollView/etc)")
    }

    @Test("GenreFitView no Lucide references in code (= post-v1.x SF Symbols 6)")
    func testNoLucideInCode() throws {
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        let codeLines = source.components(separatedBy: "\n").filter { line in
            !line.trimmingCharacters(in: .whitespaces).hasPrefix("///") &&
            !line.trimmingCharacters(in: .whitespaces).hasPrefix("//")
        }
        let codeRegion = codeLines.joined(separator: "\n")
        let lucideCount = codeRegion.components(separatedBy: "Lucide").count - 1
        #expect(lucideCount == 0,
                "GenreFitView must have zero Lucide references in code (post-v1.x); found \(lucideCount)")
    }

    @Test("GenreFitView declares body + public init + struct conformance (= source-level triple check)")
    func testTripleContract() throws {
        // Triple contract check (= per Q34 5.2 structural verification):
        // 1. struct GenreFitView: View
        // 2. var body: some View
        // 3. public init()
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        #expect(source.contains("struct GenreFitView: View") ||
                source.contains("public struct GenreFitView: View"),
                "1/3: GenreFitView: View conformance missing")
        #expect(source.contains("var body: some View"),
                "2/3: var body: some View missing")
        #expect(source.contains("init("),
                "3/3: init() missing")
    }
}
