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
//  6. The conversation is WIRED to the delivery's notification: = it
//     observes the delivery's name, = and what it does about that
//     notification is the adoption.
//
//  WHY THE ADOPTION IS CALLED DIRECTLY AND NOT THROUGH THE BUS:
//
//  The notification bus is global. = A whole-suite run has dozens of
//  open conversations on it, = every notification a test posts
//  reaches every one of them, = and every one of them queues a
//  main-actor task. = So a test that goes through the bus measures
//  the suite's contention and not the adoption: = it passed alone
//  and failed in the whole suite, = and the diagnostic showed the
//  message found and appended = in a conversation that was not the
//  one under test.
//
//  So the adoption's CONTRACT is tested by calling it, = and the
//  WIRING is pinned by reading the source. = Between them, = the
//  delivery's own test (= it writes the row and names it), = the
//  adoption's contract (= what a conversation does with that name),
//  and the wiring (= the conversation observes that name and calls
//  the adoption), = every link in the chain is held by a test that
//  can fail.
//
//  The fake does not hide the answer either: = it returns EVERY
//  session's messages, = so removing the session check lets the
//  adopter find a message that belongs to another conversation, =
//  and the test that says "a reply belongs to the conversation that
//  asked for it" has to be able to fail.
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

    // MARK: - The helpers

    /// Deliver a result through the production delivery, = and return
    /// the message id it wrote.
    @MainActor
    private static func deliver(
        _ repository: AdoptionChatRepository,
        runID: String,
        sessionID: SessionID,
        bookID: BookID?,
        result: String
    ) async -> UUID {
        let delivery = SubAgentResultDelivery(repository: repository)
        let handle = BackgroundDelegationHandle(
            id: runID,
            agentName: "researcher",
            userMessage: "find something",
            scope: AgentScope(sessionID: sessionID, bookID: bookID)
        )
        _ = await delivery.deliver(handle: handle, result: result)
        return SubAgentResultDelivery.messageID(for: runID)
    }

    /// Tell the conversation that a result landed, = the way the
    /// notification does.
    ///
    /// The bus is not used, = because the bus is global and a
    /// whole-suite run has dozens of conversations on it. = What the
    /// bus does is call this, = and the wiring test below pins that.
    @MainActor
    private static func tell(
        _ vm: ChatViewModel,
        sessionID: String,
        messageID: UUID
    ) async {
        await vm.adoptDeliveredSubAgentResult(
            sessionID: sessionID,
            messageID: messageID.uuidString
        )
    }

    // MARK: - The contract

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

        // The production path: = the delivery writes the result into
        // the asking conversation and says so.
        let messageID = await Self.deliver(
            repository,
            runID: "run-arrival",
            sessionID: vm.testSessionId,
            bookID: vm.currentBookID,
            result: "the answer"
        )

        await Self.tell(vm, sessionID: vm.testSessionId.rawValue, messageID: messageID)

        #expect(vm.messages.contains { $0.id == messageID },
                "the result must reach the conversation that asked for it")
        // The body is the agent's label and then the result, = so the
        // user can see who answered.
        let content = vm.messages.first { $0.id == messageID }?.content ?? ""
        #expect(content.contains("the answer"), "the result must be in the body")
        #expect(content.hasPrefix(SubAgentRoleRegistry.role(forSlug: "researcher")?.displayLabel ?? ""),
                "and the body must say which agent answered")
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
        let otherID = await Self.deliver(
            repository,
            runID: "run-other",
            sessionID: SessionID(rawValue: "some-other-session"),
            bookID: vm.currentBookID,
            result: "another answer"
        )

        // The sentinel: = a result for THIS conversation. = When it
        // arrives, = the adoption works, = so the absence of the other
        // one is a fact and not a guess.
        let sentinelID = await Self.deliver(
            repository,
            runID: "run-sentinel",
            sessionID: vm.testSessionId,
            bookID: vm.currentBookID,
            result: "this answer"
        )

        await Self.tell(vm, sessionID: "some-other-session", messageID: otherID)
        await Self.tell(vm, sessionID: vm.testSessionId.rawValue, messageID: sentinelID)

        #expect(vm.messages.contains { $0.id == sentinelID },
                "the sentinel must arrive, = or the rest proves nothing")
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

        let messageID = await Self.deliver(
            repository,
            runID: "run-twice",
            sessionID: vm.testSessionId,
            bookID: vm.currentBookID,
            result: "the answer"
        )

        // The same notification, = a second time. = Two deliveries for
        // one result arrive together, = both see that the message is
        // not here yet, = and both would append it.
        await Self.tell(vm, sessionID: vm.testSessionId.rawValue, messageID: messageID)
        await Self.tell(vm, sessionID: vm.testSessionId.rawValue, messageID: messageID)

        let count = vm.messages.filter { $0.id == messageID }.count
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

        let messageID = await Self.deliver(
            repository,
            runID: "run-already",
            sessionID: vm.testSessionId,
            bookID: vm.currentBookID,
            result: "the answer"
        )

        // The conversation already shows it: = a reload ran between
        // the write and the notification.
        if let stored = repository.appended.first(where: { $0.id == messageID }) {
            vm.messages.append(stored)
        }

        await Self.tell(vm, sessionID: vm.testSessionId.rawValue, messageID: messageID)

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

    // MARK: - The wiring

    /// The conversation observes the delivery's notification, = and what
    /// it does about that notification is the adoption.
    ///
    /// This is read from the source and not from the bus, = because
    /// the bus is global and a whole-suite run has dozens of
    /// conversations on it. = The assertion is scoped to the observer
    /// block, = because the same call appears elsewhere in the file
    /// and an unscoped assertion would be satisfied by the wrong
    /// occurrence.
    @Test("the conversation observes the delivery's notification and adopts what it names")
    func theConversationIsWiredToTheDelivery() throws {
        let source = try Self.viewModelURLs()
            .map { try String(contentsOf: $0, encoding: .utf8) }
            .joined(separator: "\n")

        let observerStart = try #require(
            source.range(of: "forName: Notification.Name(AppStateEvents.subAgentResultDelivered.rawValue)"),
            "the conversation must observe the delivery's notification"
        )
        // The observation itself: = an observer for that name.
        let callStart = source.index(observerStart.lowerBound, offsetBy: -200, limitedBy: source.startIndex)
            ?? source.startIndex
        let call = source[callStart..<observerStart.upperBound]
        #expect(call.contains("addObserver("),
                "the observation must be an observer")
        // The block is the observer's CLOSURE, = found by matching
        // braces from the closure's opening brace.
        //
        // A fixed window would be brittle: = the closure carries a
        // long comment, = so a window sized for the code misses the
        // code, = and a window sized for the comment reaches into
        // the next observer. = The braces say where it ends.
        let open = try #require(
            source.range(of: "{", range: observerStart.lowerBound..<source.endIndex),
            "the observer's closure must open"
        )
        var depth = 0
        var close: String.Index?
        var index = open.lowerBound
        while index < source.endIndex {
            if source[index] == "{" { depth += 1 }
            if source[index] == "}" {
                depth -= 1
                if depth == 0 { close = index; break }
            }
            index = source.index(after: index)
        }
        let end = try #require(close, "the observer's closure must close")
        let block = source[open.lowerBound...end]

        #expect(block.contains("adoptDeliveredSubAgentResult("),
                "and what it does about the notification must be the adoption")
        #expect(block.contains("\"sessionID\"") && block.contains("\"messageID\""),
                "and it must read the two ids the delivery names")
        // It must FORWARD the ids it read. = A call that passes
        // something else ( = nil, = or a constant) = still contains
        // the call, = so the assertion above would pass, = and the
        // result would never land. = This is the mutation that showed
        // it: = the call was there, = the ids were nil, = and the
        // suite was green.
        #expect(block.contains("sessionID: sessionID"),
                "and it must forward the session id it read")
        #expect(block.contains("messageID: messageID"),
                "and it must forward the message id it read")
    }

    /// The view model's source, = found beside the test.
    ///
    /// The path is built from the test's own path, = so a checkout
    /// that is moved still finds it. = A hardcoded absolute path
    /// would not.
    private static func viewModelURLs() -> [URL] {
        // .../Tests/WenshuAppTests/Chat/<this file>
        // .../Sources/WenshuApp/Features/Chat/Store/<the view model's files>
        var root = URL(fileURLWithPath: #filePath)
        root.deleteLastPathComponent()   // Chat
        root.deleteLastPathComponent()   // WenshuAppTests
        root.deleteLastPathComponent()   // Tests
        root.deleteLastPathComponent()   // the repository root
        root.appendPathComponent("Sources/WenshuApp/Features/Chat/Store")
        // The view model's source is spread over the files the split left
        // it in, = = so the reader takes ALL of them and joins them with a
        // newline: = = a token is then counted the same way it was counted
        // when the file was one.
        return ["ChatViewModel.swift", "ChatViewModel+Session.swift"]
            .map { root.appendingPathComponent($0) }
    }
}

/// A box the notification observer writes into, = because a
/// notification's closure cannot await and = cannot hand a value
/// back to the test directly.
final class NotificationBox: @unchecked Sendable {
    var sessionID: String?
    var messageID: String?
}
