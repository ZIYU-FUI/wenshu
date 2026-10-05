// Sources/WenshuApp/Views/Workspace/TabContentDispatcher.swift
//
// Dispatches a `TabKind` (= .projectSidebar / .projectPreview /
// .editor / .specializedTools / .aiChat / .aiDynamic) to the
// correct zone view. Reads `AppState` + `BookStore` from
// `@Environment` (= no `@Binding` chain; = the cross-zone
// communication path).
//
// The recursive `PaneRenderer` dispatches tabs through this shim;

import SwiftUI


struct TabContentDispatcher: View {
    let kind: TabKind
    let title: String

    /// (= option A =
    /// global @Observable store). TabContentDispatcher reads
    /// AppState directly via @Environment (= no @Binding chain).

    // (see OOB.md #2026-08-31) (sidebar feedback bundle #3): bottom status
    // ': N /: N' was hardcoded to 0. Now reads live counts
    // from BookStore (= the Environment value already propagated
    // from App.swift via .environment(bookStore)).
    @Environment(BookStore.self) private var bookStore

    /// (= option A =
    /// global @Observable store). TabContentDispatcher reads sidebar
    /// selection directly from AppState (= no @Binding chain).
    @Environment(AppState.self) private var appState

    // 
    // The chat-zone tab-bar wrapper (= the since-deleted wrapper that
    // previously held the chat top tab bar inside `PaneRenderer`) was
    // deleted. The state and namespace it owned (= archive-confirm
    // dialog state + per-instance SwiftUI namespace for the
    // matchedGeometryEffect underline) are now owned by
    // TabContentDispatcher directly (= single source of truth for chat
    // zone top chrome). Migration path: see commit a6b6c75d3's "top-bar
    // chrome flattening" section.
    @State private var showingArchiveConfirm: Bool = false
    @Namespace private var chatTabBarNamespace

    // (= (see OOB.md #2026-09-02) follow-up to B-14): the chrome bottom
    // status now reads ": 0 / N" (= replaces the legacy "N%"
    // progress placeholder). BacklinksViewModel lives here too (= own
    // loader for the chrome status; EditorView holds its own
    // copy for the popover content. Slight redundancy vs single source
    // of truth, but matches the existing zone-level loader pattern
    // and avoids threading the popover's @State through the chrome
    // hierarchy. The two loaders read the same BacklinkResolver, so
    // backlinks.count stays in sync).
    @State private var backlinksVM = BacklinksViewModel()
    @State private var backlinksCount: Int = 0
    // popover state for the chrome bottom-right " 0" button.
    // When the user taps the chrome bottom right text (= rendered as a
    // clickable Button by PaneStatusBar when rightOnTap is non-nil),
    // showBacklinksPopover flips true and a .popover with the full
    // BacklinksPanel renders anchored at the chrome bottom edge.
    @State private var showBacklinksPopover: Bool = false

    var body: some View {
        switch kind {
        case .projectSidebar:
            // Top chrome = the pane's internal PaneTabBar. Single
            // layer per pane (= no double chrome wrappers).
            PaneView(zoneSlot: .projectSidebar)

        case .projectPreview:
            // Same: no outer top toolbar (= internal PaneTabBar
            // IS the top chrome).
            PaneView(zoneSlot: .projectPreview)

        case .editor:
            // No outer top (= internal PaneTabBar for edit / outline
            // IS the top chrome). Bottom status = backlinks count
            // (= replaced the legacy "N%" progress text per
            // spec v0.34 B-15).
            PaneView(zoneSlot: .editor)

            // trigger backlinks load on first appear.
            // .task runs once when the editor zone is mounted (= won't
            // re-fetch on every re-render; = Apple HIG async task lifecycle).
            .task {
                await backlinksVM.load(docId: "preview-sample")
                backlinksCount = backlinksVM.backlinks.count
            }
            // BacklinksPanel popover, anchored to the chrome
            // bottom-right (= the " 0" button). Apple HIG
            // non-modal popover for contextual reference info.
            // 320x280 PT = standard inspector popover footprint.
            .popover(isPresented: $showBacklinksPopover, arrowEdge: .bottom) {
                BacklinksPanel(viewModel: backlinksVM)
                    .frame(width: DesignTokens.popoverCompactSize.width, height: DesignTokens.popoverCompactSize.height)
                    .padding(DesignTokens.spacingStandard)
            }
        case .specializedTools:
            // No outer top (= internal PaneTabBar IS the top chrome).
            PaneView(zoneSlot: .specializedTools)

        case .aiChat:
            // ChatView + PaneTabBar for the single chat tab.
            // No wrapper layer (= the PaneTabBar is mounted
            // directly here, in this dispatch branch).
            ChatView()
                    .safeAreaInset(edge: .top, spacing: 0) {
                        // safeAreaInset adds a view above the ChatView
                        // (= the top chrome) without ChatView needing to
                        // know about it. Matches macOS 26 Tahoe pattern
                        // (= content area + small top inset for tab bar).
                        //
                        // use PaneTabBar directly
                        // (= no chat-zone wrapper layer). Single
                        // hard-coded chat tab item + archive trailing button
                        // (= migrated to PaneTrailingIconButton helper from
                        // commit dcde7cff5). namespaceID stays as
                        // "chatTabUnderline" so the matchedGeometryEffect
                        // anchor remains unique across the workspace.
                        PaneTabBar(
                            items: [PaneTabItem(id: "chat", icon: "bot", label: "对话")],
                            selection: .constant("chat"),
                            namespace: chatTabBarNamespace,
                            namespaceID: "chatTabUnderline",
                            trailing: {
                                PaneTrailingIconButton(
                                    icon: "inbox",
                                    tooltip: "归档本次会话",
                                    action: { showingArchiveConfirm = true }
                                )
                            }
                        )
                    }

        case .aiDynamic:
            // No outer top (= internal DynamicZoneTabBar for progress /
            // / search IS the top chrome). Just the bottom kanban
            // status text.
            
                PaneView(zoneSlot: .aiDynamic)

        }
    }
}

// MARK: - Environment value for the tab dispatcher (kept for future use)
//
// We previously carried the dispatcher as an environment-injected
// closure (= see git history of this file); Swift 6's concurrency
// checker rejected it because AnyView is not Sendable. The current
// implementation switches on TabKind directly inside the view. If
// future tickets need pluggable view resolution (= e.g. for tests
// or alternate renderers), they can reintroduce a Sendable wrapper
// here — for now, the direct switch is sufficient and matches the
// WorkspaceView.renderTabByKind behavior 1:1.

// (GroupTabStrip removed 2026-10-05 in dead-code-sweep-2026-10-05 batch —
//  verify-dead.py strict-context grep confirmed 0 wenshu callers across
//  Sources/ + Tests/; = the View struct was a horizontal tab strip
//  designed for the FCP Browser / VS Code group-with-multiple-panes
//  pattern but the current LayoutTreeStore model only emits
//  single-pane groups (= no pane-split affordance ships to users
//  today); = the struct was never instantiated; = its drag-reorder +
//  per-pane close logic has no current consumer; = the design is
//  preserved as a breadcrumb so a future pane-split ticket can
//  resurrect it from git history if needed. See
//  wenshu-dead-code-cleanup SKILL.md.)
