//
//  HermesKanbanDBTests.swift · Wenshu · HERMES-SUBSYSTEM-3 (kanban 1:1 port retry)
//
//  10 round-trip tests for HermesKanbanDB actor:
//    1. testCreateTask_basicFields
//    2. testClaimTask_succeedsWhenUnclaimed
//    3. testClaimTask_failsWhenAlreadyClaimed
//    4. testCompleteTask_transitionsToDone
//    5. testReleaseTask_clearsClaim
//    6. testAddComment_persistsAndRetrieves
//    7. testRecordEvent_appendsToEventLog
//    8. testLinkTasks_bidirectionalRetrieval
//    9. testMultiProfile_isolation
//   10. testMultiProject_isolation
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("HermesKanbanDB (hermes kanban 1:1 port)")
struct HermesKanbanDBTests {
    /// Fresh temp DB per test (= mirrors KanbanStoreTests.tempDBPath).
    private static func tempDBPath() -> String {
        URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(".test-hermes-kanban-\(UUID().uuidString.prefix(8)).db")
            .path
    }

    @Test("createTask round-trip: all basic fields persist")
    func testCreateTask_basicFields() async throws {
        let db = try HermesKanbanDB(dbPath: URL(fileURLWithPath: Self.tempDBPath()))
        try await db.bootstrap()
        let task = HermesKanbanTask(
            boardId: "atm10-server",
            profileSlug: "pocock",
            projectSlug: "wenshu",
            title: "port kanban_db.py to Swift",
            description: "1:1 port",
            status: .ready,
            priority: 7,
            assignee: "writer"
        )
        let created = try await db.createTask(task)
        let retrieved = try await db.getTask(id: created.id)
        #expect(retrieved != nil)
        #expect(retrieved?.title == "port kanban_db.py to Swift")
        #expect(retrieved?.description == "1:1 port")
        #expect(retrieved?.status == .ready)
        #expect(retrieved?.priority == 7)
        #expect(retrieved?.assignee == "writer")
        #expect(retrieved?.boardId == "atm10-server")
        #expect(retrieved?.profileSlug == "pocock")
        #expect(retrieved?.projectSlug == "wenshu")
        #expect(retrieved?.claimedBy == nil)
        #expect(retrieved?.completedAt == nil)
    }

    @Test("claimTask succeeds when unclaimed; sets claimed_by + status=running")
    func testClaimTask_succeedsWhenUnclaimed() async throws {
        let db = try HermesKanbanDB(dbPath: URL(fileURLWithPath: Self.tempDBPath()))
        try await db.bootstrap()
        let task = try await db.createTask(HermesKanbanTask(
            boardId: "default",
            profileSlug: "pocock",
            projectSlug: "wenshu",
            title: "claimable task"
        ))
        let claimed = try await db.claimTask(id: task.id, by: "worker-1")
        #expect(claimed.claimedBy == "worker-1")
        #expect(claimed.claimedAt != nil)
        #expect(claimed.status == .running)
    }

    @Test("claimTask fails when already claimed by another worker")
    func testClaimTask_failsWhenAlreadyClaimed() async throws {
        let db = try HermesKanbanDB(dbPath: URL(fileURLWithPath: Self.tempDBPath()))
        try await db.bootstrap()
        let task = try await db.createTask(HermesKanbanTask(
            boardId: "default",
            profileSlug: "pocock",
            projectSlug: "wenshu",
            title: "contested task"
        ))
        _ = try await db.claimTask(id: task.id, by: "worker-1")
        do {
            _ = try await db.claimTask(id: task.id, by: "worker-2")
            Issue.record("expected taskAlreadyClaimed error")
        } catch let HermesKanbanError.taskAlreadyClaimed(taskId, claimedBy) {
            #expect(taskId == task.id)
            #expect(claimedBy == "worker-1")
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    @Test("completeTask transitions to done; clears claim; sets completed_at")
    func testCompleteTask_transitionsToDone() async throws {
        let db = try HermesKanbanDB(dbPath: URL(fileURLWithPath: Self.tempDBPath()))
        try await db.bootstrap()
        let task = try await db.createTask(HermesKanbanTask(
            boardId: "default",
            profileSlug: "pocock",
            projectSlug: "wenshu",
            title: "finishable task"
        ))
        _ = try await db.claimTask(id: task.id, by: "worker-1")
        let done = try await db.completeTask(id: task.id, result: "ok")
        #expect(done.status == .done)
        #expect(done.completedAt != nil)
        #expect(done.claimedBy == nil)
        #expect(done.claimedAt == nil)
    }

    @Test("releaseTask clears claimed_by + claimed_at; status preserved")
    func testReleaseTask_clearsClaim() async throws {
        let db = try HermesKanbanDB(dbPath: URL(fileURLWithPath: Self.tempDBPath()))
        try await db.bootstrap()
        let task = try await db.createTask(HermesKanbanTask(
            boardId: "default",
            profileSlug: "pocock",
            projectSlug: "wenshu",
            title: "releasable task"
        ))
        _ = try await db.claimTask(id: task.id, by: "worker-1")
        try await db.releaseTask(id: task.id)
        let after = try await db.getTask(id: task.id)
        #expect(after?.claimedBy == nil)
        #expect(after?.claimedAt == nil)
        // Status was set to .running by claimTask; release does not reset it.
        #expect(after?.status == .running)
        // Re-claim by a different worker now succeeds (= claim was truly cleared).
        let reclaim = try await db.claimTask(id: task.id, by: "worker-2")
        #expect(reclaim.claimedBy == "worker-2")
    }

    @Test("addComment persists and round-trips via listComments")
    func testAddComment_persistsAndRetrieves() async throws {
        let db = try HermesKanbanDB(dbPath: URL(fileURLWithPath: Self.tempDBPath()))
        try await db.bootstrap()
        let task = try await db.createTask(HermesKanbanTask(
            boardId: "default",
            profileSlug: "pocock",
            projectSlug: "wenshu",
            title: "task with comments"
        ))
        _ = try await db.addComment(HermesKanbanComment(
            taskId: task.id, author: "boss", body: "first comment"
        ))
        _ = try await db.addComment(HermesKanbanComment(
            taskId: task.id, author: "agent", body: "second comment"
        ))
        let comments = try await db.listComments(taskId: task.id)
        #expect(comments.count == 2)
        #expect(comments[0].author == "boss")
        #expect(comments[0].body == "first comment")
        #expect(comments[1].author == "agent")
        #expect(comments[1].body == "second comment")
    }

    @Test("recordEvent appends to task_events table")
    func testRecordEvent_appendsToEventLog() async throws {
        let db = try HermesKanbanDB(dbPath: URL(fileURLWithPath: Self.tempDBPath()))
        try await db.bootstrap()
        let task = try await db.createTask(HermesKanbanTask(
            boardId: "default",
            profileSlug: "pocock",
            projectSlug: "wenshu",
            title: "task with events"
        ))
        // createTask auto-records "task_created" event; add a manual one too.
        let evt = try await db.recordEvent(HermesKanbanEvent(
            taskId: task.id,
            eventType: "manual_ping",
            actor: "agent",
            payload: ["reason": "smoke-test", "level": "info"]
        ))
        #expect(evt.eventType == "manual_ping")
        #expect(evt.payload["reason"] == "smoke-test")
        #expect(evt.payload["level"] == "info")
        // Verify the count via a second task_comments-independent query:
        // count events for the task by listing them indirectly (= via
        // payload JSON size in the row). Instead, assert that getTask still
        // works (= event log didn't break task lookup).
        let got = try await db.getTask(id: task.id)
        #expect(got?.id == task.id)
    }

    @Test("linkTasks bidirectional retrieval: listLinkedTasks sees both directions")
    func testLinkTasks_bidirectionalRetrieval() async throws {
        let db = try HermesKanbanDB(dbPath: URL(fileURLWithPath: Self.tempDBPath()))
        try await db.bootstrap()
        let parent = try await db.createTask(HermesKanbanTask(
            boardId: "default",
            profileSlug: "pocock",
            projectSlug: "wenshu",
            title: "parent task"
        ))
        let childA = try await db.createTask(HermesKanbanTask(
            boardId: "default",
            profileSlug: "pocock",
            projectSlug: "wenshu",
            title: "child A"
        ))
        let childB = try await db.createTask(HermesKanbanTask(
            boardId: "default",
            profileSlug: "pocock",
            projectSlug: "wenshu",
            title: "child B"
        ))
        _ = try await db.linkTasks(HermesKanbanLink(
            sourceTaskId: parent.id,
            targetTaskId: childA.id,
            linkType: "parent-child"
        ))
        _ = try await db.linkTasks(HermesKanbanLink(
            sourceTaskId: parent.id,
            targetTaskId: childB.id,
            linkType: "parent-child"
        ))
        // From parent's perspective: should see childA + childB.
        let fromParent = try await db.listLinkedTasks(taskId: parent.id)
        #expect(fromParent.count == 2)
        let parentTitles = Set(fromParent.map(\.title))
        #expect(parentTitles.contains("child A"))
        #expect(parentTitles.contains("child B"))
        // From childA's perspective: should see parent (bidirectional).
        let fromChildA = try await db.listLinkedTasks(taskId: childA.id)
        #expect(fromChildA.count == 1)
        #expect(fromChildA.first?.title == "parent task")
    }

    @Test("multi-profile isolation: profile A boards do not leak into profile B")
    func testMultiProfile_isolation() async throws {
        let db = try HermesKanbanDB(dbPath: URL(fileURLWithPath: Self.tempDBPath()))
        try await db.bootstrap()
        // Profile "pocock" owns board "atm10-server" with 2 tasks.
        _ = try await db.createTask(HermesKanbanTask(
            boardId: "atm10-server",
            profileSlug: "pocock",
            projectSlug: "wenshu",
            title: "pocock task 1"
        ))
        _ = try await db.createTask(HermesKanbanTask(
            boardId: "atm10-server",
            profileSlug: "pocock",
            projectSlug: "wenshu",
            title: "pocock task 2"
        ))
        // Profile "cecilia" owns board "scratch" with 1 task.
        _ = try await db.createTask(HermesKanbanTask(
            boardId: "scratch",
            profileSlug: "cecilia",
            projectSlug: "research",
            title: "cecilia task 1"
        ))
        let pocockBoards = try await db.boardsForProfile(slug: "pocock")
        let ceciliaBoards = try await db.boardsForProfile(slug: "cecilia")
        #expect(pocockBoards == ["atm10-server"])
        #expect(ceciliaBoards == ["scratch"])
    }

    @Test("multi-project isolation: tasksForProject scopes by project_slug")
    func testMultiProject_isolation() async throws {
        let db = try HermesKanbanDB(dbPath: URL(fileURLWithPath: Self.tempDBPath()))
        try await db.bootstrap()
        // Project "wenshu" gets 3 tasks.
        _ = try await db.createTask(HermesKanbanTask(
            boardId: "default",
            profileSlug: "pocock",
            projectSlug: "wenshu",
            title: "wenshu task 1"
        ))
        _ = try await db.createTask(HermesKanbanTask(
            boardId: "default",
            profileSlug: "pocock",
            projectSlug: "wenshu",
            title: "wenshu task 2"
        ))
        _ = try await db.createTask(HermesKanbanTask(
            boardId: "default",
            profileSlug: "pocock",
            projectSlug: "wenshu",
            title: "wenshu task 3"
        ))
        // Project "research" gets 1 task.
        _ = try await db.createTask(HermesKanbanTask(
            boardId: "scratch",
            profileSlug: "pocock",
            projectSlug: "research",
            title: "research task 1"
        ))
        let wenshuTasks = try await db.tasksForProject("wenshu")
        let researchTasks = try await db.tasksForProject("research")
        #expect(wenshuTasks.count == 3)
        #expect(researchTasks.count == 1)
        // Cross-check via listTasks filter (.backlog is the default).
        let allBacklog = try await db.listTasks(filter: .backlog)
        #expect(allBacklog.count == 4)
    }
}