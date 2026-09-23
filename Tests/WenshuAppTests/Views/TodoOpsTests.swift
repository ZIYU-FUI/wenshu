//
//  TodoOpsTests.swift · Wenshu · v1.72 settings-kanban-todo-mvvm T2a
//
//  Behavior + source-level tests for `TodoOps` (= the stateless
//  enum extracted from TodoListView in v1.72 T2b). Per boss
//  2026-09-22 OOB '按MVVM UI 业务 数据，三分离': TodoListView currently
//  owns the same kind of inline business logic as KanbanView (= the
//  v1.72 T1 sibling arc), with one extra field (priority). The fix
//  per ADR-0009 + the v1.70 editor-mvvm precedent (= stateless
//  enums) is the same lift-out.
//
//  Coverage (= 9 tests; = 1 more than KanbanOpsTests because Todo
//  carries a priority field at add time, plus a no-op-on-empty-array
//  invariant for the priority-reset semantic):
//    1. `fileExistsAtCanonicalPath` — source-level guard
//    2. `loadItemsReturnsEmptyArrayWhenScopeUnresolved`
//    3. `loadItemsReturnsEmptyArrayWhenScopeDirIsNil`
//    4. `loadItemsRoundTripsFromDisk`
//    5. `addItemAppendsNewEntryWithPendingStatusAndPriority`
//    6. `addItemIgnoresEmptyAndWhitespaceTitle`
//    7. `updateStatusReplacesStatusAndBumpsUpdatedAt`
//    8. `updateStatusNoOpWhenItemMissing`
//    9. `deleteItemRemovesById`
//
//  Mock strategy (= KanbanOpsTests precedent): no mock framework,
//  real /tmp fixture, FixedResolver / NilResolver in-file structs
//  satisfy the ScopeDirectoryResolver protocol.

import Foundation
import Testing
@testable import WenshuApp

@MainActor
@Suite("v1.72 settings-kanban-todo-mvvm T2a — TodoOps (per-book todo business layer)")
struct TodoOpsTests {

    // MARK: - Fixtures

    private func makeTempDir() throws -> URL {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("wenshu-TodoOpsTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func cleanup(_ dir: URL) {
        try? FileManager.default.removeItem(at: dir)
    }

    private struct FixedResolver: TodoOps.ScopeDirectoryResolver {
        let dir: URL?
        func resolve(bookId: UUID?, scope: TaskScope) -> URL? { dir }
    }

    private struct NilResolver: TodoOps.ScopeDirectoryResolver {
        func resolve(bookId: UUID?, scope: TaskScope) -> URL? { nil }
    }

    // MARK: - Source-level structural assertions

    @Test("TodoOps.swift exists at the canonical path under Views/Todo/")
    func fileExistsAtCanonicalPath() throws {
        // #filePath resolves to .../Tests/WenshuAppTests/Views/TodoOpsTests.swift
        // (= 5 segments above the file). Walk up 4 levels to reach
        // the repo root (= .../wt/v1.72-settings-kanban-todo-mvvm-2026-09-22/).
        let testFileURL = URL(fileURLWithPath: #filePath)
        let repoRoot = testFileURL
            .deletingLastPathComponent()  // Views/        -> WenshuAppTests/
            .deletingLastPathComponent()  // WenshuAppTests/ -> Tests/
            .deletingLastPathComponent()  // Tests/         -> <worktree>/
            .deletingLastPathComponent()  // <worktree>/    -> repo root
        let sourcePath = repoRoot
            .appendingPathComponent("Sources")
            .appendingPathComponent("WenshuApp")
            .appendingPathComponent("Views")
            .appendingPathComponent("Todo")
            .appendingPathComponent("TodoOps.swift")
            .path
        #expect(FileManager.default.fileExists(atPath: sourcePath),
                "TodoOps.swift must exist at \(sourcePath) (= v1.72 T2b extraction target)")
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        #expect(source.contains("enum TodoOps"),
                "TodoOps.swift must declare `enum TodoOps` (= the canonical v1.70 stateless-enum pattern)")
        #expect(source.contains("ScopeDirectoryResolver"),
                "TodoOps must declare the `ScopeDirectoryResolver` seam (= the BookStore bypass)")
    }

    // MARK: - load behavior

    @Test("loadItems returns empty array + loadError nil when scope unresolved")
    func loadItemsReturnsEmptyArrayWhenScopeUnresolved() throws {
        let dir = try makeTempDir()
        defer { cleanup(dir) }
        let bookId = UUID()
        let resolver = NilResolver()
        let result = TodoOps.loadItems(bookId: bookId, scope: .book, resolver: resolver)
        #expect(result.items.isEmpty)
        #expect(result.scopeDir == nil)
        #expect(result.loadError == nil)
    }

    @Test("loadItems returns empty array when store file missing")
    func loadItemsReturnsEmptyArrayWhenScopeDirIsNil() throws {
        let dir = try makeTempDir()
        defer { cleanup(dir) }
        let bookId = UUID()
        let resolver = FixedResolver(dir: dir)
        let result = TodoOps.loadItems(bookId: bookId, scope: .book, resolver: resolver)
        #expect(result.items.isEmpty)
        #expect(result.scopeDir == dir)
        #expect(result.loadError == nil)
    }

    @Test("loadItems round-trips: write 2 items, read them back")
    func loadItemsRoundTripsFromDisk() throws {
        let dir = try makeTempDir()
        defer { cleanup(dir) }
        let bookId = UUID()
        let resolver = FixedResolver(dir: dir)

        let afterFirst = TodoOps.addItem(bookId: bookId, scope: .book, resolver: resolver,
                                          title: "First", priority: .high, to: [])
        let seeded = TodoOps.addItem(bookId: bookId, scope: .book, resolver: resolver,
                                      title: "Second", priority: .low,
                                      to: afterFirst.savedItems)
        #expect(seeded.savedItems.count == 2)

        let loaded = TodoOps.loadItems(bookId: bookId, scope: .book, resolver: resolver)
        #expect(loaded.items.count == 2)
        #expect(loaded.items.map(\.title) == ["First", "Second"])
        #expect(loaded.items[0].priority == .high,
                "Priority must round-trip (= the user-selected priority is preserved on disk)")
        #expect(loaded.items[1].priority == .low)
    }

    // MARK: - add behavior

    @Test("addItem appends a new entry with status=.pending and the supplied priority")
    func addItemAppendsNewEntryWithPendingStatusAndPriority() throws {
        let dir = try makeTempDir()
        defer { cleanup(dir) }
        let bookId = UUID()
        let resolver = FixedResolver(dir: dir)
        let next = TodoOps.addItem(bookId: bookId, scope: .book, resolver: resolver,
                                    title: "New todo", priority: .urgent, to: [])
        #expect(next.savedItems.count == 1)
        #expect(next.savedItems[0].title == "New todo")
        #expect(next.savedItems[0].status == .pending,
                "Default status for a freshly added todo is .pending (= mirrors Kanban's .new)")
        #expect(next.savedItems[0].priority == .urgent,
                "Priority must round-trip verbatim (= the user-selected priority from the picker)")
    }

    @Test("addItem ignores empty / whitespace-only titles (= returns input unchanged + no save)")
    func addItemIgnoresEmptyAndWhitespaceTitle() throws {
        let dir = try makeTempDir()
        defer { cleanup(dir) }
        let bookId = UUID()
        let resolver = FixedResolver(dir: dir)
        for emptyTitle in ["", "   ", "\t\n  "] {
            let result = TodoOps.addItem(bookId: bookId, scope: .book, resolver: resolver,
                                          title: emptyTitle, priority: .medium, to: [])
            #expect(result.savedItems.isEmpty,
                    "Empty / whitespace title must not append (= mirrors TodoListView's `trimmed.isEmpty` guard)")
            #expect(result.didSave == false)
        }
    }

    // MARK: - update behavior

    @Test("updateStatus replaces status AND bumps updatedAt")
    func updateStatusReplacesStatusAndBumpsUpdatedAt() throws {
        let dir = try makeTempDir()
        defer { cleanup(dir) }
        let bookId = UUID()
        let resolver = FixedResolver(dir: dir)
        let item = PerBookTodoItem(title: "T", status: .pending, priority: .medium,
                                    createdAt: Date(timeIntervalSince1970: 0),
                                    updatedAt: Date(timeIntervalSince1970: 0))
        let originalCreated = item.createdAt
        let result = TodoOps.updateStatus(bookId: bookId, scope: .book, resolver: resolver,
                                           item: item, to: .inProgress, in: [item])
        #expect(result.savedItems.count == 1)
        #expect(result.savedItems[0].status == .inProgress)
        #expect(result.savedItems[0].createdAt == originalCreated)
        #expect(result.savedItems[0].updatedAt > originalCreated,
                "updateStatus must bump updatedAt (= TodoListView's `next[idx].updatedAt = .now`)")
        #expect(result.didSave == true)
    }

    @Test("updateStatus is a no-op when item not found in array")
    func updateStatusNoOpWhenItemMissing() throws {
        let dir = try makeTempDir()
        defer { cleanup(dir) }
        let bookId = UUID()
        let resolver = FixedResolver(dir: dir)
        let real = PerBookTodoItem(title: "real")
        let ghost = PerBookTodoItem(title: "ghost")
        let result = TodoOps.updateStatus(bookId: bookId, scope: .book, resolver: resolver,
                                           item: ghost, to: .completed, in: [real])
        #expect(result.savedItems == [real])
        #expect(result.didSave == false)
    }

    // MARK: - delete behavior

    @Test("deleteItem removes by id")
    func deleteItemRemovesById() throws {
        let dir = try makeTempDir()
        defer { cleanup(dir) }
        let bookId = UUID()
        let resolver = FixedResolver(dir: dir)
        let keep = PerBookTodoItem(title: "keep")
        let drop = PerBookTodoItem(title: "drop")
        let result = TodoOps.deleteItem(bookId: bookId, scope: .book, resolver: resolver,
                                         item: drop, in: [keep, drop])
        #expect(result.savedItems == [keep])
        #expect(result.didSave == true)
    }
}