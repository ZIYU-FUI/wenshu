//
//  SidebarServiceMutation+References.swift
//
//  The sidebar's REFERENCE mutations (= the reference library's own
//  rows, = which live in the tree's library part, = not in the
//  shelves part).
//
//  They are in a file of their own so that `SidebarServiceMutation.swift`
//  stays under the repository's 600-LOC cap (= the shelf, = the book and
//  = the book-doc mutations still live there), = and the split is
//  registered in the NFI.
//
//  One view per file (per Apple HIG).
//

import Foundation

extension SidebarService {
    /// (= boss 2026-10-10 "素 材区，卡片， 右键菜单， 做删除、重 命名" directive). Delete a single
    /// reference from the reference library (= removes the `<layer>/<id>.md`
    /// body file + the index entry from `entities.json`). The reference card
    /// disappears from the sidebar tree on the next `reload()` (= the sidebar's
    /// `.onChange(of: workspaceUI. sidebarSelection)` triggers a reload; = we
    /// also call `reload()` here to refresh immediately).
    func deleteReference(id: UUID) throws {
        guard let referenceStore = bookStore?.stores.referenceStore else {
            throw MutationError.bookNotFound
        }
        try referenceStore.deleteReference(id: id)
    }

    /// rename a single reference (= change only the `title` field; = the .md
    /// filename is the stable UUID and stays unchanged; = the sidebar row's
    /// title text updates on next reload). The reference's body content is
    /// unchanged (= the rename only touches the index entry's `title`).
    /// Validation: - empty title = rejected - duplicate title (in any layer) =
    /// rejected (= the reference-library doesn't enforce unique titles but the
    /// rename sheet shows the duplicate error for consistency with shelf/book
    /// rename).
    func renameReference(id: UUID, newTitle: String) throws {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw MutationError.bookNotFound
        }
        guard let referenceStore = bookStore?.stores.referenceStore else {
            throw MutationError.bookNotFound
        }
        // Look up the reference across all 4 layers; = the reference id is unique across
        // the library.
        let all = (try? referenceStore.loadAllReferences()) ?? []
        guard let existing = all.first(where: { $0.id == id }) else {
            throw MutationError.bookNotFound
        }
        // Duplicate check: if another reference (in any layer) has the same title,
        // reject.
        let others = all.filter { $0.id != id }
        if others.contains(where: { $0.title.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            throw MutationError.duplicateName(trimmed)
        }
        // Build the updated reference (= the existing reference with the new title +
        // updatedAt). We keep all other fields (= tags, summary, category,
        // source, etc.) unchanged.
        var updated = existing
        updated.title = trimmed
        updated.updatedAt = Date()
        // Load the existing body (= the rename only touches the index entry; = the .md
        // body file is preserved verbatim; = `replaceReference` writes both
        // the index + the body).
        let body = referenceStore.loadReferenceBody(id: id) ?? ""
        try referenceStore.replaceReference(updated, bodyMarkdown: body)
        LibraryChangeNotifier.notifyLibraryChanged()
    }

    /// list of all reference titles (= for the duplicate check in
    /// `renameReference`; = = the v2.7 [archived-round] addition; = the rename sheet
    /// reads this and shows the duplicate error).
    func otherReferenceTitles(excluding id: UUID) -> [String] {
        guard let referenceStore = bookStore?.stores.referenceStore else {
            return []
        }
        let all = (try? referenceStore.loadAllReferences()) ?? []
        return all.filter { $0.id != id }.map { $0.title }
    }
}
