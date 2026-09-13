//
//  Persistence/WSMigrationRunner.swift · Wenshu · v0.72 SwiftData migration Phase 4
//
//  Migration commit 38 of 42: WSMigrationRunner scaffolding (= WSMigrationPerStore.swift
//  landed immediately after as commit 39; = both share the phase 4 spec).
//  Per AGENTS.md §11.4 + .scratch/2026-09-13-swiftdata-migration-spec.md.
//
//  One-time data migration from raw sqlite3 stores to SwiftData @Model.
//  Triggered on first launch (= after onboarding completes).
//  Idempotent (= skips rows already migrated; = safe to re-run).
//
//  Per-entity migration functions in WSMigrationPerStore.swift
//  (= separate file for clarity; = each store gets its own commit).
//
//  Public API:
//    - migratesIfNeeded() async throws  (= entry point; = safe to call repeatedly)
//    - migrationStatus() -> MigrationStatus (= inspectable; = UI can show progress)
//
//  Marker (= stored in SwiftData):
//    WSManifest.migratedFromRawSqliteAt: Date? — set to Date() after successful migration

import Foundation
import SwiftData

@MainActor
public enum WSMigrationRunner {

    public enum MigrationStatus: Equatable, Sendable {
        case notStarted
        case inProgress(stage: String, current: Int, total: Int)
        case completed(at: Date)
        case failed(error: String)
    }

    /// Entry point: migrate raw sqlite3 → SwiftData if not already done.
    /// Safe to call repeatedly (= idempotent).
    public static func migrateIfNeeded() async throws {
        let context = WSPersistenceContainer.shared.mainContext

        // Check marker
        let manifestFetch = FetchDescriptor<WSManifest>()
        if let manifest = try context.fetch(manifestFetch).first,
           manifest.migratedFromRawSqliteAt != nil {
            // Already migrated
            return
        }

        // Get or create manifest
        let manifest: WSManifest
        if let existing = try context.fetch(manifestFetch).first {
            manifest = existing
        } else {
            manifest = WSManifest(
                workspaceUUID: UUID(),
                schemaVersion: 72,
                wenshuVersion: "0.72.0"
            )
            context.insert(manifest)
            try context.save()
        }

        // Run per-store migrations
        try await WSMigrationPerStore.migrateMemoryStore(context: context)
        try await WSMigrationPerStore.migrateChatSessionStore(context: context)
        try await WSMigrationPerStore.migrateTodoStore(context: context)
        try await WSMigrationPerStore.migrateBookmarkStore(context: context)
        try await WSMigrationPerStore.migrateKanbanStore(context: context)
        try await WSMigrationPerStore.migrateLinkIndex(context: context)
        try await WSMigrationPerStore.migrateBooks(context: context)
        try await WSMigrationPerStore.migrateProviderKeys(context: context)
        try await WSMigrationPerStore.migratePreferences(context: context)

        // Mark complete
        manifest.migratedFromRawSqliteAt = Date()
        try context.save()
    }

    /// Inspect migration status (= for UI progress reporting).
    public static func migrationStatus() -> MigrationStatus {
        let context = WSPersistenceContainer.shared.mainContext
        let descriptor = FetchDescriptor<WSManifest>()
        guard let manifest = try? context.fetch(descriptor).first else {
            return .notStarted
        }
        if let at = manifest.migratedFromRawSqliteAt {
            return .completed(at: at)
        }
        return .notStarted
    }

    /// Reset marker (= test-only; = forces re-migration).
    /// Not exposed in production (= would re-trigger migration on every launch).
    #if DEBUG
    public static func resetMarker() throws {
        let context = WSPersistenceContainer.shared.mainContext
        let descriptor = FetchDescriptor<WSManifest>()
        if let manifest = try context.fetch(descriptor).first {
            manifest.migratedFromRawSqliteAt = nil
            try context.save()
        }
    }
    #endif
}
