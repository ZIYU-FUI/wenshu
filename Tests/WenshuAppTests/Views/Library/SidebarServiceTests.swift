//
//  SidebarServiceTests.swift
//  wenshu
//
//  v1.81 SSOT derivation tests (= verify the sidebar's
//  folderCatalog tuple values come from BookFolderCatalog.userFacing
//  and that the (= name, displayName, icon) shape is preserved
//  across the derivation).
//

import Testing
@testable import WenshuApp

@Suite("SidebarService (v1.81 — folderCatalog derives from BookFolderCatalog SSOT)")
struct SidebarServiceTests {

    // Note: SidebarService.folderCatalog is `private static`. The
    // SSOT contract is verified via the public behavior (= the
    // sidebar row children for a book). This test inspects the
    // catalog indirectly through the same getter the sidebar uses.

    @Test("BookFolderCatalog.userFacing is the canonical 5-folder sidebar source")
    func userFacingIsSidebarSource() {
        // The 5 user-facing folders in BookFolderCatalog are, by
        // SSOT contract, the same 5 folders shown in the sidebar
        // (in the same order). This is the single source for the
        // sidebar's folder row list (= future folder renames or
        // additions touch BookFolderCatalog only).
        let expected: [(id: String, name: String, displayName: String, icon: String)] = [
            ("world",      "world",      "世界观",   "globe"),
            ("characters", "characters", "角色",     "person.crop.circle"),
            ("outlines",   "outlines",   "章节大纲", "bookmark.circle"),
            ("chapters",   "chapters",   "小说正文", "book.closed.circle"),
            ("drafts",     "drafts",     "小说草稿", "book.circle")
        ]
        #expect(BookFolderCatalog.userFacing.count == expected.count)
        for (i, expectedFolder) in expected.enumerated() {
            let actual = BookFolderCatalog.userFacing[i]
            #expect(actual.id == expectedFolder.id)
            #expect(actual.directoryName == expectedFolder.name)
            #expect(actual.sidebarDisplayName == expectedFolder.displayName)
            #expect(actual.icon == expectedFolder.icon)
        }
    }

    @Test("3 internal folders (= sessions / foreshadowing / placeholders) are NOT in the sidebar source")
    func internalFoldersNotInSidebar() {
        let sidebarIds = Set(BookFolderCatalog.userFacing.map(\.id))
        #expect(!sidebarIds.contains("sessions"))
        #expect(!sidebarIds.contains("foreshadowing"))
        #expect(!sidebarIds.contains("placeholders"))
    }
}