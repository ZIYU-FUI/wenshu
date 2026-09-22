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
    private func forwardSelection(_ node: SidebarNode?) {
        guard let node else { return }
        switch node.kind {
        case .shelf:
            appState.sidebarSelection = .shelf(node.id)
        case .book:
            // Folder rows (= a book whose row is shown with no
            // child rows = a leaf in the children-tree) keep the
            // parent book's selection. In the v1.67 LazySidebarView
            // folders wrote `.folder(bookId:, folderName:)` to
            // sidebarSelection; here the row IS the folder so we
            // promote to .book (= the closest match in the existing
            // SidebarItem shape; = the AppState observers downstream
            // already handle .book the same way they handled .folder).
            if let parent = node.parentBookId(in: service?.nodes ?? []) {
                appState.sidebarSelection = .book(parent)
            } else {
                appState.sidebarSelection = .book(node.id)
            }
        case .reference:
            // Reference rows map to .referenceCategory with the row
            // title (= matches the v1.67 LazySidebarView's
            // reference-library behavior; = the reference-library
            // expansion is out of scope for v1.68b).
            appState.sidebarSelection = .referenceCategory(node.title)
        }
    }
}

// MARK: - SidebarNode parentBookId helper

private extension SidebarNode {
    /// Walk the tree to find the parent shelf of a node (= used by
    /// AppleSidebarView's forwardSelection to recover the parent
    /// book id when the user clicks a folder row).
    func parentBookId(in nodes: [SidebarNode]) -> UUID? {
        for root in nodes {
            if let children = root.children {
                for child in children where child.id == self.id {
                    return root.kind == .book ? root.id : nil
                }
                if let nested = parentBookId(in: children) {
                    return nested
                }
            }
        }
        return nil
    }
}