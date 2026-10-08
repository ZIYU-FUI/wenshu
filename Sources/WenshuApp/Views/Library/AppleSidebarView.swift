// AppleSidebarView.swift
//
// macOS 27 Apple HIG sidebar (= List(data, children:) +
// .listStyle(.sidebar)). The canonical sidebar surface for
// the wenshu NavigationSplitView shell.
//
// arc (= 27 commits v1.69a → v1.69bb per AGENTS.md):
//   - v1.68b: initial Apple HIG rewrite replacing the v1.64-v1.67
//     hand-rolled LazySidebarView (= SwiftUI List(.sidebar)).
//   - v1.69a-e: MVVM cleanup (= extract SidebarItem, BottomNewButton,
//     ZoneHeaderButtons to focused files; = drop 9 LazySidebar*
//     dead files + NewLibraryOutlineView 2366-LOC legacy).
//   - v1.69i-l: reference-library auto-classification (= CLC 22
//     top-level categories).
//   - v1.69m-n-q: BUG fixes (= routingKey field, shelfScopeView
//     union-of-cards, bookDocsGrid reuse).
//   - v1.69x: NSHostingView constraint loop fix (= stable SHA1
//     BookDoc.id + cached shelf books + .task(id:) dispatch).
//   - v1.69y: restore sidebar create + rename + context menu that
// e had `git rm`-deleted (= 4 sheets in SidebarSheets.swift,
//     1 builder + 2 ViewModifier wrappers in SidebarContextMenu.swift,
//     create/delete/rename business layer in SidebarService.swift).
//   - v1.69aa-bb: UI polish (= centered '' title bar + Divider
//     above List; = Divider row between shelves and the reference
//     library root).
//
// What lives here:
//   - the SwiftUI view tree (= VStack { title + Divider + List(
//     sidebarService.nodes, children: \.children, selection: ...)
//     + .listStyle(.sidebar) }).
//   - the SidebarService holder (@State + .task { service.reload() }).
//   - the selection binding (forwards into AppState.sidebarSelection
//     so the rest of wenshu continues to read the same value it did
//     before the split).
//   - 4 sheet modifiers (= .sheet(isPresented:) × 3 for
//     NewChoiceSheet / NewShelfSheet / NewBookSheet + .sheet(item:)
//     for RenameItemSheet) + 1 .alert for delete confirmation.
//   - 2 context-menu modifiers (= EmptyAreaContextMenu +
//     SidebarRowContextMenu wrapping SidebarContextMenuBuilder).
//
// What does NOT live here:
//   - the sheet bodies (= SidebarSheets.swift).
//   - the context-menu factory (= SidebarContextMenu.swift).
//   - business logic (= SidebarService.swift handles create/delete/
//     rename + on-disk file IO + validation + reserved-name guards).
//   - row rendering (= the List + SidebarRowView handle it; =
//     SwiftUI macOS 14+ does the disclosure indicator + selection
//     tint + hover highlight; = the divider row is rendered as
//     a Divider when node.kind == .divider).
//
// This file is the canonical SwiftUI sidebar surface post-MVVM
// (= the same architecture that v1.68b established, with the
// 4 sheets + context-menu + business methods restored in v1.69y).

import SwiftUI
import os

private let wenshuLogger = Logger(subsystem: "com.wenshu", category: "applesidebarview")

struct AppleSidebarView: View {
    @Environment(BookStore.self) private var bookStore
    @Environment(AppState.self) private var appState
    // sidebarSelection moved from ShellState to WorkspaceUIState
    // (= single environment-injected class for all column-local UI
    // state; = the Pages / Numbers / Keynote canonical shape).
    @Environment(WorkspaceUIState.self) private var workspaceUI
    @Environment(SheetRequestState.self) private var sheetRequests

    /// SidebarService owns the tree (= data + business logic;
    /// = SwiftUI doesn't see it; = the List renders it).
    @State private var service: SidebarService?

    /// Selection state (= forwarded to ShellState.sidebarSelection
    /// via .onChange below).
    @State private var selectedNode: SidebarNode?

    // y (see OOB.md #2026-09-23) OOB ', ':
    // the create/rename/delete sheets that live in
    // SidebarSheets.swift (recovered from the deleted v1.69e
    // NewLibraryOutlineView). Each sheet's `isPresented`
    // boolean is local @State on this sidebar body (= flips
    // via .onChange(of: appState.{choice,newShelf,newBook}
    // RequestCount) so the toolbar Menu's New buttons and the
    // sidebar's own New buttons can all flip the same shared
    // counter; = the sidebar body observes and presents).
    @State private var showNewChoiceSheet = false
    @State private var showNewShelfSheet = false
    @State private var showNewBookSheet = false
    @State private var showExportSheet = false
    @State private var renaming: SidebarRenamingTarget?
    @State private var pendingDelete: SidebarPendingDelete?

    /// set of selected `SidebarItem` (= mirrors the
    /// legacy NewLibraryOutlineView's `Set<SidebarItem>` selection
    /// pattern; = macOS 14+ `.contextMenu(forSelectionType:)` reads
    /// from the `List(selection:)` binding; = we forward the
    /// current sidebarSelection into this set for the context
    /// menu builder).
    @State private var contextMenuSelection: Set<SidebarItem> = []

    var body: some View {
        Group {
            if let service {
                VStack(spacing: 0) {
                    // ', 10 PT /
                    //  / 4 PT /  / 10 PT, Apple HIG ':
                    // lift the sidebar column title bar to the
                    // shared SectionHeader component (= also used by
                    // PreviewPane '' header; = same 10 PT / text /
                    // 4 PT gap / divider / 10 PT inset Apple HIG
                    // Mail / Notes / Finder section-header idiom).
                    SectionHeader(title: String(localized: "sidebar.column.title"))
                    let sidebarList = List(
                        service.nodes,
                        children: \.children,
                        selection: $selectedNode
                    ) { node in
                        SidebarRowView(node: node)
                    }
                    sidebarList
                    .listStyle(.sidebar)
                // y: sidebar right-click menu (= Apple HIG
                // canonical macOS 14+ contextMenu hook). The
                // closure body lives in `SidebarContextMenuModifier`
                // (= a ViewModifier that hides the SwiftUI
                // `.contextMenu(forSelectionType:menu:)` complexity
                // from the type-checker; = the closure body uses
                // direct Button rows; = no Divider; = no Group; =
                // no AnyView; = matches the Apple Developer doc
                // example for the canonical menu shape).
                //
                // y: macOS 27 right-click routing. Per
                // Apple Developer doc for
                // `contextMenu(forSelectionType:menu:primaryAction:)`:
                // 'An empty set indicates menu activation over
                // the empty area of the selectable container,
                // while a non-empty set indicates menu
                // activation over selected items.' We rely on
                // this (= NO separate plain `.contextMenu`
                // modifier on the List body; = only ONE
                // `.contextMenu(forSelectionType:menu:)` is
                // attached; = the closure body has the
                // `if items.isEmpty` branch which shows the
                // single "新建" entry for empty-area
                // right-clicks).
                .modifier(SidebarContextMenuModifier(
                    onNewShelf: { sheetRequests.choice += 1 },
                    onNewBookHere: { shelfId in
                        workspaceUI.sidebarSelection = .shelf(shelfId)
                        sheetRequests.newBook += 1
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
                    },
                    resolveShelf: { id in
                        service.shelves.first(where: { $0.id == id })
                            .map { (id: $0.id, name: $0.name) }
                    },
                    resolveBook: { id in
                        service.books.first(where: { $0.id == id })
                            .map { (id: $0.id, name: $0.title) }
                    }
                ))
                // sidebar fix (= (see OOB.md #2026-09-22) OOB
                // ''): the .onChange(of:
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
                }  // end VStack(spacing: 0) { title + Divider + List }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            AppleSidebarBottomNewButton {
                sheetRequests.choice += 1
            }
        }
        .task {
            if service == nil {
                service = SidebarService(
                    loadShelves: { try bookStore.sidebarLoadShelves() },
                    loadAllBooks: { try bookStore.sidebarLoadAllBooks() },
                    loadReferences: { try bookStore.loadAllReferences() },
                    // '
                    // ' (= mirror the reference
                    // library's "X " subtitle on each book
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
                    // y: inject bookStore so the create /
                    // delete / rename business methods can write
                    // to shelvesRoot (= the persistence layer
                    // surface for the sidebar mutations).
                    bookStore: bookStore
                )
            }
            await service?.reload()
        }
        .onChange(of: workspaceUI.sidebarSelection) { _, _ in
            Task { await service?.reload() }
        }
        // y (see OOB.md #2026-09-23) OOB ', ':
        // wire up the 3 request counters (= `choiceRequestCount`
        // + `newShelfRequestCount` + `newBookRequestCount`) to
        // flip the matching sheet's `isPresented` @State. Mirrors
        // the pre-v1.69e legacy NewLibraryOutlineView's
        // `.onChange(of: appState.*RequestCount)` blocks (= same
        // pattern = the toolbar Menu's New buttons flip the
        // counters; = the sidebar body observes and presents).
        .onChange(of: sheetRequests.choice) { _, _ in
            showNewChoiceSheet = true
        }
        .onChange(of: sheetRequests.newShelf) { _, _ in
            showNewShelfSheet = true
        }
        .onChange(of: sheetRequests.newBook) { _, _ in
            showNewBookSheet = true
        }
        .onChange(of: sheetRequests.exportSheet) { _, _ in
            showExportSheet = true
        }
        // y: the create/rename/delete sheets. Each presents
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
                        sheetRequests.newShelf += 1
                    case .book:
                        sheetRequests.newBook += 1
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
                        wenshuLogger.info("[wenshu.sidebar] createShelf failed: \(String(describing: error))")
                        showNewShelfSheet = false
                    }
                },
                onCancel: { showNewShelfSheet = false },
                existingNames: service?.existingShelfNames() ?? []
            )
        }
        .sheet(isPresented: $showNewBookSheet) {
            // y: pre-resolve target shelf from current
            // sidebarSelection (= mirrors the legacy NewLibraryOutlineView.
            // resolveNewBookTargetShelf pattern; = the same logic
            // now lives in `SidebarService.targetShelfForNewBook(...)`).
            let target = service?.targetShelfForNewBook(currentSelection: workspaceUI.sidebarSelection)
                ?? service?.defaultShelfTarget() ?? (id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!, name: String(localized: "library.default.shelf_name"))
            NewBookSheet(
                onSave: { input in
                    do {
                        let _ = try service?.createBook(input: input)
                        showNewBookSheet = false
                        Task { await service?.reload() }
                    } catch {
                        wenshuLogger.info("[wenshu.sidebar] createBook failed: \(String(describing: error))")
                        showNewBookSheet = false
                    }
                },
                onCancel: { showNewBookSheet = false },
                targetShelfId: target.id,
                targetShelfName: target.name,
                availableShelves: service?.availableShelvesForPicker() ?? []
            )
        }
        .sheet(isPresented: $showExportSheet) {
            ExportSheet(isPresented: $showExportSheet)
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
                        wenshuLogger.info("[wenshu.sidebar] rename failed: \(String(describing: error))")
                        renaming = nil
                    }
                },
                onCancel: { renaming = nil }
            )
        }
        .alert(
            String(localized: "sidebar_delete_alert_title"),
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            presenting: pendingDelete
        ) { target in
            Button(String(localized: "sidebar_context_menu_delete"), role: .destructive) {
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
                    wenshuLogger.info("[wenshu.sidebar] delete failed: \(String(describing: error))")
                    pendingDelete = nil
                }
            }
            Button(String(localized: "auto.shared.cancel"), role: .cancel) {
                pendingDelete = nil
            }
        } message: { target in
            Text(String(localized: "sidebar_delete_alert_message")
                .replacingOccurrences(of: "%@", with: target.itemName))
        }
    }

    /// ', ':
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
    ///
    /// Apple HIG canonical: the closure passed to
    /// `.contextMenu(forSelectionType:menu:)` must return a
    /// @ViewBuilder block (= no `AnyView` wrapper, no explicit
    /// Group, no Divider between buttons). The `AnyView` wrapper
    /// collapses the @ContentBuilder tuple type and the menu
    /// item extractor drops trailing items (= the v1.69y
    /// symptom = "only 新建 shows"). The `?` shorthand below
    /// ensures both return paths produce the same @ContentBuilder
    /// tuple (= Apple HIG canonical shape).

    /// Map the user-clicked sidebar row to the corresponding
    /// AppState.sidebarSelection discriminator (= so the rest of
    /// wenshu continues to read the same value it did before
    /// the v1.69 MVVM split (= when SidebarItem still lived
    /// inline inside NewLibraryOutlineView)).
    ///
    /// '
    /// ，' (= the 5 standard folders under
    /// each book are now visible in the sidebar; = the folder
    /// rows forward their selection to AppState.sidebarSelection
    /// AND open the folder in the editor's tab strip).
    private func forwardSelection(_ node: SidebarNode?) {
        guard let node else { return }
        switch node.kind {
        case .shelf:
            workspaceUI.sidebarSelection = .shelf(node.id)
        case .book:
            // Determine if this is a real book (top-level row) or a
            // folder row (child of a book). Folder rows have a
            // parent in the sidebar tree (= the v1.68f folder
            // children, = 5 standard folders per book); real books
            // are children of a shelf. Walk the tree to disambiguate.
            if let parent = Self.parentBookInfo(for: node.id, in: service?.nodes ?? []) {
                // Folder row.
                workspaceUI.sidebarSelection = .folder(bookId: parent.bookId, folderName: parent.folderName)
                openFolderInEditor(bookId: parent.bookId, folderName: parent.folderName)
            } else {
                // Real book row.
                workspaceUI.sidebarSelection = .book(node.id)
                openBookInEditor(bookId: node.id)
            }
        case .reference:
            // reference-library leaf (= a single Reference
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
            workspaceUI.sidebarSelection = .referenceCategory(node.title)
        case .referenceCategory:
            // :
            // a category parent row (= one of the 22 CLC
            // top-level categories under the Reference-Library
            // root). Selecting it scopes the middle-column card
            // grid to that category.
            //
            // p (see OOB.md #2026-09-22) OOB: read the routing key
            // (= the EntityCategory.directoryName, stored in
            // SidebarNode.routingKey during the v1.69j projection;
            // = lowercase letter for the official 22 cases,
            // "" for .z, "" for pre-v0.29 nil-category
            // references). The routing key is what
            // ShellMiddleColumn.previewScope's case-insensitive
            // EntityCategory(rawValue:) lookup resolves back to
            // a category — the user-visible title (= "") can't
            // be used directly because no EntityCategory rawValue
            // is "". Falling back to node.title (= the previous
            // m behaviour) leaves the routing key in the
            // user-visible slot (= the user's ', 
            // ' complaint).
            workspaceUI.sidebarSelection = .referenceCategory(node.routingKey ?? node.title)
        case .divider:
            // bb (see OOB.md #2026-09-23) OOB '
            // ': divider rows are non-interactive;
            // = the user can never select a divider (= it's
            // pure chrome between sections). Forwarding a
            // sidebarSelection here would corrupt the
            // .referenceCategory discriminator (= the divider
            // sentinel has no EntityCategory mapping). Simply
            // no-op so the previous selection stays put.
            break
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
    /// book itself (= the EditorView's tab strip handles a
    /// missing-documentPath gracefully).
    private func openBookInEditor(bookId: UUID) {
        let result = SidebarOpenOps.openBookInEditor(appState: appState, bookId: bookId)
        if let id = result.openedTabId {
            _ = id  // caller already wired; = explicit no-op to silence unused-let warnings.
        }
        // didSwitchExistingTab: caller can no-op (= AppState.activeTabId set in Ops).
    }

    /// Open a folder (= the `<book-id>/<folder-name>/` directory's
    /// first .md file) in the editor's tab strip.
    ///
    /// minimal folder-open wiring (= future ticket
    /// surfaces the folder's content in the editor's tab UI; =
    /// for now the editor shows a placeholder until the file is
    /// loaded). Matches the legacy v1.67 LazySidebarView's
    /// onSelectFolder behavior (= .folder(bookId:, folderName:)
    /// on sidebarSelection) preserved through the MVVM split.
    private func openFolderInEditor(bookId: UUID, folderName: String) {
        let result = SidebarOpenOps.openFolderInEditor(
            appState: appState,
            bookId: bookId,
            folderName: folderName
        )
        if let id = result.openedTabId {
            _ = id
        }
    }
}
