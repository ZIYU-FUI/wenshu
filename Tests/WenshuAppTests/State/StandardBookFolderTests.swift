//
//  StandardBookFolderTests.swift
//  wenshu
//
//  v1.81 SSOT derivation tests (= verify
//  BookStore.StandardBookFolder.folderName / displayName derive
//  from BookFolderCatalog; = the canonical source).
//

import Testing
@testable import WenshuApp

@Suite("BookStore.StandardBookFolder (v1.81 — derives from BookFolderCatalog SSOT)")
struct StandardBookFolderTests {

    @Test("folderName flows through BookStore.StandardBookFolder (= filesystem id mapping)")
    func folderNameDerivation() {
        // StandardBookFolder's folderName is the filesystem-
        // stable identifier (= the JSON filename suffix in
        // KanbanStore / TodoStore). Post-v1.81 it derives from
        // BookFolderCatalog (= the SSOT for id → directoryName).
        #expect(StandardBookFolder.world.folderName == "world")
        #expect(StandardBookFolder.characters.folderName == "characters")
        #expect(StandardBookFolder.outlines.folderName == "outlines")
        #expect(StandardBookFolder.chapters.folderName == "chapters")
        #expect(StandardBookFolder.drafts.folderName == "drafts")
        #expect(StandardBookFolder.sessions.folderName == "sessions")
        #expect(StandardBookFolder.foreshadowing.folderName == "foreshadowing")
        #expect(StandardBookFolder.placeholders.folderName == "placeholders")
    }

    @Test("displayName flows through BookStore.StandardBookFolder (= Chinese label)")
    func displayNameDerivation() {
        // StandardBookFolder's displayName is shown in the
        // Kanban / Todo scope picker. Post-v1.81 it derives
        // from BookFolderCatalog.cardDisplayName (= SSOT).
        // Pre-v1.81 it used shorter labels (= '大纲', '草稿',
        // '占位'); post-v1.81 it matches PreviewPane.BookFolder
        // displayName (= '章节大纲', '草稿', '占位符'); = a
        // single label across the app.
        #expect(StandardBookFolder.world.displayName == "世界观")
        #expect(StandardBookFolder.characters.displayName == "角色")
        #expect(StandardBookFolder.outlines.displayName == "章节大纲")
        #expect(StandardBookFolder.chapters.displayName == "章节")
        #expect(StandardBookFolder.drafts.displayName == "草稿")
        #expect(StandardBookFolder.sessions.displayName == "会话")
        #expect(StandardBookFolder.foreshadowing.displayName == "伏笔")
        #expect(StandardBookFolder.placeholders.displayName == "占位符")
    }

    @Test("all 8 StandardBookFolder cases map to a BookFolderSpec (= enum ↔ catalog bijection)")
    func allCasesMap() {
        for folder in StandardBookFolder.allCases {
            #expect(BookFolderCatalog.spec(for: folder.rawValue) != nil,
                    "StandardBookFolder.\(folder.rawValue) has no BookFolderCatalog entry (= SSOT drift)")
        }
    }
}