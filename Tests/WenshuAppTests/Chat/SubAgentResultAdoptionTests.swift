//
//  Tests/Chat/SubAgentResultAdoptionTests.swift · Wenshu
//
//  A result that landed in the open conversation shows up in it.
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
//  4. The delivery says what it wrote: = the session id and the
//     message id, = so the receiver can find the one message it
//     needs.
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

    @MainActor
    @Test("a result that lands in the open session shows up in it")
    func aResultInTheOpenSessionShowsUp() async throws {
        let repository = AdoptionChatRepository()
        let vm = ChatViewModel(repository: repository, providersConfigured: { true })
        await vm.loadHistory()

        let messageID = UUID()
        try await repository.append(
            ChatMessage(id: messageID, role: .agentResult, source: .agentResult, content: "the answer"),
            sessionId: vm.testSessionId,
            bookID: vm.currentBookID
        )

        NotificationCenter.default.post(
            name: Self.delivered,
            object: nil,
            userInfo: [
                "sessionID": vm.testSessionId.rawValue,
                "messageID": messageID.uuidString
            ]
        )

        // The adoption reads the message back asynchronously.
        try await Task.sleep(nanoseconds: 300_000_000)

        #expect(vm.messages.contains { $0.id == messageID },
                "the result must reach the conversation that asked for it")
        #expect(vm.messages.first { $0.id == messageID }?.content == "the answer")
    }

    @MainActor
    @Test("a result for another session does not show up here")
    func aResultForAnotherSessionIsIgnored() async throws {
        let repository = AdoptionChatRepository()
        let vm = ChatViewModel(repository: repository, providersConfigured: { true })
        await vm.loadHistory()

        let messageID = UUID()
        try await repository.append(
            ChatMessage(id: messageID, role: .agentResult, source: .agentResult, content: "another answer"),
            sessionId: SessionID(rawValue: "some-other-session"),
            bookID: vm.currentBookID
        )

        NotificationCenter.default.post(
            name: Self.delivered,
            object: nil,
            userInfo: [
                "sessionID": "some-other-session",
                "messageID": messageID.uuidString
            ]
        )

        try await Task.sleep(nanoseconds: 300_000_000)

        #expect(!vm.messages.contains { $0.id == messageID },
                "a reply belongs to the conversation that asked for it")
    }

    @MainActor
    @Test("the same result twice does not show up twice")
    func theSameResultTwiceShowsOnce() async throws {
        let repository = AdoptionChatRepository()
        let vm = ChatViewModel(repository: repository, providersConfigured: { true })
        await vm.loadHistory()

        let messageID = UUID()
        try await repository.append(
            ChatMessage(id: messageID, role: .agentResult, source: .agentResult, content: "the answer"),
            sessionId: vm.testSessionId,
            bookID: vm.currentBookID
        )

        for _ in 0..<2 {
            NotificationCenter.default.post(
                name: Self.delivered,
                object: nil,
                userInfo: [
                    "sessionID": vm.testSessionId.rawValue,
                    "messageID": messageID.uuidString
                ]
            )
        }

        try await Task.sleep(nanoseconds: 400_000_000)

        let count = vm.messages.filter { $0.id == messageID }.count
        #expect(count == 1, "the result must show up exactly once")
    }

    @MainActor
    @Test("a result that is already shown is not shown again")
    func aResultAlreadyShownIsNotShownAgain() async throws {
        let repository = AdoptionChatRepository()
        let vm = ChatViewModel(repository: repository, providersConfigured: { true })
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

        NotificationCenter.default.post(
            name: Self.delivered,
            object: nil,
            userInfo: [
                "sessionID": vm.testSessionId.rawValue,
                "messageID": messageID.uuidString
            ]
        )

        try await Task.sleep(nanoseconds: 400_000_000)

        let count = vm.messages.filter { $0.id == messageID }.count
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
