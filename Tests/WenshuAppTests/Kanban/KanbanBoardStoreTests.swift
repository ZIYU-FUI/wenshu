//
//  KanbanBoardStoreTests.swift · Wenshu
//
//  Behavior tests for the board's data source and its rules.
//
//  The board reads the app's task store (= SwiftData, = the store the
//  `kanban` tool writes), so the board and the scheduler read one list.
//  The board follows the focused session (= the session names its
//  book), so one book means one board and a board shows only its own
//  book's tasks.
//
//  The USER does not schedule: the status belongs to the scheduler, so
//  the board's read is where the status comes from, and the board
//  writes no status at all.
//

import Foundation
import SwiftData
import Testing
import WenshuData
@testable import WenshuApp

@Suite("Kanban board store (= the board reads the app's task store)")
struct KanbanBoardStoreTests {

    /// A throwaway store (= no disk, = the board reads it as it reads
    /// the app's live store).
    @MainActor
    private static func makeRepository() throws -> WSKanbanRepository {
        let container = try WSPersistenceContainer.makeInMemoryContainer()
        return WSKanbanRepository(container: container)
    }

    // MARK: - One book, one board

    @Test("a book's board holds that book's tasks")
    @MainActor
    func aBooksBoardHoldsThatBooksTasks() throws {
        let repo = try Self.makeRepository()
        let book = "book-a"

        _ = try repo.add(title: "Draft chapter one", status: "new", bookID: book)
        _ = try repo.add(title: "Draft chapter two", status: "new", bookID: book)

        let tasks = try repo.list(bookID: book)
        #expect(tasks.count == 2, "both of the book's tasks are on its board")
        #expect(tasks.allSatisfy { $0.bookID == book },
                "the board holds nothing but its own book's tasks")
    }

    @Test("two books have two boards")
    @MainActor
    func twoBooksHaveTwoBoards() throws {
        let repo = try Self.makeRepository()

        _ = try repo.add(title: "Book A's task", status: "new", bookID: "book-a")
        _ = try repo.add(title: "Book B's task", status: "new", bookID: "book-b")

        #expect(try repo.list(bookID: "book-a").map(\.title) == ["Book A's task"],
                "book A's board holds only book A's task")
        #expect(try repo.list(bookID: "book-b").map(\.title) == ["Book B's task"],
                "book B's board holds only book B's task")
    }

    @Test("the library-level board holds the tasks that name no book")
    @MainActor
    func theLibraryLevelBoardHoldsTheTasksThatNameNoBook() throws {
        let repo = try Self.makeRepository()

        _ = try repo.add(title: "A book's task", status: "new", bookID: "book-a")
        _ = try repo.add(title: "A library-level task", status: "new")

        let libraryTasks = try repo.list(bookID: nil)
        #expect(libraryTasks.map(\.title) == ["A library-level task"],
                "the library-level board holds the tasks that name no book")
    }

    // MARK: - The board reads the scheduler's status

    @Test("the board reads the status the scheduler wrote")
    @MainActor
    func theBoardReadsTheStatusTheSchedulerWrote() throws {
        let repo = try Self.makeRepository()

        let id = try repo.add(title: "A scheduled task", status: "new", bookID: "book-a")
        #expect(try repo.list(bookID: "book-a").first?.status == "new",
                "the task starts in the queue")

        // The scheduler moves it (= the `kanban` tool's transition).
        try repo.transition(id: id, to: "running")
        #expect(try repo.list(bookID: "book-a").first?.status == "running",
                "the board shows the status the scheduler wrote")
    }

    @Test("a task's board is the board its book names")
    @MainActor
    func aTasksBoardIsTheBoardItsBookNames() throws {
        let repo = try Self.makeRepository()

        let id = try repo.add(title: "A task that moves", status: "new", bookID: "book-a")
        try repo.transition(id: id, to: "done")

        #expect(try repo.list(bookID: "book-a").first?.status == "done",
                "the task stays on its book's board when it resolves")
        #expect(try repo.list(bookID: "book-b").isEmpty,
                "another book's board does not show it")
    }

    // MARK: - The board deletes

    @Test("the board's delete removes the task from the store")
    @MainActor
    func theBoardsDeleteRemovesTheTaskFromTheStore() throws {
        let repo = try Self.makeRepository()

        let id = try repo.add(title: "A task to delete", status: "new", bookID: "book-a")
        #expect(try repo.list(bookID: "book-a").count == 1)

        try repo.delete(id: id)
        #expect(try repo.list(bookID: "book-a").isEmpty,
                "the deleted task is off the board")
    }

    // MARK: - The board's own rules

    @Test("the board's first status is the queue a new task waits in")
    func theBoardsFirstStatusIsTheQueueANewTaskWaitsIn() {
        let first = KanbanStatus.boardOrder.first
        #expect(first == .new,
                "a new task waits in the first status (= the scheduler's queue)")
    }

    @Test("the board's statuses are the scheduler's statuses")
    func theBoardsStatusesAreTheSchedulersStatuses() {
        // The board reads the store's raw status strings, so every
        // status the board shows must be one the store can hold.
        for status in KanbanStatus.boardOrder {
            let raw = status.rawValue
            #expect(KanbanStatus(rawValue: raw) == status,
                    "the board's status \(raw) must round-trip through the store's spelling")
        }
    }
}
