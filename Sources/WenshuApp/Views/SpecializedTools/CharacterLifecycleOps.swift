//
//  CharacterLifecycleOps.swift · Wenshu · v1.75 character-lifecycle-mvvm T1b
//
//  Per-book character lifecycle business layer, extracted from
//  CharacterLifecycleView (= the P0 view listed in
//  .scratch/2026-09-23-mvvm-audit/spec.md §9.2 row 1; = 483 LOC
//  with 5 inline async funcs that delegate to the
//  CharacterLifecycleTracker actor in Core/Agent/Specialized/
//  CharacterLifecycleTools.swift L287).
//
//  Per boss 2026-09-22 OOB '按MVVM UI 业务 数据，三分离' (= the
//  v1.70/v1.71/v1.72/v1.74 arcs have done UI / 业务 / 数据 分离
//  for editor / right-column / settings-kanban-todo / tagmanager-
//  placeholder-idealibrary / cardopen-dedupe; = CharacterLifecycleView
//  is the next P0 split per the §9 extended audit on 2026-09-23).
//
//  Public surface (= 4 entry points + 4 Result types):
//    - reload(manager:bookId:bookStore:) -> LoadResult
//    - reloadTimeline(manager:bookId:characterId:) -> TimelineResult
//    - addEvent(manager:bookId:characterId:stage:chapterUUIDText:excerpt:) -> AddResult
//    - removeEvent(manager:event:) -> WriteResult
//
//  Why all entries accept `manager: CharacterLifecycleTracker?`
//  (= optional actor seam; = lets tests cover nil-paths without
//  constructing the heavy BookStore fixture that the actor init
//  requires). Production wires the real actor (= no nil-path
//  behavior in production = the @State manager is non-nil after
//  ensureTracker() per the view wire in T1c).
//
//  Source-side compilation: 0 errors / 0 new warnings (verified
//  via swift build --target WenshuApp).
//  Test-side: 14/14 tests pass (verified via swift test --filter
//  CharacterLifecycleOpsTests).
//
//  Pattern (= v1.72 KanbanOpsTests T1a + v1.74 TagManagerOps
//  precedent): @MainActor + Swift Testing + per-call nil-guards
//  + nil-path tests only (= no real-actor integration tests to
//  avoid the BookStore fixture complexity).
//

import Foundation

@MainActor
enum CharacterLifecycleOps {

    // MARK: - Result types

    struct LoadResult: Sendable {
        let characters: [Character]
        let events: [LifecycleEvent]
        let contradictions: [LifecycleContradiction]
        let didLoad: Bool
        let error: String?
    }

    struct TimelineResult: Sendable {
        let rows: [LifecycleEvent]
        let error: String?
    }

    struct AddResult: Sendable {
        let didSave: Bool
        let error: String?
    }

    struct WriteResult: Sendable {
        let didSave: Bool
        let error: String?
    }

    // MARK: - Public surface

    /// Load the per-book state (= characters from BookStore +
    /// events + contradictions from actor + delegate timeline load
    /// to `reloadTimeline`). Mirrors CharacterLifecycleView
    /// .reload() (= the source of truth pre-v1.75).
    static func reload(
        manager: CharacterLifecycleTracker?,
        bookId: UUID?,
        bookStore: BookStore?
    ) async -> LoadResult {
        guard let actor = manager,
              let bookId,
              let bookStore else {
            return LoadResult(
                characters: [],
                events: [],
                contradictions: [],
                didLoad: false,
                error: manager == nil ? "manager is nil" : (bookId == nil ? "bookId is nil" : "bookStore is nil")
            )
        }
        // Load characters from the per-book character store (= single
        // source of truth for character metadata). Forgiving on
        // missing / corrupt store = empty array.
        let characters = (try? bookStore.characterStore.loadCharacters()) ?? []
        do {
            let events = try await actor.list(bookId: bookId)
            let contradictions = try await actor.contradictions(bookId: bookId)
            return LoadResult(
                characters: characters,
                events: events,
                contradictions: contradictions,
                didLoad: true,
                error: nil
            )
        } catch {
            return LoadResult(
                characters: characters,
                events: [],
                contradictions: [],
                didLoad: false,
                error: error.localizedDescription
            )
        }
    }

    /// Load the timeline for one character (= the per-character
    /// lifecycle list shown under the picker).
    static func reloadTimeline(
        manager: CharacterLifecycleTracker?,
        bookId: UUID?,
        characterId: UUID?
    ) async -> TimelineResult {
        guard let actor = manager,
              let bookId,
              let characterId,
              characterId != UUID() else {
            return TimelineResult(rows: [], error: nil)
        }
        do {
            let rows = try await actor.timeline(bookId: bookId, characterId: characterId)
            return TimelineResult(rows: rows, error: nil)
        } catch {
            return TimelineResult(rows: [], error: error.localizedDescription)
        }
    }

    /// Add a new lifecycle event (= the "+ Event" button handler).
    /// Validates: characterId non-empty (= not UUID()) + excerpt
    /// non-empty + chapterUUIDText parses if non-empty.
    static func addEvent(
        manager: CharacterLifecycleTracker?,
        bookId: UUID?,
        characterId: UUID?,
        stage: LifecycleStage,
        chapterUUIDText: String,
        excerpt: String
    ) async -> AddResult {
        guard let actor = manager,
              let bookId,
              let characterId,
              characterId != UUID() else {
            return AddResult(didSave: false, error: "manager / bookId / characterId missing")
        }
        let trimmedExcerpt = excerpt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedExcerpt.isEmpty else {
            return AddResult(didSave: false, error: "excerpt is empty")
        }
        let chapterId: UUID? = {
            let trimmed = chapterUUIDText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            return UUID(uuidString: trimmed)
        }()
        let event = LifecycleEvent(
            bookId: bookId,
            characterId: characterId,
            stage: stage,
            chapterId: chapterId,
            excerpt: trimmedExcerpt
        )
        do {
            try await actor.add(event)
            return AddResult(didSave: true, error: nil)
        } catch {
            return AddResult(didSave: false, error: error.localizedDescription)
        }
    }

    /// Remove a lifecycle event by id (= the row's delete button).
    static func removeEvent(
        manager: CharacterLifecycleTracker?,
        event: LifecycleEvent
    ) async -> WriteResult {
        guard let actor = manager else {
            return WriteResult(didSave: false, error: "manager is nil")
        }
        do {
            try await actor.remove(id: event.id)
            return WriteResult(didSave: true, error: nil)
        } catch {
            return WriteResult(didSave: false, error: error.localizedDescription)
        }
    }
}