//
//  ChapterFocusLockTests.swift · wenshu · chapter-focus-lock 2026-09-28 T1
//
//  the single-focus chapter lock. The lock's source of truth is
//  `AppState.focusedChapterPath` (= derived from active tab +
//  chatVisible). The editor view renders read-only when this path
//  matches the tab's documentPath (= LLM holds the cursor).
//
//  Source-content anchors: the gate asserts that the lock predicate
//  is APPLIED to the editor's editability, in the file that owns the
//  decision. The host (= EditorView) computes the predicate and
//  writes it onto the editor surface; the surface carries it; the
//  engine receives the surface.
//
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("ChapterFocusLock (chapter-focus-lock 2026-09-28 T1)")
struct ChapterFocusLockTests {

    private static let appStatePath = "Sources/WenshuApp/Shared/State/AppState.swift"
    private static let editorViewPath = "Sources/WenshuApp/Features/Editor/View/EditorView.swift"
    private static let editorSurfacePath = "Sources/WenshuApp/Features/Editor/Model/EditorSurface.swift"
    private static let editorEditContentPath = "Sources/WenshuApp/Features/Editor/View/EditorEditContent.swift"

    @Test("AppState exposes `focusedChapterPath` as the single-focus source of truth")
    func sourceHasFocusedChapterPath() throws {
        let source = try SourceLocator.read(Self.appStatePath)
        #expect(source.contains("var focusedChapterPath: String?"))
        // The lock predicate derives from chatVisible (= in ShellState)
        // + activeTabId's tab.documentPath.
        #expect(source.contains("chatVisible"))
    }

    @Test("EditorView applies the chapter-focus lock to the editor surface")
    func editorAppliesChapterFocusLockToSurface() throws {
        // The predicate = the chapter is focused AND the chat is hidden
        // AND the focused path is the tab's document path. All three
        // clauses must be present, and the host must negate the whole
        // predicate onto the surface's editability.
        let editorView = try SourceLocator.read(Self.editorViewPath)
        #expect(editorView.contains("focusedChapterPath != nil"))
        #expect(editorView.contains("!workspaceUI.chatVisible"))
        #expect(editorView.contains("focusedChapterPath == currentTabDocumentPath"))
        #expect(editorView.contains("surface.isEditable = !("),
                "EditorView must negate the lock predicate onto the surface's editability")

        // The surface carries the decision (= the host writes it, the
        // engine reads it).
        let editorSurface = try SourceLocator.read(Self.editorSurfacePath)
        #expect(editorSurface.contains("var isEditable: Bool"))

        // The edit-mode surface hands the surface to the engine.
        let editorEditContent = try SourceLocator.read(Self.editorEditContentPath)
        #expect(editorEditContent.contains("surface: surface"),
                "EditorEditContent must hand the surface to the engine")
    }
}
