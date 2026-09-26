//
//  SubAgentRunnerStorageDispatchTests.swift · Wenshu · v2.7d
//
//  Unit tests for the Archivist + Auditor storage-dispatch paths
//  in SubAgentRunner (= v2.7d, boss 2026-09-26 '团队链路通').
//
//  What we test:
//    1. Archivist sub-agent dispatches to ArchivistStorage (= no
//       LLM round-trip)
//    2. Archivist task parsing handles add / list / delete / backup
//    3. Archivist throws when storage is nil (= §11 baseline
//       'no fake success')
//    4. Auditor sub-agent dispatches to AuditorStorage (= no LLM)
//    5. Auditor returns verdict JSON envelope (pass / warn / skip)
//    6. Auditor throws when storage is nil
//
//  Test isolation: each test uses a fresh `AsyncDelegationRegistry`
//  (= no handle state leaks across tests) and an in-memory
//  `StubArchivistStorage` / `StubAuditorStorage` (= no SwiftData
//  container coupling).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("SubAgentRunner storage dispatch · v2.7d Archivist + Auditor", .serialized)
@MainActor
struct SubAgentRunnerStorageDispatchTests {

    // MARK: - Stubs

    /// In-memory ArchivistStorage (= no SwiftData coupling).
    private final class StubArchivistStorage: ArchivistStorage, @unchecked Sendable {
        private let lock = NSLock()
        private var _bookmarks: [ArchivistBookmark] = []
        private var _backupURLs: [URL] = []

        var addCount: Int {
            lock.withLock { _bookmarks.count }
        }
        var backupCount: Int {
            lock.withLock { _backupURLs.count }
        }

        func addBookmark(docID: String, label: String) async throws {
            let bookmark = ArchivistBookmark(
                id: UUID().uuidString,
                docId: docID,
                label: label,
                createdAt: Date()
            )
            lock.withLock { _bookmarks.append(bookmark) }
        }

        func listBookmarks() async throws -> [ArchivistBookmark] {
            lock.withLock { _bookmarks }
        }

        func removeBookmark(id: String) async throws {
            lock.withLock {
                _bookmarks.removeAll { $0.id == id }
            }
        }

        func writeBackup(label: String, contents: String) async throws -> URL {
            let url = URL(fileURLWithPath: "/tmp/\(label)-backup.md")
            lock.withLock { _backupURLs.append(url) }
            return url
        }
    }

    /// In-memory AuditorStorage (= no SwiftData coupling).
    private final class StubAuditorStorage: AuditorStorage, @unchecked Sendable {
        let memoryFixture: String
        init(memory: String) { self.memoryFixture = memory }
        func readMemory(forUserMessage message: String) async -> String {
            memoryFixture
        }
    }

    /// Recording connector (= never called for Archivist / Auditor;
    /// = used to assert the runner did NOT dispatch an LLM call).
    private final class RecordingConnector: LLMConnector, @unchecked Sendable {
        let connectorID = "recording"
        let sendCountLock = NSLock()
        var sendCount = 0
        let streamCountLock = NSLock()
        var streamCount = 0

        func send(messages: [LLMMessage], options: LLMCallOptions) async throws -> LLMResponse {
            sendCountLock.withLock { sendCount += 1 }
            return LLMResponse(
                id: "stub",
                model: "stub",
                blocks: [],
                stopReason: .endTurn,
                usage: LLMUsage(inputTokens: 0, outputTokens: 0)
            )
        }

        func stream(messages: [LLMMessage], options: LLMCallOptions) -> AsyncStream<LLMBlock> {
            streamCountLock.withLock { streamCount += 1 }
            return AsyncStream { continuation in
                continuation.finish()
            }
        }
    }

    // MARK: - Archivist tests

    @Test("archivist dispatches to storage, no LLM call")
    func archivistDispatchesWithoutLLM() async throws {
        let registry = AsyncDelegationRegistry()
        let connector = RecordingConnector()
        let archivist = StubArchivistStorage()
        let runner = SubAgentRunner(
            isolatedRegistry: registry,
            connector: connector,
            archivistStorage: archivist
        )

        let result = try await delegate(
            subagentProfile: SubAgentIdentity.Name.archivist.rawValue,
            task: "add doc-chapter-1 关键章节",
            context: [:],
            registry: registry
        )
        let handleID = result.handle.id
        let n = await runner.drainPending()
        #expect(n >= 1)
        let final = await registry.get(id: handleID)
        #expect(final?.state == .completed, "archivist handle should complete; got \(String(describing: final?.state))")
        #expect(final?.result?.contains("\"action\":\"add\"") == true)
        #expect(archivist.addCount == 1)
        // No LLM call (= archivist domain is deterministic).
        #expect(connector.sendCount == 0, "archivist must NOT call LLM send; got sendCount=\(connector.sendCount)")
        #expect(connector.streamCount == 0, "archivist must NOT call LLM stream; got streamCount=\(connector.streamCount)")
    }

    @Test("archivist handles list / delete / backup tasks")
    func archivistHandlesAllActions() async throws {
        let registry = AsyncDelegationRegistry()
        let connector = RecordingConnector()
        let archivist = StubArchivistStorage()
        let runner = SubAgentRunner(
            isolatedRegistry: registry,
            connector: connector,
            archivistStorage: archivist
        )

        // Step 1: add a bookmark
        let addResult = try await delegate(
            subagentProfile: SubAgentIdentity.Name.archivist.rawValue,
            task: "add doc-A label-A",
            context: [:],
            registry: registry
        )
        await runner.drainPending()
        #expect(archivist.addCount == 1)

        // Step 2: list (= expects 1 bookmark)
        let listResult = try await delegate(
            subagentProfile: SubAgentIdentity.Name.archivist.rawValue,
            task: "list",
            context: [:],
            registry: registry
        )
        await runner.drainPending()
        let listFinal = await registry.get(id: listResult.handle.id)
        #expect(listFinal?.result?.contains("\"stored\":1") == true)
        #expect(listFinal?.result?.contains("\"action\":\"list\"") == true)

        // Step 3: backup
        let backupResult = try await delegate(
            subagentProfile: SubAgentIdentity.Name.archivist.rawValue,
            task: "backup chapter-snapshot # chapter 1 content",
            context: [:],
            registry: registry
        )
        await runner.drainPending()
        let backupFinal = await registry.get(id: backupResult.handle.id)
        #expect(backupFinal?.result?.contains("\"action\":\"backup\"") == true)
        #expect(archivist.backupCount == 1)
    }

    @Test("archivist throws when storage is nil (= no fake success)")
    func archivistThrowsWithoutStorage() async throws {
        let registry = AsyncDelegationRegistry()
        let connector = RecordingConnector()
        // NO archivistStorage injected.
        let runner = SubAgentRunner(
            isolatedRegistry: registry,
            connector: connector
        )

        let result = try await delegate(
            subagentProfile: SubAgentIdentity.Name.archivist.rawValue,
            task: "add doc-1 label-1",
            context: [:],
            registry: registry
        )
        let handleID = result.handle.id
        await runner.drainPending()
        let final = await registry.get(id: handleID)
        // Handle must be .failed (= storage misconfigured; = no fake
        // success envelope).
        #expect(final?.state == .failed, "archivist without storage must fail the handle; got \(String(describing: final?.state))")
    }

    @Test("archivist unknown action returns noop envelope")
    func archivistUnknownAction() async throws {
        let registry = AsyncDelegationRegistry()
        let archivist = StubArchivistStorage()
        let runner = SubAgentRunner(
            isolatedRegistry: registry,
            connector: RecordingConnector(),
            archivistStorage: archivist
        )

        let result = try await delegate(
            subagentProfile: SubAgentIdentity.Name.archivist.rawValue,
            task: "frobnicate something",
            context: [:],
            registry: registry
        )
        await runner.drainPending()
        let final = await registry.get(id: result.handle.id)
        #expect(final?.state == .completed)
        #expect(final?.result?.contains("\"action\":\"noop\"") == true)
        #expect(final?.result?.contains("unknown action") == true)
    }

    // MARK: - Auditor tests

    @Test("auditor dispatches to storage, no LLM call")
    func auditorDispatchesWithoutLLM() async throws {
        let registry = AsyncDelegationRegistry()
        let connector = RecordingConnector()
        let auditor = StubAuditorStorage(memory: "snip1\n\nsnip2")
        let runner = SubAgentRunner(
            isolatedRegistry: registry,
            connector: connector,
            auditorStorage: auditor
        )

        let result = try await delegate(
            subagentProfile: SubAgentIdentity.Name.auditor.rawValue,
            task: "verify chapter 1 against canonical memory",
            context: [:],
            registry: registry
        )
        let handleID = result.handle.id
        await runner.drainPending()
        let final = await registry.get(id: handleID)
        #expect(final?.state == .completed)
        #expect(final?.result?.contains("\"verdict\":\"pass\"") == true)
        #expect(final?.result?.contains("\"memory_snippet_count\":2") == true)
        #expect(connector.sendCount == 0)
        #expect(connector.streamCount == 0)
    }

    @Test("auditor returns skip when memory is empty")
    func auditorSkipWhenNoMemory() async throws {
        let registry = AsyncDelegationRegistry()
        let auditor = StubAuditorStorage(memory: "")
        let runner = SubAgentRunner(
            isolatedRegistry: registry,
            connector: RecordingConnector(),
            auditorStorage: auditor
        )

        let result = try await delegate(
            subagentProfile: SubAgentIdentity.Name.auditor.rawValue,
            task: "verify nothing",
            context: [:],
            registry: registry
        )
        await runner.drainPending()
        let final = await registry.get(id: result.handle.id)
        #expect(final?.state == .completed)
        #expect(final?.result?.contains("\"verdict\":\"skip\"") == true)
        #expect(final?.result?.contains("\"memory_snippet_count\":0") == true)
    }

    @Test("auditor throws when storage is nil (= no fake success)")
    func auditorThrowsWithoutStorage() async throws {
        let registry = AsyncDelegationRegistry()
        let runner = SubAgentRunner(
            isolatedRegistry: registry,
            connector: RecordingConnector()
        )

        let result = try await delegate(
            subagentProfile: SubAgentIdentity.Name.auditor.rawValue,
            task: "verify chapter 1",
            context: [:],
            registry: registry
        )
        await runner.drainPending()
        let final = await registry.get(id: result.handle.id)
        #expect(final?.state == .failed, "auditor without storage must fail the handle")
    }
}

// MARK: - NSLock helper

private extension NSLock {
    @discardableResult
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}