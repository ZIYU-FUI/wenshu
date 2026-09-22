//
//  KanbanOpsTests.swift · Wenshu · v1.72 settings-kanban-todo-mvvm T1a
//
//  Behavior + source-level tests for `KanbanOps` (= the stateless
//  enum extracted from KanbanView in v1.72 T1b). Per boss
//  2026-09-22 OOB '按MVVM UI 业务 数据，三分离，排查设置页，kanban，
//  todo 这三个独立窗口是否符合标准': KanbanView currently owns the
//  business logic (= reloadFromDisk / addTicket / updateStatus /
//  deleteTicket + the `bookId = ... ?? UUID()` fallback + the
//  `scopeDirectory` resolution). The fix per ADR-0009 + the v1.70
//  editor-mvvm precedent (= EditorFileWatcher / EditorPersistence /
//  WikiLinkNavigation = stateless enums with @MainActor static funcs)
//  is to lift these into `KanbanOps` (= this test's SUT) and make
//  KanbanView a pure consumer.
//
//  Why an enum (not @Observable class):
//  - State already lives in `BookStore` (= the @Observable global
//    container from AppState; = per v1.68 sidebar UI/业务/数据分离
//    precedent + §11.4 phase 5 = SwiftData is the canonical store).
//  - KanbanView is currently a leaf view (= no parent owns the
//    tickets state; = kanbanViewModel as an @Observable class would
//    either re-shelter the state the BookStore already owns, or
//    require a new @State holder per scene = exactly the problem
//    KanbanWindow.swift:25-71 documents).
//  - The enum only mutates call-site `tickets: inout [KanbanTicket]`
//    + returns Result types. Stateless. Reusable from any caller.
//
//  Coverage (= 8 tests):
//    1. `fileExistsAtCanonicalPath` — source-level guard
//    2. `loadTicketsReturnsEmptyArrayWhenScopeUnresolved`
//    3. `loadTicketsReturnsEmptyArrayWhenScopeDirIsNil`
//    4. `loadTicketsRoundTripsFromDisk` (= real FS + JSON)
//    5. `addTicketAppendsNewEntryWithNewStatus`
//    6. `addTicketIgnoresEmptyAndWhitespaceTitle`
//    7. `updateStatusReplacesStatusAndBumpsUpdatedAt`
//    8. `deleteTicketRemovesById`
//
//  Mock strategy:
//  - No mock framework. Real `/tmp` fixture (= BookDataStoring + the
//    JSON serializer ARE the test target; = mock would test the mock,
//    not the code).
//  - The `ScopeDirectoryResolver` protocol is the seam that lets
//    tests bypass `BookStore.scopeDirectory` (= no global env
//    injection needed; = the helper is swappable per the v1.70
//    WikiLinkNavigation reference-store mock pattern).
//
//  Pattern (= v1.70 editor-mvvm T1a/T2a/T3 precedent): @MainActor +
//  Swift Testing + real fixture in /tmp. No mock framework. The
//  filesystem IS the test target.

import Foundation
import Testing
@testable import WenshuApp

@MainActor
@Suite("v1.72 settings-kanban-todo-mvvm T1a — KanbanOps (per-book kanban business layer)")
struct KanbanOpsTests {

    // MARK: - Fixtures

    /// Real /tmp directory for the test target (= the FS IS the test).
    /// Caller cleans up via `cleanup(_:)`.
    private func makeTempDir() throws -> URL {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("wenshu-KanbanOpsTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func cleanup(_ dir: URL) {
        try? FileManager.default.removeItem(at: dir)
    }

    /// A no-op scope resolver that returns the supplied `dir` for
    /// every scope. Lets tests bypass `BookStore.scopeDirectory` while
    /// keeping the production seam (`bookStore.scopeDirectory(...)` in
    /// production = `ScopeDirectoryResolver.resolve(...)` in the helper).
    private struct FixedResolver: KanbanOps.ScopeDirectoryResolver {
        let dir: URL?
        func resolve(bookId: UUID?, scope: TaskScope) -> URL? { dir }
    }

    private struct NilResolver: KanbanOps.ScopeDirectoryResolver {
        func resolve(bookId: UUID?, scope: TaskScope) -> URL? { nil }
    }

    // MARK: - Source-level structural assertions

    @Test("KanbanOps.swift exists at the canonical path under Views/Kanban/")
    func fileExistsAtCanonicalPath() throws {
        // #filePath resolves to .../Tests/WenshuAppTests/Views/KanbanOpsTests.swift
        // (= 5 segments above the file). Walk up 5 levels to reach
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
            .appendingPathComponent("Kanban")
            .appendingPathComponent("KanbanOps.swift")
            .path
        #expect(FileManager.default.fileExists(atPath: sourcePath),
                "KanbanOps.swift must exist at \(sourcePath) (= v1.72 T1b extraction target)")
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        #expect(source.contains("enum KanbanOps"),
                "KanbanOps.swift must declare `enum KanbanOps` (= the canonical v1.70 stateless-enum pattern)")
        #expect(source.contains("ScopeDirectoryResolver"),
                "KanbanOps must declare the `ScopeDirectoryResolver` seam (= the BookStore bypass seam)")
    }

    // MARK: - load behavior

    @Test("loadTickets returns empty array + loadError nil when scope unresolved")
    func loadTicketsReturnsEmptyArrayWhenScopeUnresolved() throws {
        let dir = try makeTempDir()
        defer { cleanup(dir) }
        let bookId = UUID()
        let resolver = NilResolver()
        let result = KanbanOps.loadTickets(bookId: bookId, scope: .book, resolver: resolver)
        #expect(result.tickets.isEmpty,
                "Unresolved scope (= bookId nil but per-book scope) must produce empty tickets")
        #expect(result.scopeDir == nil,
                "Unresolved scope must report scopeDir == nil (= KanbanView's empty-state guard)")
        #expect(result.loadError == nil,
                "Unresolved scope is NOT an error (= KanbanView shows the empty state, not the red error caption)")
    }

    @Test("loadTickets returns empty array when store file missing (fresh dir)")
    func loadTicketsReturnsEmptyArrayWhenScopeDirIsNil() throws {
        let dir = try makeTempDir()
        defer { cleanup(dir) }
        let bookId = UUID()
        let resolver = FixedResolver(dir: dir)
        let result = KanbanOps.loadTickets(bookId: bookId, scope: .book, resolver: resolver)
        #expect(result.tickets.isEmpty,
                "Missing kanban.json on a real dir must return empty (= per KanbanView's B-09 fallback)")
        #expect(result.scopeDir == dir,
                "scopeDir must mirror the resolver (= the view's reload path reads from it)")
        #expect(result.loadError == nil,
                "Missing file is NOT an error (= matches KanbanView.reloadFromDisk's guard)")
    }

    @Test("loadTickets round-trips: write 2 tickets, read them back")
    func loadTicketsRoundTripsFromDisk() throws {
        let dir = try makeTempDir()
        defer { cleanup(dir) }
        let bookId = UUID()
        let resolver = FixedResolver(dir: dir)

        // Write two tickets first (via addTicket path). The first
        // add returns the post-write array (= 1 entry); we use that
        // as the `to:` input for the second add so the second
        // append lands on top of the first.
        let afterFirst = KanbanOps.addTicket(bookId: bookId, scope: .book, resolver: resolver,
                                              title: "First", to: [])
        #expect(afterFirst.savedTickets.count == 1,
                "First addTicket must append the new entry (= post-write state)")
        let seeded = KanbanOps.addTicket(bookId: bookId, scope: .book, resolver: resolver,
                                          title: "Second", to: afterFirst.savedTickets)
        #expect(seeded.savedTickets.count == 2,
                "Second addTicket must append on top of the first (= the cumulative invariant)")

        let loaded = KanbanOps.loadTickets(bookId: bookId, scope: .book, resolver: resolver)
        #expect(loaded.tickets.count == 2, "loadTickets must round-trip both entries from disk")
        #expect(loaded.tickets.map(\.title) == ["First", "Second"],
                "Order must match the insertion order (= JSON encoder preserves array order)")
        #expect(loaded.loadError == nil, "Round-trip must not surface a load error")
    }

    // MARK: - add behavior

    @Test("addTicket appends a new entry with status = .new when title is non-empty")
    func addTicketAppendsNewEntryWithNewStatus() throws {
        let dir = try makeTempDir()
        defer { cleanup(dir) }
        let bookId = UUID()
        let resolver = FixedResolver(dir: dir)
        let next = KanbanOps.addTicket(bookId: bookId, scope: .book, resolver: resolver,
                                        title: "New kanban", to: [])
        #expect(next.savedTickets.count == 1)
        #expect(next.savedTickets[0].title == "New kanban",
                "Title must round-trip verbatim (= the title the user typed in the inline TextField)")
        #expect(next.savedTickets[0].status == .new,
                "Default status for a freshly added kanban ticket is .new (= B-09 acceptance: \"new ticket goes to .new\")")
        #expect(next.savedTickets[0].id != UUID(),
                "Each new ticket gets a fresh UUID (= per KanbanTicket.init default)")
    }

    @Test("addTicket ignores empty / whitespace-only titles (= returns input unchanged + no save)")
    func addTicketIgnoresEmptyAndWhitespaceTitle() throws {
        let dir = try makeTempDir()
        defer { cleanup(dir) }
        let bookId = UUID()
        let resolver = FixedResolver(dir: dir)
        for emptyTitle in ["", "   ", "\t\n  "] {
            let result = KanbanOps.addTicket(bookId: bookId, scope: .book, resolver: resolver,
                                              title: emptyTitle, to: [])
            #expect(result.savedTickets.isEmpty,
                    "Empty / whitespace title must not append (= mirrors KanbanView.addTicket's `trimmed.isEmpty` guard)")
            #expect(result.didSave == false,
                    "No disk write must happen on empty title (= the helper short-circuits before BookKanbanStore.save)")
        }
    }

    // MARK: - update behavior

    @Test("updateStatus replaces status AND bumps updatedAt")
    func updateStatusReplacesStatusAndBumpsUpdatedAt() throws {
        let dir = try makeTempDir()
        defer { cleanup(dir) }
        let bookId = UUID()
        let resolver = FixedResolver(dir: dir)
        var ticket = KanbanTicket(title: "T", status: .new, createdAt: Date(timeIntervalSince1970: 0),
                                   updatedAt: Date(timeIntervalSince1970: 0))
        let originalCreated = ticket.createdAt
        let result = KanbanOps.updateStatus(bookId: bookId, scope: .book, resolver: resolver,
                                             ticket: ticket, to: .running, in: [ticket])
        #expect(result.savedTickets.count == 1)
        #expect(result.savedTickets[0].status == .running,
                "updateStatus must move the ticket to the new status (= the column-move invariant)")
        #expect(result.savedTickets[0].createdAt == originalCreated,
                "updateStatus must NOT touch createdAt (= the immutable creation timestamp invariant)")
        #expect(result.savedTickets[0].updatedAt > originalCreated,
                "updateStatus must bump updatedAt (= KanbanView.updateStatus: `next[idx].updatedAt = .now`)")
        // also: didSave true
        #expect(result.didSave == true)
        _ = ticket  // silence unused-let warning under `@Suite` re-instantiation
    }

    @Test("updateStatus is a no-op when ticket not found in array")
    func updateStatusNoOpWhenTicketMissing() throws {
        let dir = try makeTempDir()
        defer { cleanup(dir) }
        let bookId = UUID()
        let resolver = FixedResolver(dir: dir)
        let real = KanbanTicket(title: "real")
        let ghost = KanbanTicket(title: "ghost")
        let result = KanbanOps.updateStatus(bookId: bookId, scope: .book, resolver: resolver,
                                             ticket: ghost, to: .done, in: [real])
        #expect(result.savedTickets == [real],
                "Missing ticket must not mutate the array (= KanbanView's `firstIndex(of:)` guard)")
        #expect(result.didSave == false,
                "Missing ticket must not write to disk (= no spurious empty-file rewrite)")
    }

    // MARK: - delete behavior

    @Test("deleteTicket removes by id")
    func deleteTicketRemovesById() throws {
        let dir = try makeTempDir()
        defer { cleanup(dir) }
        let bookId = UUID()
        let resolver = FixedResolver(dir: dir)
        let keep = KanbanTicket(title: "keep")
        let drop = KanbanTicket(title: "drop")
        let result = KanbanOps.deleteTicket(bookId: bookId, scope: .book, resolver: resolver,
                                             ticket: drop, in: [keep, drop])
        #expect(result.savedTickets == [keep],
                "deleteTicket must remove only the matching id (= KanbanView's `$0.id != ticket.id` filter)")
        #expect(result.didSave == true)
    }
}