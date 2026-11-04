//
//  Tests/Chat/SubAgentResultDeliveryTests.swift · Wenshu
//
//  Verifies that a finished sub-agent's result reaches the
//  conversation that asked for it, exactly once.
//
//  Why this test exists (= the gap it closes):
//
//  The delegation marked itself completed, = the result sat in the
//  registry's in-memory record, = and the chat showed a dispatch
//  receipt and then nothing. = The result reached nobody.
//
//  What is pinned here:
//
//  1. The result lands in the ASKING conversation. = A background run
//     can finish minutes later, = and by then the user may have
//     opened another session. = The result must not follow the user
//     to whatever session happens to be open.
//  2. The result lands ONCE. = A retried delivery, = or a delivery
//     that runs twice because the registry was drained twice, = must
//     not show the same result twice.
//  3. A run with no scope has nowhere to go. = That is not an
//     error, = it is the shape of "nobody asked for this".
//  4. A failing write does not throw. = The run already finished, =
//     and its outcome is in the ledger; = a conversation that could
//     not be written to must not turn that into a failed run.
//
//  The repository is a fake, = so the test does not need the
//  SwiftData stack.
//

import Foundation
import Testing
import WenshuAgent
@testable import WenshuApp
import WenshuData

/// A repository that keeps what it was given, = so the test can ask
/// "what does the conversation show now?".
@MainActor
final class RecordingChatRepository: ChatRepositoryProtocol {
    /// Every message written, = in order.
    private(set) var appended: [ChatMessage] = []
    /// The bookID every append carried.
    private(set) var appendBookIDs: [BookID?] = []
    /// The session every append carried.
    private(set) var appendSessionIDs: [SessionID] = []
    /// When set, = every append throws it.
    var appendError: Error?

    func append(_ message: ChatMessage, sessionId: SessionID, bookID: BookID?) async throws {
        appendBookIDs.append(bookID)
        appendSessionIDs.append(sessionId)
        if let appendError { throw appendError }
        appended.append(message)
    }

    /// What the conversation holds, = per session and book.
    ///
    /// This has to be real: = the once-check asks the repository what
    /// is already there, = and a fake that always answered "nothing"
    /// would make the second delivery write a second row, = which
    /// would make the once-test pass for the wrong reason.
    private func storedMessages(sessionId: SessionID, bookID: BookID?) -> [ChatMessage] {
        var result: [ChatMessage] = []
        for (index, message) in appended.enumerated() {
            let sameSession = appendSessionIDs[index] == sessionId
            let sameBook = appendBookIDs[index]?.rawValue == bookID?.rawValue
            if sameSession && sameBook {
                result.append(message)
            }
        }
        return result
    }

    func loadMessages(sessionId: SessionID, bookID: BookID?) async throws -> [ChatMessage] {
        storedMessages(sessionId: sessionId, bookID: bookID)
    }

    func summarizeIfNeeded(
        sessionId: SessionID,
        lastN: Int,
        threshold: Int,
        verifier: WenshuVerifier,
        bookID: BookID?
    ) async throws {
    }

    func copyChatUpload(sourceURL: URL, intoLibraryAt path: String) async throws -> String? {
        nil
    }
}

/// Builds a handle the way the delegation does.
private func makeHandle(
    id: String,
    agentName: String = "researcher",
    scope: AgentScope? = nil
) -> BackgroundDelegationHandle {
    BackgroundDelegationHandle(
        id: id,
        agentName: agentName,
        userMessage: "find me something",
        scope: scope
    )
}

@Suite("A sub-agent's result reaches the conversation that asked for it")
struct SubAgentResultDeliveryTests {

    @MainActor
    @Test("the result lands in the asking conversation, not the open one")
    func landsInTheAskingConversation() async throws {
        let repository = RecordingChatRepository()
        let delivery = SubAgentResultDelivery(repository: repository)

        let asking = AgentScope(
            sessionID: SessionID(rawValue: "session-asking"),
            bookID: BookID(rawValue: "book-A")
        )
        let handle = makeHandle(id: "run-1", scope: asking)

        let outcome = await delivery.deliver(handle: handle, result: "the answer")

        #expect(outcome == .delivered)
        #expect(repository.appended.count == 1)
        #expect(repository.appendSessionIDs.first?.rawValue == "session-asking")
        #expect(repository.appendBookIDs.first??.rawValue == "book-A")
    }

    @MainActor
    @Test("the result lands once, even when the delivery runs twice")
    func landsOnce() async throws {
        let repository = RecordingChatRepository()
        let delivery = SubAgentResultDelivery(repository: repository)

        let scope = AgentScope(sessionID: SessionID(rawValue: "session-a"), bookID: nil)
        let handle = makeHandle(id: "run-2", scope: scope)

        let first = await delivery.deliver(handle: handle, result: "the answer")
        let second = await delivery.deliver(handle: handle, result: "the answer")

        #expect(first == .delivered)
        #expect(second == .delivered)
        // The second attempt found the row already there, = so it did
        // NOT write a second one.
        #expect(repository.appended.count == 1)
    }

    @MainActor
    @Test("two different runs each land their own result")
    func differentRunsLandSeparately() async throws {
        let repository = RecordingChatRepository()
        let delivery = SubAgentResultDelivery(repository: repository)

        let scope = AgentScope(sessionID: SessionID(rawValue: "session-a"), bookID: nil)
        _ = await delivery.deliver(handle: makeHandle(id: "run-a", scope: scope), result: "first")
        _ = await delivery.deliver(handle: makeHandle(id: "run-b", scope: scope), result: "second")

        #expect(repository.appended.count == 2)
        let contents = repository.appended.map(\.content)
        #expect(contents.contains { $0.hasSuffix("first") })
        #expect(contents.contains { $0.hasSuffix("second") })
    }

    @MainActor
    @Test("a run with no scope has nowhere to go, and that is not an error")
    func noScopeIsNoDestination() async throws {
        let repository = RecordingChatRepository()
        let delivery = SubAgentResultDelivery(repository: repository)

        let outcome = await delivery.deliver(handle: makeHandle(id: "run-3"), result: "the answer")

        #expect(outcome == .noDestination)
        #expect(repository.appended.isEmpty)
    }

    @MainActor
    @Test("a failing write reports the failure instead of throwing")
    func failingWriteIsReportedNotThrown() async throws {
        struct Boom: Error {}
        let repository = RecordingChatRepository()
        repository.appendError = Boom()
        let delivery = SubAgentResultDelivery(repository: repository)

        let scope = AgentScope(sessionID: SessionID(rawValue: "session-a"), bookID: nil)
        let outcome = await delivery.deliver(
            handle: makeHandle(id: "run-4", scope: scope),
            result: "the answer"
        )

        guard case .failed = outcome else {
            Issue.record("expected a failed outcome, got \(outcome)")
            return
        }
    }

    @MainActor
    @Test("the result says which agent produced it")
    func namesTheProducingAgent() async throws {
        let repository = RecordingChatRepository()
        let delivery = SubAgentResultDelivery(repository: repository)

        let scope = AgentScope(sessionID: SessionID(rawValue: "session-a"), bookID: nil)
        _ = await delivery.deliver(
            handle: makeHandle(id: "run-5", agentName: "librarian", scope: scope),
            result: "the answer"
        )

        let content = try #require(repository.appended.first?.content)
        #expect(content.contains("Librarian"))
        #expect(content.contains("the answer"))
    }

    @MainActor
    @Test("the message carries the sub-agent's own source, not the main agent's")
    func carriesItsOwnSource() async throws {
        let repository = RecordingChatRepository()
        let delivery = SubAgentResultDelivery(repository: repository)

        let scope = AgentScope(sessionID: SessionID(rawValue: "session-a"), bookID: nil)
        _ = await delivery.deliver(handle: makeHandle(id: "run-6", scope: scope), result: "the answer")

        let message = try #require(repository.appended.first)
        #expect(message.source == .agentResult)
        #expect(message.role == .agentResult)
    }

    @Test("the message id is derived from the run, so it is a UUID and it is stable")
    func messageIDIsStableAndAUUID() throws {
        let first = SubAgentResultDelivery.messageID(for: "run-7")
        let second = SubAgentResultDelivery.messageID(for: "run-7")
        let other = SubAgentResultDelivery.messageID(for: "run-8")

        #expect(first == second)
        #expect(first != other)
        // The read path drops a row whose id is not a UUID, = so the
        // derived id has to be one.
        #expect(first.uuidString.count == 36)
    }
}
