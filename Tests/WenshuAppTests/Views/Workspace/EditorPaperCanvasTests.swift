// EditorPaperCanvasTests.swift · Wenshu · v0.93 ticket 001
//
// Source-level structural tests for EditorPaperCanvas (= the A4
// paper-canvas wrapper used by the editor pane to give the document
// the Pages-like "white sheet on dark background" presentation).
//
// Per boss 2026-09-14 OOB '按优先级推' + 'A': extend item 10
// (= WorkspaceView test coverage expansion). v0.82-83 covered 3
// subcomponents; v0.87 covered 4; v0.88 covered the main WorkspaceView;
// v0.93 = the 3 helper structs in WorkspaceView.swift
// (= ZoneModuleView, EditorPlaceholder, EditorPaperCanvas).
// This ticket covers the simplest = EditorPaperCanvas.
//
// EditorPaperCanvas is a generic struct that takes @ViewBuilder
// content + wraps it in a ScrollView + paper-canvas styling
// (= A4 dimensions + white background + shadow + dark colorScheme).
// ViewInspector v0.10.3 behavior tests are limited for generic
// structs + ScrollView wrappers (= v0.82 Q-lesson); = use
// source-level structural assertions per v0.82 pattern.
//
// v1.37 ticket 001: path is derived from `#filePath` (= the same
// pattern as v1.33 EditorPlaceholderTests = robust to worktree
// relocations).

import Foundation
import SwiftUI
import Testing
@testable import WenshuApp

@Suite("EditorPaperCanvas (v0.93 — A4 paper-canvas wrapper)")
struct EditorPaperCanvasTests {

    /// Resolves the EditorPaperCanvas.swift path from this test file's
    /// `#filePath` (= `.../Tests/WenshuAppTests/Views/Workspace/EditorPaperCanvasTests.swift`)
    /// by walking up 5 levels to the project root and appending the
    /// canonical `Sources/...` path.
    private var editorPaperCanvasPath: String {
        var url = URL(fileURLWithPath: #filePath)
        url.deleteLastPathComponent()  // drop file name → .../Workspace
        url.deleteLastPathComponent()  // drop Workspace → .../Views
        url.deleteLastPathComponent()  // drop Views → .../WenshuAppTests
        url.deleteLastPathComponent()  // drop WenshuAppTests → .../Tests
        url.deleteLastPathComponent()  // drop Tests → project root
        url.appendPathComponent("Sources")
        url.appendPathComponent("WenshuApp")
        url.appendPathComponent("Views")
        url.appendPathComponent("Workspace")
        url.appendPathComponent("EditorPaperCanvas.swift")
        return url.path
    }

    @Test("source imports SwiftUI")
    func importsSwiftUI() throws {
        // v1.34 ticket 001: EditorPaperCanvas extracted from WorkspaceView.swift
        // to its own file at Sources/WenshuApp/Views/Workspace/EditorPaperCanvas.swift.
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

    @Test("paper width = 595 PT (= A4 width, per Pages standard)")
    func paperWidthIsA4() throws {
        let source = try String(contentsOfFile: editorPaperCanvasPath, encoding: .utf8)
        // Per boss 2026-09-10 OOB 'just design the paper as a single A4
        // sheet' (= Pages / Numbers use the same). The paperWidth
        // constant must be 595 PT (= A4 width in points).
        #expect(source.contains("paperWidth: CGFloat { 595 }"),
                "EditorPaperCanvas.paperWidth must be 595 PT (= A4 width; = per boss 2026-09-10 OOB)")
    }

    @Test("paper margin = 72 PT (= 1 inch Pages default)")
    func paperMarginIsOneInch() throws {
        let source = try String(contentsOfFile: editorPaperCanvasPath, encoding: .utf8)
        #expect(source.contains("paperMargin: CGFloat { 72 }"),
                "EditorPaperCanvas.paperMargin must be 72 PT (= 1 inch; = Pages default)")
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
        // Per boss 2026-09-10 OOB: the sheet used to be left-aligned.
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
