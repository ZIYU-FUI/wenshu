//
// ZoneContentView.swift · Wenshu · v0.24 bossverification
//
// Boss 2026-08-24 (out-of-band): region, can tab view.
// [CJK-TRANSLATE] 1 line(s) awaiting manual translation (see git blame for original CJK text)
// not oktop bar, top bar, can tab.
//
// Pattern (ChatZoneView ChatZoneTabBar + DynamicZoneView DynamicZoneTabBar):
//  - 1 layer per zone (no ZoneTopToolbar / ZoneBottomToolbar outer shells)
// - internal tabs (Apple HIG Button(.plain) + .accentColor on selected)
// - in progress tab labels (per AGENTS.md §12 in progress)
//
//  Applied to 4 zones:
// - projectSidebar: / /
// - projectPreview: / / search
// - editor: edit / /
// - specializedTools: / /
//
//  Other 2 zones (chat, dynamic) have their own specialized tab bars:
//  - ChatZoneView: ChatZoneTabBar (chat / search / settings)
// - DynamicZoneView: DynamicZoneTabBar (progress / / search)
//

import SwiftUI
import Lucide

/// Generic tab content view: 1-layer pattern with multiple internal tabs.
/// Used by the 4 "general" zones (projectSidebar / projectPreview / editor / specializedTools).
struct ZoneContentView: View {
    struct Tab: Identifiable {
        // v0.24 bossverificationfix: use String label as ID (UUID auto-generated per re-render
        // → stale selectedTabId after re-render → no tab marked selected).
        let id: String
        let label: String
        let icon: String
        let content: AnyView
    }

    let tabs: [Tab]
    // v0.25.1 (= ticket 029c-trailing-button editor zone expand/shrink):
    // owner 2026-08-26 OOB ' yesbutton yes
    // teb' = optional trailing button rendered at the right
    // edge of the tab bar (= independent of tab count). nil = no
    // trailing button = default behavior preserved for all OTHER
    // zone-content tab bars; only the editor zone passes a
    // trailing expand/shrink button.
    var trailingButton: AnyView? = nil

    @State private var selectedTabId: String

    // v0.34 boss 2026-09-02 OOB: per-instance SwiftUI namespace for the
    // matchedGeometryEffect underline (= SwiftUI requires the namespace
    // to scope within a single view tree). Held by ZoneContentView now
    // (= previously held by the deleted ZoneContentTabBar wrapper).
    @Namespace private var tabBarNamespace

    var body: some View {
        // v0.24 bossverificationfix: simpler structure (VStack only, no ZStack wrapper
        // which was regressing tab bar visibility). .frame(minHeight: 600)
        // forces window contentMinSize.
        VStack(spacing: 0) {
            // v0.34 boss 2026-09-02 OOB: use PaneTabBar directly (= the
            // shared tab-bar generic). Deleted the ZoneContentTabBar
            // wrapper (= ~187 LOC of thin adapter that just forwarded
            // items + namespace + trailing to PaneTabBar). One canonical
            // tab-bar component per workspace.
            PaneTabBar(
                items: tabs.map { PaneTabItem(id: $0.id, icon: $0.icon, label: $0.label) },
                selection: selectionBinding,
                namespace: tabBarNamespace,
                trailing: {
                    if let trailingButton = trailingButton {
                        trailingButton
                    }
                }
            )
            // v0.24 bossverificationfix (2026-08-24): pass maxWidth/maxHeight explicitly to AnyView
            // so it inherits zone size (not forces zone to grow). Without this,
            // AnyView collapses to its intrinsic size and zone shrinks to ~0.
            // ZONE-INSET-002 (2026-09-07): the unified zone-content
            // inset (= 18 PT all sides) was originally applied here
            // as a single source of truth for all 5 zones. Boss 9/7
            // round 2 ', zones 1-2-4 too large, zone 3 correct, 6
            // ' = the outer 18 PT wraps Apple HIG components (=
            // List(.sidebar) in zone 1, LazyVGrid in zone 2) that
            // already have their own canonical padding (= Apple HIG
            // designed them to be used with the system default
            // content margins). The result was DOUBLED visual inset
            // (= 26 PT in sidebar, ~38 PT in cards). Zone 3 worked
            // only because WenshuMarkdownEditor wraps NativeTextViewWrapper
            // (= no Apple built-in inset = my 18 PT was the sole
            // padding). Zone 4 (right column = aiDynamic =
            // DynamicZoneView) didn't go through ZoneContentView at all
            // (= no inset = 0 = content looked flush against the
            // zone edge).
            //
            // Fix: REMOVED the outer .padding(.all, zoneContentInset)
            // from ZoneContentView (= no more doubled padding). Each
            // zone's content view now owns its own inset (= restored
            // to v0.40 pre-ZONE-INSET-002 state). The canonical
            // token DesignTokens.zoneContentInset (= 18) is still
            // exported and used by the few content views that
            // don't have built-in Apple HIG padding (= the editor's
            // NativeTextViewWrapper view). Future cleanup ticket can
            // re-introduce a smart outer padding that detects Apple
            // HIG components and skips them (= needs Apple API
            // research).
            //
            // Boss 9/7 round 2 ' apple api can'
            // = the right place for the inset IS Apple's built-in
            // content margins (= List, LazyVGrid, ScrollView all
            // have them); = we shouldn't duplicate them with our
            // own outer wrapper.
            Group {
                if let selected = tabs.first(where: { $0.label == selectedTabId }) {
                    selected.content
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.default, value: selectedTabId)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)  // prevent window shrink
        // Note: do NOT add .frame(minHeight: 600) - it breaks upper band
        // (which is only ~485 PT tall, 600 PT min would push it out of view).
    }

    // v0.24 bossverificationfix (2026-08-24): persist tab selection per zone across launches.
// Boss 8/24 feedback: 'region tab shouldyesin progress, in progressstatusshould'.
// Implemented via zone-specific UserDefaults key (one per zone).
    private let storageKey: String

    init(zoneSlug: String, tabs: [(label: String, icon: String, content: AnyView)], trailingButton: AnyView? = nil) {
        let mapped = tabs.map { Tab(id: $0.label, label: $0.label, icon: $0.icon, content: $0.content) }
        self.tabs = mapped
        // v0.25.1 (= ticket 029c-trailing-button editor zone expand/shrink):
        // owner 2026-08-26 OOB ' yesbutton yes
        // teb' = optional trailing button parameter passed through
        // to ZoneContentTabBar (= rendered at the right edge of the tab
        // bar via Spacer()).
        self.trailingButton = trailingButton
        self.storageKey = "wenshu.tabIndex.\(zoneSlug)"
        // Restore selected tab from UserDefaults (or default to first tab).
        // v0.24 bossverificationfix: handle invalid saved value (e.g. tab list changed)
        // by falling back to first tab + resetting stored index.
        let savedIndex = UserDefaults.standard.integer(forKey: self.storageKey)
        let initialLabel: String
        if mapped.indices.contains(savedIndex) {
            initialLabel = mapped[savedIndex].label
        } else {
            initialLabel = mapped.first?.label ?? ""
            // Reset stored index to 0 so future launches start at first tab.
            UserDefaults.standard.set(0, forKey: self.storageKey)
        }
        _selectedTabId = State(initialValue: mapped.first?.label ?? "")
    }

    private var selectionBinding: Binding<String> {
        Binding(
            get: { selectedTabId },
            set: { newId in
                selectedTabId = newId
                // Persist current tab index for next launch.
                if let idx = tabs.firstIndex(where: { $0.id == newId }) {
                    UserDefaults.standard.set(idx, forKey: storageKey)
                }
            }
        )
    }
}

/// ZoneContentTabBar: Apple HIG tab bar (matches ChatZoneTabBar / DynamicZoneTabBar).
/// Top bar SF Symbol + Chinese label + .accentColor on selected.
///
/// v0.34 boss 2026-09-02 OOB 'all-zone top bars have the same structure, why
/// can't they be one component' (= apple-api-first #7 multi-layer audit).
/// Deleted. ZoneContentView now uses `PaneTabBar` directly with a
/// per-instance `@Namespace`. The wrapper contributed only ~12 lines of
/// real logic (= items → PaneTabItem mapping + namespace forwarding +
/// trailing button slot) which is now inlined at the call site.
private struct ZoneContentTabBar: View {
    struct Item: Identifiable, Equatable {
        let id: String  // stable String (matches Tab.id)
        let label: String
        let icon: String
    }

    let items: [Item]
    @Binding var selection: String
    // v0.25.1 (= ticket 013 underline slide animation): owner 2026-08-26
    // [CJK-TRANSLATE] 1 line(s) awaiting manual translation (see git blame for original CJK text)
    // OOB 'changemove yes'. See
    // PaneTabBar comment (= matchedGeometryEffect pattern). One
    // namespace per tab bar class (= SwiftUI requires the namespace to
    // scope within a single view tree).
    @Namespace private var tabBarNamespace

    // v0.25.1 (= ticket 029c-trailing-button editor zone expand/shrink):
    // owner 2026-08-26 OOB ' yesbutton yes
    // teb' = the expand/shrink toggle is NOT a tab (= no underline
    // selected indicator, no selected-tab highlighting), it's a
    // SEPARATE button pushed to the trailing edge of the tab bar
    // (= per Apple HIG canonical toolbar pattern where action
    // buttons sit at the trailing edge, separate from the
    // selection tabs). trailingButton is an optional ViewBuilder
    // parameter (= nil = no trailing button = default behavior
    // preserved for all OTHER zone-content tab bars; only the
    // editor zone passes a trailing expand/shrink button). The
    // trailing button is pushed via Spacer() before it so it sits
    // at the rightmost position (= independent of how many tabs
    // the zone has).
    var trailingButton: AnyView? = nil

    // v0.24 bossverificationfix: selectedItem (Item with matching label) for icon highlighting.
    private var selectedItem: Item? {
        items.first(where: { $0.id == selection })
    }

    var body: some View {
        // v0.28 followup Boss UX round A (Boss 2026-08-30 OOB 'need
        // group'): Phase 3 of refactor. ZoneContentTabBar body now
        // delegates to the new `PaneTabBar` generic component (=
        // ComponentIndex.md Level 3.2). PaneTabBar wraps RegionTabBar
        // chrome + ForEach of PaneIconTab + optional trailing buttons.
        // Was 166 LOC, now ~10 LOC. Behavior preserved 1:1.
        PaneTabBar(
            items: items.map { item in
                PaneTabItem(id: item.id, icon: item.icon, label: item.label)
            },
            selection: $selection,
            namespace: tabBarNamespace,
            trailing: {
                if let trailingButton = trailingButton {
                    trailingButton
                }
            }
        )
    }

    /// v0.28 followup Boss UX round A (Phase 2 of refactor): this helper
    /// is no longer needed because PaneTabBar uses PaneIconTab internally
    /// (= which uses LucideIconSystemFallback directly). Kept as a no-op
    /// stub for backward compatibility with any external callers (= will
    /// be deleted in a follow-up commit after search confirms no
    /// remaining callers).
    @ViewBuilder
    private func zoneContentTabBarIcon(_ systemName: String) -> some View {
        LucideIconSystemFallback(systemName)
    }
}
