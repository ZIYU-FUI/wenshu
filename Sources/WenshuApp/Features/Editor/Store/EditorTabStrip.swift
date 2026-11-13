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
    // / pattern as the pane tab strip).
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

    /// Horizontal scroll offset of the strip, in points (= the left edge
    /// of the first visible segment).
    @State private var scrollPosition = ScrollPosition(idType: CGFloat.self, x: 0)

    /// The tabs the strip DRAWS, in display order.
    ///
    /// The control's cells are this array's count (= one cell per tab),
    /// and the scroll math below divides by the same count, = so the
    /// scroll offset and the drawn cells cannot drift apart.
    private var orderedTabs: [EditorTab] {
        displayOrder.compactMap { tabId in
            tabs.first(where: { $0.id == tabId })
        }
    }

    /// The width one tab takes (= the region's share).
    ///
    /// The tab strip divides the column it was given: every tab takes
    /// one equal share, and the share is NOT floored. The boss's rule
    /// (= 2026-11-12) is the browser's mechanism: the region is divided
    /// into as many equal shares as there are tabs, the strip never
    /// exceeds the region, and a tab label has no minimum width (= a tab
    /// may end up showing not one character, = and that is fine).
    ///
    /// The value belongs to `PaneTabStripWidth`, because the chat zone's
    /// session bar asks the same question of the same control, = and
    /// because the control itself asks that owner for the width it
    /// draws.
    private var segmentWidth: CGFloat {
        PaneTabStripWidth.segmentWidth(
            columnWidth: columnWidth,
            segmentCount: orderedTabs.count
        )
    }

    /// Stable value standing for "no tab is active". It never matches a
    /// tab id, and it does not change between reads.
    ///
    /// When the bound value names no segment (= this sentinel, or a
    /// closed document's id), the segmented control shows NO selection:
    /// `LabelSegmentedControl.selectedSegmentIndex(for:in:)` returns
    /// -1 (= AppKit's own "no segment is selected") and the control
    /// writes it, so the drawn selection can never name a DIFFERENT
    /// value than the bound one.
    static let noSelectionSentinel = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

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
                    // A stable sentinel for "no tab is active" (= a tab
                    // was closed while another was selected). A fresh
                    // UUID per read could never match a label, and the
                    // random value also changed on every read, so the
                    // control's selected segment never settled.
                    get: { selectedTabId ?? Self.noSelectionSentinel },
                    set: { newId in onSelect(newId) }
                ),
                labels: orderedTabs.map(\.id),
                displayStrings: orderedTabs.map { EditorTab.displayTitle($0) },
                iconStyle: .paneTab,
                onDoubleClickSegment: { segmentIndex in
                    guard segmentIndex >= 0 && segmentIndex < displayOrder.count else { return }
                    onClose(displayOrder[segmentIndex])
                },
                // The strip divides the column it was given: every tab
                // takes one equal share of the measured column width, so
                // the strip's total width tracks the column the writer
                // dragged instead of the number of open documents.
                //
                // The region is what the control's frame is PINNED to
                // (= `LabelSegmentedControl.sizeThatFits`), = and
                // AppKit's `.fillEqually` then divides that frame
                // exactly, at any tab count, with no per-cell minimum.
                // A zero width means the column has not been measured
                // yet, so the strip takes its own fitting width until the
                // first measurement lands.
                regionWidth: columnWidth,
                // The segments carry the open documents' TITLES, so the
                // role must be `.valueSelection`. The `.tabs` role draws
                // the selected segment as a dark inset and leaves its
                // label unpainted, which put the active document's name
                // behind a blank dark capsule.
                role: .valueSelection,
                // The strip's drawn capsule takes its height from the
                // segmented control the left and right columns already
                // use (= `.small`), = so all four columns' top bands
                // draw the same capsule height.
                controlSize: .small
            )
            // A horizontal scroll container clips the strip to the
            // column, so a control that has not been measured yet (= it
            // still carries its own fitting width) can never paint over
            // the panel next door. The strip itself never overflows: the
            // control's frame is pinned to the column's width (= see the
            // `regionWidth` above), = and AppKit's `.fillEqually` then
            // divides that frame, = so the container has nothing to
            // scroll. It stays because it is the canonical macOS tab-bar
            // shape and because it is the strip's clip.
            ScrollView(.horizontal) {
                control
                    // The control keeps its own height (= the `.small`
                    // capsule's 20 PT), = the same way the sidebar's and
                    // the inspector's switchers keep theirs: AppKit draws
                    // the capsule to fill the control's height, = so a
                    // control stretched to the band row's height would
                    // draw a full-height pill with no air.
                    .fixedSize(horizontal: false, vertical: true)
            }
            // Apple's own tab bars scroll the overflow without an
            // indicator, and a floating scroll bar is the one part of
            // this strip that is not a document name. Only the drawing
            // goes: the container still scrolls and still clips.
            .scrollIndicators(.hidden, axes: .horizontal)
            .scrollPosition($scrollPosition)
            // Keep the selected tab on screen. Without this a tab that has
            // scrolled past the column's edge can still be selected but
            // never seen.
            .onChange(of: selectedTabId) { _, _ in
                revealSelectedTab()
            }
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
        //
        // The band's height is the column's other bands' height (= the
        // sidebar's, the assets column's and the inspector's band row), =
        // so this strip's bottom edge is the same y as theirs, = and the
        // strip's drawn capsule (= the `.small` control above) takes its
        // height from the same segmented control those columns use.
        .frame(height: DesignTokens.paneTabHotArea)
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

    /// Scroll the strip so the selected tab is inside the column.
    ///
    /// The offset is derived from the same segment width the control is
    /// configured with, so the scroll lands on the tab rather than near
    /// it. Scrolling by the smallest amount that brings the tab into view
    /// keeps the neighbouring tabs where the writer left them.
    private func revealSelectedTab() {
        // The index and the count come from the SAME array the cells are
        // drawn from (= `orderedTabs`), = so the scroll's basis and the
        // drawn cells cannot disagree when an id in the display order is
        // not in the caller's tabs.
        guard let selectedTabId,
              let index = orderedTabs.firstIndex(where: { $0.id == selectedTabId }),
              segmentWidth > 0
        else { return }

        let tabLeft = CGFloat(index) * segmentWidth
        let tabRight = tabLeft + segmentWidth
        let visibleWidth = columnWidth
        guard tabRight > columnWidth || tabLeft < 0 else { return }

        let offset = tabRight > columnWidth ? tabRight - visibleWidth : tabLeft
        let maxOffset = max(0, segmentWidth * CGFloat(orderedTabs.count) - visibleWidth)
        scrollPosition = ScrollPosition(
            idType: CGFloat.self,
            x: max(0, min(offset, maxOffset))
        )
    }

    // / Render a single tab (= title label + close X). RATIONALE: the close X is
    // … (= 13 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / used by Safari / Finder / Mail for list-row close buttons.
}
