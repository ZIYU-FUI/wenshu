//
//  CharacterRelationshipsOps.swift · Wenshu · v1.75 character-relationships-mvvm T1b
//
//  Per-book character-relationship business layer, extracted from
//  CharacterRelationshipsView (= the P0 view listed in
//  .scratch/2026-09-23-mvvm-audit/spec.md §9 v1.75 arc).
//
//  Per v1.72 KanbanOps template (= @MainActor enum + Result types +
//  static funcs). Per Q112 1 ticket = 1 file.
//
//  Public surface (= 3 entry points + 3 Result types):
//    1. reload(manager:bookId:) -> LoadResult
//    2. addRelationship(manager:bookId:fromCharacterId:toCharacterId:kind:description:) -> AddResult
//    3. removeRelationship(manager:bookId:row:) -> WriteResult
//
//  All actor calls nil-guarded. Per Q112 no actor 搬家: actor stays in
//  Sources/WenshuApp/Core/Agent/Specialized/CharacterRelationshipTools.swift.
//

import Foundation

/// Stateless business layer for CharacterRelationshipsView. Mirrors the
/// v1.72 + v1.74 + v1.75a/b/c/d precedents.
@MainActor
enum CharacterRelationshipsOps {

    // MARK: - Result types

    /// Outcome of a `reload` (= per-book relationship + character + inconsistency snapshot).
    struct LoadResult {
        var relationships: [CharacterRelationship]
        var inconsistencies: [RelationshipInconsistency]
        var didLoad: Bool
        var error: String?
    }

    /// Outcome of an `addRelationship` write.
    struct AddResult {
        var didSave: Bool
        var error: String?
    }

    /// Outcome of a `removeRelationship` write (= or generic write).
    struct WriteResult {
        var didSave: Bool
        var error: String?
    }

    // MARK: - Entry points

    /// Load relationships + inconsistencies for one book (= the picker + list source).
    static func reload(
        manager: CharacterRelationshipTracker?,
        bookId: UUID?
    ) async -> LoadResult {
        guard let actor = manager,
              let bookId else {
            return LoadResult(relationships: [], inconsistencies: [], didLoad: false, error: nil)
        }
        do {
            let list = try await actor.list(bookId: bookId)
            let issues = try await actor.inconsistencies(bookId: bookId)
            return LoadResult(relationships: list, inconsistencies: issues, didLoad: true, error: nil)
        } catch {
            return LoadResult(relationships: [], inconsistencies: [], didLoad: false, error: error.localizedDescription)
        }
    }

    /// Add a new relationship. Rejects when from == to (= same character).
    static func addRelationship(
        manager: CharacterRelationshipTracker?,
        bookId: UUID?,
        fromCharacterId: UUID?,
        toCharacterId: UUID?,
        kind: RelationshipKind,
        description: String
    ) async -> AddResult {
        guard let actor = manager,
              let bookId,
              let from = fromCharacterId,
              let to = toCharacterId else {
            return AddResult(didSave: false, error: "manager, bookId, or character ids missing")
        }
        guard from != to else {
            return AddResult(didSave: false, error: "from and to are the same character")
        }
        let row = CharacterRelationship(
            bookId: bookId,
            fromCharacterId: from,
            toCharacterId: to,
            kind: kind,
            description: description
        )
        do {
            try await actor.add(row)
            return AddResult(didSave: true, error: nil)
        } catch {
            return AddResult(didSave: false, error: error.localizedDescription)
        }
    }

    /// Remove one relationship by id (= the row's delete button).
    static func removeRelationship(
        manager: CharacterRelationshipTracker?,
        bookId: UUID?,
        row: CharacterRelationship
    ) async -> WriteResult {
        guard let actor = manager,
              let bookId else {
            return WriteResult(didSave: false, error: "manager or bookId is nil")
        }
        do {
            try await actor.remove(id: row.id, from: bookId)
            return WriteResult(didSave: true, error: nil)
        } catch {
            return WriteResult(didSave: false, error: error.localizedDescription)
        }
    }
}