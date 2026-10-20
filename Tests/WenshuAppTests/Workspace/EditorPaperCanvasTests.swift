// EditorPaperCanvasTests.swift · Wenshu · v0.93 ticket 001
//
// Source-level structural tests for EditorPaperCanvas (= the A4
// paper-canvas wrapper used by the editor pane to give the document
// the Pages-like "white sheet on dark background" presentation).
//
// 
// (= WorkspaceView test coverage expansion). v0.82-83 covered 3
// subcomponents; v0.87 covered 4; v0.88 covered the main WorkspaceView;
// 
// (= PaneView, EditorView, EditorPaperCanvas).
// This ticket covers the simplest = EditorPaperCanvas.
//
// EditorPaperCanvas is a generic struct that takes @ViewBuilder
// content + wraps it in a ScrollView + paper-canvas styling
// (= A4 dimensions + white background + shadow + dark colorScheme).
// ViewInspector v0.10.3 behavior tests are limited for generic
// structs + ScrollView wrappers (= v0.82 Q-lesson); = use
// source-level structural assertions per v0.82 pattern.
//
// 
// pattern as v1.33 EditorViewTests = robust to worktree
// relocations).

import Foundation
import SwiftUI
import Testing
@testable import WenshuApp

@Suite("EditorPaperCanvas (v0.93 — A4 paper-canvas wrapper)")
struct EditorPaperCanvasTests {

    /// Resolved through SourceLocator (= a Package.swift probe), so this test
    /// keeps working wherever it sits in the tree.
    private var editorPaperCanvasPath: String {
        SourceLocator.path("Sources/WenshuApp/Features/Editor/View/EditorPaperCanvas.swift")
    }

    @Test("source imports SwiftUI")
    func importsSwiftUI() throws {
        // 
        // to its own file at Sources/WenshuApp/Workspace/EditorPaperCanvas.swift.
        let source = try String(contentsOfFile: editorPaperCanvasPath, encoding: .utf8)
        #expect(source.contains("struct EditorPaperCanvas<Content: View>: View"),
                "EditorPaperCanvas must be declared inside EditorPaperCanvas.swift (= v1.34 extraction)")
    }

    @Test("struct is a generic over Content conforming to View")
    func isGenericOverContent() throws {
        let source = try String(contentsOfFile: editorPaperCanvasPath, encoding: .utf8)
        let codeLines = source.components(separatedBy: "\n").filter {
            !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//")
        }
        let codeRegion = codeLines.joined(separator: "\n")

        #expect(codeRegion.contains("struct EditorPaperCanvas<Content: View>"),
                "EditorPaperCanvas must be generic over Content: View (= supports any view body)")
        #expect(codeRegion.contains("@ViewBuilder var content: Content"),
                "EditorPaperCanvas must declare @ViewBuilder var content (= composes any view)")
    }

    @Test("body wraps content in ScrollView with horizontal + vertical axes")
    func bodyUsesScrollView() throws {
        let source = try String(contentsOfFile: editorPaperCanvasPath, encoding: .utf8)
        // EditorPaperCanvas's body must wrap content in ScrollView so the
        // sheet scrolls horizontally when the detail column is narrower
        // than A4 (= boss 2026-09-10 OOB 'Pages does the same when its
        // window is narrower than A4').
        #expect(source.contains("ScrollView([.horizontal, .vertical])"),
                "EditorPaperCanvas body must wrap content in ScrollView with horizontal + vertical axes (= per boss 2026-09-10 OOB)")
    }

    @Test("no fixed A4 paper width (= the wrapper follows the editor column)")
    func paperWidthIsNotFixed() throws {
        // The A4 sheet was dropped: a fixed 595 PT width clipped the text on a
        // narrow column. The engine's NSTextView now reads the column width and
        // scrolls horizontally itself, so the constraint must stay gone.
        let source = try String(contentsOfFile: editorPaperCanvasPath, encoding: .utf8)
        let code = source.components(separatedBy: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
        #expect(!code.contains("paperWidth"),
                "EditorPaperCanvas must not reintroduce a fixed paperWidth (= column drives the width)")
        #expect(!code.contains(".frame(width: 595)"),
                "EditorPaperCanvas must not reintroduce a 595 PT fixed frame")
    }

    @Test("no fixed paper margin (= the engine supplies the inner inset)")
    func paperMarginIsNotFixed() throws {
        let source = try String(contentsOfFile: editorPaperCanvasPath, encoding: .utf8)
        let code = source.components(separatedBy: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
        #expect(!code.contains("paperMargin"),
                "EditorPaperCanvas must not reintroduce a paperMargin (= engine textContainerInset owns the inset)")
        #expect(!code.contains(".padding(72)"),
                "EditorPaperCanvas must not reintroduce a 72 PT paper padding")
    }

    @Test("body uses Color.white background + shadow for the paper sheet")
    func bodyUsesPaperStyling() throws {
        let source = try String(contentsOfFile: editorPaperCanvasPath, encoding: .utf8)
        #expect(source.contains(".background(Color.white)"),
                "EditorPaperCanvas body must use .background(Color.white) (= paper sheet visual contract)")
        #expect(source.contains(".shadow(color: .black.opacity(0.35)"),
                "EditorPaperCanvas body must add shadow for the paper sheet (= Pages-like presentation)")
        #expect(source.contains(".environment(\\.colorScheme, .light)"),
                "EditorPaperCanvas body must force light color scheme (= white paper on dark column)")
    }

    @Test("body uses defaultScrollAnchor(.center) (= macOS 14+ centering API)")
    func bodyUsesDefaultScrollAnchor() throws {
        let source = try String(contentsOfFile: editorPaperCanvasPath, encoding: .utf8)
        // The sheet used to be left-aligned.
        // Center the paper horizontally with defaultScrollAnchor(.center)
        // (= Apple macOS 14+ API).
        #expect(source.contains(".defaultScrollAnchor(.center)"),
                "EditorPaperCanvas body must center the paper horizontally with .defaultScrollAnchor(.center) (= per boss 2026-09-10 OOB)")
    }

    @Test("body sets minHeight 842 (= A4 height)")
    func bodySetsMinHeightA4() throws {
        let source = try String(contentsOfFile: editorPaperCanvasPath, encoding: .utf8)
        #expect(source.contains(".frame(minHeight: 842)"),
                "EditorPaperCanvas body must set minHeight 842 (= A4 height in points)")
    }
}
