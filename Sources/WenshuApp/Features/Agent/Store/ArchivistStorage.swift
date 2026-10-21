//
//  ArchivistStorage.swift
//
//  Storage adapter for the Archivist sub-agent.
//
//  Background:
//  Archivist's domain (= filesystem backup) does NOT have an
//  LLM-facing tool in `ToolRegistry.shared` (= the backup tool was
//  never ported). The Archivist sub-agent writes to the per-book
//  archive dir on the filesystem directly (same pattern as
//  `DelegateResearchTool.addKanbanTask`).
//
//  This protocol isolates the storage calls so the runner can be
//  tested without a real filesystem (the test passes an in-memory
//  ArchivistStorage stub).
//
//  Threading: all methods are `@MainActor`. Callers (= SubAgentRunner)
//  hop to MainActor before invoking.
//

import Foundation
import WenshuData
import os.log

private let wenshuLogger = Logger(subsystem: "com.wenshu", category: "archiviststorage")

@MainActor
protocol ArchivistStorage: Sendable {
    /// Write a backup snapshot (= blob) to the per-book archive dir.
    /// Used by Archivist's "backup" sub-task (= copies current
    /// chapter content + meta to a dated snapshot file).
    func writeBackup(label: String, contents: String) async throws -> URL
}

/// Production default implementation. Writes backups to the per-book
/// archive dir on the filesystem.
@MainActor
final class LiveArchivistStorage: ArchivistStorage {
    private let archiveRoot: URL

    init(archiveRoot: URL) {
        self.archiveRoot = archiveRoot
    }

    func writeBackup(label: String, contents: String) async throws -> URL {
        try FileManager.default.createDirectory(
            at: archiveRoot,
            withIntermediateDirectories: true
        )
        let stamp = Date().formatted(.iso8601)
            .replacingOccurrences(of: ":", with: "-")
        let safeLabel = label
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined(separator: "-")
            .prefix(64)
        let fileURL = archiveRoot.appendingPathComponent("\(safeLabel)-\(stamp).md")
        try contents.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }
}