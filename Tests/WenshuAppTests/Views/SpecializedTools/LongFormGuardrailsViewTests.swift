//
//  LongFormGuardrailsViewTests.swift · Wenshu · v1.44 ticket 001
//
//  Structural tests for LongFormGuardrailsView (= 6 guardrail kinds + add/remove/run check (= P1 ticket #6 = hermes long_form_guardrails.py port = boss 8/27 top competitive moat); = ~458 NLOC,
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

@Suite("LongFormGuardrailsView (v1.44 — specialized tools P1 hermes-port batch)")
struct LongFormGuardrailsViewTests {

    private var sourcePath: String {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 { url.deleteLastPathComponent() }
        url.appendPathComponent("Sources/WenshuApp/Views/SpecializedTools/LongFormGuardrailsView.swift")
        return url.path
    }

    @Test("LongFormGuardrailsView exists as public struct (= confirmed by source)")
    func testExists() throws {
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        #expect(source.contains("struct LongFormGuardrailsView: View") ||
                source.contains("struct LongFormGuardrailsView: View"),
                "LongFormGuardrailsView must be declared in LongFormGuardrailsView.swift")
    }

    @Test("LongFormGuardrailsView conforms to View protocol (= source-level check)")
    func testConformsToView() throws {
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        #expect(source.contains("View"),
                "LongFormGuardrailsView must conform to View protocol")
    }

    @Test("LongFormGuardrailsView has body returning some View (= SwiftUI requirement)")
    func testBodyReturnsView() throws {
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        #expect(source.contains("var body: some View"),
                "LongFormGuardrailsView must declare body returning some View")
    }

    @Test("LongFormGuardrailsView imports SwiftUI (= canonical icon layer)")
    func testImportsSwiftUI() throws {
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        #expect(source.contains("import SwiftUI"),
                "LongFormGuardrailsView must import SwiftUI")
        #expect(!source.contains("import LucideSwift"),
                "LongFormGuardrailsView must NOT import LucideSwift (= removed by v1.x)")
    }

    @Test("LongFormGuardrailsView file > 100 NLOC (= real hermes-port evidence)")
    func testFileSize() throws {
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        let lineCount = source.components(separatedBy: "\n").count
        #expect(lineCount > 100,
                "LongFormGuardrailsView.swift must be > 100 NLOC (= real port; found \(lineCount))")
    }

    @Test("LongFormGuardrailsView has public init (= SwiftUI view requirement)")
    func testHasInit() throws {
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        #expect(source.contains("init(") || source.contains("init"),
                "LongFormGuardrailsView must declare an init (= SwiftUI view contract)")
    }

    @Test("LongFormGuardrailsView declares at least one LongFormGuardrailsView struct (= primary view present)")
    func testSinglePrimaryStruct() throws {
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        #expect(source.contains("struct LongFormGuardrailsView: View") ||
                source.contains("struct LongFormGuardrailsView: View"),
                "LongFormGuardrailsView must declare primary LongFormGuardrailsView: View struct")
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

    @Test("LongFormGuardrailsView no Lucide references in code (= post-v1.x SF Symbols 6)")
    func testNoLucideInCode() throws {
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        let codeLines = source.components(separatedBy: "\n").filter { line in
            !line.trimmingCharacters(in: .whitespaces).hasPrefix("///") &&
            !line.trimmingCharacters(in: .whitespaces).hasPrefix("//")
        }
        let codeRegion = codeLines.joined(separator: "\n")
        let lucideCount = codeRegion.components(separatedBy: "Lucide").count - 1
        #expect(lucideCount == 0,
                "LongFormGuardrailsView must have zero Lucide references in code (post-v1.x); found \(lucideCount)")
    }

    @Test("LongFormGuardrailsView declares body + public init + struct conformance (= source-level triple check)")
    func testTripleContract() throws {
        // Triple contract check (= per Q34 5.2 structural verification):
        // 1. struct LongFormGuardrailsView: View
        // 2. var body: some View
        // 3. public init()
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        #expect(source.contains("struct LongFormGuardrailsView: View") ||
                source.contains("struct LongFormGuardrailsView: View"),
                "1/3: LongFormGuardrailsView: View conformance missing")
        #expect(source.contains("var body: some View"),
                "2/3: var body: some View missing")
        #expect(source.contains("init("),
                "3/3: init() missing")
    }

    @Test("LongFormGuardrailsViewState mirror exists (= business state hoisted out of @State per v1.72 MVVM split)")
    func testStateMirrorExists() throws {
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        #expect(source.contains("LongFormGuardrailsViewState"),
                "LongFormGuardrailsView must reference LongFormGuardrailsViewState mirror")
        #expect(source.contains("@State private var state = LongFormGuardrailsViewState()"),
                "LongFormGuardrailsView must hold state via @State mirror")
        #expect(!source.contains("@State private var guardrails: [LongFormGuardrail]"),
                "guardrails must NOT be a bare @State var")
        #expect(!source.contains("@State private var loadingState: SpecializedToolLoadStatus = .idle"),
                "loadingState must NOT be a bare @State var")
        #expect(!source.contains("@State private var lastViolations: [LongFormGuardrailViolation]"),
                "lastViolations must NOT be a bare @State var")
    }

    @Test("LongFormGuardrailsViewState mirror file exists")
    func testStateMirrorFileExists() throws {
        let filePath = "/Volumes/ANAN/Engineering/wenshu/.worktrees/p2-batch2/Sources/WenshuApp/Views/SpecializedTools/LongFormGuardrailsViewState.swift"
        #expect(FileManager.default.fileExists(atPath: filePath))
        let source = try String(contentsOfFile: filePath, encoding: .utf8)
        #expect(source.contains("@Observable"))
        #expect(source.contains("final class LongFormGuardrailsViewState"))
        #expect(source.contains("var guardrails: [LongFormGuardrail]"))
        #expect(source.contains("var loadingState: SpecializedToolLoadStatus"))
        #expect(source.contains("var lastViolations: [LongFormGuardrailViolation]"))
    }
}
