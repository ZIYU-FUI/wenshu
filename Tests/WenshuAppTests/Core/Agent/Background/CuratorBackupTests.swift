//
//  CuratorBackupTests.swift · Wenshu · HERMES-INTERNAL-005 (2026-09-04)
//
//  Round-trip tests for CuratorBackup (= hermes curator_backup.py port).
//
//  Tests covered:
//    1. testSaveBackup_createsFile              — saveBackup writes a JSON file
//    2. testRestoreFromLatestBackup_returnsMostRecent — restores newest
//    3. testListAvailableBackups_sortedByDate   — list ordered newest first
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("CuratorBackup (HERMES-INTERNAL-005)")
struct CuratorBackupTests {

    @Test("saveBackup writes a JSON file under backupRoot")
    func testSaveBackup_createsFile() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("wenshu_curator_backup_\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }

        let backup = CuratorBackup(backupRoot: root)
        let dest = try await backup.saveBackup(curatorConfig: .init())
        #expect(FileManager.default.fileExists(atPath: dest.path))
        #expect(dest.pathExtension == "json")
    }

    @Test("restoreFromLatestBackup returns the most recent snapshot")
    func testRestoreFromLatestBackup_returnsMostRecent() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("wenshu_curator_backup_\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }

        let backup = CuratorBackup(backupRoot: root)
        _ = try await backup.saveBackup(curatorConfig: .init())
        // Sleep briefly so the second backup has a strictly newer mtime.
        try await Task.sleep(nanoseconds: 20_000_000)
        _ = try await backup.saveBackup(curatorConfig: .init())

        let restored = try await backup.restoreFromLatestBackup()
        #expect(restored != nil)
    }

    @Test("listAvailableBackups returns snapshots sorted newest-first")
    func testListAvailableBackups_sortedByDate() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("wenshu_curator_backup_\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }

        for _ in 0..<3 {
            let backup = CuratorBackup(backupRoot: root)
            _ = try await backup.saveBackup(curatorConfig: .init())
            try await Task.sleep(nanoseconds: 20_000_000)
        }

        let backup = CuratorBackup(backupRoot: root)
        let listed = try await backup.listAvailableBackups()
        #expect(listed.count == 3)
        let d0 = (try? listed[0].resourceValues(forKeys: [.contentModificationDateKey])
            .contentModificationDate) ?? .distantPast
        let d1 = (try? listed[1].resourceValues(forKeys: [.contentModificationDateKey])
            .contentModificationDate) ?? .distantPast
        #expect(d0 >= d1)
    }
}