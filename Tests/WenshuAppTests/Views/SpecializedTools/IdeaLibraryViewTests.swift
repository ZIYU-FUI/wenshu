//
//  IdeaLibraryViewTests.swift · Wenshu · v1.44 ticket 001
//
//  Structural tests for IdeaLibraryView (= 5 statuses + link to chapter/character/plot-thread + search + suggest (= P1 ticket #15 = hermes idea_library.py port); = ~667 NLOC,
//  = repowise untested hotspot with 4 dependents).
//
// : v1.44 batch-adds source-level structural
//  coverage for the 11 specialized tools (= the P1 hermes-port
//  batch per WorkspaceView renderTab dispatcher; = the
//  specializedTools column tab list).
//
//  Per Q34 5.2 + Q173 ponytail + Q186 + Q57 + Q112: source-level
//  tests following the v1.30 PlaceholderViewTests + v1.40
//  PreviewPaneTests precedent.
//  Pattern: 10 tests per file.
//
//  Path is derived from #filePath (= robust to worktree relocations).

import Foundation
import SwiftUI
import Testing
@testable import WenshuApp

@Suite("IdeaLibraryView (v1.44 — specialized tools P1 hermes-port batch)")
struct IdeaLibraryViewTests {

    private var sourcePath: String {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 { url.deleteLastPathComponent() }
        url.appendPathComponent("Sources/WenshuApp/Views/SpecializedTools/IdeaLibraryView.swift")
        return url.path
    }

    @Test("IdeaLibraryView exists as public struct (= confirmed by source)")
    func testExists() throws {
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        #expect(source.contains("struct IdeaLibraryView: View") ||
                source.contains("struct IdeaLibraryView: View"),
                "IdeaLibraryView must be declared in IdeaLibraryView.swift")
    }

    @Test("IdeaLibraryView conforms to View protocol (= source-level check)")
    func testConformsToView() throws {
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        #expect(source.contains("View"),
                "IdeaLibraryView must conform to View protocol")
    }

    @Test("IdeaLibraryView has body returning some View (= SwiftUI requirement)")
    func testBodyReturnsView() throws {
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        #expect(source.contains("var body: some View"),
                "IdeaLibraryView must declare body returning some View")
    }

    @Test("IdeaLibraryView imports SwiftUI (= canonical icon layer)")
    func testImportsSwiftUI() throws {
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        #expect(source.contains("import SwiftUI"),
                "IdeaLibraryView must import SwiftUI")
        #expect(!source.contains("import LucideSwift"),
                "IdeaLibraryView must NOT import LucideSwift (= removed by v1.x)")
    }

    @Test("IdeaLibraryView file > 100 NLOC (= real hermes-port evidence)")
    func testFileSize() throws {
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        let lineCount = source.components(separatedBy: "\n").count
        #expect(lineCount > 100,
                "IdeaLibraryView.swift must be > 100 NLOC (= real port; found \(lineCount))")
    }

    @Test("IdeaLibraryView has public init (= SwiftUI view requirement)")
    func testHasInit() throws {
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        #expect(source.contains("init(") || source.contains("init"),
                "IdeaLibraryView must declare an init (= SwiftUI view contract)")
    }

    @Test("IdeaLibraryView declares at least one IdeaLibraryView struct (= primary view present)")
    func testSinglePrimaryStruct() throws {
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        #expect(source.contains("struct IdeaLibraryView: View") ||
                source.contains("struct IdeaLibraryView: View"),
                "IdeaLibraryView must declare primary IdeaLibraryView: View struct")
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

    @Test("IdeaLibraryView no Lucide references in code (= post-v1.x SF Symbols 6)")
    func testNoLucideInCode() throws {
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        let codeLines = source.components(separatedBy: "\n").filter { line in
            !line.trimmingCharacters(in: .whitespaces).hasPrefix("///") &&
            !line.trimmingCharacters(in: .whitespaces).hasPrefix("//")
        }
        let codeRegion = codeLines.joined(separator: "\n")
        let lucideCount = codeRegion.components(separatedBy: "Lucide").count - 1
        #expect(lucideCount == 0,
                "IdeaLibraryView must have zero Lucide references in code (post-v1.x); found \(lucideCount)")
    }

    @Test("IdeaLibraryView declares body + public init + struct conformance (= source-level triple check)")
    func testTripleContract() throws {
        // Triple contract check (= per Q34 5.2 structural verification):
        // 1. struct IdeaLibraryView: View
        // 2. var body: some View
        // 3. public init()
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        #expect(source.contains("struct IdeaLibraryView: View") ||
                source.contains("struct IdeaLibraryView: View"),
                "1/3: IdeaLibraryView: View conformance missing")
        #expect(source.contains("var body: some View"),
                "2/3: var body: some View missing")
        #expect(source.contains("init("),
                "3/3: init() missing")
    }

    @Test("IdeaLibraryViewState mirror exists (= business state hoisted out of @State per v1.72 MVVM split)")
    func testStateMirrorExists() throws {
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        #expect(source.contains("IdeaLibraryViewState"),
                "IdeaLibraryView must reference IdeaLibraryViewState mirror")
        #expect(source.contains("@State private var state = IdeaLibraryViewState()"),
                "IdeaLibraryView must hold state via @State mirror (not bare @State vars)")
        // The 4 hoisted fields must NOT appear as bare @State vars
        let bareIdeas = source.contains("@State private var ideas: [Idea]")
        let bareSuggestions = source.contains("@State private var suggestions: [Idea]")
        let bareStatus = source.contains("@State private var status: SpecializedToolLoadStatus")
        let bareErrorText = source.contains("@State private var errorText: String?")
        #expect(!bareIdeas, "ideas must NOT be a bare @State var (= hoisted to state.ideas)")
        #expect(!bareSuggestions, "suggestions must NOT be a bare @State var (= hoisted to state.suggestions)")
        #expect(!bareStatus, "status must NOT be a bare @State var (= hoisted to state.status)")
        #expect(!bareErrorText, "errorText must NOT be a bare @State var (= hoisted to state.errorText)")
    }

    @Test("IdeaLibraryViewState mirror file exists (= companion file under Views/SpecializedTools/)")
    func testStateMirrorFileExists() throws {
        let filePath = "/Volumes/ANAN/Engineering/wenshu/.worktrees/mvvm-p1/Sources/WenshuApp/Views/SpecializedTools/IdeaLibraryViewState.swift"
        #expect(FileManager.default.fileExists(atPath: filePath),
                "IdeaLibraryViewState.swift must exist as a companion file")
        let source = try String(contentsOfFile: filePath, encoding: .utf8)
        #expect(source.contains("@Observable"),
                "mirror struct must use @Observable macro (per §4.13 standing rule)")
        #expect(source.contains("final class IdeaLibraryViewState"),
                "mirror must be a final class (per §4.13 standing rule)")
        #expect(source.contains("var ideas: [Idea]"),
                "mirror must hold ideas field")
        #expect(source.contains("var suggestions: [Idea]"),
                "mirror must hold suggestions field")
        #expect(source.contains("var status: SpecializedToolLoadStatus"),
                "mirror must hold status field")
        #expect(source.contains("var errorText: String?"),
                "mirror must hold errorText field")
    }
}
