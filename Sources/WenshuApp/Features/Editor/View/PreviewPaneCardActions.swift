//
//  PreviewPaneCardActions.swift
//
//  4 card callback helpers extracted from PreviewPane.swift
//  (= §6.6 god-class split + discoverability: beginReferenceRename
//  + beginReferenceDelete + beginBookDocRename + beginBookDocDelete
//  moved out of the main file into this dedicated cross-file
//  `extension PreviewPane` module).
//
//  Why extracted (= §6.6 god-class split + discoverability): the main
//  `struct PreviewPane: View` is 998 LOC = 1.66x the 600-LOC cap. The
//  4 card callbacks are a single concern (= "set the local @State
//  for the rename sheet + delete alert"). Putting them in a dedicated
//  file named after the concern (= PreviewPaneCardActions.swift) lets
//  the next reader find the card callback logic by name.
//
//  The 4 funcs are instance methods on `PreviewPane` (as a cross-file
//  extension). The `private func` was already relaxed to `func`
//  (= internal scope; = required for the cross-file `referenceCategoryCard`
//  to call them).
//

import Foundation

extension PreviewPane {

    /// begin the rename flow for a single reference card (= set `cardRenaming`
    /// to a `.reference` target). The `originalName` is read from the
    /// `Reference`'s current title.
    func beginReferenceRename(_ entity: Reference) {
        cardRenaming = SidebarRenamingTarget(
            kind: .reference,
            itemId: entity.id,
            originalName: entity.title,
            shelfId: nil
        )
    }


    /// begin the delete flow for a single reference card (= set
    /// `cardPendingDelete` to a `.reference` target). The delete alert shows
    /// the reference's title + a destructive confirm button.
    func beginReferenceDelete(_ entity: Reference) {
        cardPendingDelete = SidebarPendingDelete(
            kind: .reference,
            itemId: entity.id,
            itemName: entity.title
        )
    }


    /// begin the rename flow for a single book doc card (= set `cardRenaming`
    /// to a `.bookDoc` target). Mirrors the reference helper (= the rename
    /// sheet's `.bookDoc` case shows the file's current title + uses
    /// `otherBookDocTitles` for the duplicate check; = the underlying service
    /// method `renameBookDoc` updates the .md file's filename + content
    /// heading).
    func beginBookDocRename(_ doc: BookDoc) {
        cardRenaming = SidebarRenamingTarget(
            kind: .bookDoc,
            itemId: doc.id,
            originalName: doc.title,
            shelfId: nil
        )
    }


    /// begin the delete flow for a single book doc card (= set
    /// `cardPendingDelete` to a `.bookDoc` target). The delete alert shows the
    /// file's title + a destructive confirm button. The underlying
    /// `deleteBookDoc` service method removes the .md file from disk (= the
    /// book doc is JUST a file; = no entities.json index entry to remove; = the
    /// file deletion IS the complete delete).
    func beginBookDocDelete(_ doc: BookDoc) {
        cardPendingDelete = SidebarPendingDelete(
            kind: .bookDoc,
            itemId: doc.id,
            itemName: doc.title
        )
    }


}
