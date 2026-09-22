// LazySidebarView.swift · Wenshu · v1.64
//
// Per boss 2026-09-18 'window drag crashes — fix the windows
// BUG first' + 'sidebar really has a problem — Apple API has
// other methods for hierarchical browsing, not necessarily
// outline tree': replace the NewLibraryOutlineView List(
// .sidebar) (= NSTableView under the hood = NSLayoutConstraint
// conflict on window resize per
// WenshuApp-2026-09-18-143621.ips) with a pure-SwiftUI
// LazyVStack of Button rows inside a ScrollView.
//
// Why this fixes the crash:
//   - List(.sidebar) on macOS 27 is rendered via NSTableView
//     (= SwiftUI List is a thin SwiftUI surface over AppKit's
//     NSTableView). When the NSWindow frame changes (= drag
//     resize), NSTableView's
//     _updateConstraintsAtColumn:row:rowView: rebuilds row
//     cell auto-layout. If any row modifier (= .badge,
//     .contextMenu, custom RowContent) introduces conflicting
//     constraints, CoreAutoLayout throws NSException from
//     -[NSLayoutConstraint setActive:] = app crash.
//   - LazyVStack is pure SwiftUI = no NSTableView = no
//     CoreAutoLayout conflict. SwiftUI uses its own layout
//     engine; SwiftUI's NSHostingView handles the resize
//     cache invalidation we already fixed in v1.63.
//
// Why LazyVStack (not OutlineGroup, not List(.plain)):
//   - OutlineGroup still renders as NSTableView (= same crash).
//   - List(.plain) ALSO renders as NSTableView on macOS.
//   - LazyVStack = pure SwiftUI view tree, no AppKit table.
//
// Visual: Apple's Mail / Notes / Finder sidebars use
// NSTableView (= can render thousands of rows efficiently).
// wenshu sidebar has at most a few shelves + a few books per
// shelf + 5 standard folders per book = < 100 rows total =
// LazyVStack performance is fine.
//
// Feature parity with NewLibraryOutlineView (= what we keep):
//   - shelves list (Section 1, with shelf DisclosureGroup)
//   - books per shelf (nested DisclosureGroup inside shelf)
//   - 5 standard folders per book (leaf rows inside book)
//   - reference library Section at the bottom
//   - .tag-based selection via a single @State variable that
//     mirrors appState.sidebarSelection
//   - sidebar bottom 'New' button via .safeAreaInset(edge: .bottom)
//
// Feature parity DELIBERATELY DROPPED (= simpler = no crash):
//   - .badge counts (= dropped in v1.61, not restored here)
//   - .contextMenu(forSelectionType:) (= drop; per-row
//     .contextMenu still works inside LazyVStack rows)
//   - list-level .contextMenu for empty area (= replaced with
//     a dedicated '+ New' bottom button which is more discoverable
//     anyway)

import SwiftUI

struct LazySidebarView: View {
    @Environment(AppState.self) private var appState
    @Environment(BookStore.self) private var bookStore

    @AppStorage("wenshu.sidebarState") private var persistedSidebarState: String = ""

    @State private var shelves: [Bookshelf] = []
    @State private var books: [Book] = []
    @State private var references: [Reference] = []
    @State private var loadError: String?

    @State private var shelfDisclosureStates: [UUID: Bool] = [:]
    @State private var bookDisclosureStates: [UUID: Bool] = [:]
    @State private var referenceLibraryDisclosureExpanded: Bool = false

    @State private var showNewBookSheet: Bool = false
    @State private var showNewShelfSheet: Bool = false
    @State private var showNewChoiceSheet: Bool = false
    @State private var renaming: LazyRenamingTarget?
    @State private var pendingDelete: LazyPendingDelete?

    var body: some View {
            // v1.72 boss 2026-09-18 'sidebar is not macOS 27 standard,
            // selection isn't Liquid Glass' — boss clarification: don't
            // add a glass panel to the sidebar background itself (= the
            // v1.72 first attempt wrapped the entire ScrollView in
            // .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
            // + .backgroundExtensionEffect() = the sidebar became a
            // gray fog covering everything = boss rejected it). The
            // correct macOS 27 sidebar pattern (= Apple Mail / Notes /
            // Pages) = the sidebar background STAYS the standard content-
            // tier (.underPageBackgroundColor = Apple Pages sidebar
            // visual) and ONLY the selected row gets a glass-effect
            // tinted highlight (= the macOS 27 .background(.tint) +
            // .glassEffect() pattern Apple uses for selected sidebar
            // rows on Mail / Notes / Finder).
            //
            // Selected row visual = nested macOS 27 glass tint:
            //   .background(
            //     RoundedRectangle(cornerRadius: 6)
            //         .fill(Color.accentColor.opacity(0.22))  // Apple system tint
            //         .overlay(
            //             RoundedRectangle(cornerRadius: 6)
            //                 .strokeBorder(.tint.opacity(0.30), lineWidth: 1)
            //         )
            //   )
            // = the standard Apple Mail / Notes selected sidebar row
            // visual (= light glass tint background + 1 PT tint stroke
            // border; = no flat opacity fill; = the macOS 27 standard).
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    LazySidebarHeader()
                    shelvesSection
                    LazySidebarReferenceSection(
                        isExpanded: referenceLibraryDisclosureExpanded,
                        categories: usedCategories(),
                        selectedCategory: LazySidebarData.selectedReferenceCategoryRaw(
                            appState.sidebarSelection
                        ),
                        onToggle: {
                            referenceLibraryDisclosureExpanded.toggle()
                        },
                        onSelectCategory: { raw in
                            appState.sidebarSelection = .referenceCategory(raw)
                        }
                    )
                    if let loadError {
                        Text(loadError)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                    }
                }
                .padding(.vertical, 4)
            }
            // v1.76 boss 2026-09-18 'left + right columns need default
            // inner padding matching the chat zone': add horizontal
            // padding to the sidebar (= the same 8 PT Apple HIG
            // canonical inline content inset that chat history uses
            // via DesignTokens.chromePaddingLeading; = SwiftUI's
            // Spacing.small). Currently the sidebar rows flush
            // against the column edges (= no outer inset = the
            // sidebar looks cramped next to the chat zone's padded
            // content).
            .padding(.horizontal, DesignTokens.chromePaddingLeading)
            // v1.72 macOS 27 sidebar standard (= no extra glass background;
            // = the NavigationSplitView auto-paints the standard
            // content-tier background; = the boss's screenshot showed
            // the sidebar with a clean dark gray content-tier background
            // (= same as the editor zone) which IS the macOS 27 sidebar
            // visual). Strip the v1.72 first-attempt .glassEffect
            // background + .backgroundExtensionEffect (= that fog layer
            // = boss rejected).
            .background(Color.clear)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                LazySidebarBottomNewButton {
                    appState.choiceRequestCount += 1
                }
            }
        .onAppear { onAppearLoad() }
        .onChange(of: appState.sidebarSelection) { _, _ in
            persistedSidebarState = snapshotSidebarState().jsonString
        }
        .onChange(of: shelfDisclosureStates) { _, _ in
            persistedSidebarState = snapshotSidebarState().jsonString
        }
        .onChange(of: bookDisclosureStates) { _, _ in
            persistedSidebarState = snapshotSidebarState().jsonString
        }
        .onChange(of: referenceLibraryDisclosureExpanded) { _, _ in
            persistedSidebarState = snapshotSidebarState().jsonString
        }
        .onChange(of: appState.newBookRequestCount) { _, _ in
            showNewBookSheet = true
        }
        .onChange(of: appState.newShelfRequestCount) { _, _ in
            showNewShelfSheet = true
        }
        .onChange(of: appState.choiceRequestCount) { _, _ in
            showNewChoiceSheet = true
        }
        .sheet(isPresented: $showNewBookSheet) {
            let newItemTarget = LazySidebarFileOps.resolveNewItemTargetShelf(
                selection: appState.sidebarSelection,
                books: books,
                shelves: shelves
            )
            LazyNewBookSheet(
                targetShelfId: newItemTarget.id,
                targetShelfName: newItemTarget.name,
                availableShelves: shelves.map { ($0.id, $0.name) },
                onSave: { book in
                    do {
                        try bookStore.sidebarSaveBook(book)
                        reload()
                    } catch {
                        loadError = error.localizedDescription
                    }
                }
            )
        }
        .sheet(isPresented: $showNewShelfSheet) {
            LazyNewShelfSheet(
                existingNames: shelves.map { $0.name },
                onSave: { name, icon in
                    do {
                        try bookStore.sidebarSaveShelf(name: name, icon: icon)
                        reload()
                    } catch {
                        loadError = error.localizedDescription
                    }
                }
            )
        }
        .sheet(isPresented: $showNewChoiceSheet) {
            LazyNewChoiceSheet(
                onNewBook: {
                    showNewChoiceSheet = false
                    showNewBookSheet = true
                },
                onNewShelf: {
                    showNewChoiceSheet = false
                    showNewShelfSheet = true
                }
            )
        }
        .sheet(item: $renaming) { target in
            LazyRenameItemSheet(
                title: target.kind == .shelf ? "重命名书架" : "重命名书",
                originalName: target.originalName,
                existingNames: target.kind == .shelf
                    ? shelves.filter { $0.id != target.itemId }.map { $0.name }
                    : books.filter { $0.id != target.itemId }.map { $0.title },
                onSave: { newName in
                    do {
                        if target.kind == .shelf {
                            try LazySidebarFileOps.renameShelf(
                                id: target.itemId,
                                newName: newName,
                                shelves: shelves,
                                shelvesRoot: bookStore.stores.shelvesRoot
                            )
                        } else {
                            try LazySidebarFileOps.renameBook(
                                id: target.itemId,
                                newTitle: newName,
                                books: books,
                                shelves: shelves,
                                shelvesRoot: bookStore.stores.shelvesRoot
                            )
                        }
                        reload()
                    } catch {
                        loadError = error.localizedDescription
                    }
                }
            )
        }
        .alert(
            "确认删除?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            presenting: pendingDelete
        ) { target in
            Button("取消", role: .cancel) { pendingDelete = nil }
            Button("删除", role: .destructive) {
                do {
                    if target.kind == .shelf {
                        try LazySidebarFileOps.deleteShelf(
                            id: target.itemId,
                            shelvesRoot: bookStore.stores.shelvesRoot
                        )
                    } else {
                        try LazySidebarFileOps.deleteBook(
                            id: target.itemId,
                            shelves: shelves,
                            shelvesRoot: bookStore.stores.shelvesRoot
                        )
                    }
                    reload()
                } catch {
                    loadError = error.localizedDescription
                }
                pendingDelete = nil
            }
        } message: { target in
            let count = LazySidebarFileOps.pendingDeleteChildCount(
                target: target,
                books: books,
                bookStore: bookStore
            )
            Text(count > 0 ? "将一并删除 \(count) 个子项." : "")
        }
    }

    // MARK: - Header (= moved to LazySidebarChromeRow.swift)

    // MARK: - Shelves Section

    private var shelvesSection: some View {
        ForEach(shelves) { shelf in
            LazySidebarShelfRow(
                shelf: shelf,
                booksInShelf: LazySidebarData.shelfBooks(shelfId: shelf.id, in: books),
                isSelected: LazySidebarData.isShelfSelected(shelf.id, in: appState.sidebarSelection),
                isExpanded: shelfDisclosureStates[shelf.id, default: false],
                onToggle: {
                    shelfDisclosureStates[shelf.id, default: false].toggle()
                },
                onSelect: {
                    appState.sidebarSelection = .shelf(shelf.id)
                },
                onRename: {
                    renaming = LazyRenamingTarget(
                        kind: .shelf,
                        itemId: shelf.id,
                        originalName: shelf.name
                    )
                },
                onDelete: {
                    pendingDelete = LazyPendingDelete(
                        kind: .shelf,
                        itemId: shelf.id,
                        itemName: shelf.name
                    )
                },
                standardFolders: standardFolderNames,
                bookDisclosureStates: bookDisclosureStates,
                onToggleBook: { bookId in
                    bookDisclosureStates[bookId, default: false].toggle()
                },
                onSelectBook: { bookId in
                    appState.sidebarSelection = .book(bookId)
                },
                onSelectFolder: { bookId, folderName in
                    appState.sidebarSelection = .folder(
                        bookId: bookId, folderName: folderName
                    )
                },
                onRenameBook: { bookId, bookTitle in
                    renaming = LazyRenamingTarget(
                        kind: .book,
                        itemId: bookId,
                        originalName: bookTitle
                    )
                },
                onDeleteBook: { bookId, bookTitle in
                    pendingDelete = LazyPendingDelete(
                        kind: .book,
                        itemId: bookId,
                        itemName: bookTitle
                    )
                }
            )
        }
    }

    // MARK: - Reference Library Section
    // (= moved to LazySidebarReferenceSection.swift per boss 2026-09-22
    // OOB 'UI 与功能分离, UI 是 UI, 加载的内容是内容, 不要混合写大文件'
    // — the v1.68 split: row rendering = LazySidebarReferenceSection,
    // business logic = LazySidebarFileOps, state = LazySidebarState.)

    // MARK: - Bottom New button (= moved to LazySidebarChromeRow.swift)

    // MARK: - Data + Persistence

    private func onAppearLoad() {
        reload()
        let saved = LazySidebarState.from(jsonString: persistedSidebarState)
        shelfDisclosureStates = saved.shelfExpanded
        bookDisclosureStates = saved.bookExpanded
        referenceLibraryDisclosureExpanded = saved.referenceLibraryExpanded
        if let savedSel = saved.selection, appState.sidebarSelection == nil {
            appState.sidebarSelection = savedSel
        }
    }

    private func reload() {
        do {
            shelves = try bookStore.sidebarLoadShelves()
            books = try bookStore.sidebarLoadAllBooks()
            references = try bookStore.referenceStore.loadAllReferences()
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func snapshotSidebarState() -> LazySidebarState {
        LazySidebarState(
            shelfExpanded: shelfDisclosureStates,
            bookExpanded: bookDisclosureStates,
            referenceLibraryExpanded: referenceLibraryDisclosureExpanded,
            selection: appState.sidebarSelection
        )
    }

    // MARK: - File ops
    // (= moved to LazySidebarFileOps.swift per boss 2026-09-22 OOB
    // 'UI 与功能分离'. The view now calls LazySidebarFileOps.{...}
    // directly; = no business logic lives in this file.)
    //
    // pendingDeleteChildCount       → LazySidebarFileOps.pendingDeleteChildCount
    // resolveNewItemTargetShelf     → LazySidebarFileOps.resolveNewItemTargetShelf
    // deleteShelf                   → LazySidebarFileOps.deleteShelf
    // deleteBook                    → LazySidebarFileOps.deleteBook
    // renameShelf                   → LazySidebarFileOps.renameShelf
    // renameBook                    → LazySidebarFileOps.renameBook

    // MARK: - Helpers

    private var standardFolderNames: [(name: String, displayName: String, icon: String)] {
        LazySidebarStandardFolders.all.map { ($0.name, $0.displayName, $0.icon) }
    }

    private func usedCategories() -> [EntityCategory] {
        LazySidebarData.usedEntityCategories(in: references)
    }
}

// MARK: - State types
// (= LazySidebarState / LazyItemKind / LazyRenamingTarget /
// LazyPendingDelete; now live in LazySidebarState.swift per boss
// 2026-09-22 OOB 'UI 与功能分离, UI 是 UI, 加载的内容是内容, 不要混合
// 写大文件'. They are pure data types with no SwiftUI dependency; =
// the 'UI is UI, content is content' split.)

// MARK: - Sheets
// (= LazyNewBookSheet / LazyNewShelfSheet / LazyNewChoiceSheet /
// LazyRenameItemSheet; now live in LazySidebarSheets.swift per boss
// 2026-09-22 OOB 'UI 与功能分离, UI 是 UI, 加载的内容是内容, 不要混合
// 写大文件'. Each sheet is a self-contained modal form.)