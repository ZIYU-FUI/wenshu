// AppleSidebarMVVMSplitTests.swift · Wenshu · v1.69
//
// v1.69 sidebar MVVM cleanup: end-to-end source-level verification
// that the new MVVM-split sidebar stack
// (= AppleSidebarView + SidebarService + SidebarNode + SidebarItem)
// is correctly wired together (= the boss 2026-09-22 OOB requirement
// "拆完了之后, 老的不符合 MVVM, UI, 业务, 数据分离的文件要删掉").
//
// Three things must hold:
//   1. The legacy NewLibraryOutlineView is GONE (= removed in
//      v1.69; = any future re-introduction breaks the MVVM
//      split).
//   2. The new MVVM-split sidebar files all exist + form the
//      canonical chain (= data = SidebarNode + SidebarItem;
//      business = SidebarService; UI = AppleSidebarView +
//      SidebarRowView + AppleSidebarBottomNewButton +
//      SidebarZoneHeaderButtons).
//   3. The folder-click chain (`folder → .folder(bookId,
//      folderName) → appState.sidebarSelection → previewScope =
//      .bookScope(bookId:, folderName:) → PreviewPane.loadBookDocs`)
//      is the canonical path that renders the folder's .md files
//      as cards (= the boss 2026-09-22 OOB requirement "书下的
//      每目录可点击，然后卡片栏显示这个目录下的所有文件卡片").

import Testing
import Foundation

@Suite("v1.69 — AppleSidebarView MVVM split + folder→cards chain")
struct AppleSidebarMVVMSplitTests {

    /// Resolve repo-relative paths against the wenshu project root
    /// (= not the Swift Testing worker's CWD which can be the
    /// build directory at test runtime).
    private static func wenshuRoot() -> String {
        // Tests run with the package's source root as CWD when
        // launched via `swift test` from the wenshu root; = the
        // canonical repo-relative path matches the source layout.
        // (No environment-variable lookup because the existing
        // sidebar source-level tests in this repo use the same
        // pattern; = consistency over portability.)
        let cwd = FileManager.default.currentDirectoryPath
        // If the test runner CWD is somewhere nested (e.g. the
        // .build/out directory), walk up until we find a directory
        // containing both Sources/ and Tests/.
        var dir = cwd
        for _ in 0..<6 {
            let hasSources = FileManager.default.fileExists(
                atPath: dir + "/Sources/WenshuApp/Views/Library/AppleSidebarView.swift"
            )
            let hasTests = FileManager.default.fileExists(
                atPath: dir + "/Tests/WenshuAppTests/Views/Library"
            )
            if hasSources && hasTests { return dir }
            dir = (dir as NSString).deletingLastPathComponent
        }
        return cwd
    }

    private static func repoPath(_ relative: String) -> String {
        wenshuRoot() + "/" + relative
    }

    /// Parse a binary1 Localizable.strings file and return its keys.
    /// v1.69s boss 2026-09-22 OOB shelf-empty-state copy needs
    /// both languages to define the new keys; = the test asserts
    /// the keys are present in the plist (= not just the Swift
    /// call site that reads them).
    private static func localizableKeys(relaPath: String) throws -> Set<String> {
        let url = URL(fileURLWithPath: repoPath(relaPath))
        let data = try Data(contentsOf: url)
        // binary1 Localizable.strings == NSDictionary of String → String.
        let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        guard let dict = plist as? [String: String] else {
            return []
        }
        return Set(dict.keys)
    }

    // MARK: - 1. Old legacy sidebar is gone

    @Test("legacy_NewLibraryOutlineView_is_removed")
    func legacy_NewLibraryOutlineView_is_removed() throws {
        let oldFile = Self.repoPath("Sources/WenshuApp/Views/Library/NewLibraryOutlineView.swift")
        let oldExt = Self.repoPath("Sources/WenshuApp/Views/Library/NewLibraryOutlineView+DisclosureState.swift")
        #expect(!FileManager.default.fileExists(atPath: oldFile),
                "NewLibraryOutlineView.swift MUST be removed in v1.69 (= the legacy 2520-LOC sidebar that did not follow MVVM)")
        #expect(!FileManager.default.fileExists(atPath: oldExt),
                "NewLibraryOutlineView+DisclosureState.swift MUST be removed in v1.69 (= the legacy sidebar extension)")

        // The 9 v1.68 lazy-extraction files (= unrolled-back v1.68
        // attempt that pre-dated the v1.68b AppleSidebarView
        // rewrite; = kept around as dead code per the pre-v1.69
        // state; = removed in v1.69 too).
        let deadLazyFiles = [
            "Sources/WenshuApp/Views/Library/LazySidebarView.swift",
            "Sources/WenshuApp/Views/Library/LazySidebarState.swift",
            "Sources/WenshuApp/Views/Library/LazySidebarData.swift",
            "Sources/WenshuApp/Views/Library/LazySidebarFileOps.swift",
            "Sources/WenshuApp/Views/Library/LazySidebarChromeRow.swift",
            "Sources/WenshuApp/Views/Library/LazySidebarShelfRow.swift",
            "Sources/WenshuApp/Views/Library/LazySidebarBookRow.swift",
            "Sources/WenshuApp/Views/Library/LazySidebarSheets.swift",
            "Sources/WenshuApp/Views/Library/LazySidebarReferenceSection.swift",
        ]
        for f in deadLazyFiles {
            #expect(!FileManager.default.fileExists(atPath: Self.repoPath(f)),
                    "\(f) MUST be removed in v1.69 (= dead-code from the pre-v1.68b lazy sidebar extraction)")
        }
    }

    // MARK: - 2. New MVVM-split files exist + wire correctly

    @Test("new_mvvm_split_sidebar_files_exist")
    func new_mvvm_split_sidebar_files_exist() throws {
        // Data layer
        let dataFiles = [
            "Sources/WenshuApp/Views/Library/SidebarNode.swift",  // data: tree row
            "Sources/WenshuApp/Views/Library/SidebarItem.swift",  // data: selection enum
        ]
        for f in dataFiles {
            #expect(FileManager.default.fileExists(atPath: Self.repoPath(f)),
                    "\(f) MUST exist (= the data layer of the v1.68b MVVM-split sidebar)")
        }
        // Business layer
        let businessFiles = [
            "Sources/WenshuApp/Views/Library/SidebarService.swift",  // business: tree loader
        ]
        for f in businessFiles {
            #expect(FileManager.default.fileExists(atPath: Self.repoPath(f)),
                    "\(f) MUST exist (= the business layer of the v1.68b MVVM-split sidebar)")
        }
        // UI layer
        let uiFiles = [
            "Sources/WenshuApp/Views/Library/AppleSidebarView.swift",  // UI: main view
            "Sources/WenshuApp/Views/Library/SidebarRowView.swift",  // UI: row content
            "Sources/WenshuApp/Views/Library/AppleSidebarBottomNewButton.swift",  // UI: bottom '+' button
            "Sources/WenshuApp/Views/Library/SidebarZoneHeaderButtons.swift",  // UI: zone header New/Import
        ]
        for f in uiFiles {
            #expect(FileManager.default.fileExists(atPath: Self.repoPath(f)),
                    "\(f) MUST exist (= the UI layer of the v1.68b MVVM-split sidebar)")
        }
    }

    @Test("sidebar_files_have_strict_role_separation")
    func sidebar_files_have_strict_role_separation() throws {
        // Data layer (= SidebarNode, SidebarItem) MUST NOT import
        // SwiftUI (= pure data types; = testable without the view
        // framework).
        let dataFiles = [
            "Sources/WenshuApp/Views/Library/SidebarNode.swift",
            "Sources/WenshuApp/Views/Library/SidebarItem.swift",
        ]
        for f in dataFiles {
            let src = try String(contentsOfFile: Self.repoPath(f), encoding: .utf8)
            #expect(!src.contains("import SwiftUI"),
                    "\(f) MUST NOT import SwiftUI (= data layer is pure value types)")
        }

        // Business layer (= SidebarService) MUST NOT import SwiftUI
        // (= holds the tree; = loads via closures; = no view code).
        let businessSrc = try String(
            contentsOfFile: Self.repoPath("Sources/WenshuApp/Views/Library/SidebarService.swift"),
            encoding: .utf8
        )
        #expect(!businessSrc.contains("import SwiftUI"),
                "SidebarService.swift MUST NOT import SwiftUI (= business layer is plain @Observable + @MainActor actor)")

        // UI layer (= AppleSidebarView, SidebarRowView,
        // AppleSidebarBottomNewButton, SidebarZoneHeaderButtons)
        // MUST import SwiftUI.
        let uiFiles = [
            "Sources/WenshuApp/Views/Library/AppleSidebarView.swift",
            "Sources/WenshuApp/Views/Library/SidebarRowView.swift",
            "Sources/WenshuApp/Views/Library/AppleSidebarBottomNewButton.swift",
            "Sources/WenshuApp/Views/Library/SidebarZoneHeaderButtons.swift",
        ]
        for f in uiFiles {
            let src = try String(contentsOfFile: Self.repoPath(f), encoding: .utf8)
            #expect(src.contains("import SwiftUI"),
                    "\(f) MUST import SwiftUI (= UI layer)")
        }
    }

    // MARK: - 3. Folder-click → cards chain is intact

    @Test("appleSidebarView_forwards_folder_selection_to_appState")
    func appleSidebarView_forwards_folder_selection_to_appState() throws {
        let src = try String(
            contentsOfFile: Self.repoPath("Sources/WenshuApp/Views/Library/AppleSidebarView.swift"),
            encoding: .utf8
        )
        // AppleSidebarView's forwardSelection MUST write the
        // .folder(bookId:, folderName:) discriminator into
        // appState.sidebarSelection (= the canonical chain to
        // WorkspaceView.previewScope / ShellMiddleColumn.previewScope
        // → PreviewPane.bookScopeView → loadBookDocs(folderName:)).
        #expect(src.contains(".folder(bookId: parent.bookId, folderName: parent.folderName)"),
                "AppleSidebarView MUST forward folder selection as .folder(bookId:, folderName:) (= the canonical chain to cards)")
        #expect(src.contains("appState.sidebarSelection = .folder"),
                "AppleSidebarView MUST write the folder selection to appState.sidebarSelection")
    }

    @Test("sidebarItem_folder_case_is_defined")
    func sidebarItem_folder_case_is_defined() throws {
        let src = try String(
            contentsOfFile: Self.repoPath("Sources/WenshuApp/Views/Library/SidebarItem.swift"),
            encoding: .utf8
        )
        // SidebarItem.folder(bookId:, folderName:) is the
        // discriminator WorkspaceView.previewScope /
        // ShellMiddleColumn.previewScope switch on. If missing,
        // the folder-click chain is broken.
        #expect(src.contains("case folder(bookId: UUID, folderName: String)"),
                "SidebarItem MUST have the .folder(bookId:, folderName:) case (= the canonical selection discriminator)")
    }

    @Test("sidebar_service_projects_folder_children_per_book")
    func sidebar_service_projects_folder_children_per_book() throws {
        let src = try String(
            contentsOfFile: Self.repoPath("Sources/WenshuApp/Views/Library/SidebarService.swift"),
            encoding: .utf8
        )
        // SidebarService.folderChildren(for:) MUST render the 5
        // standard folders under each book (= the v1.68f boss OOB
        // '帮助和测试小说下面的自动生成的目录没有出现，需要实现').
        #expect(src.contains("folderChildren"),
                "SidebarService MUST expose folderChildren (= the 5 standard folders per book)")
        #expect(src.contains("\"世界观\""),
                "SidebarService MUST render 世界观 folder (= one of the 5 standard sub-folders)")
        #expect(src.contains("\"章节大纲\""),
                "SidebarService MUST render 章节大纲 folder")
        #expect(src.contains("\"小说正文\""),
                "SidebarService MUST render 小说正文 folder")
    }

    @Test("sidebar_service_folder_children_carry_X_items_subtitle")
    func sidebar_service_folder_children_carry_X_items_subtitle() throws {
        // v1.69 boss 2026-09-22 OOB '上面书架的五目录也可以加':
        // each of the 5 standard folders (= 世界观 / 角色 /
        // 章节大纲 / 小说正文 / 小说草稿) renders an "X 项"
        // subtitle (= the .md file count under that folder),
        // mirroring the reference-library category row shape.
        let src = try String(
            contentsOfFile: Self.repoPath("Sources/WenshuApp/Views/Library/SidebarService.swift"),
            encoding: .utf8
        )
        #expect(src.contains("loadFolderDocCount"),
                "SidebarService MUST inject a loadFolderDocCount closure (= the count loader)")
        #expect(src.contains("\\(count) 项"),
                        "folderChildren MUST format the count as \"X 项\" (= the same shape the reference-library rows use)")
    }

    @Test("sidebar_service_reference_library_expands_to_category_rows")
    func sidebar_service_reference_library_expands_to_category_rows() throws {
        // v1.69 boss 2026-09-22 OOB '资料库自动分类目录的展示':
        // the Reference-Library root now has children that are
        // .referenceCategory rows (= one per non-empty CLC bucket).
        // Individual references are NOT rendered as leaves in the
        // sidebar (= boss 2026-09-22 '到分类层就够了'): the
        // category row's children stay nil so the row carries no
        // disclosure chevron.
        let src = try String(
            contentsOfFile: Self.repoPath("Sources/WenshuApp/Views/Library/SidebarService.swift"),
            encoding: .utf8
        )
        #expect(src.contains("referenceCategoryKey"),
                "SidebarService MUST bucket references by category")
        #expect(src.contains("EntityCategoryFromDirectoryName"),
                "SidebarService MUST map directoryName back to EntityCategory (= for icon + displayName)")
        #expect(src.contains("referenceRootChildren"),
                "SidebarService MUST emit category rows as Reference-Library children")
        #expect(src.contains("kind: .referenceCategory"),
                "category rows MUST be tagged .referenceCategory (= distinguishes from .reference leaves)")
    }

    @Test("sidebar_node_kind_includes_referenceCategory")
    func sidebar_node_kind_includes_referenceCategory() throws {
        // v1.69 boss 2026-09-22 OOB '资料库自动分类目录的展示':
        // SidebarNode.Kind grows a `.referenceCategory` case so
        // AppleSidebarView.forwardSelection can route category
        // row clicks to .referenceCategory(dirName) selection
        // (= the preview pane narrows to that category).
        let src = try String(
            contentsOfFile: Self.repoPath("Sources/WenshuApp/Views/Library/SidebarNode.swift"),
            encoding: .utf8
        )
        #expect(src.contains("case referenceCategory"),
                "SidebarNode.Kind MUST have .referenceCategory (= the category row discriminator)")
    }

    @Test("previewScope_referenceCategory_lookup_is_case_insensitive")
    func previewScope_referenceCategory_lookup_is_case_insensitive() throws {
        // v1.69 boss 2026-09-22 OOB: SidebarItem.referenceCategory
        // carries the EntityCategory.directoryName (= lowercase
        // letter for the official 22 CLC cases, "其它" for .z,
        // "未分类" for the nil-bucket fallback). ShellMiddleColumn
        // previewScope must look the dirName up case-insensitively
        // (= EntityCategory rawValues are uppercase) so clicking a
        // category row actually narrows the middle-column card
        // grid (= the previous case-sensitive lookup fell back
        // to .referenceScope(nil) = the user saw the full overview
        // after clicking a category = the boss's bug).
        let src = try String(
            contentsOfFile: Self.repoPath("Sources/WenshuApp/UI/Layout/ShellMiddleColumn.swift"),
            encoding: .utf8
        )
        #expect(src.contains(".uppercased()"),
                "ShellMiddleColumn.previewScope MUST do a case-insensitive rawValue lookup")
    }

    @Test("sidebar_service_reference_category_title_is_displayName_with_routing_key")
    func sidebar_service_reference_category_title_is_displayName_with_routing_key() throws {
        // v1.69 boss 2026-09-22 OOB '资料库分类, 现在显示是
        // 的一个字母. 不是中文分类名': category row title
        // MUST be the EntityCategory.displayName (= the
        // user-facing Chinese label "哲学、宗教", what the
        // user reads in the sidebar) NOT the routing key.
        // The routing key (= EntityCategory.directoryName
        // that previewScope's case-insensitive rawValue
        // lookup resolves back to a category) lives in the
        // dedicated `routingKey` field on SidebarNode.
        //
        // Why split title vs routingKey (= the v1.69m
        // inverse of this ticket):
        //   v1.69m put directoryName in title + displayName
        //   in subtitle. forwardSelection read node.title →
        //   routed correctly BUT the sidebar showed "i" /
        //   "l" / "k" (= boss complaint: '显示是的一个字
        //   母'). v1.69p fixes the split: displayName in
        //   title (user-readable); routingKey in dedicated
        //   field (forwardSelection reads it).
        let src = try String(
            contentsOfFile: Self.repoPath("Sources/WenshuApp/Views/Library/SidebarService.swift"),
            encoding: .utf8
        )
        #expect(src.contains("title: category.displayName"),
                "category rows MUST use displayName as the title (= the user-facing Chinese label)")
        #expect(src.contains("routingKey: category.directoryName"),
                "category rows MUST store directoryName in the dedicated routingKey field (= the routing key)")
    }

    @Test("sidebar_node_kind_includes_routing_key")
    func sidebar_node_kind_includes_routing_key() throws {
        // v1.69p: SidebarNode grows a `routingKey: String?`
        // field so the user-visible title and the
        // forwardSelection routing key can diverge (= the
        // category row shows Chinese label + routes by
        // EntityCategory directoryName).
        let src = try String(
            contentsOfFile: Self.repoPath("Sources/WenshuApp/Views/Library/SidebarNode.swift"),
            encoding: .utf8
        )
        #expect(src.contains("var routingKey: String?"),
                "SidebarNode MUST expose routingKey as an optional String field")
    }

    @Test("previewPane_shelfScopeView_loads_union_of_books_under_shelf")
    func previewPane_shelfScopeView_loads_union_of_books_under_shelf() throws {
        // v1.69 boss 2026-09-22 OOB '书架, 就是从这里开始,
        // 测试书架. 这两个目录项可以点击, 但没有在卡片栏
        // 加载所有卡片': clicking a shelf row must load every
        // .md card from every book under that shelf (= the
        // union of `loadBookDocs(bookId:, folderName: nil)`
        // for books whose `shelfId` matches).
        let src = try String(
            contentsOfFile: Self.repoPath("Sources/WenshuApp/Views/Workspace/PreviewPane.swift"),
            encoding: .utf8
        )
        #expect(src.contains("private func shelfScopeView(shelfId: UUID)"),
                "shelfScopeView MUST accept a shelfId parameter (= replaces the empty-state-only v1.0.0-m1-shell form)")
        #expect(src.contains("func loadBooksInShelf(shelfId: UUID)"),
                "PreviewPane MUST expose loadBooksInShelf(= helper that filters BookStore.sidebarLoadAllBooks by shelfId)")
    }

    @Test("previewPane_shelfScopeView_empty_state_uses_shelf_specific_copy")
    func previewPane_shelfScopeView_empty_state_uses_shelf_specific_copy() throws {
        // v1.69s boss 2026-09-22 OOB '点击网络长文时, 卡片区
        // 的空态, 原来用的是非选书, 现在因为书架可以点了.
        // 这个地方需要换了. 和测试小说点击时一样. 应该改成
        // 书架下暂无文档': the shelf empty-state copy must
        // describe the shelf (= "暂无文档"), NOT a stale
        // "select a book" hint from the v1.0.0-m1-shell era
        // (= when shelves were a drill-down intermediate
        // rather than a document scope).
        let src = try String(
            contentsOfFile: Self.repoPath("Sources/WenshuApp/Views/Workspace/PreviewPane.swift"),
            encoding: .utf8
        )
        #expect(src.contains("titleKey: \"preview.empty_state.shelf_empty\""),
                "shelfScopeView MUST use the shelf-specific empty-state title key (= no longer references the v1.0.0-m1 pick-book hint)")
        #expect(src.contains("bodyKey: \"preview.empty.shelf_no_books\""),
                "shelfScopeView MUST use a shelf-specific body key (= distinct from book_scope / reference_scope body keys)")

        // Verify both Localizable.strings files define the keys
        // (= the v1.69q-r era shipped the title-only override;
        // v1.69s adds a body key + retitles the title to match
        // the book_empty copy contract).
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
        let src = try String(
            contentsOfFile: Self.repoPath("Sources/WenshuApp/Views/Workspace/PreviewPane.swift"),
            encoding: .utf8
        )
        // PreviewPane.loadBookDocs(bookId:, folderName:) MUST
        // read the single folder (= when folderName is non-nil)
        // = the .md files inside that folder become the card
        // grid. Without this, the boss's '点 folder → 显示这个
        // 目录下的所有文件卡片' requirement is broken.
        #expect(src.contains("private func loadBookDocs(bookId: UUID, folderName: String?) -> [BookDoc]"),
                "PreviewPane MUST have loadBookDocs(bookId:, folderName:) (= the card grid loader)")
        #expect(src.contains("folders = [folderName]"),
                "PreviewPane.loadBookDocs MUST scope to the one folder when non-nil (= single-folder card grid)")
    }
}