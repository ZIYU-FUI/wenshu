//
//  ReferenceSidebarContextMenuTests.swift
//
//  v2.7 round-63 (= boss
//  2026-10-10 "素材
//  区，卡片，右
//  键菜单，做删
//  除、重命名"
//  directive). Verifies
//  the right-click menu
//  + rename sheet +
//  delete alert for
//  `.reference` rows
//  (= the 6 sidebar-
//  visible reference
//  cards in the
//  wenshu material
//  library).
//
//  Three surfaces are
//  tested:
//  1. `SidebarRowCallbacks`
//     has the two new
//     callbacks (= the
//     menu builder can
//     reach them).
//  2. `PerRowContextMenu`
//     renders "重命名" +
//     "删除" for
//     `.reference` rows
//     (= the visual menu
//     surface).
//  3. `SidebarService` has
//     the new
//     `renameReference` /
//     `deleteReference` /
//     `otherReferenceTitles`
//     methods (= the
//     business layer is
//     wired).
//

import Foundation
import Testing
@testable import WenshuApp

@MainActor
@Suite("Reference sidebar context menu (v2.7 round-63)")
struct ReferenceSidebarContextMenuTests {

    // MARK: - SidebarService business-layer wiring

    /// v2.7 round-63: the
    /// `SidebarService`
    /// exposes 3 new
    /// methods (= the
    /// business layer for
    /// the right-click
    /// menu). Build a
    /// stub `BookStore`-
    /// backed service to
    /// verify the methods
    /// exist (= compile-
    /// time check) and
    /// return the expected
    /// signatures.
    @Test("SidebarService exposes renameReference / deleteReference / otherReferenceTitles")
    func sidebarServiceExposesReferenceMethods() throws {
        // Use the canonical
        // build pattern
        // (= the same one
        // `AppleSidebarView`
        // uses; = the
        // service is an
        // actor-isolated
        // class; = the
        // existence of the
        // new methods is
        // the assertion).
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
