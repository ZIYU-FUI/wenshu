// AppleSidebarView.swift
// … (= 51 rationale lines collapsed; = A112 docblock collapse per §1.8)
// 4 sheets + context-menu + business methods restored in v1.69y).
import SwiftUI
import os

private let wenshuLogger = Logger(subsystem: "com.wenshu", category: "applesidebarview")

struct AppleSidebarView: View {
    @Environment(BookStore.self) var bookStore
    @Environment(AppState.self) private var appState
    // sidebarSelection moved from ShellState to WorkspaceUIState
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // state; = the Pages / Numbers / Keynote canonical shape).
    @Environment(WorkspaceUIState.self) var workspaceUI
    @Environment(SheetRequestState.self) private var sheetRequests

    /// SidebarService owns the tree (= data + business logic; = SwiftUI doesn't
    /// see it; = the List renders it).
    @State var service: SidebarService?

    /// The row the user picked (= derived from the shared state; = the
    /// shared state is the single truth, so the sidebar and the preview
    /// pane always agree, and the row survives a relaunch).
    private var selectedNode: SidebarNode? {
        Self.node(for: workspaceUI.sidebarSelection, in: service?.nodes ?? [])
    }

    // y (see OOB.md #2026-09-23) OOB ', ':
    // … (= 7 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // counter; = the sidebar body observes and presents).
    @State private var showNewChoiceSheet = false
    @State private var showNewShelfSheet = false
    @State private var showNewBookSheet = false
    @State private var showExportSheet = false
    @State private var showImportSheet = false
    // / prefill state for the import sheet (= the import target is pre-selected
    // … (= 4 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / pick the right destination.
    @State private var importPrefillDestination: ImportSheet.ImportDestination = .book
    @State private var importPrefillBookID: UUID?
    @State private var renaming: SidebarRenamingTarget?
    @State private var pendingDelete: SidebarPendingDelete?

    // / set of selected `SidebarItem` (= mirrors the legacy
    // … (= 3 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / context menu builder).
    @State private var contextMenuSelection: Set<SidebarItem> = []

    /// What the current part shows.
    ///
    /// The reserved ebooks part shows the platform's empty state; = the
    /// other two parts show their tree.
    @ViewBuilder
    private var partContent: some View {
        if workspaceUI.currentSidebarPart == .referenceBooks {
            EmptyStateView(
                icon: "book.closed",
                title: String(localized: "sidebar.part.reference_books.empty.title"),
                body: String(localized: "sidebar.part.reference_books.empty.body")
            )
        } else {
            sidebarList
        }
    }

    /// The tree the current part shows.
    ///
    /// The shelves part shows the shelf hierarchy, the library part shows
    /// the reference library hierarchy, and the reserved ebooks part has
    /// no tree.
    private var currentNodes: [SidebarNode] {
        switch workspaceUI.currentSidebarPart {
        case .shelves: return service?.shelfNodes ?? []
        case .library: return service?.libraryNodes ?? []
        case .referenceBooks: return []
        }
    }

    /// The tree of the current part.
    ///
    /// The list is a separate property because a large list expression
    /// inside a conditional in the body does not type-check in reasonable
    /// time.
    private var sidebarList: some View {
        List(
            currentNodes,
            children: \.children,
            selection: Binding(
                get: { selectedNode },
                set: { newValue in forwardSelection(newValue) }
            )
        ) { node in
            // The per-row `SidebarRowView`
            // … (= 18 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // multi-select case).
            SidebarRowView(
                node: node,
                callbacks: SidebarRowCallbacks(
                    onNewBookHere: { shelfId in
                        workspaceUI.sidebarSelection = .shelf(shelfId)
                        sheetRequests.newBook += 1
                    },
                    onRenameShelf: { shelfId, _ in
                        if let shelf = service?.shelves.first(where: { $0.id == shelfId }) {
                            renaming = SidebarRenamingTarget(
                                kind: .shelf,
                                itemId: shelfId,
                                originalName: shelf.name,
                                shelfId: nil
                            )
                        }
                    },
                    onRenameBook: { bookId, _ in
                        if let book = service?.books.first(where: { $0.id == bookId }) {
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
                        let resolvedName = service?.books.first(where: { $0.id == bookId })?.title ?? ""
                        pendingDelete = SidebarPendingDelete(
                            kind: .book,
                            itemId: bookId,
                            itemName: resolvedName
                        )
                    },
                    resolveShelf: { id in
                        service?.shelves.first(where: { $0.id == id })
                            .map { (id: $0.id, name: $0.name) }
                    },
                    resolveBook: { id in
                        service?.books.first(where: { $0.id == id })
                            .map { (id: $0.id, name: $0.title) }
                    },
                    onImportToReferenceLibrary: {
                        importPrefillDestination = .referenceLibrary
                        importPrefillBookID = nil
                        showImportSheet = true
                    },
                    onImportToBook: { bookId in
                        importPrefillDestination = .book
                        importPrefillBookID = bookId
                        showImportSheet = true
                    },
                    // The
                    // … (= 31 rationale lines collapsed; = A112 docblock collapse per §1.8)
                    // `otherReferenceTitles`).
                    onRenameReference: { referenceId, _ in
                        renaming = SidebarRenamingTarget(
                            kind: .reference,
                            itemId: referenceId,
                            originalName: referenceTitle(for: referenceId) ?? "",
                            shelfId: nil
                        )
                    },
                    onDeleteReference: { referenceId, name in
                        pendingDelete = SidebarPendingDelete(
                            kind: .reference,
                            itemId: referenceId,
                            itemName: name
                        )
                    }
                )
            )
                    }
        .listStyle(.sidebar)
    }

    var body: some View {
        Group {
            if let service {
                VStack(spacing: 0) {
                    // ', 10 PT /
                    // … (= 5 rationale lines collapsed; = A112 docblock collapse per §1.8)
                    // Mail / Notes / Finder section-header idiom).
                    SectionHeader(title: String(localized: "sidebar.column.title"))
                    // The three parts of the sidebar (= the shelves, the
                    // reference library, and the reserved ebooks part).
                    LabelSegmentedControl(
                        selection: Binding(
                            get: { workspaceUI.currentSidebarPart },
                            set: { newValue in workspaceUI.currentSidebarPart = newValue }
                        ),
                        labels: SidebarPart.allCases,
                        displayStrings: SidebarPart.allCases.map(\.displayName),
                        iconStyle: .paneTab
                    )
                    .frame(maxWidth: .infinity)
                    partContent

                // y (see OOB.md #2026-09-23) OOB ', ':
                // … (= 6 rationale lines collapsed; = A112 docblock collapse per §1.8)
                // counters; = the sidebar body observes and presents).
                .modifier(EmptyAreaContextMenu(
                    newLabel: String(localized: "sidebar_context_menu_new"),
                    action: startNewItem
                ))
                // The previous list-level
                // … (= 86 rationale lines collapsed; = A112 docblock collapse per §1.8)
                // newValue).
                }  // end VStack(spacing: 0) { title + Divider + List }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            AppleSidebarBottomNewButton {
                startNewItem()
            }
        }
        .task {
            if service == nil {
                service = SidebarService(
                    loadShelves: { try bookStore.sidebarLoadShelves() },
                    loadAllBooks: { try bookStore.sidebarLoadAllBooks() },
                    loadReferences: { try bookStore.loadAllReferences() },
                    // '
                    // … (= 5 rationale lines collapsed; = A112 docblock collapse per §1.8)
                    // / empty folder).
                    loadFolderDocCount: { [bookStore] bookId, folderName in
                        let shelvesRoot = bookStore.stores.shelvesRoot
                        // Walk every shelf under shelvesRoot
                        // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
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
                    // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
                    // surface for the sidebar mutations).
                    bookStore: bookStore
                )
            }
            await service?.reload()
        }
        .onChange(of: workspaceUI.sidebarSelection) { _, _ in
            Task { await service?.reload() }
        }
        // Reveal the first level of the part's tree when the part
        // changes. The list's own expansion state is not reachable
        // through the public API, so the first level is revealed by
        // selecting a row in it. The remembered selection for the part
        // wins when it has one.
        .onChange(of: workspaceUI.currentSidebarPart) { _, _ in
            revealFirstLevel()
        }
        // y (see OOB.md #2026-09-23) OOB ', ':
        // … (= 6 rationale lines collapsed; = A112 docblock collapse per §1.8)
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
        .onReceive(NotificationCenter.default.publisher(for: .wenshuImportRequested)) { _ in
            showImportSheet = true
        }
        // Reload the sidebar tree when the markdown import
        // … (= 15 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // the tree stays unchanged).
        .onReceive(NotificationCenter.default.publisher(for: .wenshuLibraryDidChange)) { _ in
            Task { await service?.reload() }
        }
        // y: the create/rename/delete sheets. Each presents
        // … (= 4 rationale lines collapsed; = A112 docblock collapse per §1.8)
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
            // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
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
                availableShelves: service?.availableShelvesForPicker() ?? []
            )
        }
        .sheet(isPresented: $showExportSheet) {
            ExportSheet(isPresented: $showExportSheet)
        }
        .sheet(isPresented: $showImportSheet) {
            ImportSheet(
                isPresented: $showImportSheet,
                prefillDestination: importPrefillDestination,
                prefillBookID: importPrefillBookID
            )
        }
        .sheet(item: $renaming) { target in
            RenameItemSheet(
                originalName: target.originalName,
                // the
                // … (= 11 rationale lines collapsed; = A112 docblock collapse per §1.8)
                // `SidebarService`).
                otherNames: otherNamesForRename(target: target),
                onSave: { newName in
                    do {
                        switch target.kind {
                        case .shelf:
                            try service?.renameShelf(id: target.itemId, newName: newName)
                        case .book:
                            try service?.renameBook(id: target.itemId, newTitle: newName)
                        case .reference:
                            try service?.renameReference(id: target.itemId, newTitle: newName)
                        case .bookDoc:
                            // the
                            // … (= 30 rationale lines collapsed; = A112 docblock collapse per §1.8)
                            // entry).
                            try service?.renameBookDoc(id: target.itemId, newTitle: newName)
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
                    case .reference:
                        // 
                        // … (= 25 rationale lines collapsed; = A112 docblock collapse per §1.8)
                        // tree.
                        try service?.deleteReference(id: target.itemId)
                    case .bookDoc:
                        // 
                        // … (= 15 rationale lines collapsed; = A112 docblock collapse per §1.8)
                        // menu).
                        try service?.deleteBookDoc(id: target.itemId)
                    }
                    pendingDelete = nil
                    Task { await service?.reload() }
                    // Post the
                    // … (= 15 rationale lines collapsed; = A112 docblock collapse per §1.8)
                    // disappears).
                    NotificationCenter.default.post(
                        name: .wenshuLibraryDidChange,
                        object: nil
                    )
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



    /// Start a new item in the current part.
    ///
    /// The shelves part offers the shelf and book choices. The library
    /// part offers the reference library import. The reserved ebooks part
    /// does nothing, because nothing can be created there yet.
    private func startNewItem() {
        switch workspaceUI.currentSidebarPart {
        case .shelves:
            sheetRequests.choice += 1
        case .library:
            importPrefillDestination = .referenceLibrary
            importPrefillBookID = nil
            showImportSheet = true
        case .referenceBooks:
            break
        }
    }

    /// Select a row at the first level of the current part's tree.
    ///
    /// The selection goes through the shared state, so the part's
    /// remembered selection wins when it has one. A part with no
    /// remembered selection and no first-level row leaves the selection
    /// empty, and the preview pane falls back to its overview.
    private func revealFirstLevel() {
        if workspaceUI.sidebarSelection != nil { return }
        guard let first = currentNodes.first else { return }
        forwardSelection(first)
    }

    // / Find the tree row a shared selection names.
    // … (= 4 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / a row in the tree (= the sidebar draws the same row as selected).
    static func node(for selection: SidebarItem?, in nodes: [SidebarNode]) -> SidebarNode? {
        guard let selection else { return nil }
        return findNode(for: selection, in: nodes)
    }

    // / The row search itself (= every selection case the tree can make).
    // … (= 4 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / a category row and a tag row carry a string, not an identifier.
    private static func findNode(for selection: SidebarItem, in nodes: [SidebarNode]) -> SidebarNode? {
        for node in nodes {
            switch selection {
            case .shelf(let id):
                if node.kind == .shelf && node.id == id { return node }
            case .book(let id):
                if node.kind == .book && node.id == id { return node }
            case .folder(let bookId, let folderName):
                // The folder row's title is the display name, so the
                // selection's folder name is compared against the title
                // the row's own name maps back to (= the same mapping the
                // parent-book lookup uses).
                if node.kind == .book, node.id == bookId,
                   let folder = node.children?.first(where: {
                       $0.title == folderName || Self.reverseFolderName(title: $0.title) == folderName
                   }) {
                    return folder
                }
            case .referenceCategory(let key):
                if node.kind == .referenceCategory, node.routingKey == key { return node }
                if node.kind == .referenceCategory, node.title == key { return node }
            case .referenceUnclassified:
                if node.kind == .referenceCategory,
                   node.routingKey == SidebarService.unclassifiedRoutingKey {
                    return node
                }
            case .tag(let tag):
                if node.kind == .tag, node.title == tag { return node }
            }
            if let child = findNode(for: selection, in: node.children ?? []) {
                return child
            }
        }
        return nil
    }

    // / Walk the sidebar tree to find the parent book + folder name for a row id
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / child books).
    static func parentBookInfo(for rowId: UUID, in nodes: [SidebarNode]) -> (bookId: UUID, folderName: String)? {
        // Walk each top-level shelf. If a shelf's direct child is
        // … (= 4 rationale lines collapsed; = A112 docblock collapse per §1.8)
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

    // / Map a folder row's display title back to its filesystem folder name (=
    // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / either side changes).
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

    // / Open the book's first chapter (= the `<book-id>/chapters/<n>.md` file
    // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / missing-documentPath gracefully).
    private func openBookInEditor(bookId: UUID) {
        let result = SidebarOpenOps.openBookInEditor(appState: appState, bookId: bookId)
        if let id = result.openedTabId {
            _ = id  // caller already wired; = explicit no-op to silence unused-let warnings.
        }
        // didSwitchExistingTab: caller can no-op (= AppState.activeTabId set in Ops).
    }

    // / Open a folder (= the `<book-id>/<folder-name>/` directory's first .md
    // … (= 5 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / MVVM split.
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
