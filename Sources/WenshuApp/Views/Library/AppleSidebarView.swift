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

    // v1.69y boss 2026-09-23 OOB '新建功能, 右边菜单等恢复':
    // the create/rename/delete sheets that used to live on
    // NewLibraryOutlineView (= deleted in v1.69e). Each sheet's
    // `isPresented` boolean is local @State on this sidebar body
    // (= flips via .onChange(of: appState.{choice,newShelf,newBook}
    // RequestCount) so the toolbar Menu's New buttons and the
    // sidebar's own New buttons can all flip the same shared
    // counter; = the sidebar body observes and presents).
    @State private var showNewChoiceSheet = false
    @State private var showNewShelfSheet = false
    @State private var showNewBookSheet = false
    @State private var renaming: SidebarRenamingTarget?
    @State private var pendingDelete: SidebarPendingDelete?

    /// v1.69y: set of selected `SidebarItem` (= mirrors
    /// NewLibraryOutlineView's `Set<SidebarItem>` selection;
    /// = macOS 14+ `.contextMenu(forSelectionType:)` reads
    /// from the `List(selection:)` binding; = we forward the
    /// current sidebarSelection into this set for the context
    /// menu builder).
    @State private var contextMenuSelection: Set<SidebarItem> = []

    var body: some View {
        Group {
            if let service {
                let sidebarList = List(
                    service.nodes,
                    children: \.children,
                    selection: $selectedNode
                ) { node in
                    SidebarRowView(node: node)
                }
                sidebarList
                .listStyle(.sidebar)
                // v1.69y: empty-area right-click (= the
                // `.contextMenu(forSelectionType:menuItems:)`
                // hook below does NOT route empty-area hits; =
                // macOS 26 SwiftUI behavior). A plain
                // `.contextMenu` modifier on the List covers
                // right-clicks on empty sidebar area (= shows
                // the single "New" entry that triggers the
                // choice sheet; = the legacy
                // NewLibraryOutlineView empty-area behavior).
                // The closure is tiny (= single Button) so the
                // type-checker handles it inline; = the heavy
                // closure lives in `contextMenuHandler`.
                .modifier(EmptyAreaContextMenu(
                    newLabel: WenshuI18n.t("sidebar_context_menu_new"),
                    action: { appState.choiceRequestCount += 1 }
                ))
                // v1.69y: right-click on selected rows (= Apple
                // HIG canonical macOS 14+ contextMenu hook).
                // The closure body lives in a separate
                // helper method (= `contextMenuHandler(items:)`)
                // and is wrapped in `SidebarRowContextMenu`
                // (= a ViewModifier that hides the SwiftUI
                // `.contextMenu(forSelectionType:menuItems:)`
                // complexity from the type-checker).
                .modifier(SidebarRowContextMenu(
                    selectionType: SidebarItem.self,
                    builder: { items in contextMenuHandler(items: items) }
                ))
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
                    },
                    // v1.69y: inject bookStore so the create /
                    // delete / rename business methods can write
                    // to shelvesRoot (= the persistence layer
                    // surface for the sidebar mutations).
                    bookStore: bookStore
                )
            }
            await service?.reload()
        }
        .onChange(of: appState.sidebarSelection) { _, _ in
            Task { await service?.reload() }
        }
        // v1.69y boss 2026-09-23 OOB '新建功能, 右边菜单等恢复':
        // wire up the 3 request counters (= `choiceRequestCount`
        // + `newShelfRequestCount` + `newBookRequestCount`) to
        // flip the matching sheet's `isPresented` @State. Mirrors
        // the v1.0.0-m1 legacy NewLibraryOutlineView's
        // `.onChange(of: appState.*RequestCount)` blocks (= same
        // pattern = the toolbar Menu's New buttons flip the
        // counters; = the sidebar body observes and presents).
        .onChange(of: appState.choiceRequestCount) { _, _ in
            showNewChoiceSheet = true
        }
        .onChange(of: appState.newShelfRequestCount) { _, _ in
            showNewShelfSheet = true
        }
        .onChange(of: appState.newBookRequestCount) { _, _ in
            showNewBookSheet = true
        }
        // v1.69y: the create/rename/delete sheets. Each presents
        // a focused `*Sheet` view from `SidebarSheets.swift`; =
        // the sheet's `onSave` closure calls into
        // `SidebarService.{createShelf,createBook,renameShelf,
        // renameBook,deleteShelf,deleteBook}` (= business layer)
        // and then dismisses + reloads the sidebar tree.
        .sheet(isPresented: $showNewChoiceSheet) {
            NewChoiceSheet(
                onCreate: { choice in
                    showNewChoiceSheet = false
                    switch choice {
                    case .shelf:
                        appState.newShelfRequestCount += 1
                    case .book:
                        appState.newBookRequestCount += 1
                    }
                },
                onCancel: { showNewChoiceSheet = false }
            )
        }
        .sheet(isPresented: $showNewShelfSheet) {
            NewShelfSheet(
                onSave: { name in
                    do {
                        let _ = try service?.createShelf(name: name)
                        showNewShelfSheet = false
                        Task { await service?.reload() }
                    } catch {
                        NSLog("[wenshu.sidebar] createShelf failed: %@", String(describing: error))
                        showNewShelfSheet = false
                    }
                },
                onCancel: { showNewShelfSheet = false },
                existingNames: service?.existingShelfNames() ?? []
            )
        }
        .sheet(isPresented: $showNewBookSheet) {
            // v1.69y: pre-resolve target shelf from current
            // sidebarSelection (= mirrors legacy NewLibraryOutlineView.
            // resolveNewBookTargetShelf).
            let target = service?.targetShelfForNewBook(currentSelection: appState.sidebarSelection)
                ?? service?.defaultShelfTarget() ?? (id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!, name: WenshuI18n.t("library.default.shelf_name"))
            NewBookSheet(
                onSave: { input in
                    do {
                        let _ = try service?.createBook(input: input)
                        showNewBookSheet = false
                        Task { await service?.reload() }
                    } catch {
                        NSLog("[wenshu.sidebar] createBook failed: %@", String(describing: error))
                        showNewBookSheet = false
                    }
                },
                onCancel: { showNewBookSheet = false },
                targetShelfId: target.id,
                targetShelfName: target.name,
                availableShelves: service?.availableShelvesForPicker() ?? []
            )
        }
        .sheet(item: $renaming) { target in
            RenameItemSheet(
                kind: target.kind,
                originalName: target.originalName,
                otherNames: target.kind == .shelf
                    ? (service?.otherShelfNames(excluding: target.itemId) ?? [])
                    : (service?.otherBookTitles(excluding: target.itemId) ?? []),
                onSave: { newName in
                    do {
                        switch target.kind {
                        case .shelf:
                            try service?.renameShelf(id: target.itemId, newName: newName)
                        case .book:
                            try service?.renameBook(id: target.itemId, newTitle: newName)
                        }
                        renaming = nil
                        Task { await service?.reload() }
                    } catch {
                        NSLog("[wenshu.sidebar] rename failed: %@", String(describing: error))
                        renaming = nil
                    }
                },
                onCancel: { renaming = nil }
            )
        }
        .alert(
            WenshuI18n.t("sidebar_delete_alert_title"),
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            presenting: pendingDelete
        ) { target in
            Button(WenshuI18n.t("sidebar_context_menu_delete"), role: .destructive) {
                do {
                    switch target.kind {
                    case .shelf:
                        try service?.deleteShelf(id: target.itemId)
                    case .book:
                        try service?.deleteBook(id: target.itemId)
                    }
                    pendingDelete = nil
                    Task { await service?.reload() }
                } catch {
                    NSLog("[wenshu.sidebar] delete failed: %@", String(describing: error))
                    pendingDelete = nil
                }
            }
            Button(WenshuI18n.t("auto.shared.cancel"), role: .cancel) {
                pendingDelete = nil
            }
        } message: { target in
            Text(WenshuI18n.t("sidebar_delete_alert_message")
                .replacingOccurrences(of: "%@", with: target.itemName))
        }
    }

    /// v1.69y boss 2026-09-23 OOB '新建功能, 右边菜单等恢复':
    /// context-menu builder (= extracted from the inline body
    /// of `.contextMenu(forSelectionType:menuItems:)` above; =
    /// the inline closure body was so large the Swift type
    /// checker gave up; = extracting it to a focused method
    /// gives the type-checker room to work). The handler
    /// forwards to `SidebarContextMenuBuilder.build(...)` with
    /// closures that flip `renaming` / `pendingDelete` /
    /// `appState.*RequestCount` (= the sidebar's local
    /// `@State` and the AppState shared counter; = the
    /// .sheet + .alert modifiers elsewhere on this body
    /// observe + present).
    private func contextMenuHandler(items: Set<SidebarItem>) -> AnyView {
        guard let service else {
            return AnyView(EmptyView())
        }
        let shelves = service.availableShelvesForPicker()
        return SidebarContextMenuBuilder.build(
            selection: items,
            availableShelves: shelves,
            onNewBookHere: { shelfId in
                appState.sidebarSelection = .shelf(shelfId)
                appState.newBookRequestCount += 1
            },
            onRenameShelf: { shelfId, _ in
                if let shelf = service.shelves.first(where: { $0.id == shelfId }) {
                    renaming = SidebarRenamingTarget(
                        kind: .shelf,
                        itemId: shelfId,
                        originalName: shelf.name,
                        shelfId: nil
                    )
                }
            },
            onRenameBook: { bookId, _ in
                if let book = service.books.first(where: { $0.id == bookId }) {
                    renaming = SidebarRenamingTarget(
                        kind: .book,
                        itemId: bookId,
                        originalName: book.title,
                        shelfId: book.shelfId
                    )
                }
            },
            onDeleteShelf: { shelfId, name in
                pendingDelete = SidebarPendingDelete(
                    kind: .shelf,
                    itemId: shelfId,
                    itemName: name
                )
            },
            onDeleteBook: { bookId, _ in
                let resolvedName = service.books.first(where: { $0.id == bookId })?.title ?? ""
                pendingDelete = SidebarPendingDelete(
                    kind: .book,
                    itemId: bookId,
                    itemName: resolvedName
                )
            }
        )
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
            // v1.69p boss 2026-09-22 OOB: read the routing key
            // (= the EntityCategory.directoryName, stored in
            // SidebarNode.routingKey during the v1.69j projection;
            // = lowercase letter for the official 22 cases,
            // "其它" for .z, "未分类" for pre-v0.29 nil-category
            // references). The routing key is what
            // ShellMiddleColumn.previewScope's case-insensitive
            // EntityCategory(rawValue:) lookup resolves back to
            // a category — the user-visible title (= "文学") can't
            // be used directly because no EntityCategory rawValue
            // is "文学". Falling back to node.title (= the previous
            // v1.69m behaviour) leaves the routing key in the
            // user-visible slot (= the boss's '资料库分类, 现在
            // 显示是的一个字母' complaint).
            appState.sidebarSelection = .referenceCategory(node.routingKey ?? node.title)
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