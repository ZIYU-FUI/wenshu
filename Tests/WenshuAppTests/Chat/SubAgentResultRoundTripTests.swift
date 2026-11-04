//
//  Tests/Chat/SubAgentResultRoundTripTests.swift · Wenshu
//
//  The delivered result reads back.
//
//  Why this test exists (= the gap it closes):
//
//  The delivery wrote the result to the session, = and the chat that
//  was showing that session never showed it. = The row was on disk
//  (= one row, = with the source in it), = and the chat's own read
//  path returned nothing.
//
//  The cause was the string: = the write put the enum's default raw
//  value (= `agentResult`) in the row, = and the reader matched a
//  different spelling (= `agent_result`), = so every delivered result
//  was written and then dropped on the way back.
//
//  The suite that should have caught it did not, = because its fake
//  repository kept the `ChatMessage` it was handed and handed it
//  back, = so the string mapping was never exercised. = So this suite
//  goes through the PRODUCTION repository over a real container, =
//  the chat's own `loadMessages`, = and nothing in between.
//
//  What is pinned here:
//
//  1. A delivered result reads back through the chat's own read path.
//  2. The row carries the source the enum spells, = and the same
//     spelling the reader knows.
//  3. The other three sources still round-trip, = because the fix
//     touched the shared mapping.
//  4. The result keeps its own role and source, = and is not read as
//     the main agent's reply.
//

import Foundation
import SwiftData
import Testing
import WenshuAgent
@testable import WenshuApp
import WenshuData

@Suite("A delivered result reads back")
struct SubAgentResultRoundTripTests {

    /// The production repository, = over a real container.
    @MainActor
    private static func makeRepository() throws -> LiveChatRepository {
        let container = try WSPersistenceContainer.makeInMemoryContainer()
        return LiveChatRepository(container: container)
    }

    /// Deliver one result, = through the production repository.
    @MainActor
    private static func deliver(
        into repository: LiveChatRepository,
        sessionID: String = "session-asking"
    ) async -> String {
        let delivery = SubAgentResultDelivery(repository: repository)
        let handle = BackgroundDelegationHandle(
            id: "run-roundtrip",
            agentName: "researcher",
            userMessage: "find something",
            scope: AgentScope(sessionID: SessionID(rawValue: sessionID), bookID: nil)
        )
        _ = await delivery.deliver(handle: handle, result: "the answer")
        return sessionID
    }

    @MainActor
    @Test("a delivered result reads back through the chat's own read path")
    func theResultReadsBack() async throws {
        let repository = try Self.makeRepository()
        let sessionID = await Self.deliver(into: repository)

        let messages = try await repository.loadMessages(
            sessionId: SessionID(rawValue: sessionID),
            bookID: nil
        )

        #expect(messages.count == 1, "the delivered result must read back")
        #expect(messages.first?.content.contains("the answer") == true)
    }

    @MainActor
    @Test("the row carries the source the enum spells, and the reader knows it")
    func theRowCarriesTheSourceTheEnumSpells() async throws {
        let repository = try Self.makeRepository()
        let sessionID = await Self.deliver(into: repository)

        let stored = try await repository.loadMessages(
            sessionId: SessionID(rawValue: sessionID),
            bookID: nil
        )

        // The spelling is the enum's, = and the reader parses the
        // enum's, = so they cannot drift apart.
        #expect(ChatSource.agentResult.rawValue == "agent_result")
        #expect(stored.first?.source == .agentResult)
    }

    @MainActor
    @Test("the result is not read as the main agent's reply")
    func theResultIsNotTheMainAgentsReply() async throws {
        let repository = try Self.makeRepository()
        let sessionID = await Self.deliver(into: repository)

        let messages = try await repository.loadMessages(
            sessionId: SessionID(rawValue: sessionID),
            bookID: nil
        )

        let message = try #require(messages.first)
        #expect(message.source == .agentResult)
        #expect(message.source != .wenshu, "the main agent's reply is a different thing")
        #expect(message.role == .agentResult)
    }

    @MainActor
    @Test("every source round-trips, because the fix touched the shared mapping")
    func everySourceRoundTrips() async throws {
        let repository = try Self.makeRepository()
        let sessionID = SessionID(rawValue: "session-sources")

        for source in [ChatSource.user, .wenshu, .system, .agentResult] {
            try await repository.append(
                ChatMessage(role: .agent, source: source, content: "a \(source.rawValue) message"),
                sessionId: sessionID,
                bookID: nil
            )
        }

        let messages = try await repository.loadMessages(sessionId: sessionID, bookID: nil)

        #expect(messages.count == 4, "every source must read back")
        #expect(Set(messages.map(\.source)) == Set([.user, .wenshu, .system, .agentResult]))
    }
}
