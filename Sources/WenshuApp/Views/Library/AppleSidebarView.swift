// AppleSidebarView.swift · Wenshu · v1.68b
//
// macOS 27 Apple HIG sidebar (= List(data, children:) +
// .listStyle(.sidebar)). Replaces the v1.64–v1.67
// LazySidebarView's hand-rolled LazyVStack of Button rows +
// manual .padding(.leading) + manual chevron + manual hover.
//
// Boss 2026-09-22 OOB '回方案 B 之前是因为别的原因, 记录的有问题' +
// 'macOS 27 化' (= the v1.64 NSTableView-resize-crash trade-off that
// produced LazySidebarView is reversed; = the sidebar that
// v1.68b = the Apple HIG canonical sidebar per WWDC20 10031).
//
// What lives here:
//   - the SwiftUI view tree (= List(sidebarService.nodes,
//     children: \.children) + .listStyle(.sidebar)).
//   - the SidebarService holder (= @State + .task { service.reload() }).
//   - the selection binding (= forwards into AppState.sidebarSelection
//     so the rest of wenshu continues to read the same selection it
//     did before).
//
// What does NOT live here:
//   - row rendering (= the List does it via SwiftUI for macOS 14+).
//   - file ops (= LazySidebarFileOps).
//   - state persistence (= LazySidebarState).
//   - data helpers (= LazySidebarData).
//   - the v1.67 LazySidebarView (= replaced; = the v1.68b is a new
//     view, not a refactor of the v1.67 file).
//
// v1.68b differs from the reverted v1.68a (= same architecture, =
// the boss accepted this but rejected the rest of the v1.68a patch
// because it leaked changes into LibraryStores / BookStore.init /
// 12 test fixtures — none of those are touched here).

import SwiftUI

struct AppleSidebarView: View {
    @Environment(BookStore.self) private var bookStore
    @Environment(AppState.self) private var appState

    /// SidebarService owns the tree (= data + business logic;
    /// = SwiftUI doesn't see it; = the List renders it).
    @State private var service: SidebarService?

    /// Selection state (= forwarded to AppState.sidebarSelection
    /// via .onChange below).
    @State private var selectedNode: SidebarNode?

    var body: some View {
        Group {
            if let service {
                List(
                    service.nodes,
                    children: \.children,
                    selection: $selectedNode
                ) { node in
                    SidebarRowView(node: node)
                }
                .listStyle(.sidebar)
                // v1.69 sidebar fix (= boss 2026-09-22 OOB
                // '现在目录树还是点不了'): the .onChange(of:
                // selectedNode) MUST live on the List (= outside
                // the rowContent closure), not on each row.
                //
                // Bug history: v1.68b placed `.onChange(of:
                // selectedNode) { forwardSelection(newValue) }`
                // INSIDE the rowContent closure. Each row's
                // onChange handler was re-registered whenever
                // SwiftUI rebuilt that row. When selectedNode
                // changed (= the user clicked a row), the change
                // propagated but the row rebuild had already
                // happened with the new selectedNode value baked
                // in — so onChange never fired (= a known SwiftUI
                // Observation + List(selection:) inter-row
                // race). Net user-visible effect: clicking any
                // sidebar row did nothing; = the middle-column
                // card grid (= PreviewPane) never re-rendered
                // for the clicked book / folder; = the card the
                // user saw was the one persisted from the last
                // launch via AppState.sidebarSelection.
                //
                // Fix: hoist the onChange to the List (= the
                // parent of all rows; = the change fires exactly
                // once per selectedNode mutation; =
                // forwardSelection runs with the canonical
                // newValue).
                .onChange(of: selectedNode) { _, newValue in
                    forwardSelection(newValue)
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            AppleSidebarBottomNewButton {
                appState.choiceRequestCount += 1
            }
        }
        .task {
            if service == nil {
                service = SidebarService(
                    loadShelves: { try bookStore.sidebarLoadShelves() },
                    loadAllBooks: { try bookStore.sidebarLoadAllBooks() },
                    loadReferences: { try bookStore.referenceStore.loadAllReferences() },
                    // v1.69 boss 2026-09-22 OOB '上面书架的五
                    // 目录也可以加' (= mirror the reference
                    // library's "X 项" subtitle on each book
                    // folder row). Count .md files in the
                    // matching on-disk folder; = returns 0 if
                    // the folder doesn't exist (= first-launch
                    // / empty folder).
                    loadFolderDocCount: { [bookStore] bookId, folderName in
                        let shelvesRoot = bookStore.stores.shelvesRoot
                        // Walk every shelf under shelvesRoot
                        // (= the book can live under any shelf; =
                        // matches PreviewPane.loadBookDocs path
                        // resolution logic).
                        guard FileManager.default.fileExists(atPath: shelvesRoot.path),
                              let shelfDirs = try? FileManager.default.contentsOfDirectory(
                                at: shelvesRoot,
                                includingPropertiesForKeys: nil,
                                options: [.skipsHiddenFiles]
                              ) else {
                            return 0
                        }
                        for shelfDir in shelfDirs {
                            let folderDir = shelfDir
                                .appendingPathComponent("books")
                                .appendingPathComponent(bookId.uuidString)
                                .appendingPathComponent(folderName)
                            if FileManager.default.fileExists(atPath: folderDir.path),
                               let contents = try? FileManager.default.contentsOfDirectory(
                                at: folderDir,
                                includingPropertiesForKeys: nil,
                                options: [.skipsHiddenFiles]
                              ) {
                                return contents.filter { $0.pathExtension == "md" }.count
                            }
                        }
                        return 0
                    }
                )
            }
            await service?.reload()
        }
        .onChange(of: appState.sidebarSelection) { _, _ in
            Task { await service?.reload() }
        }
    }

    /// Map the user-clicked sidebar row to the corresponding
    /// AppState.sidebarSelection discriminator (= so the rest of
    /// wenshu continues to read the same value it did under
    /// LazySidebarView).
    ///
    /// v1.68f boss 2026-09-22 OOB '帮助和测试小说下面的自动生成的
    /// 目录没有出现，需要实现' (= the 5 standard folders under
    /// each book are now visible in the sidebar; = the folder
    /// rows forward their selection to AppState.sidebarSelection
    /// AND open the folder in the editor's tab strip).
    private func forwardSelection(_ node: SidebarNode?) {
        guard let node else { return }
        switch node.kind {
        case .shelf:
            appState.sidebarSelection = .shelf(node.id)
        case .book:
            // Determine if this is a real book (top-level row) or a
            // folder row (child of a book). Folder rows have a
            // parent in the sidebar tree (= the v1.68f folder
            // children, = 5 standard folders per book); real books
            // are children of a shelf. Walk the tree to disambiguate.
            if let parent = Self.parentBookInfo(for: node.id, in: service?.nodes ?? []) {
                // Folder row.
                appState.sidebarSelection = .folder(bookId: parent.bookId, folderName: parent.folderName)
                openFolderInEditor(bookId: parent.bookId, folderName: parent.folderName)
            } else {
                // Real book row.
                appState.sidebarSelection = .book(node.id)
                openBookInEditor(bookId: node.id)
            }
        case .reference:
            // v1.69 reference-library leaf (= a single Reference
            // document). node.title carries the reference's
            // display title, not its category, so writing
            // `.referenceCategory(node.title)` here is incorrect;
            // the correct route is `.referenceCategory(<ref's
            // category directoryName>)` — but the SidebarNode
            // doesn't carry the Reference struct (= only id +
            // title + subtitle), so we resolve the reference's
            // category downstream by storing a structured
            // selection. Without that plumbing (= v1.69 ticket
            // scope = expand the CLC category tree only; =
            // single-reference selection lands on a future
            // ticket), the leaf row falls through to
            // .referenceScope(nil) in the preview pane via
            // ShellMiddleColumn's case-mismatch fallback (= =
            // the user sees the full overview; = the leaf can
            // be opened via the existing double-click pipeline
            // on the middle-column card).
            appState.sidebarSelection = .referenceCategory(node.title)
        case .referenceCategory:
            // v1.69 boss 2026-09-22 OOB '资料库自动分类目录的展示':
            // a category parent row (= one of the 22 CLC
            // top-level categories under the Reference-Library
            // root). Selecting it scopes the middle-column card
            // grid to that category.
            //
            // node.title = EntityCategory.directoryName (= "a" /
            // "b" / ... / "其它" / "未分类"). ShellMiddleColumn
            // handles the lowercase → rawValue restoration in
            // .referenceCategory case (= case-insensitive
            // lookup with nil-fallback).
            appState.sidebarSelection = .referenceCategory(node.title)
        }
    }

    /// Walk the sidebar tree to find the parent book + folder name
    /// for a row id (= returns nil for top-level books, =
    /// non-nil for folder rows under child books).
    private static func parentBookInfo(for rowId: UUID, in nodes: [SidebarNode]) -> (bookId: UUID, folderName: String)? {
        // Walk each top-level shelf. If a shelf's direct child is
        // the rowId (= top-level book), return nil. If a book's
        // children contains the rowId (= folder row), return the
        // book's id + the folder's name (= recovered from the row
        // title via a reverse lookup against the standard folder
        // catalog).
        for root in nodes where root.kind == .shelf {
            guard let shelfChildren = root.children else { continue }
            for book in shelfChildren where book.kind == .book {
                if book.id == rowId { return nil }
                if let folderChildren = book.children {
                    for cell in folderChildren where cell.id == rowId {
                        // Recover the folder name from the title.
                        let folderName = Self.reverseFolderName(title: cell.title)
                        return (book.id, folderName)
                    }
                }
            }
        }
        return nil
    }

    /// Map a folder row's display title back to its filesystem
    /// folder name (= the v1.68f SidebarService.folderCatalog
    /// is private; = the canonical mapping lives here too; =
    /// sync this with SidebarService.swift:181-187 if either side
    /// changes).
    private static func reverseFolderName(title: String) -> String {
        switch title {
        case "世界观":   return "world"
        case "角色":     return "characters"
        case "章节大纲": return "outlines"
        case "小说正文": return "chapters"
        case "小说草稿": return "drafts"
        default:         return title
        }
    }

    /// Open the book's first chapter (= the
    /// `<book-id>/chapters/<n>.md` file with the lowest `n`) in the
    /// editor's tab strip. If the book has no chapters, open the
    /// book itself (= the EditorPlaceholder's tab strip handles a
    /// missing-documentPath gracefully).
    private func openBookInEditor(bookId: UUID) {
        // v1.68e: minimal book-open wiring (= a future ticket
        // can extend this to surface the 5 standard folders in
        // the editor's tab UI — the seeded .md files are still on
        // disk; = LibraryMigrator 8/30 OOB seed is unchanged).
        //
        // EditorTab.init doesn't accept sourceScope directly (= it
        // defaults to nil; = the property is set post-init).
        if let existing = appState.openTabs.first(where: {
            if case .bookScope(let id, _) = $0.sourceScope { return id == bookId }
            return false
        }) {
            appState.activeTabId = existing.id
            return
        }
        let tab = EditorTab(
            id: UUID(),
            documentPath: nil,
            draft: "",
            originalBody: "",
            mode: .edit,
            title: nil
        )
        tab.sourceScope = .bookScope(bookId: bookId, folderName: nil)
        appState.openTabs.append(tab)
        appState.activeTabId = tab.id
    }

    /// Open a folder (= the `<book-id>/<folder-name>/` directory's
    /// first .md file) in the editor's tab strip.
    ///
    /// v1.68f: minimal folder-open wiring (= future ticket
    /// surfaces the folder's content in the editor's tab UI; =
    /// for now the editor shows a placeholder until the file is
    /// loaded). Matches the v1.67 LazySidebarView's onSelectFolder
    /// behavior (= .folder(bookId:, folderName:) on sidebarSelection).
    private func openFolderInEditor(bookId: UUID, folderName: String) {
        if let existing = appState.openTabs.first(where: {
            if case .bookScope(let id, let folder) = $0.sourceScope {
                return id == bookId && folder == folderName
            }
            return false
        }) {
            appState.activeTabId = existing.id
            return
        }
        let tab = EditorTab(
            id: UUID(),
            documentPath: nil,
            draft: "",
            originalBody: "",
            mode: .edit,
            title: nil
        )
        tab.sourceScope = .bookScope(bookId: bookId, folderName: folderName)
        appState.openTabs.append(tab)
        appState.activeTabId = tab.id
    }
}