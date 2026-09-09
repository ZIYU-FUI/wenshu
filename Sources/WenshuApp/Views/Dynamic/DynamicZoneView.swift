//
// DynamicZoneView.swift · Wenshu · v0.24 bossverification + v0.41 WIRE-OPENBOX-001
//
// Boss 2026-08-24: dynamic zone shouldyes tab (chat zone ChatZoneTabBar),
// shouldyes sheet (sheet, tab).
//
//  Tab order (per boss 8/24 explicit feedback):
// - tab1: task (Todo) — TodoListView (h07)
// - tab2: progress (Sub-agent progress) — SubAgentProgressView
// - tab3: search (Search) — SearchPanel (o06)
//
// Per AGENTS.md §12 in progress, tab labels in progress.
//
//  v0.41 WIRE-OPENBOX-001 (P2 #21): agent progress panel added at the
//  top of the zone (= below the tab bar, above the kanban/todo body).
//  Reads from `AgentProgressTracker.shared` (= written by
//  ConversationLoop). Only renders when a turn is currently in flight.
//

import SwiftUI
import Lucide

/// DynamicZoneView: body. 3 tabs (task / progress / search) + Apple HIG TabBar pattern
/// (ChatZoneTabBar: top bar SF Symbol + .accentColor in progress).
struct DynamicZoneView: View {
    enum DynamicTab: String, CaseIterable, Identifiable {
        // v0.24 bossverificationfix (2026-08-24 OOB): Boss 'yeskanban, change
        // ' = dynamic zone should be kanban (kanban), not progress (debug).
        // Per boss 8/24 'dynamic zone change 2 tab' = kanban + only.
        // Hide: progress (debug feature) + search (per 5c9ef2ee6 + chat zone pattern).
        case kanban = "看板"
        case todo = "待办"
        var id: String { rawValue }
        var label: String { rawValue }
        var icon: String {
            switch self {
            // v0.25.1 (= ticket 022 dynamic zone tab icons): owner
            // 2026-08-26 OOB teb: teb1 -> layout-grid, teb2 -> layout-list
            // layout-grid teb2 layout-list' = SF rectangle.split.3x1
            // → Lucide layout-grid (= 4-cell grid icon, kanban board
            // visual metaphor). SF checklist → Lucide layout-list
            // (= row-based list icon, list visual metaphor).
            case .kanban: return "layout-grid"
            case .todo: return "layout-list"
            }
        }
    }

    // v0.24 bossverificationfix: persist tab selection across launches.
// v0.40 apple-001 HIG absent batch: migrated wenshu.tabIndex.aiDynamic
// from @AppStorage to @SceneStorage (= Apple HIG macOS 14+ per-window
// tab state restoration). Each window has its own active dynamic
// tab (= user can have Chat tab in one window + Kanban tab in another).
    @SceneStorage("wenshu.tabIndex.aiDynamic") private var selectedTabRaw: String = "看板"

    private var selectedTab: DynamicTab {
        get { DynamicTab(rawValue: selectedTabRaw) ?? .kanban }
        nonmutating set { selectedTabRaw = newValue.rawValue }
    }

    // v0.36 ticket 013 sub-step 3: 🟨 half-visible right-bottom panel
    // per spec §6.4. MemoryRetrievalPanel = ticket 009 canonical
    // (= per ticket 013 sub-step 1 we deleted the duplicate
    // DynamicZoneMemoryPanel + its test). Activation here is a
    // safe append-only patch (= preserves v0.34 in-flight ship sequence).
    @State private var memoryEntries: [MemoryAdapter.MemoryEntry] = []

    var body: some View {
        // v0.30 boss 8/31 OOB: alignment: .leading so the top tab bar
        // (= DynamicZoneTabBar) is left-aligned instead of default
        // center-aligned (= SwiftUI VStack defaults to .center). Boss
        // spec: " teb iconchange" = the dynamic zone tabs should
        // sit at the left edge (= 18 PT padding from pane left) like
        // every other zone's top bar.
        VStack(alignment: .leading, spacing: 0) {
            DynamicZoneTabBar(selectedTab: Binding(
                get: { selectedTab },
                set: { selectedTab = $0 }
            ))
            // WIRE-OPENBOX-001 (v0.41 P2 #21): agent progress panel.
            // Top-of-zone strip that surfaces real-time step-by-step
            // feedback from the running ConversationLoop turn. Only
            // renders when an entry is currently running (= user just
            // sent a message; loop is in flight). Hidden when idle.
            AgentProgressPanel()
            Group {
                switch selectedTab {
                case .kanban:
                    KanbanView()
                case .todo:
                    TodoListView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.default, value: selectedTab)

            // v0.36 ticket 013 sub-step 3: MemoryRetrievalPanel
            // (= ticket 009 canonical) as right-bottom panel per spec §6.4
            // 🟨 half-visible. The panel is always rendered at the bottom
            // of the DynamicZone (= memory preview is global to all tabs).
            MemoryRetrievalPanel(entries: memoryEntries)
                .frame(height: DesignTokens.cardPreviewHeight)
                .padding(.horizontal, DesignTokens.chromePaddingLeading)
                .padding(.bottom, DesignTokens.chromePaddingVertical)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)  // prevent window shrink
        // v0.40 boss 2026-09-09 OOB 'Plan A: full Apple native': removed
        // .regionContentBackground() (= per Plan A = the pane
        // relies on NavigationSplitView's built-in Liquid Glass
        // material = no custom per-pane background paint). The
        // previous .ultraThinMaterial / RegionContentBackground
        // double-layer was the source of 'Liquid Glasseffect
        // ' = per Apple's WWDC25-219 'Liquid Glass is
        // composed of a number of layers that work together' =
        // removing the custom layer lets Apple's native material
        // flow uniformly across all 6 zones.
        .onAppear { loadRecentMemory() }
    }

    /// Load recent memory entries (= stub; real impl = MemoryManager.prefetch
    /// from ticket 009 canonical adapter). v0.36 ships empty list; future
    /// ticket wires the full adapter.
    private func loadRecentMemory() {
        // No-op for v0.36 (= MemoryAdapter.prefetch returns empty when no
        // bookStore is available; see ticket 009 sub-step 1+2 for real impl).
    }
}

/// DynamicZoneTabBar: top bar 3 SF Symbol tab + in progress .accentColor (ChatZoneTabBar)
struct DynamicZoneTabBar: View {
    @Binding var selectedTab: DynamicZoneView.DynamicTab
    // v0.25.1 (= ticket 013 underline slide animation): matchedGeometry
    // namespace for the shared underline (= PaneTabBar handles the
    // .matchedGeometryEffect internally). One namespace per tab bar
    // class (= SwiftUI requires the namespace to scope within a single
    // view tree).
    @Namespace private var tabBarNamespace

    var body: some View {
        // v0.28 followup Boss UX round A (Phase 3 of refactor): DynamicZoneTabBar
        // body now delegates to `PaneTabBar` generic component (= ComponentIndex.md
        // Level 3.2). Was 135 LOC, now ~10 LOC. Behavior preserved 1:1.
        //
        // v0.40 boss 2026-09-09 OOB 'macOS 27 official API + segmented picker':
        // replaced the previous PaneTabBar (= custom icon tab bar) with
        // Apple's canonical Picker(...).pickerStyle(.segmented). Per
        // WWDC25-323 'Build a SwiftUI app with the new design' (= the
        // official macOS 27 sample code for tab-style view switching
        // in a column). The kanban zone has 2 tabs (= perfect for
        // segmented picker = 2-5 segments = canonical Apple range).
        // No more custom matchedGeometryEffect / no custom PaneTabBar
        // wrapper needed (= Apple handles the selection animation).
        Picker(
            String(localized: "View", defaultValue: "View"),
            selection: Binding(
                get: { selectedTab.id },
                set: { newId in
                    if let newTab = DynamicZoneView.DynamicTab(rawValue: newId) {
                        selectedTab = newTab
                    }
                }
            )
        ) {
            ForEach(DynamicZoneView.DynamicTab.allCases) { tab in
                Label(tab.label, systemImage: tab.icon).tag(tab.id)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }
}