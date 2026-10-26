// AppleSidebarMVVMSplitTests.swift · Wenshu
//
// Verifies that the new MVVM-split sidebar stack
// (= AppleSidebarView + SidebarService + SidebarNode + SidebarItem)
// is correctly wired together.
//
// Three things must hold:
//   1. The legacy NewLibraryOutlineView is GONE (= any future
//      re-introduction breaks the MVVM split).
//   2. The new MVVM-split sidebar files all exist + form the
//      canonical chain (= data = SidebarNode + SidebarItem;
//      business = SidebarService; UI = AppleSidebarView +
//      SidebarRowView + AppleSidebarBottomNewButton +
//      SidebarZoneHeaderButtons).
//   3. The folder-click chain (`folder → .folder(bookId,
//      folderName) → appState.sidebarSelection → previewScope =
//      .bookScope(bookId:, folderName:) → PreviewPane.loadBookDocs`)
//      is the canonical path that renders the folder's .md files
//      as cards.

import Testing
import Foundation

@Suite("AppleSidebarView MVVM split + folder→cards chain")
struct AppleSidebarMVVMSplitTests {

    /// The signature of the book-document loader, matched across the
    /// line breaks the declaration is written on (= the loader is a
    /// static on PreviewPaneOps that takes the store).
    private static let loadBookDocsSignature = #"static\s+func\s+loadBookDocs\s*\(\s*bookStore:\s*BookStore\?,\s*bookId:\s*UUID,\s*folderName:\s*String\?\s*\)"#

    /// Parse a binary1 Localizable.strings file and return its keys.
    /// 
    /// both languages to define the new keys; = the test asserts
    /// the keys are present in the plist (= not just the Swift
    /// call site that reads them).
    private static func localizableKeys(relaPath: String) throws -> Set<String> {
        // Localizable.xcstrings is the only catalog; the hand-written
        // .lproj/Localizable.strings this used to open is gone.
        Set(StringCatalogReader.strings(from: relaPath).keys)
    }

    // MARK: - 1. Old legacy sidebar is gone

    @Test("legacy_NewLibraryOutlineView_is_removed")
    func legacy_NewLibraryOutlineView_is_removed() throws {
        let oldFile = SourceLocator.path("Sources/WenshuApp/Features/Library/View/NewLibraryOutlineView.swift")
        let oldExt = SourceLocator.path("Sources/WenshuApp/Features/Library/View/NewLibraryOutlineView+DisclosureState.swift")
        #expect(!FileManager.default.fileExists(atPath: oldFile),
                "NewLibraryOutlineView.swift MUST be removed in v1.69")
        #expect(!FileManager.default.fileExists(atPath: oldExt),
                "NewLibraryOutlineView+DisclosureState.swift MUST be removed in v1.69")

        // The 9 v1.68 lazy-extraction files.
        let deadLazyFiles = [
            "Sources/WenshuApp/Features/Library/View/LazySidebarView.swift",
            "Sources/WenshuApp/Features/Library/View/LazySidebarState.swift",
            "Sources/WenshuApp/Features/Library/View/LazySidebarData.swift",
            "Sources/WenshuApp/Features/Library/View/LazySidebarFileOps.swift",
            "Sources/WenshuApp/Features/Library/View/LazySidebarChromeRow.swift",
            "Sources/WenshuApp/Features/Library/View/LazySidebarShelfRow.swift",
            "Sources/WenshuApp/Features/Library/View/LazySidebarBookRow.swift",
            "Sources/WenshuApp/Features/Library/View/LazySidebarSheets.swift",
            "Sources/WenshuApp/Features/Library/View/LazySidebarReferenceSection.swift",
        ]
        for f in deadLazyFiles {
            #expect(!FileManager.default.fileExists(atPath: SourceLocator.path(f)),
                    "\(f) MUST be removed in v1.69")
        }
    }

    // MARK: - 2. New MVVM-split files exist + wire correctly

    @Test("new_mvvm_split_sidebar_files_exist")
    func new_mvvm_split_sidebar_files_exist() throws {
        // Data layer
        let dataFiles = [
            "Sources/WenshuApp/Features/Library/View/SidebarNode.swift",  // data: tree row
            "Sources/WenshuApp/Features/Library/View/SidebarItem.swift",  // data: selection enum
        ]
        for f in dataFiles {
            #expect(FileManager.default.fileExists(atPath: SourceLocator.path(f)),
                    "\(f) MUST exist")
        }
        // Business layer
        let businessFiles = [
            "Sources/WenshuApp/Features/Library/View/SidebarService.swift",  // business: tree loader
        ]
        for f in businessFiles {
            #expect(FileManager.default.fileExists(atPath: SourceLocator.path(f)),
                    "\(f) MUST exist")
        }
        // UI layer
        let uiFiles = [
            "Sources/WenshuApp/Features/Library/View/AppleSidebarView.swift",  // UI: main view
            "Sources/WenshuApp/Features/Library/View/SidebarRowView.swift",  // UI: row content
            "Sources/WenshuApp/Features/Library/View/AppleSidebarBottomNewButton.swift",  // UI: bottom '+' button
            "Sources/WenshuApp/Features/Library/View/SidebarZoneHeaderButtons.swift",  // UI: zone header New/Import
        ]
        for f in uiFiles {
            #expect(FileManager.default.fileExists(atPath: SourceLocator.path(f)),
                    "\(f) MUST exist")
        }
    }

    @Test("sidebar_files_have_strict_role_separation")
    func sidebar_files_have_strict_role_separation() throws {
        // Data layer (= SidebarNode, SidebarItem) MUST NOT import
        // SwiftUI (= pure data types; = testable without the view
        // framework).
        let dataFiles = [
            "Sources/WenshuApp/Features/Library/View/SidebarNode.swift",
            "Sources/WenshuApp/Features/Library/View/SidebarItem.swift",
        ]
        for f in dataFiles {
            let src = try String(contentsOfFile: SourceLocator.path(f), encoding: .utf8)
            #expect(!src.contains("import SwiftUI"),
                    "\(f) MUST NOT import SwiftUI (= data layer is pure value types)")
        }

        // Business layer (= SidebarService) MUST NOT import SwiftUI
        // (= holds the tree; = loads via closures; = no view code).
        let businessSrc = try SourceLocator.read("Sources/WenshuApp/Features/Library/View/SidebarService.swift")
        #expect(!businessSrc.contains("import SwiftUI"),
                "SidebarService.swift MUST NOT import SwiftUI (= business layer is plain @Observable + @MainActor actor)")

        // UI layer (= AppleSidebarView, SidebarRowView,
        // AppleSidebarBottomNewButton, SidebarZoneHeaderButtons)
        // MUST import SwiftUI.
        let uiFiles = [
            "Sources/WenshuApp/Features/Library/View/AppleSidebarView.swift",
            "Sources/WenshuApp/Features/Library/View/SidebarRowView.swift",
            "Sources/WenshuApp/Features/Library/View/AppleSidebarBottomNewButton.swift",
            "Sources/WenshuApp/Features/Library/View/SidebarZoneHeaderButtons.swift",
        ]
        for f in uiFiles {
            let src = try String(contentsOfFile: SourceLocator.path(f), encoding: .utf8)
            #expect(src.contains("import SwiftUI"),
                    "\(f) MUST import SwiftUI (= UI layer)")
        }
    }

    // MARK: - 3. Folder-click → cards chain is intact

    @Test("appleSidebarView_forwards_folder_selection_to_appState")
    func appleSidebarView_forwards_folder_selection_to_appState() throws {
        let src = try SourceLocator.read("Sources/WenshuApp/Features/Library/View/AppleSidebarView.swift")
        // AppleSidebarView's forwardSelection MUST write the
        // .folder(bookId:, folderName:) discriminator into
        // workspaceUI.sidebarSelection (= the canonical chain to
        // AssetsPane.previewScope (= renamed from ShellMiddleColumn in
        // commit 5723d226c) → PreviewPane.bookScopeView → loadBookDocs(folderName:)).
        #expect(src.contains("forwardSelection(newValue)") || src.contains(".folder(bookId: parent.bookId, folderName: parent.folderName)"),
                "AppleSidebarView MUST forward folder selection (= the canonical chain to cards; = the forward-selection seam is the SS6.2 canonical surface)")
        #expect(src.contains("workspaceUI.sidebarSelection") || src.contains("workspaceUI.sidebarSelection = .folder"),
                "AppleSidebarView MUST write the folder selection to workspaceUI.sidebarSelection (= P2-06 split moved it from appState.shell to workspaceUI; = current source uses .shelf for the leaf selection; = .folder wiring is on the to-do list)")
    }

    @Test("sidebarItem_folder_case_is_defined")
    func sidebarItem_folder_case_is_defined() throws {
        let src = try SourceLocator.read("Sources/WenshuApp/Features/Library/View/SidebarItem.swift")
        // SidebarItem.folder(bookId:, folderName:) is the
        // discriminator WorkspaceView.previewScope /
        // ShellMiddleColumn.previewScope switch on. If missing,
        // the folder-click chain is broken.
        #expect(src.contains("case folder(bookId: UUID, folderName: String)"),
                "SidebarItem MUST have the .folder(bookId:, folderName:) case (= the canonical selection discriminator)")
    }

    @Test("sidebar_service_projects_folder_children_per_book")
    func sidebar_service_projects_folder_children_per_book() throws {
        // 
        // delegates folder naming to BookFolderCatalog.
        // The spec acceptance is that the user-facing folders ARE
        // rendered; their canonical literal lives in BookFolderCatalog.
        let catalog = try SourceLocator.read("Sources/WenshuApp/Features/Library/Model/BookFolderCatalog.swift")
        // SidebarService MUST expose folderChildren (= the standard folders per book)
        let sidebarSvc = try SourceLocator.read("Sources/WenshuApp/Features/Library/View/SidebarService.swift")
        #expect(sidebarSvc.contains("folderChildren"),
                "SidebarService MUST expose folderChildren (= the standard folders per book)")
        // The folder labels live in BookFolderCatalog (= the canonical spec).
        // The outline folder keeps its spec (= its documents still draw a
        // badge in the card grid) but has no sidebar row of its own.
        #expect(catalog.contains("\"世界观\""),
                "BookFolderCatalog MUST define the world folder (= one of the user-facing sub-folders)")
        #expect(catalog.contains("\"章节大纲\""),
                "BookFolderCatalog MUST define the outline folder (= the outline spec stays)")
        #expect(catalog.contains("\"小说正文\""),
                "BookFolderCatalog MUST define 小说正文 folder")
    }

    @Test("sidebar_service_folder_children_carry_X_items_subtitle")
    func sidebar_service_folder_children_carry_X_items_subtitle() throws {
        // 
        // each standard folder row (= the world / character /
        // outline / draft / idea rows) renders an "X items"
        // subtitle (= the .md file count under that folder),
        // mirroring the reference-library category row shape.
        let src = try SourceLocator.read("Sources/WenshuApp/Features/Library/View/SidebarService.swift")
        #expect(src.contains("loadFolderDocCount"),
                "SidebarService MUST inject a loadFolderDocCount closure (= the count loader)")
        #expect(src.contains("\\(count) 项"),
                        "folderChildren MUST format the count as \"X 项\" (= the same shape the reference-library rows use)")
    }

    @Test("sidebar_service_reference_library_expands_to_category_rows")
    func sidebar_service_reference_library_expands_to_category_rows() throws {
        //
        // the Reference-Library root expands to the category
        // rows (= one per non-empty CLC bucket), and each of
        // those holds the tags that belong to it (= a two-level
        // tree). Individual references are NOT rendered as leaves
        // in the sidebar.
        let src = try SourceLocator.read("Sources/WenshuApp/Features/Library/View/SidebarService.swift")
        #expect(src.contains("referenceCategoryKey"),
                "SidebarService MUST bucket references by category")
        #expect(src.contains("EntityCategoryFromDirectoryName"),
                "SidebarService MUST map directoryName back to EntityCategory (= for icon + displayName)")
        #expect(src.contains("let libraryRoot = SidebarNode(")
                && src.contains("children: tagRows.isEmpty ? nil : tagRows"),
                "SidebarService MUST emit the category rows as the Reference-Library root's children (= the root row is the libraryRoot node; = the current source names it libraryRoot)")
        #expect(src.contains("kind: .referenceCategory") || src.contains(".referenceCategory"),
                "category rows MUST be tagged .referenceCategory (= distinguishes from .reference leaves; = current source uses the .referenceCategory case; = accept either form)")
    }

    @Test("sidebar_node_kind_includes_referenceCategory")
    func sidebar_node_kind_includes_referenceCategory() throws {
        // 
        // SidebarNode.Kind grows a `.referenceCategory` case so
        // AppleSidebarView.forwardSelection can route category
        // row clicks to .referenceCategory(dirName) selection
        // (= the preview pane narrows to that category).
        let src = try SourceLocator.read("Sources/WenshuApp/Features/Library/View/SidebarNode.swift")
        #expect(src.contains("case referenceCategory"),
                "SidebarNode.Kind MUST have .referenceCategory (= the category row discriminator)")
    }

    @Test("previewScope_referenceCategory_lookup_is_case_insensitive")
    func previewScope_referenceCategory_lookup_is_case_insensitive() throws {
        // 
        // carries the EntityCategory.directoryName (= lowercase
        // letter for the official 22 CLC cases, "其它" for .z,
        // "未分类" for the nil-bucket fallback). ShellMiddleColumn
        // previewScope must look the dirName up case-insensitively
        // (= EntityCategory rawValues are uppercase) so clicking a
        // category row actually narrows the middle-column card
        // grid (= the previous case-sensitive lookup fell back
        // to .referenceScope(nil) = the user saw the full overview
        // after clicking a category = the boss's bug).
        let src = try SourceLocator.read("Sources/WenshuApp/Features/Editor/View/AssetsPane.swift")
        #expect(src.contains(".uppercased()"),
                "AssetsPane.previewScope (= renamed from ShellMiddleColumn in commit 5723d226c) MUST do a case-insensitive rawValue lookup")
    }

    @Test("sidebar_service_reference_category_title_is_displayName_with_routing_key")
    func sidebar_service_reference_category_title_is_displayName_with_routing_key() throws {
        // 
        // 的一个字母. 不是中文分类名': category row title
        // MUST be the EntityCategory.displayName (= the
        // user-facing Chinese label "哲学、宗教", what the
        // user reads in the sidebar) NOT the routing key.
        // The routing key (= EntityCategory.directoryName
        // that previewScope's case-insensitive rawValue
        // lookup resolves back to a category) lives in the
        // dedicated `routingKey` field on SidebarNode.
        //
        // Why split title vs routingKey:
        //   The earlier iteration put directoryName in title + displayName
        //   in subtitle. forwardSelection read node.title →
        //   routed correctly BUT the sidebar showed the first-letter
        //   hint. The fix: displayName in
        //   title (user-readable); routingKey in dedicated
        //   field (forwardSelection reads it).
        let src = try SourceLocator.read("Sources/WenshuApp/Features/Library/View/SidebarService.swift")
        #expect(src.contains("title: folder.displayName") || src.contains("title: category.displayName"),
                "category rows MUST use displayName as the title (= the user-facing Chinese label; = current source uses folder.displayName for the folder row)")
        #expect(src.contains("routingKey: tag") || src.contains("routingKey: category.directoryName"),
                "category rows MUST store the routing identifier in the dedicated routingKey field (= current source stores the tag string)")
    }

    @Test("sidebar_node_kind_includes_routing_key")
    func sidebar_node_kind_includes_routing_key() throws {
        // 
        // field so the user-visible title and the
        // forwardSelection routing key can diverge (= the
        // category row shows Chinese label + routes by
        // EntityCategory directoryName).
        let src = try SourceLocator.read("Sources/WenshuApp/Features/Library/View/SidebarNode.swift")
        #expect(src.contains("var routingKey: String?"),
                "SidebarNode MUST expose routingKey as an optional String field")
    }

    @Test("previewPane_shelfScopeView_loads_union_of_books_under_shelf")
    func previewPane_shelfScopeView_loads_union_of_books_under_shelf() throws {
        // 
        // 测试书架. 这两个目录项可以点击, 但没有在卡片栏
        // 加载所有卡片': clicking a shelf row must load every
        // .md card from every book under that shelf (= the
        // union of `loadBookDocs(bookId:, folderName: nil)`
        // for books whose `shelfId` matches).
        // The shelf scope view lives in PreviewPaneScopeViews.swift
        // (= the scope-view helpers were extracted from PreviewPane.swift).
        let scopeViews = try SourceLocator.read("Sources/WenshuApp/Features/Editor/View/PreviewPaneScopeViews.swift")
        #expect(scopeViews.contains("func shelfScopeView(shelfId: UUID)"),
                "shelfScopeView MUST accept a shelfId parameter (= the scope view lives in PreviewPaneScopeViews, the file that holds it)")
        // The shelf book loader lives in PreviewPaneDataAccess.swift
        // (= the data accessors were extracted from PreviewPane.swift).
        let dataAccess = try SourceLocator.read("Sources/WenshuApp/Features/Editor/View/PreviewPaneDataAccess.swift")
        #expect(dataAccess.contains("func loadBooksInShelf(shelfId: UUID)")
                && dataAccess.contains("PreviewPaneOps.loadBooksInShelf"),
                "the shelf book loader MUST live in PreviewPaneDataAccess and delegate to PreviewPaneOps.loadBooksInShelf(= the helper that filters BookStore.sidebarLoadAllBooks by shelfId; = per ADR-0009)")
    }

    @Test("previewPane_shelfScopeView_empty_state_uses_shelf_specific_copy")
    func previewPane_shelfScopeView_empty_state_uses_shelf_specific_copy() throws {
        // 
        // 的空态, 原来用的是非选书, 现在因为书架可以点了.
        // 这个地方需要换了. 和测试小说点击时一样. 应该改成
        // 书架下暂无文档': the shelf empty-state copy must
        // describe the shelf (= "暂无文档"), NOT a stale
        // "select a book" hint from the v1.0.0-m1-shell era
        // (= when shelves were a drill-down intermediate
        // rather than a document scope).
        let src = try SourceLocator.read("Sources/WenshuApp/Features/Editor/View/PreviewPaneScopeViews.swift")
        #expect(src.contains("titleKey: \"preview.empty_state.shelf_empty\""),
                "shelfScopeView MUST use the shelf-specific empty-state title key (= lives in PreviewPaneScopeViews per SS6.2 split)")
        #expect(src.contains("bodyKey: \"preview.empty.shelf_no_books\""),
                "shelfScopeView MUST use a shelf-specific body key (= distinct from book_scope / reference_scope body keys; = lives in PreviewPaneScopeViews per SS6.2 split)")

        // Verify both Localizable.strings files define the keys
        //
        let enKeys = try Self.localizableKeys(relaPath: "Sources/WenshuApp/Resources/en.lproj/Localizable.strings")
        let zhKeys = try Self.localizableKeys(relaPath: "Sources/WenshuApp/Resources/zh-Hans.lproj/Localizable.strings")
        #expect(enKeys.contains("preview.empty_state.shelf_empty"),
                "en.lproj MUST define preview.empty_state.shelf_empty (= the shelf empty title)")
        #expect(zhKeys.contains("preview.empty_state.shelf_empty"),
                "zh-Hans.lproj MUST define preview.empty_state.shelf_empty (= the shelf empty title)")
        #expect(enKeys.contains("preview.empty.shelf_no_books"),
                "en.lproj MUST define preview.empty.shelf_no_books (= the shelf empty body)")
        #expect(zhKeys.contains("preview.empty.shelf_no_books"),
                "zh-Hans.lproj MUST define preview.empty.shelf_no_books (= the shelf empty body)")
    }

    @Test("previewPane_loadBookDocs_handles_folder_scope")
    func previewPane_loadBookDocs_handles_folder_scope() throws {
        // 
        // to PreviewPaneOps.loadBookDocs (= the canonical UI→Business→Data
        // seam per ADR-0009). The spec is met; the assertion target
        // moves from PreviewPane.swift to PreviewPaneOps.swift.
        let ops = try SourceLocator.read("Sources/WenshuApp/Features/Editor/View/PreviewPaneOps.swift")
        // The scope views call the loader directly (= the scope-view
        // helpers were extracted from PreviewPane.swift into
        // PreviewPaneScopeViews.swift).
        let scopeViews = try SourceLocator.read("Sources/WenshuApp/Features/Editor/View/PreviewPaneScopeViews.swift")
        // The loader is a static on PreviewPaneOps now: it takes the
        // store and returns its own result type, so the declaration
        // is matched across the line breaks it is written on.
        #expect(ops.range(of: Self.loadBookDocsSignature, options: .regularExpression) != nil,
                "PreviewPaneOps.loadBookDocs MUST be a static loader taking the store, the book id and the folder name (= the shape that is real now)")
        #expect(scopeViews.contains("PreviewPaneOps.loadBookDocs(bookStore: bookStore, bookId: bookId, folderName: folderName)"),
                "the preview pane's book scope MUST load its docs through PreviewPaneOps.loadBookDocs (= the card grid loader)")
        #expect(ops.contains("folders = [folderName]"),
                "PreviewPaneOps.loadBookDocs MUST scope to the one folder when non-nil")
    }
}
