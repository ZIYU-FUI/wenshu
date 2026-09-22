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