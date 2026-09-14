//
//  Persistence/WSManifestTests.swift · Wenshu · v0.72 SwiftData migration Phase 1
//
//  Test commit 1: WSManifest = first @Model class (= simplest, no relationships).
//  Validates that the SwiftData build pipeline works end-to-end:
//    - WenshuApp builds with SwiftData import
//    - WSManifest instantiates with the documented init signature
//    - Properties persist + retrieve from an in-memory ModelContainer
//    - migratedFromRawSqliteAt defaults to nil (= Phase 4 will populate)
//
//  Per boss 2026-09-13 OOB: "build one, test one, commit one"

import Foundation
import SwiftData
import Testing
@testable import WenshuApp

@Suite("WSManifest (= first SwiftData @Model)")
struct WSManifestTests {

    /// Helper: build an in-memory ModelContainer that contains just WSManifest
    /// (= no other @Model classes yet; = isolates this test from Phase 1+ additions).
    @MainActor
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([WSManifest.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    @Test("WSManifest init sets all required fields (= workspace_uuid, schema_version, wenshu_version)")
    @MainActor
    func initSetsRequiredFields() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let uuid = UUID()
        let manifest = WSManifest(
            workspaceUUID: uuid,
            schemaVersion: 72,
            wenshuVersion: "0.72.0"
        )
        context.insert(manifest)
        try context.save()

        // Re-fetch via predicate (= verify it round-trips through SwiftData)
        let descriptor = FetchDescriptor<WSManifest>()
        let fetched = try context.fetch(descriptor)
        #expect(fetched.count == 1)
        #expect(fetched[0].workspaceUUID == uuid)
        #expect(fetched[0].schemaVersion == 72)
        #expect(fetched[0].wenshuVersion == "0.72.0")
    }

    @Test("WSManifest default value: migratedFromRawSqliteAt = nil (= Phase 4 not yet run)")
    @MainActor
    func migratedFromRawSqliteAtDefaultsNil() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let manifest = WSManifest(
            workspaceUUID: UUID(),
            schemaVersion: 72,
            wenshuVersion: "0.72.0"
        )
        context.insert(manifest)
        try context.save()

        #expect(manifest.migratedFromRawSqliteAt == nil)
    }

    @Test("WSManifest createdAt + updatedAt are set to ~now on init")
    @MainActor
    func initSetsTimestamps() throws {
        let before = Date()
        let manifest = WSManifest(
            workspaceUUID: UUID(),
            schemaVersion: 72,
            wenshuVersion: "0.72.0"
        )
        let after = Date()

        // createdAt + updatedAt should both be in [before, after]
        #expect(manifest.createdAt >= before && manifest.createdAt <= after)
        #expect(manifest.updatedAt >= before && manifest.updatedAt <= after)
        #expect(manifest.createdAt == manifest.updatedAt)
    }

    @Test("WSManifest checksum is optional (= can be nil)")
    @MainActor
    func checksumIsOptional() throws {
        let manifest = WSManifest(
            workspaceUUID: UUID(),
            schemaVersion: 72,
            wenshuVersion: "0.72.0"
        )
        #expect(manifest.checksum == nil)

        manifest.checksum = "abc123"
        #expect(manifest.checksum == "abc123")
    }
}
