//
//  ChatSealedMessageRuleTests.swift · WenshuApp
//
//  What "the last sealed message" means (= = the rule the ⌥C copy and
//  the ⌥A append ask the model for).
//
//  WHY THIS RULE IS ITS OWN
//  =========================
//  The two shortcuts say "the last SEALED message" (= = the reply whose
//  turn is over). Their old rule was "the last row that is not a
//  placeholder", = = and that stopped meaning "sealed" the moment the
//  streaming reply started DRAWING: the placeholder flag is cleared on
//  the FIRST FRAME (= so the row shows its parts while they arrive), = =
//  so a row that is still receiving is no longer a placeholder.
//
//  Under the old rule, ⌥C pasted a half-written reply. The rule now
//  lives in the model (= = `lastSealedMessage`), = = and the tests
//  below are BEHAVIOUR tests: they build messages, = = and they read
//  what the model answers.
//

import Foundation
import Testing
import WenshuAgent
@testable import WenshuApp
import WenshuData

@MainActor
@Suite("The sealed-message rule (= = what the copy and the append ask for)")
struct ChatSealedMessageRuleTests {
    /// A message whose turn is over.
    private static func sealedMessage(_ content: String) -> ChatMessage {
        ChatMessage(
            role: .agent,
            source: .wenshu,
            content: content,
            streamState: .sealed
        )
    }

    /// A message whose reply is still arriving.
    ///
    /// It is NOT a placeholder (= = the flag was cleared on the first
    /// frame, = = so the row draws its parts while they arrive), = =
    /// which is exactly the case the old rule got wrong.
    private static func arrivingMessage(_ content: String) -> ChatMessage {
        var message = ChatMessage(
            role: .agent,
            source: .wenshu,
            content: content,
            streamState: .streaming
        )
        message.isPlaceholder = false
        return message
    }

    @Test("A reply that is still arriving is not the last sealed message")
    func anArrivingReplyIsNotSealed() {
        let model = ChatViewModel(
            initialMessages: [
                Self.sealedMessage("the finished answer"),
                Self.arrivingMessage("the half-written ans"),
            ],
            repository: SealedRuleChatRepository(),
            providersConfigured: { true }
        )

        #expect(
            model.lastSealedMessage?.content == "the finished answer",
            "the rule must skip the reply that is still arriving"
        )
    }

    @Test("A row that still carries the placeholder flag is not sealed either")
    func aPlaceholderIsNotSealed() {
        let model = ChatViewModel(
            initialMessages: [
                Self.sealedMessage("the finished answer"),
                ChatMessage(role: .agent, source: .wenshu, content: "", isPlaceholder: true),
            ],
            repository: SealedRuleChatRepository(),
            providersConfigured: { true }
        )

        #expect(
            model.lastSealedMessage?.content == "the finished answer",
            "the placeholder row is not a sealed message"
        )
    }

    @Test("The newest sealed message wins")
    func theNewestSealedMessageWins() {
        let model = ChatViewModel(
            initialMessages: [
                Self.sealedMessage("the older answer"),
                Self.sealedMessage("the newer answer"),
            ],
            repository: SealedRuleChatRepository(),
            providersConfigured: { true }
        )

        #expect(model.lastSealedMessage?.content == "the newer answer")
    }

    @Test("A conversation with no sealed message has none")
    func noSealedMessageMeansNone() {
        let model = ChatViewModel(
            initialMessages: [Self.arrivingMessage("still arriving")],
            repository: SealedRuleChatRepository(),
            providersConfigured: { true }
        )

        #expect(model.lastSealedMessage == nil)
    }

    @Test("A restored session still has a last sealed message")
    func aRestoredSessionHasOne() {
        // The persisted read path never writes the stream's state (= a
        // stored message keeps its words, = = not the fact that it was
        // streaming when it was written), = = so a restored row carries
        // the DEFAULT state (= .idle).
        //
        // MEASURED: with the rule "the state is .sealed", the restored
        // row was NOT sealed, = = and ⌥C / ⌥A went silent after a
        // restart (= = they copied nothing at all).
        //
        // The row here is built through the production read path (= =
        // `LiveChatRepository.makeDomain`), = = so the case measures the
        // mapping and not a hand-made message.
        let stored = WSChatMessage(
            id: UUID().uuidString,
            sessionID: "session-1",
            role: ChatSource.wenshu.rawValue,
            content: "the answer from last week",
            position: 0
        )
        guard let restored = LiveChatRepository.makeDomain(from: stored) else {
            Issue.record(Comment("the production read path must map the stored row"))
            return
        }
        #expect(restored.streamState == .idle,
                Comment("a restored row carries the default state (= = the store does not keep it)"))

        let model = ChatViewModel(
            initialMessages: [restored],
            repository: SealedRuleChatRepository(messages: []),
            providersConfigured: { true }
        )
        #expect(model.lastSealedMessage?.content == "the answer from last week",
                Comment("a restored session must still have a last sealed message"))
    }
}

/// The repository these tests need (= = nothing): the rule is about
/// the messages, = = and the repository is only there because the model
/// asks for one.
private final class SealedRuleChatRepository: ChatRepositoryProtocol, @unchecked Sendable {
    /// The messages a restored session would load (= = the cases that
    /// need the load path use it).
    let messages: [ChatMessage]

    init(messages: [ChatMessage] = []) {
        self.messages = messages
    }

    func append(_: ChatMessage, sessionId _: SessionID, bookID _: BookID?) async throws {}

    func loadMessages(sessionId _: SessionID, bookID _: BookID?) async throws -> [ChatMessage] {
        []
    }

    func summarizeIfNeeded(
        sessionId _: SessionID,
        lastN _: Int,
        threshold _: Int,
        verifier _: WenshuVerifier,
        bookID _: BookID?
    ) async throws {}

    func copyChatUpload(sourceURL _: URL, intoLibraryAt _: String) async throws -> String? {
        nil
    }
}
