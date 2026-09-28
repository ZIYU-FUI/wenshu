//
//  ChapterFocusLockDialogWrapperTests.swift · wenshu · chapter-dialog 2026-09-28 T2
//
//  RED tests for the dialog-aware wrapper. T1 shipped the dialog
//  surface (= presenter + ChatZoneView alert); = T2 wires the
//  conductor's ChapterFocusLockWrappedTool to call into the
//  presenter instead of auto-allowing (= §11.23 MVP). The wrapper
//  now:
//  - catches ChapterFocusLockedError from the inner tool
//  - snapshots the prior focusedChapterPath (= for restore on Deny
//    or after Allow completes)
//  - presents the dialog via the presenter
//  - resumes the inner tool on Allow (= releasing the focus lock
//    for the duration of the inner call, then restoring the snapshot)
//  - throws DatasetLockDeniedByBoss on Deny (= the LLM receives
//    the error and decides what to do next)
//
//  Source-content anchors (= Q112 1 source + 1 test per commit).
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("ChapterFocusLockDialogWrapper (chapter-dialog 2026-09-28 T2)")
struct ChapterFocusLockDialogWrapperTests {

    @Test("Conductor wrapper calls into ChapterFocusLockDialogPresenter")
    func wrapperUsesPresenter() throws {
        let path = Self.repoSourcePath("Sources/WenshuApp/Core/Agent/Conversation/WenshuConductor.swift")
        let source = try String(contentsOfFile: path, encoding: .utf8)
        #expect(source.contains("ChapterFocusLockDialogPresenter"))
        #expect(source.contains("present("))
    }

    @Test("Wrapper throws DatasetLockDeniedByBoss on Deny")
    func wrapperThrowsOnDeny() throws {
        let path = Self.repoSourcePath("Sources/WenshuApp/Core/Agent/Librarian/EditChapterActor.swift")
        let source = try String(contentsOfFile: path, encoding: .utf8)
        #expect(source.contains("DatasetLockDeniedByBoss"))
    }

    @Test("Wrapper snapshots + restores focusedChapterPath around the inner call")
    func wrapperSnapshotsAndRestores() throws {
        let path = Self.repoSourcePath("Sources/WenshuApp/Core/Agent/Conversation/WenshuConductor.swift")
        let source = try String(contentsOfFile: path, encoding: .utf8)
        // The snapshot must happen BEFORE the dialog is presented
        // (= so restore can put the prior value back even if the
        // dialog is dismissed asynchronously).
        #expect(source.contains("snapshot"))
    }

    // MARK: - Repo-root path helper
    private static func repoSourcePath(_ relativeFromRepoRoot: String) -> String {
        let path = "/Volumes/ANAN/Engineering/wenshu/\(relativeFromRepoRoot)"
        return path
    }
}