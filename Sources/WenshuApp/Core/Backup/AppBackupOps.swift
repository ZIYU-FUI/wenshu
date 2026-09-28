//
//  AppBackupOps.swift · Wenshu · v2.9c ticket T33 (boss 2026-09-28 OOB B5 follow-up)
//
//  @MainActor enum that wraps the canonical `BackupTools`
//  struct (= per AGENTS.md §11 baseline; = the view never
//  calls BackupTools directly; = all backup surfaces go
//  through AppBackupOps).
//
//  Per the v2.8c BackgroundReviewOps + v2.9a LLMWikiOps
//  template:
//   - @MainActor enum (= single-source-of-truth per surface)
//   - public-ish (internal) Result types
//   - static func entry points (= each blocks on the actor
//     bridge with `await Task.detached` for the file
//     coordination that BackupTools needs)
//
//  v2.9c adds:
//   - AppBackupOps.list() — wraps BackupTools.list
//   - AppBackupOps.restore(backupName:to:) — wraps
//     BackupTools.restore (= the restore UI surface)
//   - AppBackupOps.backup(sourceDir:) — wraps
//     BackupTools.backup (= a one-click full-backup
//     surface; = currently no UI caller, = exposed for the
//     future restore-pane or scheduled-backup ticket).

import Foundation

/// v2.9c (boss 2026-09-28 OOB B5 follow-up): the @MainActor
/// backup surface (= the canonical bridge between SwiftUI views
/// and the synchronous `BackupTools` struct).
@MainActor
enum AppBackupOps {

    // MARK: - Result types

    /// One backup record (= a thin wrapper around
    /// `BackupMetadata` so the view never imports
    /// Backup.swift directly).
    struct BackupRecord: Identifiable, Equatable {
        let id: String
        let sourcePath: String
        let archivePath: String
        let size: Int64
        let createdAt: Date
    }

    // MARK: - List

    /// List every available backup in the default backup
    /// directory (= the canonical wenshu backup shape; = the
    /// timestamps in the directory names give the sort order).
    static func list(backupDir: String? = nil) throws -> [BackupRecord] {
        let rows = try BackupTools().list()
        return rows.map { meta in
            BackupRecord(
                id: meta.id,
                sourcePath: meta.sourcePath,
                archivePath: meta.archivePath,
                size: meta.size,
                createdAt: meta.createdAt
            )
        }
    }

    // MARK: - Restore

    /// Restore the backup named `backupName` (= the directory
    /// under the default backup root) into `destDir`.
    ///
    /// This is the restore UI surface (= the user clicks
    /// Restore in the toolbar; = we pick the latest from
    /// `list()` and call this).
    static func restore(
        backupName: String,
        to destDir: String,
        backupDir: String? = nil
    ) throws {
        try BackupTools().restore(backupName: backupName, to: destDir, backupDir: backupDir)
    }

    // MARK: - Backup

    /// Run a fresh backup (= the canonical `BackupTools.backup`
    /// entry point; = exposed for future scheduled-backup or
    /// restore-pane surfaces).
    static func backup(
        sourceDir: String,
        backupDir: String? = nil
    ) throws -> BackupRecord {
        let meta = try BackupTools().backup(sourceDir: sourceDir, backupDir: backupDir)
        return BackupRecord(
            id: meta.id,
            sourcePath: meta.sourcePath,
            archivePath: meta.archivePath,
            size: meta.size,
            createdAt: meta.createdAt
        )
    }
}