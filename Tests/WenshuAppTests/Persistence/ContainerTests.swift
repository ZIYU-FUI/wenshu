//
//  Persistence/ContainerTests.swift · Wenshu · v0.72 SwiftData migration 
//
//  Test : WSPersistenceContainer = ModelContainer setup.
//  Validates that all 22 @Model classes can co-exist in one container
//  (= no schema conflicts; = SwiftData accepts the union).

import Foundation
import SwiftData
import Testing
@testable import WenshuApp

@Suite("WSPersistenceContainer (= SwiftData ModelContainer setup)")
struct WSPersistenceContainerTests {

    @Test("Container.makeInMemoryContainer() succeeds with all 22 @Model classes")
    @MainActor
    func makeInMemoryContainerSucceeds() throws {
        let container = try WSPersistenceContainer.makeInMemoryContainer()
        let context = ModelContext(container)
        #expect(context.container.configurations.count == 1)
    }

    @Test("Container can insert + fetch across multiple @Model types")
    @MainActor
    func crossTypeInsertAndFetch() throws {
        let container = try WSPersistenceContainer.makeInMemoryContainer()
        let context = ModelContext(container)

        // Insert one of each major type
        let manifest = WSManifest(workspaceUUID: UUID(), schemaVersion: 72, wenshuVersion: "0.72.0")
        let todo = WSTodo(id: "t-001", title: "x")
        let session = WSSession(sessionID: "sess-001", title: "test")
        context.insert(manifest)
        context.insert(todo)
        context.insert(session)
        try context.save()

        // Fetch each
        let manifests = try context.fetch(FetchDescriptor<WSManifest>())
        let todos = try context.fetch(FetchDescriptor<WSTodo>())
        let sessions = try context.fetch(FetchDescriptor<WSSession>())
        #expect(manifests.count == 1)
        #expect(todos.count == 1)
        #expect(sessions.count == 1)
    }
}
