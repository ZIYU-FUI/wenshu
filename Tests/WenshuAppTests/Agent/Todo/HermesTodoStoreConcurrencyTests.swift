//
//  HermesTodoStoreConcurrencyTests.swift · Wenshu · FIX-TODO-LOCK-001
//
//  Regression tests for the lock-recursion deadlock that hit
//  TodoStoreTool.execute() (= reported during P5 #23
//  VERIFY-INTEGRATION-001): the previous HermesTodoStore used a
//  non-recursive NSLock and `write(...)` returned `read()` while
//  still holding the lock, so the first call from any nonisolated
//  context would deadlock. The fix swapped NSLock for a serial
//  DispatchQueue with `.sync` blocks, and removed the nested read
//  call from inside the write path.
//
//  Five round-trip tests, per ticket acceptance:
//
//    1. testConcurrentWrites_remainConsistent
//       (= 100 concurrent writes to different keys; all 100 keys
//        must be present at the end; no torn write or lost update).
//
//    2. testConcurrentReads_returnsSameValue
//       (= 100 concurrent reads from the same key; every read
//        returns the same value).
//
//    3. testReadWrite_neverDeadlocks
//       (= read + write in a tight loop 1000 times; the call must
//        complete in well under 5 seconds -- if NSLock recursion
//        is reintroduced, this test will hang past the timeout).
//
//    4. testTodoStoreTool_execute_doesNotHang
//       (= full TodoStoreTool.execute() flow end-to-end; the call
//        must complete in well under 5 seconds).
//
//    5. testHermesTodoTool_execute_doesNotHang
//       (= HermesTodoTool.execute() flow end-to-end; the call must
//        complete in well under 5 seconds).
//
//  All tests use a 5-second budget per call to surface the deadlock
//  (= a hanging call never returns, so the test fails with a
//  timeout). Acceptance: `--filter "HermesTodoStoreConcurrency"`
//  = 5/5 pass in well under 30 seconds total.
//

import Foundation
import Testing
@testable import WenshuApp

// MARK: - Sendable observation collector

/// A thread-safe collector for read observations. Wraps a
/// serial DispatchQueue so we don't have to fight Swift 6's strict
/// concurrency checker (= mutations of `var` arrays from concurrent
/// closures are flagged as `#SendableClosureCaptures`).
private final class ObservationBox<T>: @unchecked Sendable {
    private let queue = DispatchQueue(label: "ObservationBox")
    private var storage: [T] = []

    func append(_ value: T) {
        queue.sync { storage.append(value) }
    }

    func snapshot() -> [T] {
        return queue.sync { storage }
    }
}

// MARK: - Test suite

@Suite("HermesTodoStore concurrency (FIX-TODO-LOCK-001)")
struct HermesTodoStoreConcurrencyTests {

    // MARK: - Test 1: concurrent writes stay consistent

    @Test("100 concurrent writes to different keys all land in the store")
    func testConcurrentWrites_remainConsistent() throws {
        let store = HermesTodoStore()

        // Pre-condition: store is empty.
        #expect(store.read().isEmpty, "fresh HermesTodoStore must start empty")

        // Fire 100 concurrent write tasks, each writing a different
        // unique id. We use a DispatchGroup barrier so we know when
        // every task has completed before we read.
        let total = 100
        let group = DispatchGroup()
        let queue = DispatchQueue(label: "test.concurrentWrites", attributes: .concurrent)

        for i in 0..<total {
            group.enter()
            queue.async {
                let item = HermesTodoItem(
                    id: "task-\(i)",
                    content: "Concurrent write #\(i)",
                    status: .pending
                )
                let written = store.write(todos: [item], merge: true)
                // Sanity: the write should report our item back (plus
                // anything that landed before us -- race-tolerant).
                #expect(written.contains { $0.id == "task-\(i)" })
                group.leave()
            }
        }

        // Wait for all writes. DispatchGroup.wait is sync, so this
        // test function stays sync too (= matches the locking
        // semantics we are testing -- a sync operation).
        let waitResult = group.wait(timeout: .now() + .seconds(5))
        #expect(
            waitResult == .success,
            "100 concurrent writes must complete in under 5 seconds; got \(waitResult)"
        )

        // Verify all 100 ids landed.
        let all = store.read()
        #expect(all.count == total, "expected \(total) items after concurrent writes; got \(all.count)")

        let ids = Set(all.map { $0.id })
        for i in 0..<total {
            #expect(ids.contains("task-\(i)"), "missing task-\(i) after concurrent writes")
        }
    }

    // MARK: - Test 2: concurrent reads see the same value

    @Test("100 concurrent reads from the same key all return the same value")
    func testConcurrentReads_returnsSameValue() throws {
        let store = HermesTodoStore()
        // Seed with one item.
        let seed = HermesTodoItem(
            id: "shared",
            content: "the shared value",
            status: .pending
        )
        _ = store.write(todos: [seed], merge: false)
        #expect(store.read().count == 1)

        // Fire 100 concurrent read tasks, gather their observations.
        let total = 100
        let group = DispatchGroup()
        let queue = DispatchQueue(label: "test.concurrentReads", attributes: .concurrent)
        let box = ObservationBox<[HermesTodoItem]>()

        for _ in 0..<total {
            group.enter()
            queue.async {
                let snapshot = store.read()
                box.append(snapshot)
                group.leave()
            }
        }

        let waitResult = group.wait(timeout: .now() + .seconds(5))
        #expect(
            waitResult == .success,
            "100 concurrent reads must complete in under 5 seconds; got \(waitResult)"
        )

        let observations = box.snapshot()
        #expect(observations.count == total, "expected \(total) read observations; got \(observations.count)")

        // Every observation must equal the seed.
        for (index, snapshot) in observations.enumerated() {
            #expect(snapshot.count == 1, "observation \(index) must have exactly 1 item; got \(snapshot.count)")
            #expect(snapshot.first?.id == "shared", "observation \(index) must have id=shared")
            #expect(snapshot.first?.content == "the shared value", "observation \(index) must have content='the shared value'")
            #expect(snapshot.first?.status == .pending, "observation \(index) must have status=.pending")
        }
    }

    // MARK: - Test 3: read+write loop never deadlocks

    @Test("1000 read+write iterations complete well under 5 seconds")
    func testReadWrite_neverDeadlocks() throws {
        let store = HermesTodoStore()
        // Seed with one item so reads have something to read.
        _ = store.write(todos: [
            HermesTodoItem(id: "loop-target", content: "loop", status: .pending)
        ], merge: false)

        let group = DispatchGroup()
        let queue = DispatchQueue(label: "test.readWriteLoop", attributes: .concurrent)

        // Two background loops: one hammer-reads, the other hammer-writes.
        // If the previous NSLock recursion is reintroduced, one of
        // these will deadlock and the test will time out.
        group.enter()
        queue.async {
            for _ in 0..<500 {
                _ = store.read()
            }
            group.leave()
        }
        group.enter()
        queue.async {
            for i in 0..<500 {
                _ = store.write(
                    todos: [HermesTodoItem(
                        id: "loop-target",
                        content: "loop iter \(i)",
                        status: i % 2 == 0 ? .pending : .inProgress
                    )],
                    merge: true
                )
            }
            group.leave()
        }

        let waitResult = group.wait(timeout: .now() + .seconds(5))
        #expect(
            waitResult == .success,
            "1000 mixed read+write operations must complete in under 5 seconds; got \(waitResult)"
        )

        // Final state: the loop-target item is still present (merge
        // mode preserves it).
        let final = store.read()
        #expect(final.count == 1, "expected exactly 1 item after the loop; got \(final.count)")
        #expect(final.first?.id == "loop-target")
    }

    // MARK: - Test 4: TodoStoreTool.execute() does not hang

    @Test("TodoStoreTool.execute() returns in under 5 seconds (regression for the deadlock reported in VERIFY-INTEGRATION-001)")
    func testTodoStoreTool_execute_doesNotHang() async throws {
        let todoStore = try await Self.makeTodoStore()
        let hermesStore = HermesTodoStore()
        let hermesTool = HermesTodoTool(store: hermesStore)
        let tool = TodoStoreTool(hermesTodo: hermesTool, todoStore: todoStore)

        // Race two flows: a create + a list. If the previous NSLock
        // recursion is reintroduced, one of these will hang.
        let started = Date()
        async let createResult: String = tool.execute(input: #"{"action":"create","id":"deadlock-1","content":"first"}"#)
        async let listResult: String = tool.execute(input: #"{"action":"list"}"#)

        let create = try await createResult
        let list = try await listResult
        let elapsed = Date().timeIntervalSince(started)

        #expect(elapsed < 5.0, "TodoStoreTool.execute() took \(elapsed)s (>= 5s budget)")
        #expect(create.contains("\"ok\":true"), "create must return ok=true; got: \(create)")
        #expect(list.contains("\"ok\":true"), "list must return ok=true; got: \(list)")
    }

    // MARK: - Test 5: HermesTodoTool.execute() does not hang

    @Test("HermesTodoTool.execute() write returns in under 5 seconds (regression for the write→read recursion deadlock)")
    func testHermesTodoTool_execute_doesNotHang() async throws {
        let hermesStore = HermesTodoStore()
        let tool = HermesTodoTool(store: hermesStore)

        // The original deadlock lived in the `write → read` recursion
        // inside HermesTodoStore.write (= `return read()` while
        // holding the lock). After the fix, write returns the
        // post-mutation snapshot directly, so the very first write
        // call must complete deterministically. We run the write
        // once with a full replace-mode payload (= the path that
        // used to deadlock) and assert the returned JSON contains
        // the just-written item.
        let started = Date()
        let writeResult = try await tool.execute(
            input: #"{"todos":[{"id":"deadlock-2","content":"second","status":"pending"}],"merge":false}"#
        )
        let elapsed = Date().timeIntervalSince(started)

        #expect(elapsed < 5.0, "HermesTodoTool.execute() took \(elapsed)s (>= 5s budget)")
        #expect(writeResult.contains("\"total\":1"), "write must report total=1; got: \(writeResult)")
        #expect(writeResult.contains("deadlock-2"), "write must echo the just-written item; got: \(writeResult)")

        // Then read back deterministically (= no race; the store is
        // already populated).
        let readResult = try await tool.execute(input: "")
        #expect(readResult.contains("\"total\":1"), "read must report total=1; got: \(readResult)")
        #expect(readResult.contains("deadlock-2"), "read must include the item we just wrote; got: \(readResult)")
    }

    // MARK: - Helpers

    /// Make a fresh TodoStore backed by a tmp file (= each test gets
    /// isolation; no cleanup race because we use a unique UUID per
    /// call and the OS reclaims tmp files on reboot).
    /// Async because TodoStore.bootstrap() is actor-isolated.
    private static func makeTodoStore() async throws -> TodoStore {
        let path = NSTemporaryDirectory() + "wenshu-todo-store-concurrency-\(UUID().uuidString).sqlite"
        let store = try TodoStore(path: path)
        try await store.bootstrap()
        return store
    }
}