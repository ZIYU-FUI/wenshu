//
//  ChatContextUsagePersistenceTests.swift · Wenshu
//
//  The meter in the chat bar answers from the conversation's own stored
//  reading, so a relaunch restores the number with the messages it
//  describes. The defect these tests close: the reading lived only in
//  `ContextUsageRecorder`, a process-local actor, so the transcript came
//  back from SwiftData and the meter did not.
//
//  Most cases use a session id this process has never recorded against,
//  so the recorder's own-scope lookup is empty by construction and the
//  durable path is the only one that can answer. That is the relaunch.
//  The one case that DOES record against its session id checks the other
//  half of the order: a live reading wins over the stored one.
//

import Foundation
import SwiftData
import Testing
import WenshuAgent
@testable import WenshuApp
import WenshuData

@Suite("Chat context reading survives a relaunch")
struct ChatContextUsagePersistenceTests {

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        try WSPersistenceContainer.makeInMemoryContainer()
    }

    /// A reading with every field the meter and the breakdown popover show.
    private func makeReading(prompt: Int, window: Int) -> ContextUsageSnapshot {
        ContextUsageSnapshot(
            promptTokens: prompt,
            completionTokens: 40,
            cacheReadTokens: 1_020,
            cacheCreationTokens: 18,
            contextWindow: window,
            categories: [
                ContextUsageCategory(id: .systemPrompt, tokens: 300),
                ContextUsageCategory(id: .toolSchemas, tokens: 120),
                ContextUsageCategory(id: .messages, tokens: 700),
                ContextUsageCategory(id: .toolResults, tokens: 60),
                ContextUsageCategory(id: .memory, tokens: 20),
            ],
            compressed: true
        )
    }

    private func uniqueScope(_ tag: String) -> (SessionID, BookID?) {
        (SessionID(rawValue: "relaunch-\(tag)-\(UUID().uuidString.prefix(8))"), nil)
    }

    @Test("a stored reading is what the meter shows before any send")
    @MainActor
    func relaunchRestoresTheReadingOfTheConversationOnScreen() async throws {
        let container = try makeContainer()
        let live = LiveChatRepository(container: container)
        let (sessionId, bookID) = uniqueScope("restore")
        let reading = makeReading(prompt: 12_000, window: 200_000)

        try await live.saveContextUsage(reading, sessionId: sessionId, bookID: bookID)

        // A fresh view model on the same store = the app after a relaunch.
        let vm = ChatViewModel(
            sessionId: sessionId,
            repository: live,
            bookID: bookID,
            providersConfigured: { true }
        )
        await vm.refreshContextUsage()

        #expect(vm.contextUsage == reading)
        let gauge = try #require(vm.contextUsage)
        #expect(gauge.promptTokens == 12_000)
        #expect(gauge.contextWindow == 200_000)
        #expect(gauge.occupancy == 0.06)
        #expect(gauge.categories.count == 5)
        #expect(gauge.cacheReadTokens == 1_020)
        #expect(gauge.compressed)
    }

    @Test("a reading is never restored under a different conversation")
    @MainActor
    func storedReadingDoesNotCrossScopes() async throws {
        let container = try makeContainer()
        let live = LiveChatRepository(container: container)
        let (writtenScope, _) = uniqueScope("owner")
        let (otherScope, _) = uniqueScope("visitor")

        try await live.saveContextUsage(
            makeReading(prompt: 9_000, window: 100_000),
            sessionId: writtenScope,
            bookID: nil
        )

        #expect(try await live.loadContextUsage(sessionId: otherScope, bookID: nil) == nil)

        let vm = ChatViewModel(
            sessionId: otherScope,
            repository: live,
            providersConfigured: { true }
        )
        // The other conversation's number must not be the answer here. The
        // in-process recorder may hold some other suite's reading, so the
        // assertion is that the durable store was not the source.
        await vm.refreshContextUsage()
        #expect(vm.contextUsage?.promptTokens != 9_000)
    }

    @Test("a turn's live reading is written to the conversation's row")
    @MainActor
    func liveReadingIsPersisted() async throws {
        let container = try makeContainer()
        let live = LiveChatRepository(container: container)
        let (sessionId, bookID) = uniqueScope("write")
        let reading = makeReading(prompt: 3_300, window: 200_000)
        await ContextUsageRecorder.shared.record(conversationId: sessionId.rawValue, snapshot: reading)

        let vm = ChatViewModel(
            sessionId: sessionId,
            repository: live,
            bookID: bookID,
            providersConfigured: { true }
        )
        await vm.refreshContextUsage()

        #expect(vm.contextUsage == reading)
        #expect(try await live.loadContextUsage(sessionId: sessionId, bookID: bookID) == reading)
    }

    @Test("the book half of the scope is carried into the stored reading")
    @MainActor
    func readingIsScopedToItsBook() async throws {
        let container = try makeContainer()
        let live = LiveChatRepository(container: container)
        let sessionId = SessionID(rawValue: "relaunch-bookscope-\(UUID().uuidString.prefix(8))")
        let bookA = BookID(rawValue: "relaunch-book-A")
        let bookB = BookID(rawValue: "relaunch-book-B")

        try await live.saveContextUsage(
            makeReading(prompt: 500, window: 200_000),
            sessionId: sessionId,
            bookID: bookA
        )

        #expect(try await live.loadContextUsage(sessionId: sessionId, bookID: bookB) == nil)
        #expect(try await live.loadContextUsage(sessionId: sessionId, bookID: nil) == nil)
        #expect(
            try await live.loadContextUsage(sessionId: sessionId, bookID: bookA)?
                .promptTokens == 500
        )
    }

    @Test("the relaunch path itself restores the reading (= the trigger, not just the seam)")
    @MainActor
    func theRelaunchTriggerRestoresTheReading() async throws {
        let container = try makeContainer()
        let live = LiveChatRepository(container: container)
        let (sessionId, bookID) = uniqueScope("trigger")
        let reading = makeReading(prompt: 15_500, window: 200_000)

        try await live.saveContextUsage(reading, sessionId: sessionId, bookID: bookID)

        // The app's own relaunch path is `ChatView.task` -> `loadAvailableModels`
        // -> `refreshContextUsage` (= the models list is what the view asks
        // for first, and it asks the meter on the way). So the trigger is
        // what has to work, = = and this drives it directly instead of
        // calling the seam the trigger happens to call.
        let vm = ChatViewModel(
            sessionId: sessionId,
            repository: live,
            bookID: bookID,
            providersConfigured: { true }
        )
        await vm.loadAvailableModels()

        #expect(vm.contextUsage == reading)
    }

    @Test("a payload that does not decode is not a number this conversation may show")
    @MainActor
    func unreadablePayloadIsNotAGuess() async throws {
        let container = try makeContainer()
        let (sessionId, bookID) = uniqueScope("corrupt")
        // Write the payload behind the adapter's encoder (= a row written by
        // a shape this build cannot read).
        try await WSChatRepository(container: container).saveContextUsage(
            "{ this is not a reading }",
            sessionId: sessionId.rawValue,
            bookID: bookID?.rawValue
        )

        let live = LiveChatRepository(container: container)
        // The seam answers by throwing, because "there is a reading here and
        // I cannot read it" is not the same answer as "there is none".
        await #expect(throws: (any Error).self) {
            try await live.loadContextUsage(sessionId: sessionId, bookID: bookID)
        }

        // And the METER half: the unreadable row must not send the meter to
        // another conversation's live reading, which is the number the
        // recorder hands out when the scope on screen has none of its own.
        let otherScope = SessionID(rawValue: "relaunch-other-\(UUID().uuidString.prefix(8))")
        await ContextUsageRecorder.shared.record(
            conversationId: otherScope.rawValue,
            snapshot: makeReading(prompt: 77_000, window: 200_000)
        )

        let vm = ChatViewModel(
            sessionId: sessionId,
            repository: live,
            bookID: bookID,
            providersConfigured: { true }
        )
        await vm.refreshContextUsage()
        #expect(vm.contextUsage == nil)
    }
}
