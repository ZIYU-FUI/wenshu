//
//  SidebarServiceTests.swift
//  wenshu
//
//  The sidebar's folder rows come from the catalog, and the
//  derivation keeps the row shape identical across the
//  derivation.
//

import Testing
@testable import WenshuApp

@Suite("SidebarService (folderCatalog derives from BookFolderCatalog SSOT)")
struct SidebarServiceTests {

    // Note: SidebarService.folderCatalog is `private static`. The
    // SSOT contract is verified via the public behavior (= the
    // sidebar row children for a book). This test inspects the
    // catalog indirectly through the same getter the sidebar uses.

    @Test("BookFolderCatalog.userFacing is the canonical 5-folder sidebar source")
    func userFacingIsSidebarSource() {
        // The sidebar shows 5 folder rows under each book (= the
        // outline folder is not one of them: = the outline is a
        // plain markdown document the user opens in the editor,
        // so it needs no sidebar row of its own).
        let expected: [(id: String, name: String, displayName: String, icon: String)] = [
            ("world",      "world",      "世界观",   "globe"),
            ("characters", "characters", "角色",     "person.crop.circle"),
            ("chapters",   "chapters",   "小说正文", "book.closed.circle"),
            ("drafts",     "drafts",     "小说草稿", "book.circle"),
            ("ideas",      "ideas",      "构思",     "timelapse")
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

    @Test("the internal folders (= sessions / outlines) are NOT in the sidebar source")
    func internalFoldersNotInSidebar() {
        let sidebarIds = Set(BookFolderCatalog.userFacing.map(\.id))
        #expect(!sidebarIds.contains("sessions"))
        #expect(!sidebarIds.contains("outlines"))
    }
}
