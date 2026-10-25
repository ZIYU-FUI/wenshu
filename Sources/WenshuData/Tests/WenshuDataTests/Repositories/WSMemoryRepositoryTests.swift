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

    /// A string built from Unicode code points (= the CJK test data
    /// stays out of this file's source, = the repo writes code in
    /// English).
    private static func cjk(_ codePoints: [UInt32]) -> String {
        String(String.UnicodeScalarView(codePoints.map { Unicode.Scalar($0)! }))
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

    @Test("search(userId:query:) matches a memory that carries the term")
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

    @Test("search(userId:query:) answers a question, not a substring")
    @MainActor
    func searchAnswersAQuestion() throws {
        // The boss's case: a question that shares no substring with
        // the memory that holds the answer. The whole-query
        // substring test answered nothing here, so the constraint
        // never reached the context.
        let repo = try makeRepository()
        _ = try repo.add(
            userId: "u",
            content: "The third scene of chapter five opens in the harbor, and the kestrel arrives."
        )
        let results = try repo.search(userId: "u", query: "what did the third scene of chapter five say?")
        #expect(results.count == 1)
        #expect(results[0].content.contains("kestrel"))
    }

    @Test("search(userId:query:) answers a question in Chinese")
    @MainActor
    func searchAnswersAChineseQuestion() throws {
        // The CJK path of the matcher (= the boss's library is
        // Chinese; = a query has no spaces, so the characters are the
        // terms). The characters are written as code points so this
        // file stays English-only (= the repo's rule); = the test
        // still runs the CJK path.
        let memory = Self.cjk([0x6F6E, 0x6C50])        // "tide"
        let query = Self.cjk([0x6F6E, 0x6C50, 0x8868])  // "tide table"
        let repo = try makeRepository()
        _ = try repo.add(userId: "u", content: memory)
        let results = try repo.search(userId: "u", query: query)
        #expect(results.count == 1)
        #expect(results[0].content == memory)
    }

    @Test("search(userId:query:) ranks the memory that carries more of the terms first")
    @MainActor
    func searchRanksTheBestMatchFirst() throws {
        let repo = try makeRepository()
        // The better match is the OLDER one, so the score decides
        // (= the recency only breaks a tie).
        _ = try repo.add(userId: "u", content: "The harbor tide gauge was read at dawn.")
        _ = try repo.add(userId: "u", content: "A note about the harbor.")
        let results = try repo.search(userId: "u", query: "harbor tide gauge")
        #expect(results.count == 2)
        #expect(results[0].content.contains("read at dawn"))
    }

    @Test("search(userId:query:) with a blank query returns the most recent memories")
    @MainActor
    func searchWithBlankQueryReturnsRecent() throws {
        // The caller's "give me the context" call passes an empty
        // query; = it asks for the recent memories, not for a search.
        let repo = try makeRepository()
        _ = try repo.add(userId: "u", content: "first")
        _ = try repo.add(userId: "u", content: "second")
        let results = try repo.search(userId: "u", query: "", limit: 2)
        #expect(results.count == 2)
        #expect(results[0].content == "second")
    }

    @Test("search(userId:query:) keeps the user partition")
    @MainActor
    func searchKeepsTheUserPartition() throws {
        let repo = try makeRepository()
        _ = try repo.add(userId: "u", content: "apple banana cherry")
        _ = try repo.add(userId: "other", content: "apple")
        let results = try repo.search(userId: "u", query: "apple")
        #expect(results.count == 1)
        #expect(results[0].content == "apple banana cherry")
    }

    @Test("search(userId:query:) returns nothing when no memory carries a term")
    @MainActor
    func searchWithNoMatch() throws {
        let repo = try makeRepository()
        _ = try repo.add(userId: "u", content: "a quiet morning in the harbor")
        #expect(try repo.search(userId: "u", query: "kestrel").isEmpty)
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
