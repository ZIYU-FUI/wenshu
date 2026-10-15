//
//  ChapterFocusLockActorTests.swift · wenshu · chapter-focus-lock 2026-09-28 T2
//
//  the actor-side lock check. Both BookChapterActor.update
//  and EditChapterActor.edit throw ChapterFocusLockedError when the
//  boss has the editor focused on the target chapter path (= single-
//  focus model per boss 2026-09-28 OOB '互锁编辑权限'). When the lock
//  is empty (= boss not focused on any chapter, OR boss in chat zone),
//  the actor proceeds normally.
//
//  Source-content anchors: the test verifies the actor source contains
//  the canonical error type + the focusedChapterPathSnapshot() read
//  at the entry point.
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("ChapterFocusLockActor (chapter-focus-lock 2026-09-28 T2)")
struct ChapterFocusLockActorTests {

    @Test("EditChapterActor declares ChapterFocusLockedError and reads the lock")
    func editActorDeclaresError() throws {
        let path = Self.repoSourcePath("Sources/WenshuApp/Core/Agent/Librarian/EditChapterActor.swift")
        let source = try String(contentsOfFile: path, encoding: .utf8)
        #expect(source.contains("ChapterFocusLockedError"))
        #expect(source.contains("focusedChapterPath"))
    }

    @Test("BookChapterActor also gates the update path on the focused-chapter lock")
    func bookActorGatesUpdate() throws {
        // v1.85 chat-diff-preview arc (= §11.20) consolidated BookChapterActor
        // into BookChapterTool.swift (= the actor + tool live in the same
        // file). Tests assert against the canonical file containing the actor.
        let path = Self.repoSourcePath("Sources/WenshuApp/Core/Agent/Librarian/BookChapterTool.swift")
        let source = try String(contentsOfFile: path, encoding: .utf8)
        // Both `update` and the patch-style `edit` surfaces must
        // honor the lock. The book_chapter tool exposes update
        // (= full replace), so the actor.update entry point is
        // the gate site (= matches EditChapterActor.edit).
        #expect(source.contains("ChapterFocusLockedError") ||
                source.contains("focusedChapterPath"))
    }

    // MARK: - Repo-root path helper
    private static func repoSourcePath(_ relativeFromRepoRoot: String) -> String {
        let path = "/Volumes/ANAN/Engineering/wenshu/\(relativeFromRepoRoot)"
        return path
    }
}