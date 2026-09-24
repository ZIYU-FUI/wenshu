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

    @Test("8 standard folders registered (= world / characters / outlines / chapters / drafts / sessions / foreshadowing / placeholders)")
    func allFoldersRegistered() {
        #expect(BookFolderCatalog.allBookFolders.count == 8)
        let ids = BookFolderCatalog.allBookFolders.map(\.id)
        #expect(ids.contains("world"))
        #expect(ids.contains("characters"))
        #expect(ids.contains("outlines"))
        #expect(ids.contains("chapters"))
        #expect(ids.contains("drafts"))
        #expect(ids.contains("sessions"))
        #expect(ids.contains("foreshadowing"))
        #expect(ids.contains("placeholders"))
    }

    @Test("5 user-facing folders (= sidebar-visible; = world / characters / outlines / chapters / drafts)")
    func userFacingFolders() {
        #expect(BookFolderCatalog.userFacing.count == 5)
        for folder in BookFolderCatalog.userFacing {
            #expect(folder.isUserFacing == true)
            #expect(folder.icon != nil, "user-facing folder '\(folder.id)' must have an icon")
        }
        // The 5 user-facing folders, in expected sidebar order.
        #expect(BookFolderCatalog.userFacing.map(\.id) == [
            "world", "characters", "outlines", "chapters", "drafts"
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
        // Boss 2026-09-24 OOB '替换目录树 和 卡片的 ICON, = 角色换为
        // person.crop.circle, 章节大纲 换为 bookmark.circle, 小说正文
        // 换为 book.closed.circle, 小说草稿 换为 book.circle':
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
