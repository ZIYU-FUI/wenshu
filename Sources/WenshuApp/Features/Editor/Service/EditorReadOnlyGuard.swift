//
//  EditorReadOnlyGuard.swift
//
//  Is the tab's OWN document read-only?
//
//  The editor has two doors, = and both must ask the SAME question: =
//  "does this tab's document belong to a book the user may not change?"
//
//  ⇒ THE KEY IS THE TAB'S OWN DOCUMENT, = AND A DOCUMENT HAS TWO NAMES
//  FOR ITS BOOK: = the tab's own scope (= `PreviewScope.bookScope`'s book
//  id, = which the live tab carries) and = the tab's own PATH (= which
//  names its book by the library's layout, = and which is the one thing
//  that survives a relaunch: = `PersistedEditorTab` carries the path and
//  NOT the scope). = ⇒ The guard refuses when EITHER names the read-only
//  book (= fail closed), = and it is NOT keyed on the tree's selected
//  book.
//
//  ⇒ MEASURED WHY: the tab's document and the selected book are two
//  DIFFERENT books in the ordinary case, = so a refusal keyed on the
//  selection refuses the WRONG writes (= it drops an ordinary book's
//  unsaved edit when the user happens to have the help book's row
//  selected) and lets the help book's OWN file through (= it writes a
//  tab whose path is inside the help book while an ordinary book is
//  selected). = Both were measured, = and both were the same defect.
//

import Foundation

/// The read-only rule for the editor's two doors.
///
/// Main-actor isolated (= `EditorTab.sourceScope` is), = so the two
/// doors (= the surface's gate and the write path) ask it on the main
/// actor, = which is where both of them already live.
@MainActor
enum EditorReadOnlyGuard {
    /// Whether this tab's own document belongs to a read-only book.
    ///
    /// ⇒ THE GUARD ANSWERS "WHICH BOOK IS THIS TAB'S DOCUMENT IN?", = and
    /// it asks the two things that name a book, = and it refuses when
    /// EITHER of them names the read-only one (= fail CLOSED).
    ///
    /// 1. THE TAB'S OWN SCOPE (= the book it was opened on). = This is
    ///    the live tab.
    /// 2. THE TAB'S OWN PATH (= the one thing that survives a relaunch:
    ///    `PersistedEditorTab` carries the path, = and NOT the scope), =
    ///    so a restored tab is still asked about its own book.
    ///
    /// ⇒ AND NOT THE TREE'S SELECTION. = The selection is a DIFFERENT
    /// book from the tab's document in the ordinary case, = and a rule
    /// keyed on it refuses the wrong writes (= it drops an ordinary
    /// book's unsaved edit when the help book's row happens to be
    /// selected) = and lets the help book's OWN file through (= the tab
    /// is on the help book, = the selection is somewhere else).
    ///
    /// ⇒ AND THE SELECTION IS NOT A THIRD KEY, = because the write of a
    /// tab with no document yet does NOT land in the selected book: =
    /// `DraftPersistence.proposedPath` puts it under the shelves root, =
    /// outside every book. = ⇒ So the two keys above name EVERY book
    /// this tab's write can reach.
    static func isReadOnly(_ tab: EditorTab) -> Bool {
        if case let .bookScope(bookID, _) = tab.sourceScope,
           BookSessionLifecycle.isHelpBook(bookID)
        {
            return true
        }
        return BookSessionLifecycle.isReadOnlyDocumentPath(tab.documentPath)
    }

    /// Whether this tab's own document belongs to a read-only book.
    static func isReadOnly(_ tab: EditorTab?) -> Bool {
        guard let tab else { return false }
        return isReadOnly(tab)
    }
}
