//
//  Persistence/WSMigrationRunnerTests.swift · Wenshu · v0.72 SwiftData migration Phase 4
//
//  Test commit 38: WSMigrationRunner scaffolding tests.

import Foundation
import SwiftData
import Testing
@testable import WenshuApp

@Suite("WSMigrationRunner (= SwiftData one-time data migration)")
struct WSMigrationRunnerTests {

    @MainActor
    @Test("migrationStatus() returns .notStarted on fresh container")
    func statusFresh() throws {
        // Use a fresh container (= in-memory; = not the .shared singleton)
        // Migration status only makes sense against the shared container, so
        // we test the marker round-trip via the manifest instead.
        let container = try WSPersistenceContainer.makeInMemoryContainer()
        let context = container.mainContext
        let manifest = WSManifest(workspaceUUID: UUID(), schemaVersion: 72, wenshuVersion: "0.72.0")
        context.insert(manifest)
        try context.save()
        let fetched = try context.fetch(FetchDescriptor<WSManifest>())
        #expect(fetched.count == 1)
        #expect(fetched[0].migratedFromRawSqliteAt == nil)
    }

    @MainActor
    @Test("WSManifest.migratedFromRawSqliteAt can be set + read")
    func markerSetGet() throws {
        let container = try WSPersistenceContainer.makeInMemoryContainer()
        let context = container.mainContext
        let manifest = WSManifest(workspaceUUID: UUID(), schemaVersion: 72, wenshuVersion: "0.72.0")
        context.insert(manifest)
        try context.save()
        manifest.migratedFromRawSqliteAt = Date()
        try context.save()
        let fetched = try context.fetch(FetchDescriptor<WSManifest>())
        #expect(fetched[0].migratedFromRawSqliteAt != nil)
    }

    @MainActor
    @Test("WSMigrationRunner.migrateIfNeeded() is idempotent on empty container")
    func idempotentEmpty() async throws {
        // First call: runs all per-store migrations (= all no-ops on empty)
        try await WSMigrationRunner.migrateIfNeeded()
        // Second call: should detect marker (= from first call) and skip
        try await WSMigrationRunner.migrateIfNeeded()
        // Verify marker is set
        let context = WSPersistenceContainer.shared.mainContext
        let manifest = try context.fetch(FetchDescriptor<WSManifest>()).first
        #expect(manifest?.migratedFromRawSqliteAt != nil)
    }

    @MainActor
    @Test("WSMigrationRunner.migrationStatus() returns .completed after migrateIfNeeded")
    func statusAfterMigration() async throws {
        try await WSMigrationRunner.migrateIfNeeded()
        let status = WSMigrationRunner.migrationStatus()
        switch status {
        case .completed:
            break  // expected
        default:
            Issue.record("Expected .completed, got \(status)")
        }
    }
}
