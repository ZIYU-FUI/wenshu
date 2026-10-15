//
//  Persistence/Repositories/WSMemoryRepositoryTests.swift · Wenshu · v0.72 SwiftData migration 
//
//  Test : WSMemoryRepository (= MemoryStore actor replacement).

import Foundation
import Testing
import WenshuData

@Suite("WSMemoryRepository (= SwiftData @Model MemoryStore replacement)")
struct WSMemoryRepositoryTests {

    @MainActor
    private func makeRepository() throws -> WSMemoryRepository {
        let container = try WSPersistenceContainer.makeInMemoryContainer()
        return WSMemoryRepository(container: container)
    }

    @Test("add(userId:content:) creates Memory + returns it")
    @MainActor
    func add() throws {
        let repo = try makeRepository()
        let mem = try repo.add(userId: "user-1", content: "hello world")
        #expect(mem.userID == "user-1")
        #expect(mem.content == "hello world")
        #expect(!mem.memoryID.isEmpty)
    }

    @Test("get(memoryID:) round-trips the Memory")
    @MainActor
    func get() throws {
        let repo = try makeRepository()
        let added = try repo.add(userId: "u", content: "x")
        let fetched = try repo.get(memoryID: added.memoryID)
        #expect(fetched?.memoryID == added.memoryID)
        #expect(fetched?.content == "x")
    }

    @Test("get(memoryID:) returns nil for missing")
    @MainActor
    func getMissing() throws {
        let repo = try makeRepository()
        let fetched = try repo.get(memoryID: MemoryID(rawValue: "nope").rawValue)
        #expect(fetched == nil)
    }

    @Test("search(userId:query:) matches via localizedStandardContains")
    @MainActor
    func search() throws {
        let repo = try makeRepository()
        _ = try repo.add(userId: "u", content: "apple banana cherry")
        _ = try repo.add(userId: "u", content: "pear")
        _ = try repo.add(userId: "other", content: "apple")
        let results = try repo.search(userId: "u", query: "apple")
        #expect(results.count == 1)
        #expect(results[0].content.contains("apple"))
    }

    @Test("update(memoryID:content:) mutates content + bumps updatedAt")
    @MainActor
    func update() throws {
        let repo = try makeRepository()
        let added = try repo.add(userId: "u", content: "old")
        let addedUpdatedAt = added.updatedAt  // (= capture the timestamp before update, since `added` and the fetched model are the same SwiftData @Model instance)
        try? Thread.sleep(forTimeInterval: 0.5)
        try repo.update(memoryID: added.memoryID, content: "new")
        let fetched = try repo.get(memoryID: added.memoryID)
        #expect(fetched?.content == "new")
        #expect(fetched!.updatedAt > addedUpdatedAt)  // (= new updatedAt must be later than the pre-update timestamp)
    }

    @Test("update throws notFound for missing")
    @MainActor
    func updateMissing() throws {
        let repo = try makeRepository()
        #expect(throws: WSMemoryRepositoryError.notFound.self) {
            try repo.update(memoryID: MemoryID(rawValue: "nope").rawValue, content: "x")
        }
    }

    @Test("delete removes the row")
    @MainActor
    func delete() throws {
        let repo = try makeRepository()
        let added = try repo.add(userId: "u", content: "x")
        try repo.delete(memoryID: added.memoryID)
        let fetched = try repo.get(memoryID: added.memoryID)
        #expect(fetched == nil)
    }

    @Test("count + listRecent respect userId partition")
    @MainActor
    func countAndList() throws {
        let repo = try makeRepository()
        _ = try repo.add(userId: "u", content: "1")
        _ = try repo.add(userId: "u", content: "2")
        _ = try repo.add(userId: "u", content: "3")
        _ = try repo.add(userId: "other", content: "4")
        #expect(try repo.count(userId: "u") == 3)
        #expect(try repo.count(userId: "other") == 1)
        let list = try repo.listRecent(userId: "u", limit: 2)
        #expect(list.count == 2)
    }

    @Test("purgeOlderThan removes entries older than retentionDays")
    @MainActor
    func purge() throws {
        let repo = try makeRepository()
        _ = try repo.add(userId: "u", content: "old")
        // = all entries are fresh, so nothing to purge with retentionDays=1
        let purged = try repo.purgeOlderThan(userId: "u", retentionDays: 1)
        #expect(purged == 0)
    }
}
