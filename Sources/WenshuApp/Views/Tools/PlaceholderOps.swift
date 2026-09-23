//
//  PlaceholderOps.swift · Wenshu · v1.74 placeholder-mvvm T1
//
//  Per-book placeholder business layer, extracted from PlaceholderView.
//
//  Per boss 2026-09-22 OOB '按MVVM UI 业务 数据，三分离' (= UI /
//  业务 / 数据 separation audit) + the v1.72 settings-kanban-todo
//  precedent (= KanbanOps / TodoOps / SettingsOps = stateless
//  enums with @MainActor static funcs) + the v1.74 tagmanager-mvvm
//  precedent (= TagManagerOps = nil-able actor reference seam
//  for tests): PlaceholderView currently owns the business logic
//  for the per-book placeholder tracker. reload / addPlaceholder /
//  resolvePlaceholder / abandonPlaceholder / reopenPlaceholder /
//  removePlaceholder / runScan are private methods on the View
//  (= coupling UI to the domain actor's lifecycle + the SwiftUI
//  draft state in the same file). This helper lifts the business
//  layer into a stateless enum so the View can become a pure
//  consumer.
//
//  Why a stateless enum (not an @Observable class):
//  - State already lives in `PlaceholderScanner` (= the actor
//    defined in Core/Agent/Specialized/PlaceholderScannerTools.swift;
//    = source of truth per AGENTS.md §11.3 wenshu-side wins
//    pattern).
//  - View-level state (`scanner: PlaceholderScanner?` + draft form
//    fields + rows + filterStatus) is the SwiftUI layer; ==
//    transient for the v1 tab session.
//  - The enum only takes the actor reference as a parameter and
//    returns Result types. Stateless. Reusable from any caller.
//
//  Why async throws (vs the v1.72 KanbanOps sync shape):
//  - PlaceholderScanner is an actor (= the canonical domain store
//    for placeholders.json); = every method is `async throws`
//    for actor isolation. The Ops enum exposes the same shape so
//    the View's `await actor.foo()` calls land on Ops without
//    changing the TaskGroup wiring.
//
//  `scanner: PlaceholderScanner?` instead of
//  `scanner: PlaceholderScanner` is the seam that lets tests
//  bypass the BookStore (= tests pass nil to drive the
//  empty-result paths + pre-condition guards; = no global env
//  injection needed).
//
//  Apple HIG canonical pattern: stateless business-layer enum +
//  per-call Result structs (= matches Foundation URLSession's
//  completion-handler shape; = no leaky global state).
//
//  All methods are @MainActor-isolated because:
//  - The View writes through them on @MainActor.
//  - The actor's public methods are actor-isolated (= calls land
//    on @MainActor for view safety).
//  - The Result types are simple value types; = no shared
//    mutation.
//
//  Public surface (= 8 entry points):
//    - reload(scanner:bookId:filterStatus:) -> LoadResult
//    - addPlaceholder(scanner:bookId:chapterIdText:lineText:context:pattern:status:) -> WriteResult
//    - resolvePlaceholder(scanner:row:) -> WriteResult
//    - abandonPlaceholder(scanner:row:) -> WriteResult
//    - reopenPlaceholder(scanner:row:) -> WriteResult
//    - removePlaceholder(scanner:row:) -> WriteResult
//    - runScan(scanner:bookId:chapterText:) -> ScanResult
//
//  Out of scope (= NOT moved here, stays in View):
//    - UI state (`draftChapterText` / `draftLineText` /
//      `draftContext` / `draftPattern` / `draftStatus` /
//      `filterStatus` / `scanChapterText` / `lastScanCount`
//      state + errorText) — these are SwiftUI-only concerns that
//      have no business meaning outside the view.
//    - The `.task(id:)` triggers that decide WHEN to reload —
//      the helper exposes WHEN via the call site, not WHEN via a
//      subscription (per ADR-0009 = the view layer owns reactive
//      triggers; the business layer is pure).
//    - `ensureScanner()` lazy-actor-construction stays in the
//      View (= it is a state transition, not a remote call).
//    - `scratchChapterId(for:)` static helper stays in the View
//      (= it's used in two view-local places: the runScan caller
//      and any future "open the scratch chapter" affordance).
//
//  Honest scope note (= Q46 stop-rule boundary):
//    PlaceholderView's `addPlaceholder` had a side effect of
//    clearing 4 draft @State strings on success (= the
//    SwiftUI-side inline-create UX reset). That reset stays in
//    the View (= it is a SwiftUI binding reset, not a business
//    rule). The helper returns a WriteResult; the View decides
//    whether to reset the text fields based on `result.didSave`.
//

import Foundation

/// Stateless business layer for the per-book placeholder
/// tracker. Lifts the actor-call + state-transition logic out of
/// `PlaceholderView` per the v1.74 UI/业务/数据 separation audit
/// (= ADR-0009).
@MainActor
enum PlaceholderOps {

    // MARK: - Result types

    /// Result of `reload` (= list placeholders filtered by status).
    struct LoadResult: Sendable {
        let rows: [Placeholder]
        let didLoad: Bool
        let error: String?
        init(rows: [Placeholder], didLoad: Bool, error: String? = nil) {
            self.rows = rows
            self.didLoad = didLoad
            self.error = error
        }
    }

    /// Result of `addPlaceholder` / `resolve` / `abandon` /
    /// `reopen` / `remove` (= a single write to the actor).
    struct WriteResult: Sendable {
        let didSave: Bool
        let error: String?
        init(didSave: Bool, error: String? = nil) {
            self.didSave = didSave
            self.error = error
        }
    }

    /// Result of `runScan` (= scan-and-add from a pasted chapter
    /// text).
    struct ScanResult: Sendable {
        let addedCount: Int
        let didScan: Bool
        let error: String?
        init(addedCount: Int, didScan: Bool, error: String? = nil) {
            self.addedCount = addedCount
            self.didScan = didScan
            self.error = error
        }
    }

    // MARK: - Load

    /// Load the placeholder list for `bookId`. Mirrors
    /// `PlaceholderView.reload` (= the pre-v1.74 invariant set):
    /// - nil scanner OR nil bookId → empty rows with didLoad=false
    /// - otherwise → actor.list(bookId:status:filterStatus)
    static func reload(
        scanner: PlaceholderScanner?,
        bookId: UUID?,
        filterStatus: PlaceholderStatus?
    ) async -> LoadResult {
        guard let scanner = scanner, let bookId = bookId else {
            return LoadResult(rows: [], didLoad: false)
        }
        do {
            let rows = try await scanner.list(bookId: bookId, status: filterStatus)
            return LoadResult(rows: rows, didLoad: true)
        } catch {
            return LoadResult(rows: [], didLoad: false,
                              error: error.localizedDescription)
        }
    }

    // MARK: - Add

    /// Add a new placeholder. Mirrors
    /// `PlaceholderView.addPlaceholder`:
    /// - nil scanner OR nil bookId → no-op (didSave=false, no error)
    /// - empty / whitespace-only chapter / empty / whitespace-only
    ///   pattern → no-op (didSave=false, no error)
    /// - unparseable chapterId → no-op (didSave=false, no error)
    /// - otherwise → actor.add(Placeholder(bookId:chapterId:
    ///   lineNumber:context:pattern:status:))
    static func addPlaceholder(
        scanner: PlaceholderScanner?,
        bookId: UUID?,
        chapterIdText: String,
        lineText: String,
        context: String,
        pattern: String,
        status: PlaceholderStatus
    ) async -> WriteResult {
        guard let scanner = scanner, let bookId = bookId else {
            return WriteResult(didSave: false)
        }
        let trimmedChapter = chapterIdText.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPattern = pattern.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContext = context.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let chapterId = UUID(uuidString: trimmedChapter),
              !trimmedPattern.isEmpty else {
            return WriteResult(didSave: false)
        }
        let lineNumber = Int(lineText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        let row = Placeholder(
            bookId: bookId,
            chapterId: chapterId,
            lineNumber: lineNumber,
            context: trimmedContext,
            pattern: trimmedPattern,
            status: status
        )
        do {
            try await scanner.add(row)
            return WriteResult(didSave: true)
        } catch {
            return WriteResult(didSave: false, error: error.localizedDescription)
        }
    }

    // MARK: - Resolve

    /// Mark a placeholder resolved. Mirrors
    /// `PlaceholderView.resolvePlaceholder`:
    /// - nil scanner → no-op
    /// - otherwise → actor.resolve(id:)
    static func resolvePlaceholder(
        scanner: PlaceholderScanner?,
        row: Placeholder
    ) async -> WriteResult {
        guard let scanner = scanner else {
            return WriteResult(didSave: false)
        }
        do {
            try await scanner.resolve(id: row.id)
            return WriteResult(didSave: true)
        } catch {
            return WriteResult(didSave: false, error: error.localizedDescription)
        }
    }

    // MARK: - Abandon

    /// Mark a placeholder abandoned (= the user gave up). Mirrors
    /// `PlaceholderView.abandonPlaceholder`:
    /// - nil scanner → no-op
    /// - otherwise → actor.abandon(id:)
    static func abandonPlaceholder(
        scanner: PlaceholderScanner?,
        row: Placeholder
    ) async -> WriteResult {
        guard let scanner = scanner else {
            return WriteResult(didSave: false)
        }
        do {
            try await scanner.abandon(id: row.id)
            return WriteResult(didSave: true)
        } catch {
            return WriteResult(didSave: false, error: error.localizedDescription)
        }
    }

    // MARK: - Reopen

    /// Reopen an abandoned placeholder. Mirrors
    /// `PlaceholderView.reopenPlaceholder`:
    /// - nil scanner → no-op
    /// - otherwise → actor.reopen(id:)
    static func reopenPlaceholder(
        scanner: PlaceholderScanner?,
        row: Placeholder
    ) async -> WriteResult {
        guard let scanner = scanner else {
            return WriteResult(didSave: false)
        }
        do {
            try await scanner.reopen(id: row.id)
            return WriteResult(didSave: true)
        } catch {
            return WriteResult(didSave: false, error: error.localizedDescription)
        }
    }

    // MARK: - Remove

    /// Remove a placeholder by id. Mirrors
    /// `PlaceholderView.removePlaceholder`:
    /// - nil scanner → no-op
    /// - otherwise → actor.remove(id:)
    static func removePlaceholder(
        scanner: PlaceholderScanner?,
        row: Placeholder
    ) async -> WriteResult {
        guard let scanner = scanner else {
            return WriteResult(didSave: false)
        }
        do {
            try await scanner.remove(id: row.id)
            return WriteResult(didSave: true)
        } catch {
            return WriteResult(didSave: false, error: error.localizedDescription)
        }
    }

    // MARK: - Scan (= paste-and-scan from chapter text)

    /// Run a placeholder scan on pasted chapter text. Mirrors
    /// `PlaceholderView.runScan`:
    /// - nil scanner OR nil bookId → no-op (addedCount=0)
    /// - otherwise → actor.scanAndAdd(chapterText:bookId:
    ///   chapterId:)
    /// - chapterIdText is the deterministic scratch chapter id
    ///   (= the View computes it via `scratchChapterId(for:)` and
    ///   passes the resulting UUID string here).
    static func runScan(
        scanner: PlaceholderScanner?,
        bookId: UUID?,
        chapterText: String,
        chapterId: UUID
    ) async -> ScanResult {
        guard let scanner = scanner, let bookId = bookId else {
            return ScanResult(addedCount: 0, didScan: false)
        }
        do {
            let added = try await scanner.scanAndAdd(
                chapterText: chapterText,
                bookId: bookId,
                chapterId: chapterId
            )
            return ScanResult(addedCount: added.count, didScan: true)
        } catch {
            return ScanResult(addedCount: 0, didScan: false,
                              error: error.localizedDescription)
        }
    }
}