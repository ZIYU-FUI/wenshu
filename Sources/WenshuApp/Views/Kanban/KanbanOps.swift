//
//  KanbanOps.swift · Wenshu · v1.72 settings-kanban-todo-mvvm T1b
//
//  Per-book kanban business layer, extracted from KanbanView.
//
//  Per boss 2026-09-22 OOB '按MVVM UI 业务 数据，三分离' (= UI /
//  业务 / 数据 separation audit) + ADR-0009 + the v1.70 editor-mvvm
//  precedent (= EditorFileWatcher / EditorPersistence /
//  WikiLinkNavigation = stateless enums with @MainActor static funcs):
//  KanbanView currently owns the business logic for the per-book
//  kanban board. reloadFromDisk / addTicket / updateStatus /
//  deleteTicket are private methods on the View, and the tickets
//  array sits in @State on the View (= coupling UI to data in the
//  same file). This helper lifts the business layer into a stateless
//  enum so the View can become a pure consumer.
//
//  Why a stateless enum (not an @Observable class):
//  - State already lives in `BookStore` (= the @Observable global
//    container from AppState; = per §11.4 phase 5 = SwiftData is the
//    canonical store + BookStore exposes scopeDirectory).
//  - KanbanView is a leaf view (= no parent owns the tickets state;
//    = kanbanViewModel as an @Observable class would either
//    re-shelter the state the BookStore already owns, or require a
//    new @State holder per scene = exactly the problem
//    KanbanWindow.swift:25-71 documents: @Environment does not cross
//    scene boundaries).
//  - The enum only mutates call-site `inout [KanbanTicket]` and
//    returns Result types. Stateless. Reusable from any caller
//    (KanbanView today, future reader from a tools panel, etc.).
//
//  Why a `ScopeDirectoryResolver` seam (= BookStore bypass):
//  - Production call site = `BookStore.scopeDirectory(bookId:scope:)`.
//    Making the helper a static function with that signature would
//    force tests to construct a BookStore (= global env, fragile).
//  - The seam lets the helper accept any resolver; production wires
//    the BookStore adapter, tests pass `FixedResolver(dir:)` /
//    `NilResolver()`.
//  - Same pattern as v1.70 WikiLinkNavigation's `ReferenceStoring`
//    seam (= a protocol with one method, satisfied by BookStore in
//    production and a MockReferenceStore struct in tests).
//
//  Apple HIG canonical pattern: stateless business-layer enum +
//  per-call Result structs (= matches Foundation URLSession's
//  completion-handler shape; = no leaky global state).
//
//  All methods are @MainActor-isolated because:
//  - BookKanbanStore is a struct (= no actor), but the View writes
//    through it on @MainActor.
//  - The Result types are simple value types; = no shared mutation.
//  - Same isolation as EditorFileWatcher / EditorPersistence per
//    v1.70a / v1.70d.
//
//  Public surface (= 5 entry points):
//    - loadTickets(bookId:scope:resolver:) -> LoadResult
//    - addTicket(bookId:scope:resolver:title:to:) -> WriteResult
//    - updateStatus(bookId:scope:resolver:ticket:to:in:) -> WriteResult
//    - deleteTicket(bookId:scope:resolver:ticket:in:) -> WriteResult
//    - ScopeDirectoryResolver protocol (the BookStore seam)
//
//  Out of scope (= NOT moved here, stays in View):
//    - UI state (`scope` picker selection, `newTicketTitle` text
//      field, `loadError` display string) — these are SwiftUI-only
//      concerns that have no business meaning outside the view.
//    - The `.onChange(of:)` triggers that decide WHEN to reload —
//      the helper exposes WHEN via the call site, not WHEN via a
//      subscription (per ADR-0009 = the view layer owns reactive
//      triggers; the business layer is pure).
//    - Reload semantics from disk → applied to View state. The
//      helper returns the new array (= pure data); the View assigns
//      it to `tickets`. The trigger stays in the View per SwiftUI
//      conventions.
//
//  Honest scope note (= Q46 stop-rule boundary):
//    KanbanView's `addTicket` had a side effect of clearing the
//    `newTicketTitle` @State string on success (= the SwiftUI-side
//    inline-create UX reset). That reset stays in the View (= it's
//    a SwiftUI binding reset, not a business rule). The helper
//    returns a WriteResult; the View decides whether to reset the
//    text field based on `result.didSave`.

import Foundation

/// Stateless business layer for the per-book kanban board. Lifts
/// the disk-IO + state-transition logic out of `KanbanView` per
/// the v1.72 UI/业务/数据 separation audit (= ADR-0009).
@MainActor
enum KanbanOps {

    // MARK: - Seams (= testable seams; production wires BookStore adapter)

    /// Resolves the on-disk directory for a `(bookId, scope)` pair.
    /// Production implementation: `BookStore.scopeDirectory(bookId:
    /// scope:)`. Tests pass a `FixedResolver(dir:)` or `NilResolver()`.
    @MainActor
    protocol ScopeDirectoryResolver {
        @MainActor
        func resolve(bookId: UUID?, scope: TaskScope) -> URL?
    }

    // MARK: - Result types

    /// Result of loading the per-book kanban JSON file.
    struct LoadResult: Sendable {
        let tickets: [KanbanTicket]
        let scopeDir: URL?
        let loadError: String?
        init(tickets: [KanbanTicket], scopeDir: URL?, loadError: String?) {
            self.tickets = tickets
            self.scopeDir = scopeDir
            self.loadError = loadError
        }
    }

    /// Result of a write (= add / update / delete). The View assigns
    /// `savedTickets` to its `tickets` @State (= the new source of
    /// truth). `didSave` lets the View decide whether to reset
    /// SwiftUI-only side effects (= e.g. clearing the inline-create
    /// TextField on successful add).
    struct WriteResult: Sendable {
        let savedTickets: [KanbanTicket]
        let didSave: Bool
        let error: String?
        init(savedTickets: [KanbanTicket], didSave: Bool, error: String? = nil) {
            self.savedTickets = savedTickets
            self.didSave = didSave
            self.error = error
        }
    }

    // MARK: - Load

    /// Load the tickets for `(bookId, scope)`. Mirrors
    /// `KanbanView.reloadFromDisk` (= the B-09 + B-13 invariant set):
    /// - unresolved scope → empty tickets + nil scopeDir + nil error
    ///   (= View shows the empty state, NOT the red error caption)
    /// - resolved scope + missing file → empty tickets (= fresh board)
    /// - resolved scope + existing file → round-trip the JSON
    static func loadTickets(
        bookId: UUID?,
        scope: TaskScope,
        resolver: ScopeDirectoryResolver
    ) -> LoadResult {
        let dir = resolver.resolve(bookId: bookId, scope: scope)
        guard let dir = dir else {
            return LoadResult(tickets: [], scopeDir: nil, loadError: nil)
        }
        // The library scope has no book id; for per-book scopes we
        // use the active book (= may be nil for `.book` if no book
        // is selected, but the guard above returned in that case).
        let effectiveBookId = bookId ?? UUID()
        let store = BookKanbanStore(bookId: effectiveBookId, directory: dir, scope: scope)
        do {
            let tickets = try store.load()
            return LoadResult(tickets: tickets, scopeDir: dir, loadError: nil)
        } catch {
            return LoadResult(tickets: [], scopeDir: dir, loadError: "\(error)")
        }
    }

    // MARK: - Add

    /// Add a new ticket with `status = .new` and the given title.
    /// Empty / whitespace-only titles are a no-op (= the View's
    /// inline-create `canAdd` guard makes this unreachable from the
    /// UI, but the helper enforces it for the test + future tool
    /// surface).
    static func addTicket(
        bookId: UUID?,
        scope: TaskScope,
        resolver: ScopeDirectoryResolver,
        title: String,
        to current: [KanbanTicket]
    ) -> WriteResult {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let dir = resolver.resolve(bookId: bookId, scope: scope) else {
            return WriteResult(savedTickets: current, didSave: false,
                               error: trimmed.isEmpty ? "标题不能为空" : nil)
        }
        let effectiveBookId = bookId ?? UUID()
        let store = BookKanbanStore(bookId: effectiveBookId, directory: dir, scope: scope)
        var next = current
        next.append(KanbanTicket(title: trimmed, status: .new))
        do {
            try store.save(next)
            return WriteResult(savedTickets: next, didSave: true)
        } catch {
            return WriteResult(savedTickets: current, didSave: false, error: "保存失败: \(error)")
        }
    }

    // MARK: - Update

    /// Move a ticket to a new status. Bumps `updatedAt`; preserves
    /// `createdAt`. If the ticket is not in the array (= stale id),
    /// the call is a no-op (= no write, no array mutation).
    static func updateStatus(
        bookId: UUID?,
        scope: TaskScope,
        resolver: ScopeDirectoryResolver,
        ticket: KanbanTicket,
        to newStatus: KanbanStatus,
        in current: [KanbanTicket]
    ) -> WriteResult {
        guard let dir = resolver.resolve(bookId: bookId, scope: scope) else {
            return WriteResult(savedTickets: current, didSave: false)
        }
        let effectiveBookId = bookId ?? UUID()
        let store = BookKanbanStore(bookId: effectiveBookId, directory: dir, scope: scope)
        var next = current
        guard let idx = next.firstIndex(of: ticket) else {
            return WriteResult(savedTickets: current, didSave: false)
        }
        next[idx].status = newStatus
        next[idx].updatedAt = .now
        do {
            try store.save(next)
            return WriteResult(savedTickets: next, didSave: true)
        } catch {
            return WriteResult(savedTickets: current, didSave: false, error: "保存失败: \(error)")
        }
    }

    // MARK: - Delete

    /// Remove the matching ticket by id (= the `\$0.id != ticket.id`
    /// filter invariant from KanbanView.deleteTicket). If the ticket
    /// is not present, the array is unchanged (= the no-op write
    /// still saves the unchanged array? No — only if it was actually
    /// present. Mirrors the View's behavior of doing nothing when the
    /// id is already gone).
    static func deleteTicket(
        bookId: UUID?,
        scope: TaskScope,
        resolver: ScopeDirectoryResolver,
        ticket: KanbanTicket,
        in current: [KanbanTicket]
    ) -> WriteResult {
        let next = current.filter { $0.id != ticket.id }
        guard next.count != current.count else {
            // ticket not present — no-op, no write (= matches View)
            return WriteResult(savedTickets: current, didSave: false)
        }
        guard let dir = resolver.resolve(bookId: bookId, scope: scope) else {
            return WriteResult(savedTickets: current, didSave: false)
        }
        let effectiveBookId = bookId ?? UUID()
        let store = BookKanbanStore(bookId: effectiveBookId, directory: dir, scope: scope)
        do {
            try store.save(next)
            return WriteResult(savedTickets: next, didSave: true)
        } catch {
            return WriteResult(savedTickets: current, didSave: false, error: "保存失败: \(error)")
        }
    }
}

// MARK: - Production seam: BookStore adapter

// MARK: - Shared production seam: BookStore adapter
//
// Shared adapter (= not nested inside KanbanOps or TodoOps) because
// both helpers need to bridge the global @Observable BookStore
// container to their own ScopeDirectoryResolver protocol. Per
// v1.70 WikiLinkNavigation + ReferenceStoring precedent (= a thin
// concrete type that bridges a global container to the helper's
// protocol seam; = reusable across multiple helpers).
//
// Same role (= BookStore.scopeDirectory(bookId:scope:) →
// KanbanOps.ScopeDirectoryResolver / TodoOps.ScopeDirectoryResolver).
// The two protocols are identical; = the adapter satisfies both.

/// Wires `BookStore.scopeDirectory(bookId:scope:)` (= the production
/// resolver) into `KanbanOps.ScopeDirectoryResolver` AND
/// `TodoOps.ScopeDirectoryResolver` (= both protocols are identical
/// shapes; = one adapter satisfies both via composition-free
/// conformance).
@MainActor
struct BookStoreScopeDirectoryResolver: KanbanOps.ScopeDirectoryResolver,
                                       TodoOps.ScopeDirectoryResolver {
    let bookStore: BookStore
    init(bookStore: BookStore) { self.bookStore = bookStore }
    func resolve(bookId: UUID?, scope: TaskScope) -> URL? {
        bookStore.scopeDirectory(bookId: bookId, scope: scope)
    }
}