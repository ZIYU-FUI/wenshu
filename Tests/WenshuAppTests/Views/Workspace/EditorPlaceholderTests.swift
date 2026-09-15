// EditorPlaceholderTests.swift · Wenshu · v0.93 ticket 003
//
// Source-level structural tests for EditorPlaceholder (= the editor
// pane's wrapper that holds the tab strip + the editing surface
// + dirty-discard alert + various handlers; = ~1100 LOC body, the
// most complex of the 3 helper structs in WorkspaceView.swift).
//
// Per boss 2026-09-14 OOB '按优先级推' + 'A': extend item 10
// (= WorkspaceView test coverage expansion). v0.93 ticket 001 =
// EditorPaperCanvas (8 tests). Ticket 002 = ZoneModuleView (6 tests).
// This ticket = EditorPlaceholder (= the most complex; =
// source-level structural only; = ViewInspector behavior tests would
// require significant mock scaffolding per v0.77 spec deferral).
//
// Per v0.77 spec + Q34 5.4: ViewInspector behavior tests on
// EditorPlaceholder (= with @State + @Environment + nested Button +
// .alert + .onChange) require ~150-200 LOC of mock scaffolding that
// exceeds 1-ticket scope per Q112. Source-level structural assertions
// capture the boss-spec invariants (= the v0.34 + v0.40 + v1.0.0-m1
// features referenced in the comments).

import SwiftUI
import Testing
@testable import WenshuApp

@Suite("EditorPlaceholder (v0.93 — editor pane wrapper with tab strip + dirty alert)")
struct EditorPlaceholderTests {
    /// v1.33 (= per Q34 5.2 + Q173 ponytail + Q186): derive the
    /// EditorPlaceholder source path from THIS test file's path
    /// (= #filePath). This means the tests work regardless of
    /// where the worktree is mounted (= v1.32 hit a build failure
    /// when EditorPlaceholder was in a worktree because the old
    /// hardcoded path pointed to the main worktree).
    private static var editorPlaceholderPath: String {
        let testFileURL = URL(fileURLWithPath: #filePath)
        let testsDir = testFileURL.deletingLastPathComponent()  // Views/Workspace/
        let repoRoot = testsDir
            .deletingLastPathComponent()  // Views/
            .deletingLastPathComponent()  // WenshuAppTests/
            .deletingLastPathComponent()  // Tests/
            .deletingLastPathComponent()  // repo root
        return repoRoot
            .appendingPathComponent("Sources")
            .appendingPathComponent("WenshuApp")
            .appendingPathComponent("Views")
            .appendingPathComponent("Workspace")
            .appendingPathComponent("EditorPlaceholder.swift")
            .path
    }

    private func readEditorPlaceholderSource() throws -> String {
        return try String(contentsOfFile: Self.editorPlaceholderPath, encoding: .utf8)
    }


    @Test("struct conforms to View")
    func conformsToView() throws {
        
        let source = try readEditorPlaceholderSource()
        let startRange = source.range(of: "struct EditorPlaceholder")!
        let section = String(source[startRange.lowerBound...])
        let endOfStruct = section.range(of: "struct EditorPaperCanvas")?.lowerBound
            ?? section.endIndex
        let editorPlaceholderSection = String(section[..<endOfStruct])
        #expect(editorPlaceholderSection.contains("struct EditorPlaceholder: View"),
                "EditorPlaceholder must conform to View protocol")
    }

    @Test("reads AppState + BookStore from environment")
    func readsAppStateAndBookStore() throws {
        
        let source = try readEditorPlaceholderSource()
        let startRange = source.range(of: "struct EditorPlaceholder")!
        let section = String(source[startRange.lowerBound...])
        let endOfStruct = section.range(of: "struct EditorPaperCanvas")?.lowerBound
            ?? section.endIndex
        let editorPlaceholderSection = String(section[..<endOfStruct])
        #expect(editorPlaceholderSection.contains("@Environment(AppState.self) private var appState"),
                "EditorPlaceholder must read AppState from environment (= v0.34 B-24)")
        #expect(editorPlaceholderSection.contains("@Environment(BookStore.self) private var bookStore"),
                "EditorPlaceholder must read BookStore from environment (= v0.39 ticket 001)")
    }

    @Test("mode reads from active tab (= per-tab preview/edit state per Safari)")
    func modeReadsFromActiveTab() throws {
        
        let source = try readEditorPlaceholderSource()
        let startRange = source.range(of: "struct EditorPlaceholder")!
        let section = String(source[startRange.lowerBound...])
        let endOfStruct = section.range(of: "struct EditorPaperCanvas")?.lowerBound
            ?? section.endIndex
        let editorPlaceholderSection = String(section[..<endOfStruct])
        // Per v0.34 ticket 04: mode lives on the active tab (= each tab
        // keeps its own preview/edit state when switching tabs).
        let codeLines = editorPlaceholderSection.components(separatedBy: "\n").filter {
            !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//")
        }
        let codeRegion = codeLines.joined(separator: "\n")

        #expect(codeRegion.contains("private var mode: EditorMode {"),
                "EditorPlaceholder must declare private var mode: EditorMode computed (= v0.34 B-24)")
        #expect(codeRegion.contains("appState.openTabs.first(where: { $0.id == appState.activeTabId })?.mode ?? .preview"),
                "EditorPlaceholder mode must read from active tab (= v0.34 B-24 Safari behavior)")
    }

    @Test("declares selectedText + isApplyingParagraphAI @State vars (= P2 #19)")
    func declaresSelectionAndApplyingState() throws {
        
        let source = try readEditorPlaceholderSource()
        let startRange = source.range(of: "struct EditorPlaceholder")!
        let section = String(source[startRange.lowerBound...])
        let endOfStruct = section.range(of: "struct EditorPaperCanvas")?.lowerBound
            ?? section.endIndex
        let editorPlaceholderSection = String(section[..<endOfStruct])
        let codeLines = editorPlaceholderSection.components(separatedBy: "\n").filter {
            !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//")
        }
        let codeRegion = codeLines.joined(separator: "\n")

        // Per P2 #19 (WIRE-PARAGRAPH-002): live editor selection snapshot
        // + applyParagraphAI spinner flag.
        #expect(codeRegion.contains("@State private var selectedText: String = \"\""),
                "EditorPlaceholder must declare @State var selectedText (= P2 #19 WIRE-PARAGRAPH-002)")
        #expect(codeRegion.contains("@State private var isApplyingParagraphAI: Bool = false"),
                "EditorPlaceholder must declare @State var isApplyingParagraphAI (= P2 #19 Apple HIG actionable-control-while-busy rule)")
    }

    @Test("exposes public setSelection(_:) (= engine bridge entry point)")
    func exposesSetSelection() throws {
        
        let source = try readEditorPlaceholderSource()
        let startRange = source.range(of: "struct EditorPlaceholder")!
        let section = String(source[startRange.lowerBound...])
        let endOfStruct = section.range(of: "struct EditorPaperCanvas")?.lowerBound
            ?? section.endIndex
        let editorPlaceholderSection = String(section[..<endOfStruct])
        #expect(editorPlaceholderSection.contains("public func setSelection(_ text: String) {"),
                "EditorPlaceholder must expose public func setSelection(_ text: String) (= engine NSTextViewDelegate bridge entry point per P2 #19)")
    }

    @Test("body starts with VStack + Safari-style tab strip (= v1.0.0-m1 OOB)")
    func bodyUsesSafariStyleTabStrip() throws {
        
        let source = try readEditorPlaceholderSource()
        let startRange = source.range(of: "struct EditorPlaceholder")!
        let section = String(source[startRange.lowerBound...])
        let endOfStruct = section.range(of: "struct EditorPaperCanvas")?.lowerBound
            ?? section.endIndex
        let editorPlaceholderSection = String(section[..<endOfStruct])
        // Per v1.0.0-m1-shell boss 2026-09-10 OOB: the editor top bar =
        // Safari-style tab strip ONLY (= no formatting toolbar).
        #expect(editorPlaceholderSection.contains("VStack(spacing: 0) {"),
                "EditorPlaceholder body must wrap tab strip + content in VStack(spacing: 0)")
        #expect(editorPlaceholderSection.contains("HStack(spacing: 0) {"),
                "EditorPlaceholder body must render tab strip with HStack(spacing: 0)")
        #expect(editorPlaceholderSection.contains("ForEach(appState.openTabs)"),
                "EditorPlaceholder body must iterate over openTabs")
    }

    @Test("body shows dirty-discard confirm alert on close-with-unsaved-changes")
    func bodyShowsDirtyDiscardAlert() throws {
        
        let source = try readEditorPlaceholderSource()
        let startRange = source.range(of: "struct EditorPlaceholder")!
        let section = String(source[startRange.lowerBound...])
        let endOfStruct = section.range(of: "struct EditorPaperCanvas")?.lowerBound
            ?? section.endIndex
        let editorPlaceholderSection = String(section[..<endOfStruct])
        // Per v0.34 ticket 09: dirty-discard confirm dialog (= Apple HIG
        // 2-option confirm pattern; = destructive + cancel).
        #expect(editorPlaceholderSection.contains(".alert("),
                "EditorPlaceholder body must use SwiftUI .alert for dirty-discard confirm")
        #expect(editorPlaceholderSection.contains("workspace.editor.dirty_discard_alert_title"),
                "EditorPlaceholder must localize dirty-discard alert title via WenshuI18n (= i18n parity)")
        #expect(editorPlaceholderSection.contains("role: .destructive"),
                "EditorPlaceholder dirty-discard alert must use destructive role (= Apple HIG convention)")
        #expect(editorPlaceholderSection.contains("role: .cancel"),
                "EditorPlaceholder dirty-discard alert must use cancel role (= Apple HIG 2-option confirm pattern)")
    }

    @Test("activeTabIdString uses wenshu-editor-no-tab fallback (= v0.39 ticket 001)")
    func activeTabIdStringFallback() throws {
        
        let source = try readEditorPlaceholderSource()
        let startRange = source.range(of: "struct EditorPlaceholder")!
        let section = String(source[startRange.lowerBound...])
        let endOfStruct = section.range(of: "struct EditorPaperCanvas")?.lowerBound
            ?? section.endIndex
        let editorPlaceholderSection = String(section[..<endOfStruct])
        // Per v0.39 ticket 001: lookup the active tab's id (= the engine's
        // `documentId` for undo + replacement scoping). Falls back to
        // a deterministic placeholder id when no tab is open.
        #expect(editorPlaceholderSection.contains("private var activeTabIdString: String {"),
                "EditorPlaceholder must declare private var activeTabIdString (= v0.39 ticket 001)")
        #expect(editorPlaceholderSection.contains("?? \"wenshu-editor-no-tab\""),
                "EditorPlaceholder activeTabIdString must fall back to 'wenshu-editor-no-tab' deterministic id")
    }
}