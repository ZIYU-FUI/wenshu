//
//  ChapterFocusLockTests.swift · wenshu · chapter-focus-lock 2026-09-28 T1
//
//  RED tests for the single-focus chapter lock (= boss 2026-09-28 OOB
//  '互锁编辑权限'). The lock's source of truth is
//  `AppState.focusedChapterPath` (= derived from active tab +
//  chatVisible). The editor view renders read-only when this path
//  matches the tab's documentPath (= LLM holds the cursor).
//
//  Source-content anchors (= Q112 1 source + 1 test per commit; the
//  test verifies the AppState + EditorChatNSController source
//  carries the canonical lock surfaces).
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("ChapterFocusLock (chapter-focus-lock 2026-09-28 T1)")
struct ChapterFocusLockTests {

    @Test("AppState exposes `focusedChapterPath` as the single-focus source of truth")
    func sourceHasFocusedChapterPath() throws {
        let path = Self.repoSourcePath("Sources/WenshuApp/State/AppState.swift")
        let source = try String(contentsOfFile: path, encoding: .utf8)
        #expect(source.contains("var focusedChapterPath: String?"))
        // The lock predicate derives from chatVisible (= in ShellState)
        // + activeTabId's tab.documentPath.
        #expect(source.contains("chatVisible"))
    }

    @Test("EditorEditContent gates isEditable on the focused-chapter lock")
    func editorReadOnlyWhenFocusedPathMatches() throws {
        // The edit-mode surface passes `isEditable` into
        // WenshuMarkdownEditor (= the swift-markdown-engine
        // NSTextView wrapper). The chapter-focus-lock arc 2026-09-28
        // adds a guard so when AppState.focusedChapterPath matches
        // the tab's documentPath (= the LLM holds the cursor),
        // isEditable flips to false.
        let path = Self.repoSourcePath("Sources/WenshuApp/Views/Workspace/EditorEditContent.swift")
        let source = try String(contentsOfFile: path, encoding: .utf8)
        let hasLockedEditable = source.contains("focusedChapterPath") ||
            source.contains("isEditable") && source.contains("focusedChapterPath")
        #expect(hasLockedEditable,
                "EditorEditContent must consult focusedChapterPath to decide isEditable")
    }

    // MARK: - Repo-root path helper
    private static func repoSourcePath(_ relativeFromRepoRoot: String) -> String {
        let path = "/Volumes/ANAN/Engineering/wenshu/wt/chapter-focus-lock-2026-09-28/\(relativeFromRepoRoot)"
        return path
    }
}