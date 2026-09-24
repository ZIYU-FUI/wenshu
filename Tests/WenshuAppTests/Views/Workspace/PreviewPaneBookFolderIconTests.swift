//
//  PreviewPaneBookFolderIconTests.swift
//  wenshu
//
//  SSOT derivation tests (= verify PreviewPane.BookFolder
//  icon / displayName / directoryName computed properties
//  derive from BookFolderCatalog; = the canonical source).
//

import Testing
@testable import WenshuApp

@Suite("PreviewPane.BookFolder (derives from BookFolderCatalog SSOT)")
struct PreviewPaneBookFolderIconTests {

    @Test("5 user-facing folder icons (= sidebar + card share the same glyph)")
    func userFacingFolderIcons() {
        // Previously these were hardcoded inside the BookFolder enum
        // (= a parallel source of truth that drifted from
        // SidebarService.folderCatalog until the icon unification pass).
        // Both surfaces now read from BookFolderCatalog;
        // = the values MUST match BookFolderCatalog.userFacing in
        // display order.
        let expected: [(folder: String, icon: String)] = [
            ("world",      "globe"),
            ("characters", "person.crop.circle"),
            ("outlines",   "bookmark.circle"),
            ("chapters",   "book.closed.circle"),
            ("drafts",     "book.circle"),
        ]
        for (folderRawValue, icon) in expected {
            // Use rawValue init (BookFolder's cases match the id strings).
            let folder = BookFolder(rawValue: folderRawValue)!
            #expect(folder.icon == icon,
                    "BookFolder.\(folderRawValue).icon should derive from BookFolderCatalog (= expected '\(icon)', got '\(folder.icon)')")
        }
    }

    @Test("cardDisplayName flows through PreviewPane.BookFolder.displayName")
    func displayNameDerivation() {
        // The card display name (= short Chinese label, e.g.
        // '章节' for chapters) is the one PreviewPane shows in
        // the card grid header. BookFolderCatalog.cardDisplayName
        // is the canonical source.
        #expect(BookFolder.chapters.displayName == "章节")
        #expect(BookFolder.drafts.displayName == "草稿")
        #expect(BookFolder.world.displayName == "世界观")
        #expect(BookFolder.characters.displayName == "角色")
        #expect(BookFolder.outlines.displayName == "章节大纲")
    }

    @Test("directoryName flows through PreviewPane.BookFolder.directoryName")
    func directoryNameDerivation() {
        #expect(BookFolder.chapters.directoryName == "chapters")
        #expect(BookFolder.drafts.directoryName == "drafts")
        #expect(BookFolder.world.directoryName == "world")
        #expect(BookFolder.sessions.directoryName == "sessions")
        #expect(BookFolder.foreshadowing.directoryName == "foreshadowing")
        #expect(BookFolder.placeholders.directoryName == "placeholders")
    }

    @Test("all 8 BookFolder cases map to a BookFolderSpec (= enum ↔ catalog bijection)")
    func bookFolderCasesAllMap() {
        for folder in BookFolder.allCases {
            #expect(BookFolderCatalog.spec(for: folder.rawValue) != nil,
                    "BookFolder.\(folder.rawValue) has no BookFolderCatalog entry (= SSOT drift)")
        }
    }
}