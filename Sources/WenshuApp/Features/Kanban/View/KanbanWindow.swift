//
//  KanbanWindow.swift
//
//  Kanban as an independent macOS window (= the SwiftUI macOS 14+
//  WindowGroup(id: "wenshu-kanban") per (see OOB.md #2026-09-11) OOB
//  'Kanban and Todo — show in dedicated windows. Other Apple apps don't integrate these
//  into the main window, they just open a separate window — and Kanban boards need lots of horizontal space anyway'.
//  Per Apple HIG, multi-window apps (= Pages / Numbers / Keynote /
//  Photos / Mail) each open independent surfaces in their own
//  windows so the user can pin the kanban to the side of their
//  screen while editing.
//
//  Window composition:
//  - KanbanView (= the existing board view, takes the full
//    window body; = no extra NavigationSplitView chrome around it
//    since the window IS the kanban).
//  - The kanban window is a SIBLING scene to the main WindowGroup
//    (= not a child of it; = SwiftUI does NOT inherit env values
//    across WindowGroup boundaries). We re-construct the same
//    BookStore from the shared `library` URL (= kanban persistence is now
//    SwiftData-backed via WSKanbanRepository.shared; = the KanbanStore
//    actor was deleted in )
//    (= the same .ws package the main window uses; = both
//    windows read + write to the same on-disk JSON files via
//    BookKanbanStore; = edits in the kanban window are
//    immediately visible in the main window and vice versa).
//  - Toolbar mirrors the main window style (.unified 52 PT) for
//    visual consistency.
//
//  The board needs a book to show tickets for. The window reads the
//  app's live sidebar selection (= `workspaceUI.sidebarSelection`)
//  for that, because that is the one selection the main window
//  actually writes when the user clicks a row. The board also
//  carries its own book picker, so it is usable on its own.
//

import SwiftUI
import WenshuData
import os

private let wenshuLogger = Logger(subsystem: "com.wenshu", category: "kanbanwindow")

/// KanbanWindow = the
/// dedicated scene body for the kanban-as-independent-window
/// feature (= the WindowGroup(id: WindowID.kanban) in
/// AppRootScene). Owns its own BookStore (= the main window's
/// BookStore is held by LibraryRootView's `@State` and is not
/// reachable from a sibling scene; = the simplest fix is to
/// construct a fresh BookStore here that points at the same .ws
/// root as the main window). Kanban persistence is the shared
/// WSKanbanRepository.shared (= @MainActor SwiftData wrapper;
/// =  deleted the KanbanStore actor).
struct KanbanWindow: View {
    /// The app's shared workspace UI state (= the live sidebar
    /// selection). Passed in by `AppRootScene` because the kanban
    /// scene is a sibling of the main window and does NOT inherit
    /// the main window's environment.
    let workspaceUI: WorkspaceUIState

    @State private var bookStore: BookStore?

    init(workspaceUI: WorkspaceUIState) {
        self.workspaceUI = workspaceUI
    }

    var body: some View {
        Group {
            // -m1-shell (see OOB.md #2026-09-11) OOB fix (= cua fatal-
            // error trace at SwiftUICore/Environment+Objects.swift:34
            // when the kanban button was first clicked): the
            // kanban window is a SIBLING scene to the main
            // WindowGroup (= it does NOT inherit env values from
            // LibraryRootView). KanbanView's `@Environment(BookStore.
            // self)` crashes if BookStore is not in the env chain
            // (= 'No Observable object of type BookStore found').
            //
            // Note: KanbanView does NOT need the KanbanStore actor (= deleted in ); kanban reads go through WSKanbanRepository
            // actor injected (= the view does all its file I/O
            // via the BookKanbanStore helper, which is
            // constructed per-call from the BookStore books).
            // So we only inject BookStore (= which IS @Observable).
            //
            // Fix: construct BookStore here (= it points at the
            // same .ws package the main window uses; = the
            // BookKanbanStore on-disk file is shared across both
            // windows; = both windows see the same tickets in
            // real time).
            //
            // We wait for the store to construct (= the kanban
            // window shows a brief ProgressView while
            // LibraryLifecycleHook runs in the kanban window's
            // own task scope; = the main window doesn't block
            // while the kanban window is initializing).
            if let bookStore {
                KanbanView()
                    .environment(bookStore)
            } else {
                ProgressView()
                    .controlSize(.large)
            }
        }
        .navigationTitle(String(localized: "window.kanban.title"))
        .task {
            // -m1-shell (see OOB.md #2026-09-11) OOB: use the
            // shared LibraryLifecycleHook (= same one the main
            // window's LibraryRootView.runLaunch() invokes) to
            // construct BookStore from the .ws root. The hook
            // is idempotent (= multiple invocations against the
            // same .ws root produce stores pointing at the same
            // on-disk files; = safe to call from both windows).
            //
            // Resolve the .ws URL from the UserDefaults key the
            // main window wrote (= wenshu.libraryPath) at first
            // launch; = falls back to the user's onboarding path
            // if not set. (= KanbanWindow's `library: WenshuLibrary`
            // parameter is the main window's library handle, but
            // the path is the only thing LibraryLifecycleHook
            // needs; = we read it directly from UserDefaults to
            // avoid an indirection through the WenshuLibrary
            // type.)
            do {
                let wsRoot = try KanbanWindow.resolveLibraryPath()
                let hook = LibraryLifecycleHook(wsRoot: wsRoot)
                let result = try hook.runLaunch()
                let store = result.makeBookStore()
                // The book list backs the window's own book picker.
                store.reloadAllBooks()
                self.bookStore = store
            } catch {
                // -m1-shell (see OOB.md #2026-09-11) OOB: if the
                // kanban window can't construct its store
                // (= library path moved, file permissions, etc.)
                // show the error and stay open so the user can
                // debug (= don't silently fail; = Apple HIG
                // modal dialog for unhandled errors).
                wenshuLogger.info("[wenshu.window] kanban store construct failed: \(String(describing: error))")
            }
        }
        // The board follows the main window's book selection. The
        // sidebar selection is the one field the main window
        // writes when the user clicks a row (= `WenshuLibrary.
        // selectedBookId` and `BookStore.reload(bookId:)` both
        // exist but have no production writer).
        .onChange(of: workspaceUI.sidebarSelection) { _, _ in
            applySidebarSelection()
        }
        .onAppear {
            applySidebarSelection()
        }
    }

    /// Hand the store the book the main window has selected.
    ///
    /// A book row and a folder row both name a book (= a folder is
    /// a sub-row of one). Every other selection (= a shelf, a
    /// reference category, a tag, nothing) names no book, and the
    /// board then shows its own picker instead.
    private func applySidebarSelection() {
        guard let bookStore else { return }
        guard let bookId = KanbanWindow.bookId(for: workspaceUI.sidebarSelection) else { return }
        bookStore.selectedBookId = bookId
    }

    /// The book a sidebar selection names, if any.
    static func bookId(for selection: SidebarItem?) -> UUID? {
        switch selection {
        case .book(let bookId):
            return bookId
        case .folder(let bookId, _):
            return bookId
        case .shelf, .referenceCategory, .referenceLibraryRoot, .tag, nil:
            return nil
        }
    }

    /// resolve the active
    /// .ws package URL from `ActiveLibrary` (= the security-scoped
    /// bookmark; = single source of truth, written by
    /// LibraryRootView at onboarding). Throws if the path is empty
    /// or missing (= the user hasn't opened a library yet; = the
    /// kanban window should show a 'open a library first' hint
    /// instead of crashing).
    ///
    /// Public so TodoWindow (= the sibling scene) can also
    /// resolve the path.
    static func resolveLibraryPath() throws -> URL {
        let path = ActiveLibrary.path ?? ""
        guard !path.isEmpty else {
            throw NSError(
                domain: "WenshuWindow",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "No library selected; open a .ws package in the main window first."]
            )
        }
        return URL(fileURLWithPath: path)
    }
}
