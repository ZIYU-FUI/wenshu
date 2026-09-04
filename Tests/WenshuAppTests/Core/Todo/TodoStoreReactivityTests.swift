//
//  TodoStoreReactivityTests.swift · Wenshu · P2 #22 (WIRE-TODO-001)
//
//  Round-trip tests for the TodoStore subscribe / unsubscribe + AsyncStream
//  notification surface added in WIRE-TODO-001 (= a TodoStore write now
//  fires an `AsyncStream<TodoItem>.Continuation` to every active listener).
//
//  Test inventory (= 3 round-trip tests per spec):
//
//    1. testSubscribe_returnsStream
//       (= subscribe() returns a token + a live AsyncStream that doesn't
//         yield until a write happens)
//    2. testAdd_notifyListener_viaStream
//       (= subscribe → add → the stream yields the inserted TodoItem
//         with matching id / title / status / priority)
//    3. testComplete_notifyListener_viaStream
//       (= subscribe → add → setStatus(.completed) → the stream yields
//         the updated TodoItem with status=completed)
//
//  All tests use a tmp-file TodoStore (= unique UUID per call) so they
//  don't touch the user's canonical
//  ~/Library/Application Support/wenshu/todo.db.
//
//  Acceptance: `swift test --filter "TodoStoreReactivity"` = 3/3 pass.
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("TodoStoreReactivity (P2 #22 / WIRE-TODO-001)")
struct TodoStoreReactivityTests {

    // MARK: - Helpers

    /// Fresh TodoStore backed by a tmp file. Unique per call so tests
    /// can run in parallel without colliding on the SQLite handle.
    /// Async because TodoStore.bootstrap() is actor-isolated.
    private static func makeTodoStore() async throws -> TodoStore {
        let path = NSTemporaryDirectory() + "wenshu-todo-store-reactivity-\(UUID().uuidString).sqlite"
        let store = try TodoStore(path: path)
        try await store.bootstrap()
        return store
    }

    /// Race an `AsyncStream` consumer against a timeout. Returns the
    /// first item the consumer sees, or `nil` if the timeout wins.
    /// Cancels the loser so we don't leak the consumer task across
    /// test cases.
    private static func awaitFirstItem(
        from stream: AsyncStream<TodoItem>,
        timeoutSeconds: Double = 1.0
    ) async -> TodoItem? {
        return await withTaskGroup(of: TodoItem?.self, returning: TodoItem?.self) { group in
            group.addTask {
                for await item in stream {
                    return item
                }
                return nil
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(timeoutSeconds * 1_000_000_000))
                return nil
            }
            // First non-nil wins; if both return nil (= timeout +
            // empty-finish), we still pick whichever finishes first.
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }

    /// Collect up to `maxItems` items from the stream within a
    /// timeout, returning them in arrival order. Useful when a single
    /// test expects multiple notifications (= add + setStatus).
    private static func collectItems(
        from stream: AsyncStream<TodoItem>,
        maxItems: Int,
        timeoutSeconds: Double = 1.0
    ) async -> [TodoItem] {
        return await withTaskGroup(of: [TodoItem].self, returning: [TodoItem].self) { group in
            group.addTask {
                var collected: [TodoItem] = []
                for await item in stream {
                    collected.append(item)
                    if collected.count >= maxItems { return collected }
                }
                return collected
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(timeoutSeconds * 1_000_000_000))
                return []
            }
            // The collector returns when full; the timer returns
            // empty (= timeout). We pick whichever returns first.
            let result = await group.next() ?? []
            group.cancelAll()
            return result
        }
    }

    // MARK: - Test 1: subscribe returns a live stream

    @Test("subscribe() returns a token + a live AsyncStream that doesn't yield until a write")
    func testSubscribe_returnsStream() async throws {
        let store = try await Self.makeTodoStore()
        let (token, stream) = await store.subscribe()

        // No write → no yield within the timeout.
        let got = await Self.awaitFirstItem(from: stream, timeoutSeconds: 0.2)
        #expect(got == nil, "fresh stream must not yield without a write; got: \(String(describing: got))")

        await store.unsubscribe(token)
    }

    // MARK: - Test 2: add notifies listener via stream

    @Test("add() notifies the subscribed listener via the AsyncStream")
    func testAdd_notifyListener_viaStream() async throws {
        let store = try await Self.makeTodoStore()
        let (token, stream) = await store.subscribe()
        defer {
            Task { await store.unsubscribe(token) }
        }

        // Fire the consumer in a child task and let it arm BEFORE we
        // call add() (= ~50 ms head-start). Then trigger the write.
        let collector = Task<[TodoItem], Never> {
            await Self.collectItems(from: stream, maxItems: 1, timeoutSeconds: 1.0)
        }
        try? await Task.sleep(nanoseconds: 50_000_000)
        _ = try await store.add(title: "Draft chapter 1", priority: .high)
        let received = await collector.value

        #expect(received.count == 1, "subscriber must receive exactly 1 notification after add(); got: \(received.count)")
        let item = received.first
        #expect(item?.title == "Draft chapter 1", "notification must echo the added title; got: \(String(describing: item?.title))")
        #expect(item?.status == .pending, "notification must carry status=pending; got: \(String(describing: item?.status))")
        #expect(item?.priority == .high, "notification must carry priority=high; got: \(String(describing: item?.priority))")
    }

    // MARK: - Test 3: complete notifies listener via stream

    @Test("setStatus(.completed) notifies the subscribed listener via the AsyncStream")
    func testComplete_notifyListener_viaStream() async throws {
        let store = try await Self.makeTodoStore()
        // Seed an item BEFORE subscribing so the only event in the
        // stream is the setStatus yield.
        let seeded = try await store.add(title: "Write outline", priority: .medium)
        let (token, stream) = await store.subscribe()
        defer {
            Task { await store.unsubscribe(token) }
        }

        let collector = Task<[TodoItem], Never> {
            await Self.collectItems(from: stream, maxItems: 1, timeoutSeconds: 1.0)
        }
        try? await Task.sleep(nanoseconds: 50_000_000)
        try await store.setStatus(id: seeded.id, status: .completed)
        let received = await collector.value

        #expect(received.count == 1, "subscriber must receive exactly 1 notification after setStatus(.completed); got: \(received.count)")
        let item = received.first
        #expect(item?.id == seeded.id, "notification must echo the completed id; got: \(String(describing: item?.id))")
        #expect(item?.status == .completed, "notification must carry status=completed; got: \(String(describing: item?.status))")
    }
}