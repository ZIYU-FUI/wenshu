//
//  TodoOps.swift · Wenshu · v1.72 settings-kanban-todo-mvvm T2b
//
//  Per-book todo business layer, extracted from TodoListView.
//
//  Per boss 2026-09-22 OOB '按MVVM UI 业务 数据，三分离' (= UI /
//  业务 / 数据 separation audit) + ADR-0009 + the v1.72 T1
//  KanbanOps precedent: TodoListView currently owns the same kind
//  of inline business logic as KanbanView (= reloadFromDisk /
//  addItem / updateStatus / deleteItem), with one extra field
//  (priority at add time) carried through the lifecycle. This
//  helper lifts the business layer into a stateless enum so the
//  View can become a pure consumer.
//
//  Why a stateless enum (not @Observable class):
//  - State already lives in `BookStore` (= the @Observable global
//    container; = same reasoning as KanbanOps per v1.72 T1b).
//  - TodoListView is a leaf view (= no parent owns the items state).
//  - The enum only mutates call-site `inout [PerBookTodoItem]` and
//    returns Result types. Stateless.
//
//  Why a `ScopeDirectoryResolver` seam (= BookStore bypass):
//  - Mirrors KanbanOps (= the v1.72 T1b seam). Production wires
//    `BookStoreScopeDirectoryResolver`; tests pass `FixedResolver` /
//    `NilResolver`.
//
//  Apple HIG canonical pattern: stateless business-layer enum +
//  per-call Result structs (= matches Foundation URLSession's
//  completion-handler shape).
//
//  All methods are @MainActor-isolated because BookTodoStore is a
//  struct (= no actor) but the View writes through it on
//  @MainActor. Same isolation as KanbanOps per v1.72 T1b.
//
//  Public surface (= 5 entry points):
//    - loadItems(bookId:scope:resolver:) -> LoadResult
//    - addItem(bookId:scope:resolver:title:priority:to:) -> WriteResult
//    - updateStatus(bookId:scope:resolver:item:to:in:) -> WriteResult
//    - deleteItem(bookId:scope:resolver:item:in:) -> WriteResult
//    - ScopeDirectoryResolver protocol (the BookStore seam)
//
//  Out of scope (= NOT moved here, stays in TodoListView):
//    - UI state (scope picker, newItemTitle text field,
//      newItemPriority picker selection, loadError display string).
//    - The `.onChange(of:)` triggers that decide WHEN to reload.
//    - SwiftUI-side resets on add success (= newItemTitle = ""
//      and newItemPriority = .medium = SwiftUI binding resets,
//      NOT business rules).
//    - The TodoRow sub-view's checkbox / priority chip / due-date
//      rendering (= pure layout; = no business logic).
//
//  Honest scope note (= Q46 stop-rule boundary):
//    TodoListView's `addItem` had two SwiftUI-side resets on
//    success (= newItemTitle = "" + newItemPriority = .medium).
//    Both stay in the View (= SwiftUI binding resets, not business
//    rules). The helper returns a WriteResult; the View decides
//    whether to reset the two bindings based on `result.didSave`.

import Foundation

/// Stateless business layer for the per-book todo list. Lifts the
/// disk-IO + state-transition logic out of `TodoListView` per the
/// v1.72 UI/业务/数据 separation audit (= ADR-0009; = the TodoWindow
/// sibling of the KanbanWindow split).
@MainActor
enum TodoOps {

    // MARK: - Seams

    /// Resolves the on-disk directory for a `(bookId, scope)` pair.
    /// Production: `BookStore.scopeDirectory(bookId:scope:)`. Tests
    /// pass `FixedResolver(dir:)` / `NilResolver()`. Mirrors
    /// KanbanOps.ScopeDirectoryResolver (= the v1.72 T1b seam).
    @MainActor
    protocol ScopeDirectoryResolver {
        @MainActor
        func resolve(bookId: UUID?, scope: TaskScope) -> URL?
    }

    // MARK: - Result types

    struct LoadResult: Sendable {
        let items: [PerBookTodoItem]
        let scopeDir: URL?
        let loadError: String?
        init(items: [PerBookTodoItem], scopeDir: URL?, loadError: String?) {
            self.items = items
            self.scopeDir = scopeDir
            self.loadError = loadError
        }
    }

    struct WriteResult: Sendable {
        let savedItems: [PerBookTodoItem]
        let didSave: Bool
        let error: String?
        init(savedItems: [PerBookTodoItem], didSave: Bool, error: String? = nil) {
            self.savedItems = savedItems
            self.didSave = didSave
            self.error = error
        }
    }

    // MARK: - Load

    /// Load the items for `(bookId, scope)`. Mirrors
    /// `TodoListView.reloadFromDisk`:
    /// - unresolved scope → empty items + nil scopeDir + nil error
    /// - resolved scope + missing file → empty items
    /// - resolved scope + existing file → round-trip the JSON
    static func loadItems(
        bookId: UUID?,
        scope: TaskScope,
        resolver: ScopeDirectoryResolver
    ) -> LoadResult {
        let dir = resolver.resolve(bookId: bookId, scope: scope)
        guard let dir = dir else {
            return LoadResult(items: [], scopeDir: nil, loadError: nil)
        }
        let effectiveBookId = bookId ?? UUID()
        let store = BookTodoStore(bookId: effectiveBookId, directory: dir, scope: scope)
        do {
            let items = try store.load()
            return LoadResult(items: items, scopeDir: dir, loadError: nil)
        } catch {
            return LoadResult(items: [], scopeDir: dir, loadError: "\(error)")
        }
    }

    // MARK: - Add

    /// Add a new item with `status = .pending` + the supplied
    /// priority + the given title. Empty / whitespace-only titles
    /// are a no-op (= the View's inline-create `canAdd` guard
    /// makes this unreachable from the UI, but the helper enforces
    /// it for the test + future tool surface).
    static func addItem(
        bookId: UUID?,
        scope: TaskScope,
        resolver: ScopeDirectoryResolver,
        title: String,
        priority: TodoPriority,
        to current: [PerBookTodoItem]
    ) -> WriteResult {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let dir = resolver.resolve(bookId: bookId, scope: scope) else {
            return WriteResult(savedItems: current, didSave: false,
                               error: trimmed.isEmpty ? "标题不能为空" : nil)
        }
        let effectiveBookId = bookId ?? UUID()
        let store = BookTodoStore(bookId: effectiveBookId, directory: dir, scope: scope)
        var next = current
        next.append(PerBookTodoItem(title: trimmed, status: .pending, priority: priority))
        do {
            try store.save(next)
            return WriteResult(savedItems: next, didSave: true)
        } catch {
            return WriteResult(savedItems: current, didSave: false, error: "保存失败: \(error)")
        }
    }

    // MARK: - Update

    /// Move an item to a new status. Bumps `updatedAt`; preserves
    /// `createdAt`. No-op when the item id is stale.
    static func updateStatus(
        bookId: UUID?,
        scope: TaskScope,
        resolver: ScopeDirectoryResolver,
        item: PerBookTodoItem,
        to newStatus: TodoStatus,
        in current: [PerBookTodoItem]
    ) -> WriteResult {
        guard let dir = resolver.resolve(bookId: bookId, scope: scope) else {
            return WriteResult(savedItems: current, didSave: false)
        }
        let effectiveBookId = bookId ?? UUID()
        let store = BookTodoStore(bookId: effectiveBookId, directory: dir, scope: scope)
        var next = current
        guard let idx = next.firstIndex(of: item) else {
            return WriteResult(savedItems: current, didSave: false)
        }
        next[idx].status = newStatus
        next[idx].updatedAt = .now
        do {
            try store.save(next)
            return WriteResult(savedItems: next, didSave: true)
        } catch {
            return WriteResult(savedItems: current, didSave: false, error: "保存失败: \(error)")
        }
    }

    // MARK: - Delete

    /// Remove the matching item by id (= the `$0.id != item.id`
    /// filter invariant from TodoListView.deleteItem). No-op when
    /// the id is already gone.
    static func deleteItem(
        bookId: UUID?,
        scope: TaskScope,
        resolver: ScopeDirectoryResolver,
        item: PerBookTodoItem,
        in current: [PerBookTodoItem]
    ) -> WriteResult {
        let next = current.filter { $0.id != item.id }
        guard next.count != current.count else {
            return WriteResult(savedItems: current, didSave: false)
        }
        guard let dir = resolver.resolve(bookId: bookId, scope: scope) else {
            return WriteResult(savedItems: current, didSave: false)
        }
        let effectiveBookId = bookId ?? UUID()
        let store = BookTodoStore(bookId: effectiveBookId, directory: dir, scope: scope)
        do {
            try store.save(next)
            return WriteResult(savedItems: next, didSave: true)
        } catch {
            return WriteResult(savedItems: current, didSave: false, error: "保存失败: \(error)")
        }
    }
}