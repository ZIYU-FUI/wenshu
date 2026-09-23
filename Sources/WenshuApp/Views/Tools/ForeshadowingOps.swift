//
//  ForeshadowingOps.swift · Wenshu · v1.75 foreshadowing-mvvm T1b
//
//  Per-book foreshadowing business layer, extracted from
//  ForeshadowingView (= the P0 view listed in
//  .scratch/2026-09-23-mvvm-audit/spec.md §9 v1.75 arc).
//
//  Per v1.72 KanbanOps template (= @MainActor enum + Result types +
//  static funcs). Per Q112 1 ticket = 1 file.
//
//  Public surface (= 3 entry points + 3 Result types):
//    1. reload(manager:bookId:filterStatus:) -> LoadResult
//    2. addForeshadowing(manager:bookId:title:setupChapterIdText:setupExcerpt:status:) -> AddResult
//    3. removeForeshadowing(manager:row:) -> WriteResult
//
//  All actor calls nil-guarded. Per Q112 no actor 搬家: actor stays in
//  Sources/WenshuApp/Core/Agent/Specialized/ForeshadowingTrackerTools.swift.
//

import Foundation

/// Stateless business layer for ForeshadowingView. Mirrors the v1.72 +
/// v1.74 + v1.75a/b/c precedents (= KanbanOps / TagManagerOps /
/// CharacterLifecycleOps / BookSettingConstraintsOps / LongFormGuardrailsOps).
@MainActor
enum ForeshadowingOps {

    // MARK: - Result types

    /// Outcome of a `reload` (= per-book foreshadowing list snapshot).
    struct LoadResult {
        var rows: [Foreshadowing]
        var staleRows: [Foreshadowing]
        var didLoad: Bool
        var error: String?
    }

    /// Outcome of an `addForeshadowing` write.
    struct AddResult {
        var didSave: Bool
        var error: String?
    }

    /// Outcome of a `removeForeshadowing` write (= or generic write).
    struct WriteResult {
        var didSave: Bool
        var error: String?
    }

    // MARK: - Entry points

    /// Load active + stale foreshadowings in parallel (= the picker + list
    /// + stale-section source).
    static func reload(
        manager: ForeshadowingTracker?,
        bookId: UUID?,
        filterStatus: ForeshadowingStatus?
    ) async -> LoadResult {
        guard let actor = manager,
              let bookId else {
            return LoadResult(rows: [], staleRows: [], didLoad: false, error: nil)
        }
        do {
            async let rowsTask = actor.list(bookId: bookId, status: filterStatus)
            async let staleTask = actor.staleForeshadowings(bookId: bookId)
            let (loadedRows, loadedStale) = try await (rowsTask, staleTask)
            return LoadResult(rows: loadedRows, staleRows: loadedStale, didLoad: true, error: nil)
        } catch {
            return LoadResult(rows: [], staleRows: [], didLoad: false, error: error.localizedDescription)
        }
    }

    /// Add a new foreshadowing from the draft form.
    /// Empty title silently returns didSave=false (= no actor attempt).
    static func addForeshadowing(
        manager: ForeshadowingTracker?,
        bookId: UUID?,
        title: String,
        setupChapterIdText: String,
        setupExcerpt: String,
        status: ForeshadowingStatus
    ) async -> AddResult {
        guard let actor = manager,
              let bookId else {
            return AddResult(didSave: false, error: "manager or bookId is nil")
        }
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            return AddResult(didSave: false, error: "title is empty")
        }
        let trimmedChapterText = setupChapterIdText.trimmingCharacters(in: .whitespacesAndNewlines)
        let setupChapterId = UUID(uuidString: trimmedChapterText)
        let trimmedExcerpt = setupExcerpt.trimmingCharacters(in: .whitespacesAndNewlines)
        let row = Foreshadowing(
            bookId: bookId,
            title: trimmedTitle,
            setupChapterId: setupChapterId,
            setupExcerpt: trimmedExcerpt,
            status: status
        )
        do {
            try await actor.add(row)
            return AddResult(didSave: true, error: nil)
        } catch {
            return AddResult(didSave: false, error: error.localizedDescription)
        }
    }

    /// Remove one foreshadowing by id (= the row's trash button).
    static func removeForeshadowing(
        manager: ForeshadowingTracker?,
        row: Foreshadowing
    ) async -> WriteResult {
        guard let actor = manager else {
            return WriteResult(didSave: false, error: "manager is nil")
        }
        do {
            try await actor.remove(id: row.id)
            return WriteResult(didSave: true, error: nil)
        } catch {
            return WriteResult(didSave: false, error: error.localizedDescription)
        }
    }
}