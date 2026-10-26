//
//  BookFolderCatalogTests.swift
//  wenshu
//
//  The catalog is the SSOT for the standard book sub-folders
//  (= the sidebar rows, the card badges, and the Kanban /
//  Todo scope names all derive from it).
//

import Testing
@testable import WenshuApp

@Suite("BookFolderCatalog (sidebar + card + scope SSOT)")
struct BookFolderCatalogTests {

    @Test("7 standard folders registered (= world / characters / outlines / chapters / drafts / ideas / sessions)")
    func allFoldersRegistered() {
        // The 2026-10-25 residue cleanup dropped the
        // foreshadowing and placeholders folders (= their
        // storage models and their scope entries were
        // removed with the right-rail feature).
        #expect(BookFolderCatalog.allBookFolders.count == 7)
        let ids = BookFolderCatalog.allBookFolders.map(\.id)
        #expect(ids.contains("world"))
        #expect(ids.contains("characters"))
        #expect(ids.contains("outlines"))
        #expect(ids.contains("chapters"))
        #expect(ids.contains("drafts"))
        #expect(ids.contains("ideas"))
        #expect(ids.contains("sessions"))
        #expect(!ids.contains("foreshadowing"))
        #expect(!ids.contains("placeholders"))
    }

    @Test("5 user-facing folders (= sidebar-visible; = world / characters / chapters / drafts / ideas)")
    func userFacingFolders() {
        // The outline folder has no sidebar row (= the boss
        // 2026-10-24 decision: the outline is a plain markdown
        // document the user opens in the editor, = it needs no
        // dedicated UI). The 5 sidebar rows are the folders the
        // user browses as a tree.
        #expect(BookFolderCatalog.userFacing.count == 5)
        for folder in BookFolderCatalog.userFacing {
            #expect(folder.isUserFacing == true)
            #expect(folder.icon != nil, "user-facing folder '\(folder.id)' must have an icon")
        }
        // The 5 user-facing folders, in expected sidebar order
        // (= the outline folder sits between characters and
        // chapters in the catalog but is not sidebar-visible).
        #expect(BookFolderCatalog.userFacing.map(\.id) == [
            "world", "characters", "chapters", "drafts", "ideas"
        ])
    }

    @Test("the outline folder keeps its spec but has no sidebar row")
    func outlineFolderHasNoSidebarRow() {
        // The spec stays (= the preview pane's card grid draws
        // the outline's glyph, and the scope picker names it),
        // but the folder is not a sidebar row.
        let spec = BookFolderCatalog.spec(for: "outlines")
        #expect(spec != nil, "the outline folder must keep its catalog spec")
        #expect(spec?.isUserFacing == false)
        #expect(spec?.icon == "bookmark.circle",
                "the outline folder still renders in the card grid, so it keeps its glyph")
    }

    @Test("the session folder is internal and carries no glyph (= it never renders)")
    func sessionFolderIsInternal() {
        let spec = BookFolderCatalog.spec(for: "sessions")
        #expect(spec != nil, "missing spec for the session folder")
        #expect(spec?.isUserFacing == false)
        #expect(spec?.icon == nil,
                "the session folder never renders in the UI, so its icon would be a dead value")
    }

    @Test("v1.80 icon replacements (= 4 user-facing folder icons migrated to SF Symbols 6 circular glyphs)")
    func v1_80IconReplacements() {
        // Icon replacements per the canonical spec:
        //   characters → person.crop.circle
        //   outline → bookmark.circle
        //   draft → book.circle
        //   chapters (formal) → book.closed.circle
        #expect(BookFolderCatalog.spec(for: "characters")?.icon == "person.crop.circle")
        #expect(BookFolderCatalog.spec(for: "outlines")?.icon == "bookmark.circle")
        #expect(BookFolderCatalog.spec(for: "chapters")?.icon == "book.closed.circle")
        #expect(BookFolderCatalog.spec(for: "drafts")?.icon == "book.circle")
    }

    @Test("world folder keeps 'globe' icon (= not in v1.80 replacement list)")
    func worldFolderGlobe() {
        #expect(BookFolderCatalog.spec(for: "world")?.icon == "globe")
    }

    @Test("folder id == directoryName (= filesystem contract)")
    func idMatchesDirectoryName() {
        for folder in BookFolderCatalog.allBookFolders {
            #expect(folder.id == folder.directoryName,
                    "folder '\(folder.id)' has directoryName '\(folder.directoryName)'")
        }
    }

    @Test("sidebarDisplayName and cardDisplayName populated for every folder")
    func displayNamesPopulated() {
        for folder in BookFolderCatalog.allBookFolders {
            #expect(!folder.sidebarDisplayName.isEmpty,
                    "folder '\(folder.id)' missing sidebarDisplayName")
            #expect(!folder.cardDisplayName.isEmpty,
                    "folder '\(folder.id)' missing cardDisplayName")
        }
    }

    @Test("sidebarDisplayName + cardDisplayName are user-facing labels (= Chinese, not rawValue)")
    func displayNamesAreUserFacing() {
        // The sidebar / card surfaces must NEVER show the rawValue
        // (e.g. 'chapters') to the user. Both names must be the
        // Chinese user-facing labels.
        #expect(BookFolderCatalog.spec(for: "chapters")?.sidebarDisplayName == "小说正文")
        #expect(BookFolderCatalog.spec(for: "chapters")?.cardDisplayName == "章节")
        #expect(BookFolderCatalog.spec(for: "drafts")?.sidebarDisplayName == "小说草稿")
        #expect(BookFolderCatalog.spec(for: "drafts")?.cardDisplayName == "草稿")
    }

    @Test("spec(for:) lookup returns nil for unknown id (= caller falls back to default)")
    func specLookupMiss() {
        #expect(BookFolderCatalog.spec(for: "nonexistent") == nil)
    }
}
