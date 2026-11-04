//
//  Tests/Chat/SubAgentResultAdoptionTests.swift · Wenshu
//
//  A sub-agent's result shows up in the conversation that asked
//  for it.
//
//  Why this test exists (= the gap it closes):
//
//  The delivery writes the result to the session on disk. = The chat
//  that is showing that session holds a snapshot of its messages, =
//  and the snapshot was taken before the result landed. = So the
//  answer was on disk and nowhere else: = the user found it by
//  reopening the conversation, = and not before.
//
//  What is pinned here:
//
//  1. A result that lands in the open session shows up in it.
//  2. A result for ANOTHER session does not. = A reply belongs to the
//     conversation that asked for it.
//  3. The same result twice does not show up twice.
//  4. A result that is already shown is not shown again.
//  5. The delivery says what it wrote: = the session id and the
//     message id, = so the receiver can find the one message it
//     needs.
//
//  Two things had to be true for this suite to mean anything.
//
//  First: the notification bus is global. = A test that posts a
//  notification reaches EVERY open conversation, = so two
//  conversations with the same session id (= the default one, = for
//  a conversation with no book) = would adopt each other's
//  messages. = Each test here takes its own book, = and so its own
//  session id.
//
//  Second: the wait is for a CONDITION and not for a duration. = The
//  delivery hops to the main actor, = so a fixed sleep is a
//  load-sensitive assertion: = under load the main actor's queue
//  does not get to the notification before the sleep ends, = and the
//  suite fails for a reason that has nothing to do with the code.
//  = It failed that way, = and it was read as a defect in the
//  adoption. = The waits below poll until the conversation's count
//  of a message has settled, = and the duration is only the ceiling.
//
//  And the negative case (= a result for another session does not
//  show up here) = cannot wait for something that must never happen.
//  = So it posts a sentinel as well: = a result for THIS session,
//  = which the conversation takes in. = When the sentinel has
//  arrived, = the bus is live and the delivery works, = and the
//  absence of the other session's result is then a fact and not a
//  guess.
//

import Foundation
import Testing
import WenshuAgent
@testable import WenshuApp
import WenshuData

/// A repository that keeps what it was given, = per session.
@MainActor
final class AdoptionChatRepository: ChatRepositoryProtocol {
    private(set) var appended: [ChatMessage] = []
    private var bySession: [String: [ChatMessage]] = [:]

    func append(_ message: ChatMessage, sessionId: SessionID, bookID: BookID?) async throws {
        appended.append(message)
        bySession[sessionId.rawValue, default: []].append(message)
    }

    func loadMessages(sessionId: SessionID, bookID: BookID?) async throws -> [ChatMessage] {
        // Every message, = not just this session's. = The fake must
        // not hide the answer: = if the session check were removed,
        // the adopter would find a message that belongs to another
        // conversation, = and the test that says "a reply belongs to
        // the conversation that asked for it" has to be able to fail.
        appended
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

@Suite("A sub-agent's result shows up in the conversation that asked for it")
struct SubAgentResultAdoptionTests {

    /// The notification the delivery posts.
    private static let delivered = Notification.Name(AppStateEvents.subAgentResultDelivered.rawValue)

    // MARK: - The waits

    /// Wait until the conversation's count of a message has settled.
    ///
    /// - Returns: the count when it settled (= the ceiling's count
    ///   if it never settled).
    @MainActor
    private static func waitForSettledCount(
        _ vm: ChatViewModel,
        of messageID: UUID,
        timeout: Duration = .seconds(10)
    ) async -> Int {
        let deadline = ContinuousClock.now + timeout
        var last = -1
        var stable = 0
        while ContinuousClock.now < deadline {
            let count = vm.messages.filter { $0.id == messageID }.count
            if count == last {
                stable += 1
                // Three quiet polls, = and the message has arrived.
                if count >= 1, stable >= 3 { return count }
            } else {
                stable = 0
                last = count
            }
            try? await Task.sleep(nanoseconds: 30_000_000)
        }
        return vm.messages.filter { $0.id == messageID }.count
    }

    /// Post the notification the delivery posts.
    private static func post(sessionID: String, messageID: UUID) {
        NotificationCenter.default.post(
            name: delivered,
            object: nil,
            userInfo: [
                "sessionID": sessionID,
                "messageID": messageID.uuidString
            ]
        )
    }

    // MARK: - The tests

    @MainActor
    @Test("a result that lands in the open session shows up in it")
    func aResultInTheOpenSessionShowsUp() async throws {
        let repository = AdoptionChatRepository()
        let vm = ChatViewModel(
            repository: repository,
            bookID: BookID(rawValue: "book-\(UUID().uuidString)"),
            providersConfigured: { true }
        )
        await vm.loadHistory()

        let messageID = UUID()
        try await repository.append(
            ChatMessage(id: messageID, role: .agentResult, source: .agentResult, content: "the answer"),
            sessionId: vm.testSessionId,
            bookID: vm.currentBookID
        )

        Self.post(sessionID: vm.testSessionId.rawValue, messageID: messageID)

        _ = await Self.waitForSettledCount(vm, of: messageID)

        #expect(vm.messages.contains { $0.id == messageID },
                "the result must reach the conversation that asked for it")
        #expect(vm.messages.first { $0.id == messageID }?.content == "the answer")
    }

    @MainActor
    @Test("a result for another session does not show up here")
    func aResultForAnotherSessionIsIgnored() async throws {
        let repository = AdoptionChatRepository()
        let vm = ChatViewModel(
            repository: repository,
            bookID: BookID(rawValue: "book-\(UUID().uuidString)"),
            providersConfigured: { true }
        )
        await vm.loadHistory()

        // The result that belongs to somebody else.
        let otherID = UUID()
        try await repository.append(
            ChatMessage(id: otherID, role: .agentResult, source: .agentResult, content: "another answer"),
            sessionId: SessionID(rawValue: "some-other-session"),
            bookID: vm.currentBookID
        )

        // The sentinel: = a result for THIS conversation. = When it
        // arrives, = the bus is live and the delivery works, = so the
        // absence of the other one is a fact.
        let sentinelID = UUID()
        try await repository.append(
            ChatMessage(id: sentinelID, role: .agentResult, source: .agentResult, content: "this answer"),
            sessionId: vm.testSessionId,
            bookID: vm.currentBookID
        )

        Self.post(sessionID: "some-other-session", messageID: otherID)
        Self.post(sessionID: vm.testSessionId.rawValue, messageID: sentinelID)

        let sentinelCount = await Self.waitForSettledCount(vm, of: sentinelID)

        #expect(sentinelCount == 1,
                "the sentinel must arrive, = or the bus was not live and the rest proves nothing")
        #expect(!vm.messages.contains { $0.id == otherID },
                "a reply belongs to the conversation that asked for it")
    }

    @MainActor
    @Test("the same result twice does not show up twice")
    func theSameResultTwiceShowsOnce() async throws {
        let repository = AdoptionChatRepository()
        let vm = ChatViewModel(
            repository: repository,
            bookID: BookID(rawValue: "book-\(UUID().uuidString)"),
            providersConfigured: { true }
        )
        await vm.loadHistory()

        let messageID = UUID()
        try await repository.append(
            ChatMessage(id: messageID, role: .agentResult, source: .agentResult, content: "the answer"),
            sessionId: vm.testSessionId,
            bookID: vm.currentBookID
        )

        Self.post(sessionID: vm.testSessionId.rawValue, messageID: messageID)
        Self.post(sessionID: vm.testSessionId.rawValue, messageID: messageID)

        let count = await Self.waitForSettledCount(vm, of: messageID)

        #expect(count == 1, "the result must show up exactly once")
    }

    @MainActor
    @Test("a result that is already shown is not shown again")
    func aResultAlreadyShownIsNotShownAgain() async throws {
        let repository = AdoptionChatRepository()
        let vm = ChatViewModel(
            repository: repository,
            bookID: BookID(rawValue: "book-\(UUID().uuidString)"),
            providersConfigured: { true }
        )
        await vm.loadHistory()

        let messageID = UUID()
        let message = ChatMessage(
            id: messageID,
            role: .agentResult,
            source: .agentResult,
            content: "the answer"
        )
        // The conversation already shows it: = a reload ran between
        // the write and the notification.
        vm.messages.append(message)
        try await repository.append(
            message,
            sessionId: vm.testSessionId,
            bookID: vm.currentBookID
        )

        Self.post(sessionID: vm.testSessionId.rawValue, messageID: messageID)

        let count = await Self.waitForSettledCount(vm, of: messageID)

        #expect(count == 1, "the result must show up exactly once")
    }

    @MainActor
    @Test("the delivery says which session and which message it wrote")
    func theDeliverySaysWhatItWrote() async throws {
        let repository = AdoptionChatRepository()
        let delivery = SubAgentResultDelivery(repository: repository)

        let sessionID = SessionID(rawValue: "session-asking")
        let handle = BackgroundDelegationHandle(
            id: "run-notify",
            agentName: "researcher",
            userMessage: "find something",
            scope: AgentScope(sessionID: sessionID, bookID: nil)
        )

        let box = NotificationBox()
        let token = NotificationCenter.default.addObserver(
            forName: Self.delivered,
            object: nil,
            queue: .main
        ) { notification in
            if notification.userInfo?["sessionID"] as? String == "session-asking" {
                box.sessionID = notification.userInfo?["sessionID"] as? String
                box.messageID = notification.userInfo?["messageID"] as? String
            }
        }
        defer { NotificationCenter.default.removeObserver(token) }

        _ = await delivery.deliver(handle: handle, result: "the answer")

        // The notification is posted on the delivering task, = so it
        // has landed by the time the delivery returns.
        #expect(box.sessionID == "session-asking")
        #expect(box.messageID != nil)
        #expect(repository.appended.count == 1)
    }
}

/// A box the notification observer writes into, = because a
/// notification's closure cannot await and = cannot hand a value
/// back to the test directly.
final class NotificationBox: @unchecked Sendable {
    var sessionID: String?
    var messageID: String?
}
