//
//  BookFolderCatalogTests.swift
//  wenshu
//
// 
//

import Testing
@testable import WenshuApp

@Suite("BookFolderCatalog (v1.81 — sidebar + card + scope SSOT)")
struct BookFolderCatalogTests {

    @Test("9 standard folders registered (= world / characters / outlines / chapters / drafts / ideas / sessions / foreshadowing / placeholders)")
    func allFoldersRegistered() {
        // v2.7 round-62: the
        // catalog now has
        // 9 specs (= the
        // round-60 `ideas`
        // case is now
        // registered in the
        // catalog; = the
        // 6th sidebar-visible
        // folder for "loose
        // settings + future
        // ideas"; = the
        // standardFolders
        // array went from 8
        // to 9).
        #expect(BookFolderCatalog.allBookFolders.count == 9)
        let ids = BookFolderCatalog.allBookFolders.map(\.id)
        #expect(ids.contains("world"))
        #expect(ids.contains("characters"))
        #expect(ids.contains("outlines"))
        #expect(ids.contains("chapters"))
        #expect(ids.contains("drafts"))
        #expect(ids.contains("ideas"))
        #expect(ids.contains("sessions"))
        #expect(ids.contains("foreshadowing"))
        #expect(ids.contains("placeholders"))
    }

    @Test("6 user-facing folders (= sidebar-visible; = world / characters / outlines / chapters / drafts / ideas)")
    func userFacingFolders() {
        // v2.7 round-62: `ideas`
        // is now user-facing
        // (= 6 total; = the
        // sidebar shows 6
        // folder rows under
        // each book).
        #expect(BookFolderCatalog.userFacing.count == 6)
        for folder in BookFolderCatalog.userFacing {
            #expect(folder.isUserFacing == true)
            #expect(folder.icon != nil, "user-facing folder '\(folder.id)' must have an icon")
        }
        // The 6 user-facing folders, in expected sidebar order
        // (= v2.7 round-62 added `ideas`; = the 6th sidebar-visible
        // folder for "loose settings + future ideas").
        #expect(BookFolderCatalog.userFacing.map(\.id) == [
            "world", "characters", "outlines", "chapters", "drafts", "ideas"
        ])
    }

    @Test("3 internal folders (= sidebar-hidden; = no icon since the icon would never render)")
    func internalFolders() {
        let internalIds: [String] = ["sessions", "foreshadowing", "placeholders"]
        for id in internalIds {
            let spec = BookFolderCatalog.spec(for: id)
            #expect(spec != nil, "missing spec for internal folder '\(id)'")
            #expect(spec?.isUserFacing == false)
            #expect(spec?.icon == nil, "internal folder '\(id)' must NOT define an icon (= dead value per boss OOB 2026-09-24 '8 个目录, 不需要都定义 ICON')")
        }
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

    @Test("sidebarDisplayName and cardDisplayName populated for all 8 folders")
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
