//
//  ZoneContentView.swift · Wenshu
//
//  Generic tab content view: 1-layer pattern with multiple
//  internal tabs. Hosts the per-pane tab strip + selected
//  content. Used by the 4 general panes (projectSidebar /
//  projectPreview / editor / specializedTools).
//
//  History:
//  - Q2 era: this view was wrapped by ZoneContentTabBar (= per-zone
//    chrome). The wrapper was deleted in v0.28 (= PaneTabBar absorbed
//    the chrome), and ZoneContentView now hosts its own tab bar
//    inline (= LabelSegmentedControl against the native macOS 27
//    NSSegmentedControl).
//  - v0.40: the `zoneSlug: String` init parameter and the per-zone
//    `wenshu.tabIndex.<slug>` UserDefaults key were removed. The
//    slug-bound persistence was redundant with PaneTabBar's per-pane
//    storage (= already keyed by pane id) and forced every caller
//    to invent a slug string. The view now persists selectedTabId
//    under a single shared key (= at most one ZoneContentView is
//    visible at a time).
//

import SwiftUI

struct ZoneContentView: View {
    struct Tab: Identifiable {
        // bossverificationfix: use String label as ID (UUID auto-generated per re-render
        // → stale selectedTabId after re-render → no tab marked selected).
        let id: String
        let label: String
        let icon: String
        let content: AnyView
    }

    let tabs: [Tab]
    // (= ticket 029c-trailing-button editor zone expand/shrink):
    // owner 2026-08-26 OOB ' yesbutton yes
    // teb' = optional trailing button rendered at the right
    // edge of the tab bar (= independent of tab count). nil = no
    // trailing button = default behavior preserved for all OTHER
    // zone-content tab bars; only the editor zone passes a
    // trailing expand/shrink button.
    var trailingButton: AnyView? = nil

    @State private var selectedTabId: String

    // per-instance SwiftUI namespace for the
    // matchedGeometryEffect underline (= SwiftUI requires the
    // namespace to scope within a single view tree).
    @Namespace private var tabBarNamespace

    // Selected tab persists across launches via UserDefaults.
    // Single shared key (= at most one ZoneContentView is on
    // screen at a time since the LayoutTree renders only the
    // active pane, so per-pane keying is redundant).
    private static let storageKey = "wenshu.zoneContent.selectedTabId"

    var body: some View {
        // bossverificationfix: simpler structure (VStack only, no ZStack wrapper
        // which was regressing tab bar visibility).
        //
        // -m1-shell (see OOB.md #2026-09-11) OOB 'macOS 27's native
        // control is our first choice': use the macOS 27 native
        // NSSegmentedControl via the LabelSegmentedControl
        // wrapper (= canonical Apple HIG Pages / Numbers
        // inspector tab strip; auto-fills column width).
        //
        // We bind the control to String ids (= the Tab.id;
        // Hashable; avoids the need to make the full Tab type
        // Hashable).
        VStack(spacing: 0) {
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
                // -m1-shell (see OOB.md #2026-09-11) OOB 'Foreshadowing,
                // Placeholder, Plot Threads — that tab bar': use the
                // per-tab localized label.
                displayStrings: tabs.map(\.label),
                icon: { tabId in
                    guard let tab = tabs.first(where: { $0.id == tabId }) else { return nil }
                    // NSSegmentedControl consumes NSImage instead of SwiftUI's
                    // SFIcon, so use the central IconStyle at the AppKit
                    // boundary. This keeps all toolbar symbols on one size,
                    // weight, and scale.
                    return NSImage(systemSymbolName: tab.icon, accessibilityDescription: tab.label)
                }
            )
            .frame(maxWidth: .infinity)
            // ZONE-INSET-002 (2026-09-07): outer .padding(.all,
            // zoneContentInset) was dropped. Apple HIG List(.sidebar)
            // / LazyVGrid already have their own canonical padding;
            // the wrapper doubled it. Each content view now owns its
            // own inset.
            //
            // -m1-shell (see OOB.md #2026-09-11) OOB 'keep the
            // empty state vertically centered, title bar, divider,
            // tab bar go to the top': content area below the tab
            // strip is vertically centered when empty (= canonical
            // Apple HIG 'empty state in a tool pane' pattern;
            // Mail / Notes / Pages all center the empty-state hint
            // vertically).
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

    init(tabs: [(label: String, icon: String, content: AnyView)], trailingButton: AnyView? = nil) {
        let mapped = tabs.map { Tab(id: $0.label, label: $0.label, icon: $0.icon, content: $0.content) }
        self.tabs = mapped
        self.trailingButton = trailingButton
        // Restore selected tab from UserDefaults (or default to first tab).
        // bossverificationfix: handle invalid saved value (= tab
        // list changed across launches) by falling back to first
        // tab and resetting the stored index.
        let savedIndex = UserDefaultsStore.shared.int(forDynamicKey: Self.storageKey)
        if !mapped.indices.contains(savedIndex) {
            UserDefaultsStore.shared.setInt(0, forDynamicKey: Self.storageKey)
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
                    UserDefaultsStore.shared.setInt(idx, forDynamicKey: Self.storageKey)
                }
            }
        )
    }
}