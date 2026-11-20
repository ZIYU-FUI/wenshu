//
//  ReferenceSidebarContextMenuTests.swift
//
//  The material zone's cards get delete and rename in the right-click
//  menu (see OOB.md #2026-10-10), = and this file is the guard that
//  says which part of that is measured here.
//
//  WHAT THIS FILE MEASURES (= one claim, = and it is a small one):
//
//  * `SidebarService.otherReferenceTitles(excluding:)` answers an
//    empty list when the service has no book store (= the reader the
//    rename sheet uses is safe before anything is loaded).
//
//  WHAT IT DOES NOT MEASURE (= and no other file in this target
//  does):
//
//  * THE CONTENT OF ANY MENU. The sidebar's row menu is built inside
//    a SwiftUI view body (= `SidebarRowView`'s context-menu branch),
//    = so its buttons cannot be reached from a test without a running
//    window. = Two surfaces are NOT covered here (= `SidebarRowCallbacks
//    carrying the two reference callbacks, = and a per-row menu rendering
//    rename and delete for `.reference` rows); = both are gone from the
//    tree (= the reference library's rows are the tags again, = so the
//    tree draws no single-reference row, = and there is no such menu left
//    to render).
//  ⇒ So the library card's C4 line (= the root takes the import
//  action only) = states a decision the code makes, = NOT a behaviour
//  this file guards. = A header that advertises a guard which does not
//  exist is worse than no header: = the next reader believes it.
//
//  * renameReference / deleteReference themselves. = Their callers
//  live in the material zone's card menu, = and this file does not
//  reach them (= the assertion below names only the one method it
//  actually calls).
//
import Foundation
import Testing
@testable import WenshuApp

@MainActor
@Suite("SidebarService reference title reader (v2.7 round-63 origin)")
struct ReferenceSidebarContextMenuTests {

    // MARK: - SidebarService business-layer wiring

    /// The rename sheet asks the service for the OTHER references'
    /// titles (= to reject a duplicate). = With no book store behind
    /// the service there are no other titles, = and the answer is an
    /// empty list rather than a crash (= the state the sidebar is in
    /// before the library finishes loading).
    @Test("otherReferenceTitles answers empty when nothing is loaded")
    func otherReferenceTitlesIsEmptyWithNoBookStore() {
        // The canonical build
        // pattern (= the same one
        // `AppleSidebarView`
        // uses; = the
        // service is an
        // actor-isolated
        // class).
        let service = SidebarService(
            loadShelves: { [] },
            loadAllBooks: { [] },
            loadReferences: { [] }
        )
        // otherReferenceTitles
        // = pure read; = safe
        // to call with an
        // empty bookStore.
        let others = service.otherReferenceTitles(excluding: UUID())
        #expect(others.isEmpty, "no bookStore → empty otherReferenceTitles")
    }
}
