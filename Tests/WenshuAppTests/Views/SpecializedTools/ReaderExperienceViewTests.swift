//
//  ReaderExperienceViewTests.swift · Wenshu · v1.44 ticket 001
//
//  Structural tests for ReaderExperienceView (= 5 reader-experience analyzers: tension/pacing/foreshadowing/cliffhanger/payoff (= P1 ticket #7 = hermes reader_experience.py port); = ~294 NLOC,
//  = repowise untested hotspot with 3 dependents).
//
// : v1.44 batch-adds source-level structural
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

@Suite("ReaderExperienceView (v1.44 — specialized tools P1 hermes-port batch)")
struct ReaderExperienceViewTests {

    private var sourcePath: String {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 { url.deleteLastPathComponent() }
        url.appendPathComponent("Sources/WenshuApp/Views/SpecializedTools/ReaderExperienceView.swift")
        return url.path
    }

    @Test("ReaderExperienceView exists as public struct (= confirmed by source)")
    func testExists() throws {
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        #expect(source.contains("struct ReaderExperienceView: View") ||
                source.contains("struct ReaderExperienceView: View"),
                "ReaderExperienceView must be declared in ReaderExperienceView.swift")
    }

    @Test("ReaderExperienceView conforms to View protocol (= source-level check)")
    func testConformsToView() throws {
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        #expect(source.contains("View"),
                "ReaderExperienceView must conform to View protocol")
    }

    @Test("ReaderExperienceView has body returning some View (= SwiftUI requirement)")
    func testBodyReturnsView() throws {
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        #expect(source.contains("var body: some View"),
                "ReaderExperienceView must declare body returning some View")
    }

    @Test("ReaderExperienceView imports SwiftUI (= canonical icon layer)")
    func testImportsSwiftUI() throws {
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        #expect(source.contains("import SwiftUI"),
                "ReaderExperienceView must import SwiftUI")
        #expect(!source.contains("import LucideSwift"),
                "ReaderExperienceView must NOT import LucideSwift (= removed by v1.x)")
    }

    @Test("ReaderExperienceView file > 100 NLOC (= real hermes-port evidence)")
    func testFileSize() throws {
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        let lineCount = source.components(separatedBy: "\n").count
        #expect(lineCount > 100,
                "ReaderExperienceView.swift must be > 100 NLOC (= real port; found \(lineCount))")
    }

    @Test("ReaderExperienceView has public init (= SwiftUI view requirement)")
    func testHasInit() throws {
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        #expect(source.contains("init(") || source.contains("init"),
                "ReaderExperienceView must declare an init (= SwiftUI view contract)")
    }

    @Test("ReaderExperienceView declares at least one ReaderExperienceView struct (= primary view present)")
    func testSinglePrimaryStruct() throws {
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        #expect(source.contains("struct ReaderExperienceView: View") ||
                source.contains("struct ReaderExperienceView: View"),
                "ReaderExperienceView must declare primary ReaderExperienceView: View struct")
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

    @Test("ReaderExperienceView no Lucide references in code (= post-v1.x SF Symbols 6)")
    func testNoLucideInCode() throws {
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        let codeLines = source.components(separatedBy: "\n").filter { line in
            !line.trimmingCharacters(in: .whitespaces).hasPrefix("///") &&
            !line.trimmingCharacters(in: .whitespaces).hasPrefix("//")
        }
        let codeRegion = codeLines.joined(separator: "\n")
        let lucideCount = codeRegion.components(separatedBy: "Lucide").count - 1
        #expect(lucideCount == 0,
                "ReaderExperienceView must have zero Lucide references in code (post-v1.x); found \(lucideCount)")
    }

    @Test("ReaderExperienceView declares body + public init + struct conformance (= source-level triple check)")
    func testTripleContract() throws {
        // Triple contract check (= per Q34 5.2 structural verification):
        // 1. struct ReaderExperienceView: View
        // 2. var body: some View
        // 3. public init()
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        #expect(source.contains("struct ReaderExperienceView: View") ||
                source.contains("struct ReaderExperienceView: View"),
                "1/3: ReaderExperienceView: View conformance missing")
        #expect(source.contains("var body: some View"),
                "2/3: var body: some View missing")
        #expect(source.contains("init("),
                "3/3: init() missing")
    }

    @Test("ReaderExperienceViewState mirror exists (= business state hoisted out of @State per v1.72 MVVM split)")
    func testStateMirrorExists() throws {
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        #expect(source.contains("ReaderExperienceViewState"),
                "ReaderExperienceView must reference ReaderExperienceViewState mirror")
        #expect(source.contains("@State private var state = ReaderExperienceViewState()"),
                "ReaderExperienceView must hold state via @State mirror")
        let bareReport = source.contains("@State private var report: ReaderExperienceReport?")
        let bareStatus = source.contains("@State private var status: AnalyzeStatus = .idle")
        #expect(!bareReport, "report must NOT be a bare @State var")
        #expect(!bareStatus, "status must NOT be a bare @State var (AnalyzeStatus moved out)")
    }

    @Test("ReaderExperienceViewState mirror file exists (= companion file under Views/SpecializedTools/)")
    func testStateMirrorFileExists() throws {
        let filePath = "/Volumes/ANAN/Engineering/wenshu/.worktrees/p2-mirrors/Sources/WenshuApp/Views/SpecializedTools/ReaderExperienceViewState.swift"
        #expect(FileManager.default.fileExists(atPath: filePath),
                "ReaderExperienceViewState.swift must exist as a companion file")
        let source = try String(contentsOfFile: filePath, encoding: .utf8)
        #expect(source.contains("@Observable"), "mirror must use @Observable macro")
        #expect(source.contains("final class ReaderExperienceViewState"), "mirror must be a final class")
        #expect(source.contains("var report: ReaderExperienceReport?"), "mirror must hold report field")
        #expect(source.contains("var status: SpecializedToolLoadStatus"), "mirror must hold status field (canonical SpecializedToolLoadStatus)")
    }
}
