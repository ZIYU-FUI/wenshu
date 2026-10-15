//
//  Persistence/WSManifest.swift
//
//   : WSManifest (singleton, no relationships).
//  Per AGENTS.md §11.4 + .scratch/2026-09-13-swiftdata-migration-spec.md.
//
//  WSManifest mirrors the old `ws_manifest` table from WenshuWorkspace.swift:
//    - workspace_uuid TEXT PRIMARY KEY
//    - schema_version INTEGER NOT NULL
//    - created_at REAL NOT NULL
//    - updated_at REAL NOT NULL
//    - wenshu_version TEXT NOT NULL
//    - checksum TEXT
//
//  SwiftData additions (= migration metadata):
//    - migratedFromRawSqliteAt: Date?  (= nil until  one-time data migration runs)
//
//  AGENTS.md §11.1: Apple-recommended database = SwiftData on macOS 14+.
//  WSManifest = first SwiftData @Model in wenshu (= validates the build pipeline before
//  we add the 20 remaining classes in subsequent commits).

import Foundation
import SwiftData

@Model
public final class WSManifest {
    @Attribute(.unique) public var workspaceUUID: UUID
    public var schemaVersion: Int
    public var createdAt: Date
    public var updatedAt: Date
    public var wenshuVersion: String
    public var checksum: String?
    /// timestamp when migration from raw sqlite3 completed.
    /// nil = migration not yet run (= user on fresh install OR pre-migration existing user).
    /// Populated by the one-time data migration script in .
    public var migratedFromRawSqliteAt: Date?

    public init(workspaceUUID: UUID, schemaVersion: Int, wenshuVersion: String) {
        self.workspaceUUID = workspaceUUID
        self.schemaVersion = schemaVersion
        self.wenshuVersion = wenshuVersion
        // Shared `now` so createdAt and updatedAt are bit-identical
        // on init (= Swift Testing's CI clock is coarser than Date's
        // nanosecond precision; = the two Date() calls would
        // otherwise produce values that differ by a few ns,
        // failing the `createdAt == updatedAt` invariant).
        let now = Date()
        self.createdAt = now
        self.updatedAt = now
    }
}
