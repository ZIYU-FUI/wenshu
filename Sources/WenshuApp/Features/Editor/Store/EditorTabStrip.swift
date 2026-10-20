// Sources/WenshuApp/Editor/EditorTabStrip.swift
// … (= 27 rationale lines collapsed; = A112 docblock collapse per §1.8)
// SwiftUI diffing).
import SwiftUI

/// Safari-style multi-tab strip for the editor zone.
@MainActor
struct EditorTabStrip: View {

    // / The tabs to render, in display order (= `openTabs` array order in
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    let tabs: [EditorTab]

    // / Currently active tab id (= drives the accent-tinted + bottom- border
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / hide the entire strip in that case).
    let selectedTabId: UUID?

    /// Fired when the user picks a different tab. Caller writes this back to
    /// `AppState.activeTabId`.
    let onSelect: (UUID) -> Void

    // / Fired when the user clicks the close X. Caller routes through
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / confirmation alert in one place).
    let onClose: (UUID) -> Void

    // / SwiftUI namespace for the matchedGeometryEffect underline (= Apple's HIG
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / pattern as PaneTabBar).
    @Namespace private var tabBarNamespace

    // / Tab ids in display order (= tracked separately from `tabs` parameter for
    // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / across re-renders). Initialized from `tabs` on each render.
    @State private var displayOrder: [UUID] = []

    /// Last seen `tabs` array (= detects when the caller added / removed tabs
    /// externally so we can prune displayOrder).
    @State private var lastSeenTabIds: [UUID] = []
    // / live column width (= the editor column's current width; = updated by
    // … (= 7 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / behavior).
    @State private var columnWidth: CGFloat = 0

    var body: some View {
        // RATIONALE: per Apple HIG SwiftUI macOS 27 + the Safari
        // … (= 20 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // shift; = the caller's responsibility, not this view's.
        stripContent
    }

    // / The actual tab strip (= ScrollView of tabs + empty-state + button).
    // … (= 5 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / tabs would).
    @ViewBuilder
    private var stripContent: some View {
        // RATIONALE: the strip body is a VStack (= tab-pill
        // … (= 7 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // strip's bottom 1 PT).
        VStack(spacing: 0) {
            // Sync displayOrder with the caller's `tabs` parameter.
            // … (= 208 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // VStack).
            let control = LabelSegmentedControl(
                selection: Binding(
                    get: { selectedTabId ?? UUID() },
                    set: { newId in onSelect(newId) }
                ),
                labels: displayOrder.compactMap { tabId in
                    tabs.first(where: { $0.id == tabId })
                        .map { $0.id }
                },
                displayStrings: displayOrder.compactMap { tabId in
                    tabs.first(where: { $0.id == tabId }).map {
                        EditorTab.displayTitle($0)
                    }
                },
                iconStyle: .paneTab,
                onDoubleClickSegment: { segmentIndex in
                    guard segmentIndex >= 0 && segmentIndex < displayOrder.count else { return }
                    onClose(displayOrder[segmentIndex])
                },
                // 
                // … (= 20 rationale lines collapsed; = A112 docblock collapse per §1.8)
                // column).
                fixedSegmentWidth: 0
            )
            // 2026-10-14 v3: wrap the
            // … (= 84 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // layout.
            control
            // RATIONALE: the tab strip's
            // … (= 8 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // top inset).
            .padding(.top, DesignTokens.spacingHero - 10)
            .padding(.bottom, 0)
            // RATIONALE: the manual
            // … (= 25 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // hairlines).
        }
        // RATIONALE: the tab pills
        // … (= 25 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // right).
        .frame(maxWidth: .infinity, alignment: .leading)
        // capture
        // … (= 30 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // `columnWidth`).
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { newWidth in
            columnWidth = newWidth
        }
        // RATIONALE: the strip background is `Color.clear` (= a
        // … (= 10 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // anchor, not the Liquid Glass material).
        .background(Color.clear)
        // RATIONALE: the strip's frame height = `paneTabHotArea`
        // … (= 10 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // Apple-canonical inset).
        .frame(height: DesignTokens.paneTabHotArea)
        // RATIONALE: boss visual diff 2026-10-13 — add 2 PT
        // … (= 10 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // the named token).
        .padding(.top, DesignTokens.spacingCaption)
        .onChange(of: tabs.map(\.id), initial: true) { _, incomingIds in
            // Sync is a no-op if the id list already matches the
            // … (= 12 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // without the initial empty-array glitch).
            if incomingIds != lastSeenTabIds {
                var newOrder: [UUID] = []
                for id in incomingIds {
                    if let existing = displayOrder.first(where: { $0 == id }) {
                        newOrder.append(existing)
                    } else {
                        newOrder.append(id)
                    }
                }
                displayOrder = newOrder
                lastSeenTabIds = incomingIds
            }
        }
    }

    // / Render a single tab (= title label + close X). RATIONALE: the close X is
    // … (= 13 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / used by Safari / Finder / Mail for list-row close buttons.
}
