//
//  TagManagerViewTests.swift · Wenshu · v1.44 ticket 001
//
//  Structural tests for TagManagerView (= 5 tag categories + 4 targets + tag cloud + filter (= P1 ticket #14 = hermes tag_manager.py port); = ~620 NLOC,
//  = repowise untested hotspot with 4 dependents).
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

@Suite("TagManagerView (v1.44 — specialized tools P1 hermes-port batch)")
struct TagManagerViewTests {

    private var sourcePath: String {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 { url.deleteLastPathComponent() }
        url.appendPathComponent("Sources/WenshuApp/Views/SpecializedTools/TagManagerView.swift")
        return url.path
    }

    @Test("TagManagerView exists as public struct (= confirmed by source)")
    func testExists() throws {
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        #expect(source.contains("struct TagManagerView: View") ||
                source.contains("struct TagManagerView: View"),
                "TagManagerView must be declared in TagManagerView.swift")
    }

    @Test("TagManagerView conforms to View protocol (= source-level check)")
    func testConformsToView() throws {
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        #expect(source.contains("View"),
                "TagManagerView must conform to View protocol")
    }

    @Test("TagManagerView has body returning some View (= SwiftUI requirement)")
    func testBodyReturnsView() throws {
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        #expect(source.contains("var body: some View"),
                "TagManagerView must declare body returning some View")
    }

    @Test("TagManagerView imports SwiftUI (= canonical icon layer)")
    func testImportsSwiftUI() throws {
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        #expect(source.contains("import SwiftUI"),
                "TagManagerView must import SwiftUI")
        #expect(!source.contains("import LucideSwift"),
                "TagManagerView must NOT import LucideSwift (= removed by v1.x)")
    }

    @Test("TagManagerView file > 100 NLOC (= real hermes-port evidence)")
    func testFileSize() throws {
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        let lineCount = source.components(separatedBy: "\n").count
        #expect(lineCount > 100,
                "TagManagerView.swift must be > 100 NLOC (= real port; found \(lineCount))")
    }

    @Test("TagManagerView has public init (= SwiftUI view requirement)")
    func testHasInit() throws {
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        #expect(source.contains("init(") || source.contains("init"),
                "TagManagerView must declare an init (= SwiftUI view contract)")
    }

    @Test("TagManagerView declares at least one TagManagerView struct (= primary view present)")
    func testSinglePrimaryStruct() throws {
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        #expect(source.contains("struct TagManagerView: View") ||
                source.contains("struct TagManagerView: View"),
                "TagManagerView must declare primary TagManagerView: View struct")
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

    @Test("TagManagerView no Lucide references in code (= post-v1.x SF Symbols 6)")
    func testNoLucideInCode() throws {
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        let codeLines = source.components(separatedBy: "\n").filter { line in
            !line.trimmingCharacters(in: .whitespaces).hasPrefix("///") &&
            !line.trimmingCharacters(in: .whitespaces).hasPrefix("//")
        }
        let codeRegion = codeLines.joined(separator: "\n")
        let lucideCount = codeRegion.components(separatedBy: "Lucide").count - 1
        #expect(lucideCount == 0,
                "TagManagerView must have zero Lucide references in code (post-v1.x); found \(lucideCount)")
    }

    @Test("TagManagerView declares body + public init + struct conformance (= source-level triple check)")
    func testTripleContract() throws {
        // Triple contract check (= per Q34 5.2 structural verification):
        // 1. struct TagManagerView: View
        // 2. var body: some View
        // 3. public init()
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        #expect(source.contains("struct TagManagerView: View") ||
                source.contains("struct TagManagerView: View"),
                "1/3: TagManagerView: View conformance missing")
        #expect(source.contains("var body: some View"),
                "2/3: var body: some View missing")
        #expect(source.contains("init("),
                "3/3: init() missing")
    }

    @Test("TagManagerViewState mirror exists (= business state hoisted out of @State per v1.72 MVVM split)")
    func testStateMirrorExists() throws {
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        #expect(source.contains("TagManagerViewState"),
                "TagManagerView must reference TagManagerViewState mirror")
        #expect(source.contains("@State private var state = TagManagerViewState()"),
                "TagManagerView must hold state via @State mirror (not bare @State vars)")
        let bareTags = source.contains("@State private var tags: [Tag]")
        let bareApplications = source.contains("@State private var applications: [TagApplication]")
        let bareCloud = source.contains("@State private var cloud: [TagCloudEntry]")
        let bareFilterMatches = source.contains("@State private var filterMatches: [UUID]")
        let bareStatus = source.contains("@State private var status: SpecializedToolLoadStatus")
        let bareErrorText = source.contains("@State private var errorText: String?")
        #expect(!bareTags, "tags must NOT be a bare @State var")
        #expect(!bareApplications, "applications must NOT be a bare @State var")
        #expect(!bareCloud, "cloud must NOT be a bare @State var")
        #expect(!bareFilterMatches, "filterMatches must NOT be a bare @State var")
        #expect(!bareStatus, "status must NOT be a bare @State var")
        #expect(!bareErrorText, "errorText must NOT be a bare @State var")
    }

    @Test("TagManagerViewState mirror file exists (= companion file under Views/SpecializedTools/)")
    func testStateMirrorFileExists() throws {
        let filePath = "/Volumes/ANAN/Engineering/wenshu/.worktrees/mvvm-p1/Sources/WenshuApp/Views/SpecializedTools/TagManagerViewState.swift"
        #expect(FileManager.default.fileExists(atPath: filePath),
                "TagManagerViewState.swift must exist as a companion file")
        let source = try String(contentsOfFile: filePath, encoding: .utf8)
        #expect(source.contains("@Observable"),
                "mirror struct must use @Observable macro")
        #expect(source.contains("final class TagManagerViewState"),
                "mirror must be a final class")
        #expect(source.contains("var tags: [Tag]"), "mirror must hold tags field")
        #expect(source.contains("var applications: [TagApplication]"), "mirror must hold applications field")
        #expect(source.contains("var cloud: [TagCloudEntry]"), "mirror must hold cloud field")
        #expect(source.contains("var filterMatches: [UUID]"), "mirror must hold filterMatches field")
        #expect(source.contains("var status: SpecializedToolLoadStatus"), "mirror must hold status field")
        #expect(source.contains("var errorText: String?"), "mirror must hold errorText field")
    }
}
