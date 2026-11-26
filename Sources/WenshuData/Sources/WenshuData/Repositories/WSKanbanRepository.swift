//
//  Persistence/Repositories/WSKanbanRepository.swift
//
//  The layering this app copied from Apple's Backyard Birds sample project:
//    - write API = raw fields in (= no app-side domain type;
//      caller converts KanbanStatus -> String rawValue before calling;
//      caller consumes the returned WSKanbanTask inside MainActor scope).
//    - read  API = raw WSKanbanTask out (= caller does the
//      WSKanbanTask -> KanbanTask conversion at the boundary).
//
//    - add(...) throws -> WSKanbanTask             (write: raw @Model in/out)
//    - transition(id:to: String) throws           (write: raw String status)
//    - get(id:) throws -> WSKanbanTask?            (read:  raw @Model out)
//    - list(status: String?) throws -> [WSKanbanTask]   (read:  raw @Model out)
//    - delete(id:) throws
//    - removeCards(withTitlePrefix:) throws -> Int   (write: scoped batch delete)
//    - count(status: String?) throws -> Int
//
//  Per AGENTS.md §11.4. KanbanStatus rawValue values
//  (= caller-side owns the conversion):
//    "new" / "triage" / "ready" / "running" / "blocked" / "review" / "done" / "failed"
//
//  Note on sendability: WSKanbanTask (PersistentModel) is NOT Sendable.
//  Caller must convert INSIDE the @MainActor scope (e.g. inside
//  MainActor.run {}) or use Sendable scalar tuples across actor boundary.

import Foundation
import SwiftData

@MainActor
public final class WSKanbanRepository {
    /// The store this repository reads and writes.
    ///
    /// A named container (= a test, an isolated run) is used as it is.
    /// Without one the repository reads and writes the app's live store
    /// (= the warehouse once it is activated), resolved per operation:
    /// the live store changes when the warehouse is activated, so a
    /// repository built before that moment must not keep the store it
    /// saw at construction time.
    public let store: WSStore
    private var context: ModelContext {
        store.context
    }

    public init(container: ModelContainer? = nil) {
        store = WSStore(container: container)
    }

    public func add(
        title: String,
        status: String = "new",
        priority: Int = 5,
        assignee: String? = nil,
        modelOverride: String? = nil,
        body: String? = nil,
        bookID: String? = nil
    ) throws -> String {
        let id = UUID().uuidString
        let now = Date()
        let model = WSKanbanTask(
            id: id,
            title: title,
            status: status,
            priority: priority,
            assignee: assignee,
            modelOverride: modelOverride,
            body: body,
            bookID: bookID
        )
        // Lifecycle hooks (parity with legacy KanbanStore actor:
        // startedAt auto-set when status = "running" at add time, completedAt
        // auto-set when status = "done" or "failed" at add time).
        if status == "running" {
            model.startedAt = now
        } else if status == "done" || status == "failed" {
            model.completedAt = now
        }
        context.insert(model)
        try context.save()
        return id
    }

    public func transition(id: String, to newStatus: String) throws {
        let descriptor = FetchDescriptor<WSKanbanTask>(
            predicate: #Predicate { $0.id == id }
        )
        guard let model = try context.fetch(descriptor).first else {
            throw WSKanbanRepositoryError.notFound
        }
        model.status = newStatus
        model.updatedAt = Date()
        // Lifecycle hooks
        switch newStatus {
        case "running":
            if model.startedAt == nil {
                model.startedAt = Date()
            }
        case "done", "failed":
            if model.completedAt == nil {
                model.completedAt = Date()
            }
        default:
            break
        }
        try context.save()
    }

    public func get(id: String) throws -> WSKanbanTask? {
        let descriptor = FetchDescriptor<WSKanbanTask>(
            predicate: #Predicate { $0.id == id }
        )
        return try context.fetch(descriptor).first
    }

    public func list(status: String? = nil) throws -> [WSKanbanTask] {
        let descriptor: FetchDescriptor<WSKanbanTask>
        if let status {
            descriptor = FetchDescriptor<WSKanbanTask>(
                predicate: #Predicate { $0.status == status },
                sortBy: [SortDescriptor(\.priority, order: .reverse), SortDescriptor(\.createdAt, order: .reverse)]
            )
        } else {
            descriptor = FetchDescriptor<WSKanbanTask>(
                sortBy: [SortDescriptor(\.priority, order: .reverse), SortDescriptor(\.createdAt, order: .reverse)]
            )
        }
        return try context.fetch(descriptor)
    }

    /// The tasks on one book's board.
    ///
    /// The board follows the session, and the session names its book,
    /// so this is the board's read: the tasks whose book is this one.
    /// A nil book id reads the library-level board (= the tasks that
    /// belong to no book).
    public func list(bookID: String?) throws -> [WSKanbanTask] {
        let descriptor: FetchDescriptor<WSKanbanTask>
        if let bookID {
            descriptor = FetchDescriptor<WSKanbanTask>(
                predicate: #Predicate { $0.bookID == bookID },
                sortBy: [SortDescriptor(\.priority, order: .reverse), SortDescriptor(\.createdAt, order: .reverse)]
            )
        } else {
            descriptor = FetchDescriptor<WSKanbanTask>(
                predicate: #Predicate { $0.bookID == nil },
                sortBy: [SortDescriptor(\.priority, order: .reverse), SortDescriptor(\.createdAt, order: .reverse)]
            )
        }
        return try context.fetch(descriptor)
    }

    public func delete(id: String) throws {
        let descriptor = FetchDescriptor<WSKanbanTask>(
            predicate: #Predicate { $0.id == id }
        )
        if let model = try context.fetch(descriptor).first {
            context.delete(model)
            try context.save()
        }
    }

    /// Deletes every card that carries this title prefix and nothing else.
    ///
    /// A card is a hand-off, so it carries at least one of: the role that
    /// owns the work, the instruction it was given, the book it belongs to.
    /// A card that carries none of the three records no decision, and this
    /// removes that shape wherever it sits. Anything that qualifies as a
    /// hand-off survives the call. Returns how many rows went.
    ///
    /// An empty string counts as nothing, because that is what the board
    /// already reads: a card's owner line is drawn only when the name is
    /// non-empty, so a row whose owner or instruction is `""` shows as
    /// unowned and unnamed on screen while a nil-only test would keep it.
    /// Delete and display ask the same question, so the board cannot keep a
    /// row that it renders as an unowned, unnamed card.
    @discardableResult
    public func removeCards(withTitlePrefix prefix: String) throws -> Int {
        // The store's predicate language carries equality on the optional
        // columns and not a prefix match, so the narrowing half runs in the
        // query and the title is asked afterwards. A card that names an
        // instruction or a book is dropped by the query and never reaches the
        // title test at all. The owner's half stays in Swift: the macro cannot
        // type-check nil-or-empty on two columns and the book in one
        // expression, and a wider query only returns rows the line below
        // discards.
        let unnamed = #Predicate<WSKanbanTask> {
            ($0.body == nil || $0.body == "") && $0.bookID == nil
        }
        let doomed = try context
            .fetch(FetchDescriptor<WSKanbanTask>(predicate: unnamed))
            .filter { ($0.assignee ?? "").isEmpty && $0.title.hasPrefix(prefix) }
        guard !doomed.isEmpty else { return 0 }
        for model in doomed {
            context.delete(model)
        }
        try context.save()
        return doomed.count
    }

    public func count(status: String? = nil) throws -> Int {
        let descriptor: FetchDescriptor<WSKanbanTask>
        if let status {
            descriptor = FetchDescriptor<WSKanbanTask>(
                predicate: #Predicate { $0.status == status }
            )
        } else {
            descriptor = FetchDescriptor<WSKanbanTask>()
        }
        return try context.fetchCount(descriptor)
    }
}

public enum WSKanbanRepositoryError: Error {
    case notFound
}

extension WSKanbanRepositoryError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .notFound:
            return "Kanban task not found."
        }
    }
}
