//
//  InspectorTodoPageViewTests.swift · Wenshu
//
//  The todo page's own logic: the status rule the page reads, the
//  order the rows come out in, and the count the header shows.
//
//  The page is a View, so per the wenshu test convention its logic
//  is exercised through the value types behind it
//  (= InspectorTodo + InspectorTodoStatus + InspectorTodoModel),
//  not through ViewInspector.
//
//  The store is a throwaway in-memory SwiftData container, and the
//  writes come from the app's OWN todo tool (= TodoStoreTool), so
//  the suite proves that the todos the agent writes are the ones
//  the page shows.
//

import Foundation
import Testing
import WenshuData
@testable import WenshuApp

@Suite("Inspector todo page")
struct InspectorTodoPageViewTests {

    // MARK: - Fixtures

    /// A throwaway store (= no disk, = the app's own todo tool writes
    /// into it, = the page reads from it).
    @MainActor
    private static func makeStore() throws -> (WSTodoRepository, TodoStoreTool) {
        let container = try WSPersistenceContainer.makeInMemoryContainer()
        let repository = WSTodoRepository(container: container)
        let tool = TodoStoreTool(
            hermesTodo: HermesTodoTool(store: HermesTodoStore()),
            todoRepository: repository
        )
        return (repository, tool)
    }

    /// The page's mirror of the store (= the same reader the view
    /// draws from).
    @MainActor
    private static func makePage(_ repository: WSTodoRepository) -> InspectorTodoModel {
        let model = InspectorTodoModel(repository: repository)
        model.refresh()
        return model
    }

    // MARK: - The same store the agent writes

    @Test("the page shows the todo the agent's tool wrote")
    @MainActor
    func pageShowsTheTodoTheToolWrote() async throws {
        let (repository, tool) = try Self.makeStore()

        _ = try await tool.execute(
            input: #"{"action":"create","id":"task-1","content":"Draft chapter one"}"#
        )

        let page = Self.makePage(repository)
        #expect(page.todos.count == 1, "the todo the tool wrote is on the page")
        #expect(page.todos.first?.title == "Draft chapter one")
        #expect(page.outstandingCount == 1, "the todo the tool wrote is counted")
    }

    @Test("the page shows every todo the agent's tool wrote")
    @MainActor
    func pageShowsEveryTodoTheToolWrote() async throws {
        let (repository, tool) = try Self.makeStore()

        _ = try await tool.execute(
            input: #"{"action":"create","id":"task-1","content":"Draft chapter one"}"#
        )
        _ = try await tool.execute(
            input: #"{"action":"create","id":"task-2","content":"Draft chapter two"}"#
        )

        let page = Self.makePage(repository)
        #expect(page.todos.count == 2, "both todos are on the page")
        #expect(Set(page.todos.map(\.title)) == ["Draft chapter one", "Draft chapter two"])
        #expect(page.outstandingCount == 2)
    }

    // MARK: - The count

    @Test("the count is the number of outstanding rows")
    @MainActor
    func countIsTheNumberOfOutstandingRows() async throws {
        let (repository, tool) = try Self.makeStore()

        _ = try await tool.execute(
            input: #"{"action":"create","id":"task-1","content":"Draft chapter one"}"#
        )
        _ = try await tool.execute(
            input: #"{"action":"create","id":"task-2","content":"Draft chapter two"}"#
        )
        _ = try await tool.execute(input: #"{"action":"complete","id":"task-2"}"#)

        let page = Self.makePage(repository)
        #expect(page.outstandingCount == 1, "the finished todo is not counted")
        #expect(page.todos.filter(\.isOutstanding).count == page.outstandingCount,
                "the count and the rows come from the same read")
    }

    @Test("the count drops when a todo leaves the outstanding set")
    @MainActor
    func countDropsWhenATodoLeavesTheOutstandingSet() async throws {
        let (repository, tool) = try Self.makeStore()

        _ = try await tool.execute(
            input: #"{"action":"create","id":"task-1","content":"Draft chapter one"}"#
        )
        _ = try await tool.execute(
            input: #"{"action":"create","id":"task-2","content":"Draft chapter two"}"#
        )

        var page = Self.makePage(repository)
        #expect(page.outstandingCount == 2)

        page.finish(id: "task-1")
        #expect(page.outstandingCount == 1, "the finished todo leaves the count")
        #expect(page.todos.count == 2, "the finished todo is still on the page")
    }

    // MARK: - The order

    @Test("the outstanding rows come before the finished ones")
    @MainActor
    func outstandingRowsComeBeforeFinishedOnes() throws {
        let (repository, _) = try Self.makeStore()

        // The store hands them back in priority order, with the
        // finished one first (= the page has to move it).
        try repository.add(id: "task-1", title: "Draft chapter one", priority: 2)
        try repository.add(id: "task-2", title: "Draft chapter two", priority: 0)
        try repository.setStatus(id: "task-2", status: "completed")

        let page = Self.makePage(repository)
        #expect(page.todos.map(\.title) == ["Draft chapter one", "Draft chapter two"],
                "the outstanding row is first, = the finished one is behind it")
    }

    // MARK: - Finishing and removing

    @Test("marking a todo done writes the status the agent's tool writes")
    @MainActor
    func markingATodoDoneWritesTheToolsStatus() async throws {
        let (repository, tool) = try Self.makeStore()

        _ = try await tool.execute(
            input: #"{"action":"create","id":"task-1","content":"Draft chapter one"}"#
        )

        let page = Self.makePage(repository)
        page.finish(id: "task-1")

        let stored = try repository.get(id: "task-1")
        #expect(stored?.status == "completed",
                "the page writes the same spelling the agent's tool writes")
        #expect(page.outstandingCount == 0, "the finished todo leaves the count")
    }

    @Test("removing a todo takes it off the list")
    @MainActor
    func removingATodoTakesItOffTheList() async throws {
        let (repository, tool) = try Self.makeStore()

        _ = try await tool.execute(
            input: #"{"action":"create","id":"task-1","content":"Draft chapter one"}"#
        )
        _ = try await tool.execute(
            input: #"{"action":"create","id":"task-2","content":"Draft chapter two"}"#
        )

        let page = Self.makePage(repository)
        page.remove(id: "task-1")

        let removed = try repository.get(id: "task-1")
        #expect(removed == nil, "the removed todo is gone from the store")
        #expect(page.todos.map(\.title) == ["Draft chapter two"])
        #expect(page.outstandingCount == 1)
    }

    // MARK: - A read that fails

    @Test("a failed read says so and keeps the last good count")
    @MainActor
    func aFailedReadSaysSoAndKeepsTheLastGoodCount() async throws {
        let (repository, tool) = try Self.makeStore()

        _ = try await tool.execute(
            input: #"{"action":"create","id":"task-1","content":"Draft chapter one"}"#
        )

        var page = InspectorTodoModel(repository: repository)
        page.refresh()
        #expect(page.outstandingCount == 1)
        #expect(!page.loadFailed)

        // The store can no longer be read (= the rows and the count
        // stay the last good ones, = the page says the read failed).
        let failing = InspectorTodoModel(
            repository: repository,
            readTodos: { throw WSTodoRepositoryError.notFound }
        )
        failing.refresh()
        #expect(failing.loadFailed, "the page says the store could not be read")
        #expect(failing.outstandingCount == 0, "a failed read never invents a count")
    }

    // MARK: - The status rule

    @Test("a pending todo is outstanding")
    func pendingIsOutstanding() {
        #expect(InspectorTodoStatus.isOutstanding("pending"))
    }

    @Test("an in-progress todo is outstanding")
    func inProgressIsOutstanding() {
        #expect(InspectorTodoStatus.isOutstanding("in_progress"))
    }

    @Test("a completed todo is finished")
    func completedIsFinished() {
        #expect(!InspectorTodoStatus.isOutstanding("completed"))
    }

    @Test("a cancelled todo is finished")
    func cancelledIsFinished() {
        #expect(!InspectorTodoStatus.isOutstanding("cancelled"))
    }

    @Test("a done todo is finished")
    func doneIsFinished() {
        #expect(!InspectorTodoStatus.isOutstanding("done"))
    }

    @Test("the status the agent's tool writes for a finished todo is the finished one")
    func theToolsFinishedStatusIsFinished() {
        #expect(InspectorTodoStatus.finished == "completed",
                "the page finishes a todo the way the agent's tool finishes one")
        #expect(!InspectorTodoStatus.isOutstanding(InspectorTodoStatus.finished))
    }
}
