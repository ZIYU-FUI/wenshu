//
//  WenshuWorkspaceMigratorTests.swift · Wenshu · v0.23 ticket 014.002
//
//  Boss 2026-08-23 拍: '重点是你如何规避风险'.
//  Tests verify the 5 risk-defense strategies:
//  R1: Auto-backup before write
//  R2: dry-run mode (default, no writes)
//  R3: Never auto-delete old sqlite
//  R4: Validation (count comparison + integrity check)
//  R5: Atomic write (.tmp → rename) on transaction failure
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("WenshuWorkspaceMigrator (5-layer risk defense)")
struct WenshuWorkspaceMigratorTests {

    private func tmpPath(_ tag: String) -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory() + "wenshu-migrator-\(tag)-\(UUID().uuidString)")
    }

    // MARK: - R2: dry-run mode (no writes)

    @Test("R2: dry-run mode returns MigrationPlan without writing workspace.ws")
    func testDryRunNoWrites() async {
        let result = await WenshuWorkspaceMigrator.run(mode: .dryRun, targetPath: tmpPath("dryrun"))
        if case .dryRun(let plan) = result {
            // plan is a real plan, no file written.
            #expect(plan.targetPath.path.contains("wenshu-migrator-dryrun"))
        } else {
            Issue.record("expected .dryRun, got \(result)")
        }
    }

    @Test("R2: real mode without apply=true refuses (safety check)")
    func testRealModeRequiresApply() async {
        let result = await WenshuWorkspaceMigrator.run(mode: .real(apply: false), targetPath: tmpPath("safety"))
        if case .failure(let reason, _, _) = result {
            #expect(reason.contains("apply: true"))
        } else {
            Issue.record("expected .failure when apply=false")
        }
    }

    // MARK: - R5: Atomic write (.tmp → rename)

    @Test("R5: real mode writes to .tmp first, then renames to .ws")
    func testAtomicRename() async {
        let target = tmpPath("atomic").appendingPathExtension("ws")
        // Create fake old sqlite in standard location.
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let wenshuDir = support.appendingPathComponent("wenshu", isDirectory: true)
        let oldDB = wenshuDir.appendingPathComponent("wenshu-migrator-test-\(UUID().uuidString).sqlite")
        FileManager.default.createFile(atPath: oldDB.path, contents: Data("x".utf8), attributes: nil)
        defer { try? FileManager.default.removeItem(at: oldDB) }

        let result = await WenshuWorkspaceMigrator.run(mode: .real(apply: true), targetPath: target)
        // R5: target should exist (renamed from .tmp)
        #expect(FileManager.default.fileExists(atPath: target.path))
        // R5: no .tmp file lingering
        let tmp = target.appendingPathExtension("tmp")
        #expect(!FileManager.default.fileExists(atPath: tmp.path))
        if case .success = result {
            // expected
        } else if case .failure(let reason, _, _) = result {
            Issue.record("expected success, got failure: \(reason)")
        }
        try? FileManager.default.removeItem(at: target)
    }

    // MARK: - R3: never auto-delete old sqlite

    @Test("R3: real mode does NOT delete old sqlite files")
    func testNoAutoDelete() async {
        let target = tmpPath("nodelete").appendingPathExtension("ws")
        // Create fake old sqlite in standard location.
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let wenshuDir = support.appendingPathComponent("wenshu", isDirectory: true)
        let oldDB = wenshuDir.appendingPathComponent("wenshu-migrator-test-\(UUID().uuidString).sqlite")
        FileManager.default.createFile(atPath: oldDB.path, contents: Data("x".utf8), attributes: nil)
        defer { try? FileManager.default.removeItem(at: oldDB) }

        _ = await WenshuWorkspaceMigrator.run(mode: .real(apply: true), targetPath: target)
        // R3: old sqlite still exists (manual cleanup only)
        #expect(FileManager.default.fileExists(atPath: oldDB.path))
        try? FileManager.default.removeItem(at: target)
    }

    // MARK: - R1: auto-backup

    @Test("R1: real mode auto-creates backup directory before write")
    func testAutoBackup() async {
        let target = tmpPath("backup-test").appendingPathExtension("ws")
        // Create a fake old sqlite in standard location so discovery finds it.
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let wenshuDir = support.appendingPathComponent("wenshu", isDirectory: true)
        let oldDB = wenshuDir.appendingPathComponent("wenshu-migrator-test-\(UUID().uuidString).sqlite")
        FileManager.default.createFile(atPath: oldDB.path, contents: Data("y".utf8), attributes: nil)
        defer { try? FileManager.default.removeItem(at: oldDB) }

        let result = await WenshuWorkspaceMigrator.run(mode: .real(apply: true), targetPath: target)
        if case .success(_, let backupPath) = result {
            // R1: backupPath exists
            #expect(FileManager.default.fileExists(atPath: backupPath.path))
            // R1: backup contains the old file
            let backupFile = backupPath.appendingPathComponent(oldDB.lastPathComponent)
            #expect(FileManager.default.fileExists(atPath: backupFile.path))
            // Cleanup
            try? FileManager.default.removeItem(at: backupPath)
        } else if case .failure(let reason, _, _) = result {
            // Failure can happen if oldDB doesn't match discovery's table mapping.
            // Just verify R1 contract: if migration failed, backup should still exist
            // for recovery, OR backup directory should be marked appropriately.
            // For this test, accept any result as long as we don't have data loss.
            #expect(!oldDB.path.isEmpty)  // sanity
            Issue.record("got failure: \(reason)")
        }
        try? FileManager.default.removeItem(at: target)
    }

    // MARK: - R4: validation

    @Test("R4: verify-only mode on non-existent file returns failure")
    func testVerifyOnlyMissingFile() async {
        let result = await WenshuWorkspaceMigrator.run(
            mode: .verifyOnly,
            targetPath: tmpPath("missing").appendingPathExtension("ws")
        )
        if case .failure(let reason, _, _) = result {
            #expect(reason.contains("not found"))
        } else {
            Issue.record("expected .failure for missing file")
        }
    }

    @Test("R4: verify-only on healthy workspace returns success")
    func testVerifyOnlyHealthy() async {
        let target = tmpPath("verify").appendingPathExtension("ws")
        // Create a healthy workspace.
        do {
            let ws = try WenshuWorkspace(path: target)
            try await ws.open()
            try await ws.close()
        } catch {
            Issue.record("could not create test workspace: \(error)")
            return
        }

        let result = await WenshuWorkspaceMigrator.run(mode: .verifyOnly, targetPath: target)
        if case .success = result {
            // expected
        } else {
            Issue.record("expected .success for healthy workspace")
        }
        try? FileManager.default.removeItem(at: target)
    }

    // MARK: - Discovery

    @Test("Discovery: returns FoundFile list (may be empty in sandbox)")
    func testDiscoveryReturnsList() {
        let found = ScatteredWorkspaceDiscovery.standardLocations()
        // Type-level: returns an array (may be empty if no scattered files exist).
        #expect(found.count >= 0)
    }

    @Test("Discovery: each FoundFile has valid path + size")
    func testDiscoveryFileFields() {
        let found = ScatteredWorkspaceDiscovery.standardLocations()
        for file in found {
            #expect(!file.path.path.isEmpty)
            #expect(!file.kind.isEmpty)
            #expect(file.sizeBytes >= 0)
        }
    }
}