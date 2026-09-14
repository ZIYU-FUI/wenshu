//
//  TodoWindow.swift · Wenshu · v1.0.0-m1-shell boss 2026-09-11 OOB
//
//  Todo as an independent macOS window (= the SwiftUI macOS 14+
//  WindowGroup(id: "wenshu-todo") per boss 2026-09-11 OOB
//  '看板和待办, 独立的窗口显示'. Companion to KanbanWindow;
//  same multi-window pattern (= Pages / Numbers / Keynote /
//  Photos / Mail each open independent surfaces in their own
//  windows so the user can keep the todo list pinned to the
//  side of the screen while editing).
//
//  Window composition:
//  - TodoListView (= the existing todo list view, takes the
//    full window body; = no extra NavigationSplitView chrome
//    since the window IS the todo list).
//  - The todo window is a SIBLING scene to the main WindowGroup
//    (= SwiftUI does NOT inherit env values across WindowGroup
//    boundaries). We re-construct the BookStore + TodoStore
//    here from the shared `library` URL (= same .ws package
//    the main window uses; = the BookTodoStore on-disk file
//    is shared; = both windows see the same todos in real
//    time).
//

import SwiftUI

/// v1.0.0-m1-shell boss 2026-09-11 OOB: TodoWindow = the
/// dedicated scene body for the todo-as-independent-window
/// feature (= the WindowGroup(id: WindowID.todo) in
/// AppRootScene). Owns its own BookStore + TodoStore (= the
/// main window's BookStore is held by LibraryRootView's
/// `@State` and is not reachable from a sibling scene; = the
/// simplest fix is to construct a fresh BookStore (= TodoStore actor
/// was deleted in Phase 5 ticket 7; todo persistence is
/// WSTodoRepository.shared)
/// here that points at the same .ws root as the main window).
public struct TodoWindow: View {
    let library: WenshuLibrary

    @State private var bookStore: BookStore?

    init(library: WenshuLibrary) {
        self.library = library
    }

    public var body: some View {
        Group {
            // See KanbanWindow for the env-chain fix rationale.
            // (= the todo window is a SIBLING scene to the
            // main WindowGroup; = TodoListView's
            // `@Environment(BookStore.self)` lookup crashes
            // without an explicit `.environment(bookStore)`;
            // = TodoListView does all file I/O via BookTodoStore
            // helper, so we only inject BookStore).
            if let bookStore {
                TodoListView()
                    .environment(bookStore)
            } else {
                ProgressView()
                    .controlSize(.large)
            }
        }
        .navigationTitle(WenshuI18n.t("window.todo.title"))
        .task {
            do {
                let wsRoot = try KanbanWindow.resolveLibraryPath()
                let hook = LibraryLifecycleHook(wsRoot: wsRoot)
                let result = try hook.runLaunch()
                self.bookStore = result.makeBookStore()
            } catch {
                NSLog("[wenshu.window] todo store construct failed: %@", String(describing: error))
            }
        }
    }
}