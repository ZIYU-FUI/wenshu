//
//  EditorTabTitleTests.swift · Wenshu · v0.71 P1 batch 3
//
//  v0.71 P1 batch 3 (boss 2026-09-12 OOB 'tab title didn't go to the document name bug'
//  + 'I raise requirements, you only do what I ask for... just pick an approximate value'):
//
//  Code-level verification (= no UI render) that the canonical
//  EditorTab.displayTitle(_:) (= single source of truth for the
//  tab title fallback chain) handles every precedence level
//  correctly. Before this refactor, the same fallback chain was
//  duplicated in WorkspaceView.tabDisplayTitle + PreviewPane.tabDisplayTitle
//  (= can drift over time = a regression in one copy wouldn't be
//  caught by the other copy).
//
//  Precedence (= per the boss's 'tab title didn't go to the document name' OOB):
//    1. documentPath basename (= real file wins; = strips .md)
//    2. tab.title (= entity / book-doc title = 'Battle of Red Cliffs' etc.)
//    3. 'preview-sample' (= legacy placeholder; = last resort)
//
//  These tests don't render the tab strip; they only verify the
//  pure displayTitle logic.

import Testing
import Foundation
@testable import WenshuApp

@Suite("v0.71 P1 — EditorTab.displayTitle (tab title fallback chain)")
struct EditorTabTitleTests {

    @MainActor
    private func makeTab(documentPath: String? = nil, title: String? = nil) -> EditorTab {
        EditorTab(
            id: UUID(),
            documentPath: documentPath,
            draft: "",
            originalBody: "",
            mode: .preview,
            title: title
        )
    }

    /// boss 9/12 OOB 'tab title didn't go to the document name bug': when the tab has a
    /// real documentPath, the basename (= without .md) wins.
    @Test("displayTitle_documentPathBasenameWins_overTitle")
    @MainActor
    func displayTitle_documentPathBasenameWins_overTitle() {
        let tab = makeTab(
            documentPath: "/Users/anbaiqiang/Library/foo/赤壁之战.md",
            title: "Should Not Be Used"
        )
        let title = EditorTab.displayTitle(tab)
        #expect(
            title == "赤壁之战",
            "Expected basename '赤壁之战' (= strip .md from documentPath), got '\(title)'"
        )
    }

    /// boss 9/12 OOB 'tab title didn't go to the document name bug': when documentPath is
    /// nil (= reference-library card without a resolved path),
    /// the entity title wins.
    @Test("displayTitle_tabTitleWins_whenDocumentPathIsNil")
    @MainActor
    func displayTitle_tabTitleWins_whenDocumentPathIsNil() {
        let tab = makeTab(documentPath: nil, title: "赤壁之战")
        let title = EditorTab.displayTitle(tab)
        #expect(
            title == "赤壁之战",
            "Expected entity title '赤壁之战' (= fallback when no path), got '\(title)'"
        )
    }

    /// boss 9/12 OOB 'tab title didn't go to the document name bug': when both documentPath
    /// and title are nil, the legacy placeholder is used.
    @Test("displayTitle_previewSample_whenBothNil")
    @MainActor
    func displayTitle_previewSample_whenBothNil() {
        let tab = makeTab(documentPath: nil, title: nil)
        let title = EditorTab.displayTitle(tab)
        #expect(
            title == "preview-sample",
            "Expected 'preview-sample' legacy placeholder when both documentPath + title are nil, got '\(title)'"
        )
    }

    /// empty-string documentPath is treated as nil (= defensive
    /// against bad caller data; = openCardInEditor sometimes passes
    /// empty strings when path resolution fails).
    @Test("displayTitle_emptyDocumentPathFallsBackToTitle")
    @MainActor
    func displayTitle_emptyDocumentPathFallsBackToTitle() {
        let tab = makeTab(documentPath: "", title: "杜甫")
        let title = EditorTab.displayTitle(tab)
        #expect(
            title == "杜甫",
            "Expected '杜甫' (= empty documentPath treated as nil), got '\(title)'"
        )
    }

    /// empty-string title is treated as missing (= defensive against
    /// bad caller data; = openCardInEditor sometimes passes empty
    /// strings when the entity has no title).
    @Test("displayTitle_emptyTitleFallsBackToPlaceholder")
    @MainActor
    func displayTitle_emptyTitleFallsBackToPlaceholder() {
        let tab = makeTab(documentPath: nil, title: "")
        let title = EditorTab.displayTitle(tab)
        #expect(
            title == "preview-sample",
            "Expected 'preview-sample' legacy placeholder when both fields are empty, got '\(title)'"
        )
    }

    /// .md extension is stripped from the basename (= the tab
    /// shows 'What is Wenshu' not 'What is Wenshu.md').
    @Test("displayTitle_strips_md_extension")
    @MainActor
    func displayTitle_strips_md_extension() {
        let tab = makeTab(documentPath: "/foo/bar/什么是文枢.md")
        let title = EditorTab.displayTitle(tab)
        #expect(
            title == "什么是文枢",
            "Expected basename without .md extension, got '\(title)'"
        )
    }

    /// English names also work (= the precedence isn't tied to CJK).
    @Test("displayTitle_englishPathAndTitle")
    @MainActor
    func displayTitle_englishPathAndTitle() {
        let tab = makeTab(documentPath: "/Users/test/Documents/Hello World.md")
        let title = EditorTab.displayTitle(tab)
        #expect(
            title == "Hello World",
            "Expected 'Hello World' (= English basename), got '\(title)'"
        )
    }

    /// Paths without an extension still work (= e.g. /foo/bar/baz with
    /// no .md).
    @Test("displayTitle_pathWithoutExtension")
    @MainActor
    func displayTitle_pathWithoutExtension() {
        let tab = makeTab(documentPath: "/foo/bar/baz")
        let title = EditorTab.displayTitle(tab)
        #expect(
            title == "baz",
            "Expected 'baz' (= basename without extension), got '\(title)'"
        )
    }

    // MARK: - Codable round-trip (= title persists across app restart)

    /// The title field was added in v0.71 (= boss 9/12 OOB 'tab title didn't go to the
    /// document name bug') so the tab title survives an app relaunch.
    /// This test verifies the PersistedEditorTab Codable encoding
    /// round-trips the title field.
    @Test("persistedEditorTab_codableRoundTripPreservesTitle")
    func persistedEditorTab_codableRoundTripPreservesTitle() throws {
        let id = UUID()
        let persisted = PersistedEditorTab(
            id: id,
            documentPath: nil,
            draft: "draft body",
            originalBody: "original body",
            mode: "edit",
            title: "什么是文枢"
        )
        let encoder = JSONEncoder()
        let data = try encoder.encode(persisted)
        let decoder = JSONDecoder()
        let restored = try decoder.decode(PersistedEditorTab.self, from: data)
        #expect(restored.id == id)
        #expect(restored.documentPath == nil)
        #expect(restored.draft == "draft body")
        #expect(restored.originalBody == "original body")
        #expect(restored.mode == "edit")
        #expect(restored.title == "什么是文枢", "Title must round-trip through Codable (= survives app relaunch)")
    }

    /// PersistedEditorTab with nil title (= back-compat with v0.40
    /// persisted tabs that don't have the title field) decodes
    /// successfully with title = nil.
    @Test("persistedEditorTab_codableRoundTrip_nilTitle")
    func persistedEditorTab_codableRoundTrip_nilTitle() throws {
        let id = UUID()
        let persisted = PersistedEditorTab(
            id: id,
            documentPath: "/foo/bar.md",
            draft: "",
            originalBody: "",
            mode: "preview",
            title: nil
        )
        let encoder = JSONEncoder()
        let data = try encoder.encode(persisted)
        let decoder = JSONDecoder()
        let restored = try decoder.decode(PersistedEditorTab.self, from: data)
        #expect(restored.title == nil, "Title must round-trip nil correctly")
    }
}
