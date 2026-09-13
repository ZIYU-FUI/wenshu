//
//  Persistence/WSChatMessageTests.swift · Wenshu · v0.72 SwiftData migration Phase 1

import Foundation
import SwiftData
import Testing
@testable import WenshuApp

@Suite("WSChatMessage (= chat_messages @Model)")
struct WSChatMessageTests {

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([WSChatMessage.self, WSSession.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    @Test("WSChatMessage init sets role + content + position + sessionID")
    @MainActor
    func initSetsFields() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let msg = WSChatMessage(
            id: "msg-001",
            sessionID: "sess-A",
            role: "user",
            content: "hello",
            position: 0
        )
        context.insert(msg)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<WSChatMessage>())
        #expect(fetched.count == 1)
        #expect(fetched[0].id == "msg-001")
        #expect(fetched[0].sessionID == "sess-A")
        #expect(fetched[0].role == "user")
        #expect(fetched[0].content == "hello")
        #expect(fetched[0].position == 0)
        #expect(fetched[0].status == "ok")
        #expect(fetched[0].tokenCount == -1)
    }

    @Test("WSChatMessage role accepts user/assistant/system")
    @MainActor
    func roleValues() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        for role in ["user", "assistant", "system"] {
            let msg = WSChatMessage(id: "m-\(role)", sessionID: "s", role: role, content: "x", position: 0)
            context.insert(msg)
            try context.save()
            #expect(msg.role == role)
        }
    }

    @Test("WSChatMessage 1↔N relationship to WSSession (= bidirectional)")
    @MainActor
    func relationshipToSession() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let session = WSSession(sessionID: "sess-rel", title: "rel test")
        context.insert(session)
        let msg1 = WSChatMessage(id: "m1", sessionID: session.sessionID, role: "user", content: "1", position: 0)
        let msg2 = WSChatMessage(id: "m2", sessionID: session.sessionID, role: "assistant", content: "2", position: 1)
        context.insert(msg1)
        context.insert(msg2)
        msg1.session = session
        msg2.session = session
        try context.save()

        // Forward: child.session points to parent
        #expect(msg1.session?.sessionID == "sess-rel")
        // Inverse: parent.messages contains both children
        #expect(session.messages.count == 2)
        let ids = Set(session.messages.map { $0.id })
        #expect(ids == Set(["m1", "m2"]))
    }

    @Test("WSChatMessage id uniqueness enforced")
    @MainActor
    func idUniqueEnforced() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let a = WSChatMessage(id: "same", sessionID: "s", role: "user", content: "a", position: 0)
        let b = WSChatMessage(id: "same", sessionID: "s", role: "user", content: "b", position: 1)
        context.insert(a)
        context.insert(b)
        #expect(throws: Never.self) {
            try context.save()
        }
    }
}
