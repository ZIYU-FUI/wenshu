// PreviewTabBackgroundTests.swift · Wenshu · v0.87 ticket 001
//
// ViewInspector structural tests for PreviewTabBackground
// (= the empty Color.clear placeholder for the preview pane tab
// background; = 5 LOC of real code; = pure stateless).
//
// Per boss 2026-09-14 OOB '按优先级推' + 'A': extend item 10
// (= WorkspaceView test coverage expansion). v0.82-83 covered
// 3 subcomponents; v0.87 continues with 4 more (= PreviewTabBackground
// + EditorEditContent + EditorExpandShrinkTrailingButton + PresetCard).
//
// Test pattern (= per v0.82 Q-lesson: ViewInspector v0.10.3 cannot
// deep-inspect opaque _ShapeView containers or propagate @State-owned
// @Binding writeback in tap()): use STRUCTURAL assertions only
// (= view body returns some View, source contains Color.clear, etc.).
// Behavior assertions on tap()/find(text:) skipped (= same limitation
// documented in .scratch/v0.77-workspaceview-tests/spec.md).

import SwiftUI
import Testing
import ViewInspector
@testable import WenshuApp

@Suite("PreviewTabBackground (v0.87 — pure-stateless Color.clear placeholder)")
struct PreviewTabBackgroundTests {

    @Test("body returns some View (no crash)")
    func bodyReturnsSomeView() throws {
        // Verify the view can be constructed and its body evaluated
        // without crashing (= structural sanity).
        let view = PreviewTabBackground()
        let body = view.body
        // body must exist (it's `some View`); = no further assertion
        // because `some View` is opaque
        _ = body
    }

    @Test("source declares no params / @State / @Binding / @Environment")
    func sourceHasNoState() throws {
        // Read the source file and verify the structural claims
        // (= per the header comment: "No params, no @State, no
        // @Binding, no @Environment").
        let sourcePath = "/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Views/Workspace/PreviewTabBackground.swift"
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)

        // Strip line comments to avoid false positives (= the header
        // comment explicitly mentions "@State", "@Binding", "@Environment"
        // as strings when describing what is NOT in the file).
        let codeRegion = source
            .components(separatedBy: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")

        #expect(!codeRegion.contains("@State"),
                "code region must not declare @State (= pure stateless)")
        #expect(!codeRegion.contains("@Binding"),
                "code region must not declare @Binding (= pure stateless)")
        #expect(!codeRegion.contains("@Environment"),
                "code region must not declare @Environment (= pure stateless)")
        #expect(!codeRegion.contains("let body"),
                "body must use `var body` (= per SwiftUI convention)")
        #expect(!codeRegion.contains("@MainActor"),
                "View structs do not need @MainActor (= SwiftUI manages it)")
    }

    @Test("body declares Color.clear (= the documented placeholder)")
    func bodyDeclaresColorClear() throws {
        let sourcePath = "/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Views/Workspace/PreviewTabBackground.swift"
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        #expect(source.contains("Color.clear"),
                "body must declare Color.clear (= per the slice 9b spec)")
    }

    @Test("source file imports SwiftUI (= required for View protocol)")
    func importsSwiftUI() throws {
        let sourcePath = "/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Views/Workspace/PreviewTabBackground.swift"
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        #expect(source.contains("import SwiftUI"),
                "must import SwiftUI to conform to View protocol")
    }

    @Test("struct name matches PreviewTabBackground (= no rename drift)")
    func structNameMatches() throws {
        let sourcePath = "/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Views/Workspace/PreviewTabBackground.swift"
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        #expect(source.contains("struct PreviewTabBackground"),
                "struct name must remain PreviewTabBackground (= per spec)")
    }

    @Test("conforms to View protocol")
    func conformsToView() throws {
        let sourcePath = "/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Views/Workspace/PreviewTabBackground.swift"
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        // Pattern: `struct PreviewTabBackground: View {`
        #expect(source.contains("PreviewTabBackground: View"),
                "struct must conform to View (= structural pattern)")
    }
}