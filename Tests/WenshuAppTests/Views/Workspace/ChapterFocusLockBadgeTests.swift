//
//  ChapterFocusLockBadgeTests.swift · wenshu · chapter-dialog 2026-09-28 T3
//
//  RED tests for the visual badge. When the LLM has the chapter
//  cursor (= AppState.focusedChapterPath was overridden by the
//  wrapper's Allow path), the editor view renders a small badge
//  near the tab title (= "LLM 改中...") so the boss sees why
//  the editor went read-only.
//
//  Apple HIG canonical UX: a small inline label = the standard
//  "editing" affordance (= same shape as Pages / Numbers'
//  'Saving...' badge next to the document title).
//
//  Source-content anchors (= Q112 1 source + 1 test per commit).
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("ChapterFocusLockBadge (chapter-dialog 2026-09-28 T3)")
struct ChapterFocusLockBadgeTests {

    @Test("Editor placeholder surfaces the badge when the LLM holds the cursor")
    func editorSurfacesBadge() throws {
        let path = Self.repoSourcePath("Sources/WenshuApp/Views/Workspace/EditorPlaceholder.swift")
        let source = try String(contentsOfFile: path, encoding: .utf8)
        // The badge sits next to the title when the LLM has the
        // cursor (= focusedChapterPath == tab.documentPath AND
        // shellState.chatVisible = false). We accept either an
        // explicit `ChapterFocusLockBadge` view or an inline badge
        // rendered via Image(systemName:) + Text.
        let hasBadgeView = source.contains("ChapterFocusLockBadge") ||
            (source.contains("Image(systemName:") && source.contains("WenshuI18n.t(\"chatview.focus_lock.badge\")"))
        #expect(hasBadgeView,
                "EditorPlaceholder must render the LLM-editing badge when the LLM holds the cursor")
    }

    // MARK: - Repo-root path helper
    private static func repoSourcePath(_ relativeFromRepoRoot: String) -> String {
        let path = "/Volumes/ANAN/Engineering/wenshu/wt/chapter-dialog-2026-09-28/\(relativeFromRepoRoot)"
        return path
    }
}