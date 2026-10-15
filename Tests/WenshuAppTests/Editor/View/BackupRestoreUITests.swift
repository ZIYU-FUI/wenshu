//
//  BackupRestoreUITests.swift · Wenshu · v2.9c ticket T33 (boss 2026-09-28 OOB B5 follow-up)
//
//  Structural tests for the v2.9c Backup restore UI surface
//  (= boss 2026-09-28 OOB inventory follow-up B5 = 'Backup 缺
//  机制' / '我们有备份, 没 restore UI'; = the v2.8b arc shipped
//  BackupTools.backup / .list / .restore but no UI; = the
//  .ws bundle sits in the user's filesystem with no
//  recovery affordance).
//
//  Per boss 2026-09-28 OOB: '苹果有没有官方机制可以用';
//  = NSFileCoordinator + URLResourceKey.isExcludedFromBackupKey
//  is the canonical wenshu backup shape (= used by
//  BackupTools; = v2.9c adds the UI restore surface without
//  changing the on-disk format).
//
//  v2.9c adds:
//   1. ShellDetailColumn.toolbar: a Restore-from-backup
//      button (= i18n key backup.operator.open) that calls
//      AppBackupOps.list + .restore.
//   2. AppBackupOps enum (= @MainActor enum wrapping the
//      canonical BackupTools; = SSOT per surface).
//
//  Three source-level tests pin the canonical shape:
//
//    1. testAppBackupOpsExists — AppBackupOps.swift exists
//       (= the canonical @MainActor bridge).
//
//    2. testAppBackupOpsCallsBackupToolsRestore —
//       AppBackupOps.restore delegates to BackupTools.restore
//       (= SSOT on BackupTools; = no view plumbing around
//       raw file I/O).
//
//    3. testShellDetailColumnRestoreButton —
//       ShellDetailColumn.toolbar has the restore button
//       (= i18n key backup.operator.open) + AppBackupOps
//       call (= the user-facing surface).
//
//  Per Q34 5.2 + Q173 ponytail + Q186 + Q57 + Q112:
//  source-level tests following the v2.8b
//  BackupToolsCoordinationTests + v2.9a
//  LLMWikiOperatorButtonTests pattern.

import Testing
import Foundation
@testable import WenshuApp

@Suite("Backup restore UI surface (v2.9c — boss 2026-09-28 OOB B5 follow-up)")
struct BackupRestoreUITests {

    private func resolve(_ relative: String) -> String {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 { url.deleteLastPathComponent() }
        url.appendPathComponent(relative)
        return url.path
    }

    @Test("AppBackupOps.swift exists (= the canonical @MainActor bridge)")
    func testAppBackupOpsExists() throws {
        let path = resolve("Sources/WenshuApp/Core/Backup/AppBackupOps.swift")
        let exists = FileManager.default.fileExists(atPath: path)
        #expect(exists,
                "AppBackupOps.swift must exist at Sources/WenshuApp/Core/Backup/AppBackupOps.swift (= boss B5 follow-up = '我们有备份, 没 restore UI')")
    }

    @Test("AppBackupOps.restore delegates to BackupTools.restore")
    func testAppBackupOpsCallsBackupToolsRestore() throws {
        let source = try String(contentsOfFile: resolve("Sources/WenshuApp/Core/Backup/AppBackupOps.swift"), encoding: .utf8)
        #expect(source.contains("BackupTools().restore"),
                "AppBackupOps.restore must delegate to BackupTools.restore (= SSOT on BackupTools)")
    }

    @Test("InspectorView.toolbar has the Restore-from-backup button (= i18n key backup.operator.open)")
    func testInspectorViewRestoreButton() throws {
        let source = try String(contentsOfFile: resolve("Sources/WenshuApp/Views/Inspector/InspectorView.swift"), encoding: .utf8)
        let hasButton = source.contains("backup.operator.open")
        let hasHelp = source.contains("backup.operator.help")
        let hasRestoreCall = source.contains("AppBackupOps.restore(backupName:")
        #expect(hasButton && hasHelp && hasRestoreCall,
                "InspectorView.toolbar must include the Restore-from-backup button (= boss B5 follow-up = '没 restore UI'; = the restore button moved to InspectorView in Phase 6 commit 6e when ShellDetailColumn was renamed)")
    }
}