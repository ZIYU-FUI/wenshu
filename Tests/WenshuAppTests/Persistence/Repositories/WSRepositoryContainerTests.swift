//
//  Persistence/Repositories/WSRepositoryContainerTests.swift · Wenshu · v0.72 SwiftData migration Phase 3

import Foundation
import SwiftData
import Testing
@testable import WenshuApp

@Suite("WSRepositoryContainer (= SwiftData @Observable singleton holding all 9 repos)")
struct WSRepositoryContainerTests {

    @MainActor
    @Test("WSRepositoryContainer init succeeds + all 9 repos present")
    func initContainer() throws {
        let container = try WSPersistenceContainer.makeInMemoryContainer()
        let repoContainer = WSRepositoryContainer(container: container)
        // Just verify we can access each repo
        _ = repoContainer.memory
        _ = repoContainer.chat
        _ = repoContainer.todo
        _ = repoContainer.bookmark
        _ = repoContainer.kanban
        _ = repoContainer.link
        _ = repoContainer.book
        _ = repoContainer.providerKey
        _ = repoContainer.preference
        #expect(true)  // reach here = no crash
    }

    @MainActor
    @Test("WSRepositoryContainer.shared is reachable")
    func sharedReachable() {
        let _ = WSRepositoryContainer.shared
        #expect(true)
    }

    @MainActor
    @Test("WSMemoryRepository.shared works (= can add a memory)")
    func memorySharedWorks() throws {
        let mem = try WSMemoryRepository.shared.add(userId: "test", content: "hi")
        #expect(mem.content == "hi")
    }

    @MainActor
    @Test("WSTodoRepository.shared works (= can add a todo)")
    func todoSharedWorks() throws {
        let todo = try WSTodoRepository.shared.add(title: "test")
        #expect(todo.title == "test")
    }
}
