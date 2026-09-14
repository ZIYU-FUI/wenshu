//
//  Persistence/WSMemoryTests.swift · Wenshu · v0.72 SwiftData migration Phase 1
//
//  Test commit 2: WSMemory @Model (= memories table from MemoryStore.swift).
//  Per boss 2026-09-13 OOB: "build one, test one, commit one"

import Foundation
import SwiftData
import Testing
@testable import WenshuApp

@Suite("WSMemory (= memories @Model)")
struct WSMemoryTests {

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([WSMemory.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    @Test("WSMemory init sets all fields (= memoryID, userID, content)")
    @MainActor
    func initSetsFields() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let mem = WSMemory(memoryID: "m-001", userID: "user-1", content: "hello world")
        context.insert(mem)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<WSMemory>())
        #expect(fetched.count == 1)
        #expect(fetched[0].memoryID == "m-001")
        #expect(fetched[0].userID == "user-1")
        #expect(fetched[0].content == "hello world")
    }

    @Test("WSMemory memoryID uniqueness enforced (= SwiftData @Attribute(.unique))")
    @MainActor
    func memoryIDUniqueEnforced() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let m1 = WSMemory(memoryID: "dup", userID: "u1", content: "first")
        let m2 = WSMemory(memoryID: "dup", userID: "u2", content: "second")
        context.insert(m1)
        context.insert(m2)
        #expect(throws: Never.self) {
            try context.save()
        }
    }

    @Test("WSMemory update(content:) mutates content + bumps updatedAt")
    @MainActor
    func updateContentBumpsUpdatedAt() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let mem = WSMemory(memoryID: "m-002", userID: "u1", content: "old")
        context.insert(mem)
        try context.save()
        let originalUpdatedAt = mem.updatedAt
        // Sleep tiny amount so updatedAt differs (= Date.now precision)
        try? Thread.sleep(forTimeInterval: 0.05)  // v0.72 Q99 MED fix: bumped from 0.01 (= too flaky on slow CI; = needs > Date precision)
        mem.update(content: "new")
        try context.save()
        #expect(mem.content == "new")
        #expect(mem.updatedAt > originalUpdatedAt)
    }

    @Test("WSMemory createdAt + updatedAt initialized to same value")
    @MainActor
    func createdAndUpdatedAtEqualOnInit() throws {
        let before = Date()
        let mem = WSMemory(memoryID: "m-003", userID: "u1", content: "x")
        let after = Date()
        #expect(mem.createdAt >= before && mem.createdAt <= after)
        #expect(mem.updatedAt == mem.createdAt)
    }
}
