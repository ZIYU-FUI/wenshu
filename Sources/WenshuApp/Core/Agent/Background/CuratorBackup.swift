//
//  CuratorBackup.swift · Wenshu · HERMES-INTERNAL-005 (2026-09-04)
//
//  1:1 port of hermes curator_backup.py (= hermes-internal module #5,
//  boss 2026-09-04 OOB 'A'). Thin adapter over wenshu's Curator.swift
//  (= the canonical curator that produces CurationReport snapshots).
//
//  Wenshu-side wins preserved: Curator.swift remains canonical. This
//  module provides save / restore / list helpers for the curator's
//  output snapshots (= the hermes snapshot/rollback pattern, simplified
//  for wenshu's pure-data Curator surface).
//

import Foundation

public actor CuratorBackup {

    private let backupRoot: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(backupRoot: URL, fileManager: FileManager = .default) {
        self.backupRoot = backupRoot
        self.fileManager = fileManager
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    /// Persist a curator snapshot. The `curatorConfig` parameter captures
    /// the curator's configuration (= hermes saveBackup captures the
    /// curator's last-run-at pointer + bundled-manifest marker, etc).
    /// Returns the destination URL.
    public func saveBackup(curatorConfig: Curator.Config) async throws -> URL {
        try ensureBackupRootExists()
        let id = Self.makeSnapshotID()
        let dest = backupRoot.appendingPathComponent("\(id).json")
        let report = Curator.curate(entities: [])
        let snapshot = CuratorBackupSnapshot(
            id: id,
            createdAt: Date(),
            config: curatorConfig,
            report: report
        )
        let data = try encoder.encode(snapshot)
        try data.write(to: dest, options: [.atomic])
        return dest
    }

    /// Restore the most recent backup (= the hermes restore_from_latest_backup
    /// pattern). Returns the snapshot if one exists; otherwise nil.
    public func restoreFromLatestBackup() async throws -> CuratorBackupSnapshot? {
        let backups = try await listAvailableBackups()
        guard let latest = backups.first else { return nil }
        let data = try Data(contentsOf: latest)
        return try decoder.decode(CuratorBackupSnapshot.self, from: data)
    }

    /// List all available backups, newest first.
    public func listAvailableBackups() async throws -> [URL] {
        guard fileManager.fileExists(atPath: backupRoot.path) else { return [] }
        let entries = try fileManager.contentsOfDirectory(
            at: backupRoot,
            includingPropertiesForKeys: [.contentModificationDateKey]
        )
        let jsonFiles = entries.filter { $0.pathExtension == "json" }
        // Sort by file modification date, newest first.
        let sorted = jsonFiles.sorted { lhs, rhs in
            let lhsDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey])
                .contentModificationDate) ?? .distantPast
            let rhsDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey])
                .contentModificationDate) ?? .distantPast
            return lhsDate > rhsDate
        }
        return sorted
    }

    // MARK: - Internals

    private func ensureBackupRootExists() throws {
        if !fileManager.fileExists(atPath: backupRoot.path) {
            try fileManager.createDirectory(at: backupRoot, withIntermediateDirectories: true)
        }
    }

    private static func makeSnapshotID() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let short = UUID().uuidString.prefix(8)
        return formatter.string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
            + "-\(short)"
    }
}

// MARK: - Snapshot

public struct CuratorBackupSnapshot: Sendable, Equatable, Codable {
    public let id: String
    public let createdAt: Date
    public let config: Curator.Config
    public let report: CurationReport

    public init(
        id: String,
        createdAt: Date,
        config: Curator.Config,
        report: CurationReport
    ) {
        self.id = id
        self.createdAt = createdAt
        self.config = config
        self.report = report
    }
}