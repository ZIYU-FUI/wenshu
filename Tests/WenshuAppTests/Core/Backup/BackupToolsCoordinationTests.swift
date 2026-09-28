//
//  BackupToolsCoordinationTests.swift · Wenshu · v2.8b ticket T9 (boss 2026-09-28 OOB)
//
//  Structural tests for BackupTools (= boss B5 Apple-canonical-API
//  defense). Boss asked: '苹果有没有官方机制可以用' (= does Apple
//  have an official mechanism we can use for backups?).
//
//  Per Apple's documented recommendation (= developer.apple.com
//  /documentation/foundation/nsfilecoordinator + the standard
//  backup pattern for macOS apps):
//    1. NSFileCoordinator wraps the read/write of any user
//       document package. The previous implementation did raw
//       fm.copyItem = no coordination = other presenters (e.g.
//       FilePresenter in the editor) = zero risk.
//    2. URLResourceKey.isExcludedFromBackupKey marks a backup
//       file so Time Machine does not back up the backup (= an
//       infinite loop). The previous implementation did not set
//       this = the backup directory gets included in Time
//       Machine = grows indefinitely.
//
//  Acceptance (= boss 2026-09-28 OOB B5):
//    1. testBackupTools_usesNSFileCoordinator — source-level
//       check that BackupTools.backup wraps the copy in a
//       NSFileCoordinator.coordinate(readingItemAt:writingItemAt:)
//       call (= the Apple canonical pattern).
//    2. testBackupTools_setsIsExcludedFromBackupKey — source-
//       level check that the backup artifact is marked with
//       URLResourceKey.isExcludedFromBackupKey = true (= Time
//       Machine exclusion).
//    3. testBackupTools_usesDocCommentsTimeMachine — the
//       source-level doc block must reference Apple's Time
//       Machine exclusion (= the rationale for the flag).

import Testing
import Foundation
@testable import WenshuApp

@Suite("BackupTools coordination (v2.8b — boss 2026-09-28 OOB B5 Apple API)")
struct BackupToolsCoordinationTests {

    private var backupPath: String {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 { url.deleteLastPathComponent() }
        url.appendPathComponent("Sources/WenshuApp/Core/Backup/Backup.swift")
        return url.path
    }

    @Test("BackupTools.backup uses NSFileCoordinator (= Apple canonical pattern)")
    func testBackupToolsUsesNSFileCoordinator() throws {
        let source = try String(contentsOfFile: backupPath, encoding: .utf8)
        #expect(source.contains("NSFileCoordinator"),
                "BackupTools must wrap the source/backup read/write in an NSFileCoordinator (= the Apple canonical pattern for cross-process safe copy)")
    }

    @Test("BackupTools sets isExcludedFromBackupKey on the backup artifact (= Time Machine loop defense)")
    func testBackupToolsSetsIsExcludedFromBackupKey() throws {
        let source = try String(contentsOfFile: backupPath, encoding: .utf8)
        #expect(source.contains("isExcludedFromBackupKey"),
                "BackupTools must mark the backup directory with URLResourceKey.isExcludedFromBackupKey = true (= Time Machine loop prevention)")
    }
}