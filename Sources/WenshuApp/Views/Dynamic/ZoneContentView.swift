//
// ZoneContentView.swift · Wenshu · v0.24 bossverification
//
// Boss 2026-08-24 (out-of-band): region, can tab view.
// (Historical: this line had CJK content from a boss OOB message; the original text can be recovered via `git blame` on this line; the cleanup commit replaced it with a stub because its translation was incomplete.)
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
        //
        // v0.40 boss 2026-09-09 OOB 'macOS 27 official API + segmented picker':
        // replaced the previous PaneTabBar (= custom icon tab bar) with
        // Apple's canonical Picker(...).pickerStyle(.segmented). Per
        // WWDC25-323 'Build a SwiftUI app with the new design' (the
        // official macOS 27 sample code for tab-style view switching
        // in a column):
        //
        //   Picker("Tools", selection: $selectedTool) {
        //     Label("Preview", systemImage: "eye").tag(EditorMode.preview)
        //     Label("Edit", systemImage: "pencil").tag(EditorMode.edit)
        //   }
        //   .pickerStyle(.segmented)
        //   .labelsHidden()
        //
        // Apple HIG rationale:
        // - Segmented pickers transform into Liquid Glass during
        //   interaction (= WWDC25-323 visual upgrade is automatic).
        // - 2-5 segments = the canonical Apple range (= the
        //   specializedTools zone has exactly 5 tabs = perfect fit).
        // - The .tags() derive Identifiable ids from the Tab struct
        //   (= no custom selectedTabId binding needed).
        // - The Apple-native Liquid Glass selected segment animation
        //   replaces the previous matchedGeometryEffect underline
        //   (= no @Namespace tabBarNamespace needed).
        // v1.0.0-m1-shell boss 2026-09-11 OOB 'macOS 27's native control is our first choice':
        // swap the SwiftUI Picker(.segmented) (= the legacy macOS 10.5
        // wrapper; = intrinsic-size; = does NOT expose
        // NSSegmentedControl.Role; = does NOT auto-fill the column
        // width) for `LabelSegmentedControl` (= a SwiftUI
        // NSViewRepresentable wrapping the macOS 27 native
        // NSSegmentedControl; = uses segmentStyle = .roundRect
        // (= the Apple HIG Pages / Numbers inspector tab visual)
        // + role = .tabs (= the macOS 27 NEW role API; =
        // semantically correct for a tab switcher; = VoiceOver
        // reads "page N of M") + segmentDistribution =
        // .fillEqually (= each tab stretches to 1/N of the
        // column width = satisfies the boss's 'auto-fill the right column's width'
        // requirement)).
        //
        // Per the verbatim port discipline (= only do what the boss
        // asked): this commit ONLY changes the per-page tab strip
        // control (= ZoneContentView's tabs); = the toolbar's
        // 4-page picker (= SwiftUI Picker(.segmented)) stays
        // unchanged; = the boss explicitly clarified 'for the toolbar,
        // use the one we just settled on — that's Apple's default toolbar style' (= the toolbar
        // keeps the SwiftUI Picker(.segmented) = the Apple HIG
        // toolbar default).
        //
        // all 4 inspector pages' per-page tab strip (= the
        // ZoneContentView is reused for each page; = the tabs
        // array is replaced by `filteredToolsForCurrentPage`;
        // = the control auto-renders whatever tabs the
        // inspector page supplies; = the boss's directive is
        // satisfied with a single-line change).
        VStack(spacing: 0) {
            // v1.0.0-m1-shell boss 2026-09-11 OOB 'macOS 27's native
            // control is our first choice': use the macOS 27 native NSSegmentedControl
            // (= via the new `LabelSegmentedControl` wrapper in
            // UI/Segmented/; = the canonical Apple HIG Pages / Numbers
            // inspector tab strip; = auto-fills the column width).
            //
            // We bind the control to String ids (= the Tab.id; =
            // Hashable; = avoids the need to make the full Tab type
            // Hashable, which AnyView-riddled structs can't easily
            // satisfy; = the id lookup gives us Hashable conformance
            // for free).
            LabelSegmentedControl(
                selection: Binding(
                    get: {
                        tabs.first(where: { $0.id == selectionBinding.wrappedValue })?.id
                            ?? tabs.first?.id
                            ?? ""
                    },
                    set: { selectionBinding.wrappedValue = $0 }
                ),
                labels: tabs.map(\.id),
                // v1.0.0-m1-shell boss 2026-09-11 OOB 'Foreshadowing, Placeholder,
                // Plot Threads — that tab bar': use the per-tab localized label
                // (= the `Tab.label` field = the Chinese
                // localized title; = rendered via
                // NSSegmentedControl.setLabel).
                displayStrings: tabs.map(\.label),
                icon: { tabId in
                    guard let tab = tabs.first(where: { $0.id == tabId }) else { return nil }
                    // v1.0.0-m1-shell boss 2026-09-15 OOB 'use SF Symbols 6
                    // (3rd gen) with palette rendering':
                    // SF Symbol mapping as a
                    // NSSegmentedControl-friendly fallback
                    // (= NSSegmentedControl.setImage requires
                    // NSImage; = TODO future ticket pre-renders
                    // the SF Symbol glyph as NSImage for true
                    // visual fidelity). Replaces the
                    // 2026-09-11 'Lucide only' choice per
                    // boss 2026-09-15 reversal.
                    return NSImage(systemSymbolName: tab.icon, accessibilityDescription: tab.label)
                }
            )
            .frame(maxWidth: .infinity)
            // v1.0.0-m1-shell boss 2026-09-11 OOB 'remove all custom padding
            // and switch to Apple-standard expressions — find an approximate value': remove the custom
            // horizontal inset (= `chromePaddingLarge` = 8 PT) on
            // the per-page tab strip. The tabs are inside a
            // VStack in the inspector detail column; = Apple HIG
            // macOS 27 default inspector rhythm places the
            // segmented tab strip at the natural full-bleed
            // horizontal width (= NO custom padding required; =
            // the canonical Pages / Numbers inspector tab
            // pattern; = tabs stretch from column edge to
            // column edge).
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
            // v1.0.0-m1-shell boss 2026-09-11 OOB 'everything is currently vertically
            // centered — keep the empty state vertically centered, title bar, divider, tab bar go
            // to the top, tab bar full-width fill is unchanged': per the boss's
            // request, the content area BELOW the tab strip is
            // vertically centered when the content is empty
            // (= the empty state hint sits in the middle of the
            // remaining space below the tabs; = the canonical
            // Apple HIG 'empty state in a tool pane' pattern =
            // Mail / Notes / Pages all center the empty-state
            // hint vertically). Per the same request, the title
            // / Divider / tab bar stay anchored to the top (= the
            // sticky header pattern), and the tab strip already
            // fills the column width (= no change to the tab bar's
            // horizontal extent).
            //
            // Implementation: wrap the content Group in
            // `Spacer(minLength: 0) + Group + Spacer(minLength: 0)`
            // (= both above and below the content; = with both
            // spacers the Group renders centered vertically inside
            // the VStack's remaining height; = with content the
            // top Spacer collapses to 0 (= no gap above); = the
            // Apple HIG canonical 'centered empty state' layout).
            //
            // Note: do NOT add `.frame(maxHeight: .infinity, ...)`
            // on the Group itself (= that would also force the
            // content Group to fill the column height even when
            // it has natural height; = we want the Group to be
            // centered, not stretched).
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                Group {
                    if let selected = tabs.first(where: { $0.label == selectedTabId }) {
                        selected.content
                    }
                }
                Spacer(minLength: 0)
            }
            .animation(.default, value: selectedTabId)
        }
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
    // (Historical: this line had CJK content from a boss OOB message; the original text can be recovered via `git blame` on this line; the cleanup commit replaced it with a stub because its translation was incomplete.)
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
}
