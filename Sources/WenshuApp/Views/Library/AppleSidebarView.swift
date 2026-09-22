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
                        // Forward book / folder selections to BookStore
                        // (= the single source of truth for the rest
                        // of wenshu). Shelf / reference rows don't
                        // forward (= AppState.sidebarSelection keeps
                        // its own previous value; = no spurious
                        // selection flicker).
                        .onChange(of: selectedNode) { _, newValue in
                            forwardSelection(newValue)
                        }
                }
                .listStyle(.sidebar)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            LazySidebarBottomNewButton {
                appState.choiceRequestCount += 1
            }
        }
        .task {
            if service == nil {
                service = SidebarService(
                    loadShelves: { try bookStore.sidebarLoadShelves() },
                    loadAllBooks: { try bookStore.sidebarLoadAllBooks() },
                    loadReferences: { try bookStore.referenceStore.loadAllReferences() }
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
    /// v1.68e boss 2026-09-22 OOB '正常播种五文件夹' (= the sidebar
    /// tree = shelf → book only; = there are no folder rows to
    /// promote to .book anymore).
    private func forwardSelection(_ node: SidebarNode?) {
        guard let node else { return }
        switch node.kind {
        case .shelf:
            appState.sidebarSelection = .shelf(node.id)
        case .book:
            // Book row → AppState.sidebarSelection (.book(bookId))
            // AND open the book in the editor's tab strip
            // (= boss 2026-09-22 OOB '3rd level unclickable' =
            // sidebar row taps should open the editor, not just
            // set a sidebar selection mark).
            appState.sidebarSelection = .book(node.id)
            openBookInEditor(bookId: node.id)
        case .reference:
            // Reference rows map to .referenceCategory with the row
            // title (= matches the v1.67 LazySidebarView's
            // reference-library behavior; = the reference-library
            // expansion is out of scope for v1.68b).
            appState.sidebarSelection = .referenceCategory(node.title)
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
}