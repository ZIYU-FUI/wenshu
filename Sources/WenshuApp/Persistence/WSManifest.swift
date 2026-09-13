//
//  Persistence/WSManifest.swift · Wenshu · v0.72 SwiftData migration Phase 1
//
//  Phase 1 commit 1/21: WSManifest (singleton, no relationships).
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
//    - migratedFromRawSqliteAt: Date?  (= nil until Phase 4 one-time data migration runs)
//
//  AGENTS.md §11.1: Apple-recommended database = SwiftData on macOS 14+.
//  WSManifest = first SwiftData @Model in wenshu (= validates the build pipeline before
//  we add the 20 remaining classes in subsequent commits).

import Foundation
import SwiftData

@Model
public final class WSManifest {
    @Attribute(.unique) var workspaceUUID: UUID
    var schemaVersion: Int
    var createdAt: Date
    var updatedAt: Date
    var wenshuVersion: String
    var checksum: String?
    /// v0.72 SwiftData migration: timestamp when migration from raw sqlite3 completed.
    /// nil = migration not yet run (= user on fresh install OR pre-migration existing user).
    /// Populated by the one-time data migration script in Phase 4.
    var migratedFromRawSqliteAt: Date?

    init(workspaceUUID: UUID, schemaVersion: Int, wenshuVersion: String) {
        self.workspaceUUID = workspaceUUID
        self.schemaVersion = schemaVersion
        self.wenshuVersion = wenshuVersion
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
