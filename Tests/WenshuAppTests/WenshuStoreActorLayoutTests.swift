// WenshuStoreActorLayoutTests.swift · 文枢 (Wenshu) · v0.02.0 WO-LT-01
//
// Round-trip + migration tests for the new `CDLayoutState` entity.
//
// Covers the three acceptance criteria that touch persistence:
// 1. Save then load = same data (round-trip)
// 2. First-launch path: no row → load returns nil
// 3. Schema migration: a pre-LT-01 .ws file (7 entities, no CDLayoutState)
//    survives the auto-migration to the v0.02.0 model (8 entities, with
//    CDLayoutState) and the new entity is queryable afterwards.
//
// The migration test mirrors AGENTS §7 "数据资产 = 你自管": if LT-01
// breaks a user's existing .ws file, the 8/7 data-asset rule is violated.
// We test with a SQLite file in a temp dir (real on-disk migration path),
// not an in-memory store (which doesn't exercise the auto-migration
// inference code path).

import XCTest
@testable import WenshuApp
import CoreData

final class WenshuStoreActorLayoutTests: XCTestCase {

    // MARK: - Fixtures

    /// Build a `WenshuStoreActor` backed by an in-memory CoreData store
    /// (the same pattern WenshuStoreActorTests uses — each test owns its
    /// container, no shared state).
    private func makeInMemoryStore() -> WenshuStoreActor {
        let container = NSPersistentContainer(name: "Wenshu", managedObjectModel: makeWenshuModel())
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        container.loadPersistentStores { _, error in
            XCTAssertNil(error, "Failed to load in-memory store: \(String(describing: error))")
        }
        return WenshuStoreActor(container: container)
    }

    // MARK: - Round-trip

    func testSaveAndLoad_layoutState_roundTrips() async throws {
        let store = makeInMemoryStore()

        // Before any save: load returns nil (first-launch path).
        let firstLoad = try await store.loadLayoutState()
        XCTAssertNil(firstLoad, "Expected nil on first launch (no CDLayoutState row yet)")

        // Save a snapshot.
        let statesJSON = LayoutSnapshot.encodeCollapsed(PanelCollapsedState(
            topLeft: false, topCenter: true, topRight: false,
            bottomLeft: false, bottomRight: true
        ))
        let ratiosJSON = LayoutSnapshot.encodeRatios([0.18, 0.64, 0.18, 0.5, 0.5])
        try await store.saveLayoutState(
            panelStatesJSON: statesJSON,
            panelRatiosJSON: ratiosJSON
        )

        // Read it back.
        let loaded = try await store.loadLayoutState()
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.panelStatesJSON, statesJSON)
        XCTAssertEqual(loaded?.panelRatiosJSON, ratiosJSON)
    }

    func testSave_isIdempotent_oneRowOnly() async throws {
        let store = makeInMemoryStore()
        let s = LayoutSnapshot.encodeCollapsed(PanelCollapsedState())
        let r = LayoutSnapshot.encodeRatios(LayoutSnapshot.default.ratios)
        // Save 5 times in parallel — should still result in exactly one row
        // (upsert semantics) since CDLayoutState is a singleton per .ws file.
        await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<5 {
                group.addTask {
                    try await store.saveLayoutState(panelStatesJSON: s, panelRatiosJSON: r)
                }
            }
        }
        // Verify only one row exists by counting via fresh fetch.
        let count = try await store.countLayoutStates()
        XCTAssertEqual(count, 1, "Save must upsert, not append — singleton per .ws file")
    }

    // MARK: - Migration (LT-01 acceptance criterion: 旧 v0.01.0 .ws 不破)

    /// Pre-LT-01 model — same as makeWenshuModel() minus CDLayoutState.
    /// Hand-built here so the test stays independent of any future schema
    /// changes to the production model.
    private func makePreLT01Model() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        func attribute(_ name: String, _ type: NSAttributeType, optional: Bool = false, defaultValue: Any? = nil) -> NSAttributeDescription {
            let a = NSAttributeDescription()
            a.name = name
            a.attributeType = type
            a.isOptional = optional
            a.defaultValue = defaultValue
            return a
        }
        func entity(_ name: String, properties: [NSPropertyDescription]) -> NSEntityDescription {
            let e = NSEntityDescription()
            e.name = name
            e.managedObjectClassName = "NSManagedObject"
            e.properties = properties
            return e
        }
        model.entities = [
            entity("CDCharacter", properties: [
                attribute("name", .stringAttributeType),
                attribute("role", .stringAttributeType, optional: true),
                attribute("backstory", .stringAttributeType, optional: true),
                attribute("createdAt", .dateAttributeType)
            ]),
            entity("CDChapter", properties: [
                attribute("title", .stringAttributeType),
                attribute("content", .stringAttributeType, optional: true),
                attribute("chapterIndex", .integer32AttributeType),
                attribute("createdAt", .dateAttributeType)
            ]),
            entity("CDNote", properties: [
                attribute("text", .stringAttributeType),
                attribute("createdAt", .dateAttributeType),
                attribute("tags", .stringAttributeType, optional: true)
            ]),
            entity("CDWorldRule", properties: [
                attribute("rule", .stringAttributeType),
                attribute("category", .stringAttributeType, optional: true),
                attribute("createdAt", .dateAttributeType)
            ]),
            entity("CDForeshadow", properties: [
                attribute("hook", .stringAttributeType),
                attribute("status", .stringAttributeType, optional: true),
                attribute("plantedAt", .dateAttributeType),
                attribute("resolvedAt", .dateAttributeType, optional: true)
            ]),
            entity("CDRevision", properties: [
                attribute("originalChapterID", .UUIDAttributeType),
                attribute("revisedContent", .stringAttributeType, optional: true),
                attribute("reason", .stringAttributeType, optional: true),
                attribute("createdAt", .dateAttributeType),
                attribute("accepted", .booleanAttributeType, defaultValue: false)
            ]),
            entity("CDAIDraft", properties: [
                attribute("prompt", .stringAttributeType),
                attribute("draft", .stringAttributeType, optional: true),
                attribute("model", .stringAttributeType),
                attribute("createdAt", .dateAttributeType),
                attribute("finalizedChapterID", .UUIDAttributeType, optional: true)
            ])
            // NO CDLayoutState — this is the v0.01.0 model fingerprint.
        ]
        return model
    }

    func testMigration_preLT01_wsFile_doesNotLoseData() async throws {
        // Real on-disk SQLite (in-memory stores can't exercise lightweight
        // migration inference — the test must use the file path).
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wenshu-migration-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let storeURL = tempDir.appendingPathComponent("Wenshu.sqlite")

        // 1. Open with the pre-LT-01 model + write a CDNote (simulates a
        //    v0.01.0 user who has created projects and saved notes).
        let oldContainer = NSPersistentContainer(
            name: "Wenshu",
            managedObjectModel: makePreLT01Model()
        )
        let oldDesc = NSPersistentStoreDescription(url: storeURL)
        oldContainer.persistentStoreDescriptions = [oldDesc]
        var oldLoadError: Error?
        oldContainer.loadPersistentStores { _, error in oldLoadError = error }
        XCTAssertNil(oldLoadError, "Pre-LT-01 store must load cleanly: \(String(describing: oldLoadError))")
        let oldContext = oldContainer.viewContext
        let oldNote = NSEntityDescription.insertNewObject(forEntityName: "CDNote", into: oldContext)
        oldNote.setValue("pre-existing story from v0.01.0", forKey: "text")
        oldNote.setValue("project-v0.01.0-marker", forKey: "tags")
        oldNote.setValue(Date(timeIntervalSince1970: 1_750_000_000), forKey: "createdAt")
        try oldContext.save()
        // Tear down the v0.01.0 container before we attempt migration
        // (CoreData requires only one coordinator to own a given store).
        try await Task.sleep(for: .milliseconds(50))

        // 2. Open the same SQLite file with the v0.02.0 (current) model.
        //    Lightweight migration is enabled by the production store
        //    description; we mirror that on the test container.
        let newContainer = NSPersistentContainer(
            name: "Wenshu",
            managedObjectModel: makeWenshuModel()
        )
        let newDesc = NSPersistentStoreDescription(url: storeURL)
        newDesc.shouldInferMappingModelAutomatically = true
        newDesc.shouldMigrateStoreAutomatically = true
        newContainer.persistentStoreDescriptions = [newDesc]
        var newLoadError: Error?
        newContainer.loadPersistentStores { _, error in newLoadError = error }
        XCTAssertNil(
            newLoadError,
            "Migration from pre-LT-01 to LT-01 must succeed: \(String(describing: newLoadError))"
        )

        // 3. Verify the pre-existing CDNote is still there with intact data.
        let newContext = newContainer.viewContext
        let noteRequest = NSFetchRequest<NSManagedObject>(entityName: "CDNote")
        let notes = try newContext.fetch(noteRequest)
        XCTAssertEqual(notes.count, 1, "Pre-existing CDNote row must survive migration")
        XCTAssertEqual(notes.first?.value(forKey: "text") as? String, "pre-existing story from v0.01.0")
        XCTAssertEqual(notes.first?.value(forKey: "tags") as? String, "project-v0.01.0-marker")

        // 4. Verify the new entity is queryable (i.e. auto-migration
        //    actually added it) — and that we can write to it.
        let layoutRequest = NSFetchRequest<NSManagedObject>(entityName: "CDLayoutState")
        let layouts = try newContext.fetch(layoutRequest)
        XCTAssertEqual(layouts.count, 0, "No CDLayoutState rows yet on a freshly-migrated file")

        let newLayout = NSEntityDescription.insertNewObject(forEntityName: "CDLayoutState", into: newContext)
        newLayout.setValue(LayoutSnapshot.encodeCollapsed(PanelCollapsedState()), forKey: "panel_states")
        newLayout.setValue(LayoutSnapshot.encodeRatios(LayoutSnapshot.default.ratios), forKey: "panel_ratios")
        try newContext.save()

        let reloaded = try newContext.fetch(layoutRequest)
        XCTAssertEqual(reloaded.count, 1, "Write to migrated CDLayoutState must succeed")
    }
}
