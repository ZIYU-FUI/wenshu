// WenshuStoreActorTests.swift · 文枢 (Wenshu) · v0.02.0
//
// CoreData store-actor round-trip + concurrency tests. The
// entity-level smoke tests live here; LT-01-fix5 specific panel /
// splitter / menu behaviour lives in `LT01Fix5Tests.swift`.

import XCTest
@testable import WenshuApp
import CoreData

final class WenshuStoreActorTests: XCTestCase {
    private func makeStore() -> WenshuStoreActor {
        let container = NSPersistentContainer(name: "Wenshu", managedObjectModel: makeWenshuModel())
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        container.loadPersistentStores { _, error in
            XCTAssertNil(error)
        }
        return WenshuStoreActor(container: container)
    }

    func testConcurrentCreateCharacter_noDataRace() async throws {
        let store = makeStore()
        await withThrowingTaskGroup(of: Void.self) { group in
            for index in 0..<20 {
                group.addTask {
                    try await store.createCharacter(["name": "Character \(index)", "createdAt": Date()])
                }
            }
            group.addTask { _ = try await store.listCharacters() }
        }
        let characters = try await store.listCharacters()
        XCTAssertEqual(characters.count, 20)
    }

    func testCountAll_isAccurate() async throws {
        let store = makeStore()
        for index in 0..<10 { try await store.createNote(["text": "Note \(index)", "createdAt": Date()]) }
        for index in 0..<5 { try await store.createCharacter(["name": "Character \(index)", "createdAt": Date()]) }
        for index in 0..<3 { try await store.createWorldRule(["rule": "Rule \(index)", "createdAt": Date()]) }
        let total = try await store.countAll()
        XCTAssertEqual(total, 18)
    }

    func testCancellation_isRespected() async throws {
        let store = makeStore()
        let task = Task {
            try await Task.sleep(for: .milliseconds(100))
            try await store.createCharacter(["name": "Cancelled", "createdAt": Date()])
        }
        task.cancel()
        _ = await task.result
        try await store.createCharacter(["name": "After cancellation", "createdAt": Date()])
        let characters = try await store.listCharacters()
        XCTAssertEqual(characters.count, 1)
    }
}
