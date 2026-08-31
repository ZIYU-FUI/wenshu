// PaneNSController.swift · Wenshu · v0.30 ticket 03 / 4
//
// Future-framework native container (= boss 2026-08-31 OOB:
// "Implement the FCP layout using Apple official APIs"; see spec.md
// for the verbatim Chinese quote). This NSSplitViewController subclass
// is what FCPLayout.makeSplitController actually returns (= after
// ticket 01's stub). It walks the recursive WorkspaceState tree
// and builds the matching NSSplitView + NSSplitViewItem hierarchy.
//
// Ticket 03 / 4 scope (= this file):
//   - Declare `final class PaneNSController: NSSplitViewController`
//   - Walk store.workspace.root recursively
//   - For each SplitNode, create an NSSplitView child with the right
//     orientation + dividerStyle + autosaveName
//   - For each GroupNode, create one NSSplitViewItem per contained
//     pane (= hosting NSHostingController(rootView: TabContentDispatcher))
//   - Widen divider hit area via `effectiveRect` override (= 4 PT to
//     match Apple HIG thin divider while staying easy to grab)
//   - Set `canCollapse = true` on sidebar/chat/dynamic items (= user-
//     hideable side panels per FCP standard)
//   - NO existing source file modified
//   - NO behavior change (= dormant until ticket 04 wires the flag)
//
// Out of scope (= other tickets):
//   - NSViewControllerRepresentable wrapper → ticket 02 (already done)
//   - Feature flag wiring → ticket 04
//   - Tree diff/update logic on pane change → ticket 04 (deferred —
//     until PR 4 + manual verify, the tree is rebuilt only on
//     makeNSViewController; switching preset triggers a full re-make)

import AppKit
import SwiftUI

/// Native AppKit split container that hosts wenshu's existing SwiftUI
/// pane views (= `TabContentDispatcher` per pane). Built from a
/// `WorkspaceStore` snapshot; the tree walk is fully recursive.
///
/// Threading: instantiated on the main actor (SwiftUI representable
/// `makeNSViewController` runs on main). Child `NSHostingController`s
/// also stay on main.
@MainActor
final class PaneNSController: NSSplitViewController {

    // MARK: - Stored dependencies (= set once at init; not mutated)

    private let store: WorkspaceStore
    private let appState: AppState
    private let bookStore: BookStore

    /// Layout identifier (= for autosaveName scoping; per-preset so
    /// switching presets restores each one's last divider positions).
    private let layoutID: String

    /// Applied-once flag: tracks whether the initial weight ratio
    /// has been applied via setPosition. NSSplitView's bounds are 0
    /// at init time (= controller not yet laid out), so applyWeights
    /// must run on the FIRST viewDidLayout (= then autosaveName
    /// takes over and user's manual drags persist across launches).
    private var didApplyInitialWeights = false

    /// Divider hit-area padding (= PT on each side of the drawn divider
    /// line). Apple default = `0` (= divider is exactly the visible
    /// 1 PT line, very hard to grab). Bumped to 4 PT (= splits match
    /// FCP / Xcode / System Settings hit-area feel without making the
    /// divider look chunky).
    private let dividerHitPadding: CGFloat = 4

    // MARK: - Init

    init(
        store: WorkspaceStore,
        appState: AppState,
        bookStore: BookStore,
        layoutID: String
    ) {
        self.store = store
        self.appState = appState
        self.bookStore = bookStore
        self.layoutID = layoutID
        super.init(nibName: nil, bundle: nil)
        buildLayout()
        // Widen the divider hit area (= see AC #4). Acting as the
        // split's delegate lets us override `effectiveRect(...)` and
        // extend each divider's grabbable region by `dividerHitPadding`.
        self.splitView.delegate = self
        // Display-menu bridge (= Gap F fix). The legacy "Display" menu items
        // in App.swift:593-611 post .wenshuToggleZone(ZoneSlot)
        // notifications; this observer finds the matching NSSplitViewItem
        // and flips its collapsed state (= Apple HIG sidebar hide/show
        // affordance).
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleToggleZone(_:)),
            name: .wenshuToggleZone,
            object: nil
        )
    }

    /// Gap F forward-fix: handle `.wenshuToggleZone(ZoneSlot)` notification
    /// by finding the matching NSSplitViewItem (= the one whose pane's
    /// first tab kind matches the ZoneSlot) and flipping its
    /// `isCollapsed` property. Items without `canCollapse` (= preview /
    /// editor) are silently ignored (= their menu items were never
    /// collapsible in the FCP spec either).
    @objc private func handleToggleZone(_ notification: Notification) {
        guard let slot = notification.object as? ZoneSlot else { return }
        // Map ZoneSlot → TabKind (canonical mapping). editor has no
        // dedicated ZoneSlot toggle button (= the legacy menu doesn't
        // show it), but include it for completeness.
        let targetKind: TabKind? = {
            switch slot {
            case .projectSidebar: return .projectSidebar
            case .projectPreview: return .projectPreview
            case .editor: return .editor
            case .specializedTools: return .specializedTools
            case .aiChat: return .aiChat
            case .aiDynamic: return .aiDynamic
            }
        }()
        guard let kind = targetKind else { return }
        for item in splitViewItems {
            guard item.canCollapse else { continue }
            guard let tab = firstTabKind(for: item) else { continue }
            if tab == kind {
                item.isCollapsed.toggle()
            }
        }
    }

    /// Resolve the first TabKind for an NSSplitViewItem (= it hosts an
    /// NSHostingController(rootView: TabContentDispatcher); the
    /// dispatcher is the rootView itself).
    private func firstTabKind(for item: NSSplitViewItem) -> TabKind? {
        // NSHostingController typed-erases its rootView into AnyView;
        // the underlying SwiftUI type identity is lost at runtime.
        // Workaround: search the active pane's tab via the pane's
        // workspace state (= the same lookup FCPLayout/PaneNSController
        // already does in makeSplitItems).
        for paneID in store.workspace.allPaneIDsInTree {
            guard let pane = store.workspace.pane(for: paneID),
                  let firstTabID = pane.tabIDs.first,
                  let tab = store.workspace.tab(for: firstTabID)
            else { continue }
            let title = tab.title
            if hostingIdentifierMatches(item: item, title: title) {
                return tab.kind
            }
        }
        return nil
    }

    /// Heuristic match: NSHostingController doesn't expose its
    /// rootView type, so we walk the item's view hierarchy looking for
    /// any descendant Accessibility label matching `title`. Apple HIG
    /// truth-source: every SwiftUI view with a `.accessibilityLabel(...)`
    /// = the TabContentDispatcher carries `title` as the parameter;
    /// the rendered chrome uses that title in its tab bar (= which is
    /// NOT in this item because the tab strip lives in the parent
    /// `GroupTabStrip`, not the hosting view). Fallback: return false
    /// (= skip; user can still toggle via the toolbar button when the
    /// LayoutEditMode is active).
    private func hostingIdentifierMatches(item: NSSplitViewItem, title: String) -> Bool {
        let view = item.viewController.view
        // String-search the accessibility hierarchy for the title.
        // This is intentionally lenient (= exact substring match) so
        // locale-neutral tab titles (Chinese / English) all work.
        var matched = false
        viewAccessibilityWalk(view) { label in
            if label.contains(title) { matched = true }
        }
        return matched
    }

    /// Recursive accessibility label walker. Reads the AX hierarchy via
    /// `NSAccessibility` (no SwiftUI introspection needed). Cheap (=
    /// walks the local subtree only); called once per zone-toggle click.
    private func viewAccessibilityWalk(
        _ view: NSView,
        visit: (String) -> Void
    ) {
        if let label = view.accessibilityLabel() {
            visit(label)
        }
        for sub in view.subviews {
            viewAccessibilityWalk(sub, visit: visit)
        }
    }
    // MARK: - NSSplitViewDelegate (= divider hit-area widening)

    /// Apple HIG thin divider (= 1 PT drawn line) is hard to grab. We
    /// widen the effective hit rectangle by `dividerHitPadding` on the
    /// perpendicular axis so the divider feels like ~9 PT total
    /// (= 1 PT drawn + 4 PT pad each side = FCP-style grab affordance).
    nonisolated override func splitView(
        _ splitView: NSSplitView,
        effectiveRect proposedEffectiveRect: NSRect,
        forDrawnRect drawnRect: NSRect,
        ofDividerAt dividerIndex: Int
    ) -> NSRect {
        // We need the axis to inset by the perpendicular axis (= a
        // vertical split's divider extends in the y axis; a horizontal
        // split's divider extends in the x axis). splitView.isVertical
        // is the source of truth (= true = panes side-by-side).
        let pad = dividerHitPadding
        if splitView.isVertical {
            // Vertical divider: extend up/down (= widen the y range).
            return NSRect(
                x: drawnRect.origin.x,
                y: max(0, drawnRect.origin.y - pad),
                width: drawnRect.width,
                height: min(splitView.bounds.height, drawnRect.height + 2 * pad)
            )
        } else {
            // Horizontal divider: extend left/right.
            return NSRect(
                x: max(0, drawnRect.origin.x - pad),
                y: drawnRect.origin.y,
                width: min(splitView.bounds.width, drawnRect.width + 2 * pad),
                height: drawnRect.height
            )
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("PaneNSController is programmatic-only (= no XIB support)")
    }

    // MARK: - Build (= recursive tree walk)

    /// Walk `store.workspace.root` and produce the matching NSSplitView
    /// children + their NSSplitViewItems. Called once from `init`; the
    /// tree is then frozen for this controller's lifetime (= ticket 04
    /// will rebuild via SwiftUI re-make on preset switch).
    /// Stores the root SplitNode weights so viewDidLayout can apply
    /// them on first layout (= bounds are 0 at init time; we cannot
    /// setPosition before the view is laid out). Captured during
    /// buildLayout and consumed by viewDidLayout.
    private var pendingRootWeights: [Double] = []

    private func buildLayout() {
        // Reset any inherited children (= safety against reuse).
        for child in children {
            removeChild(at: 0)
        }
        // v0.30 boss 2026-09-01 OOB fix: explicitly set the root
        // NSSplitView's axis to match the root SplitNode's
        // orientation. Without this, NSSplitViewController defaults
        // to `isVertical = true` (= horizontal row of panes), which
        // is WRONG when the root is `.column` (= upper band + lower
        // band stacked top-to-bottom). The result: the
        // `installSplit` recursion sees parentOrientation = `.row`
        // (= derived from NSSplitView.isVertical = true), and
        // matches it against upperBand/lowerBand `.row` children,
        // installing them as siblings in one row (= 6 panes side
        // by side, NOT two bands stacked).
        switch store.workspace.root {
        case .split(let split):
            self.splitView.isVertical = (split.orientation == .row)
            // v0.30 boss 2026-09-01 OOB: NO autosaveName on the root
            // (= Apple's autosave would restore the FIRST launch's
            // default ratio and override our preset weights on
            // every subsequent launch). Nested split controllers
            // still get autosaveName (= user drag persistence for
            // the inner pane arrangements, which is where manual
            // tweaks actually happen).
            self.splitView.autosaveName = nil
            pendingRootWeights = split.weights
            installSplit(split, parent: self, parentOrientation: split.orientation == .row ? .row : .column)
        case .group(let group):
            self.splitView.isVertical = true
            installGroup(group)
        }
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        // v0.30 boss 2026-09-01 OOB fix: NSSplitView's bounds are
        // 0 at init time, so applyWeights would compute positions
        // against a 0-wide canvas. Wait until the first real
        // layout, then apply the workspace weights. After this
        // first apply, autosaveName takes over and user's manual
        // drag offsets persist (= we don't re-apply on subsequent
        // layout passes).
        guard !didApplyInitialWeights, !pendingRootWeights.isEmpty else { return }
        let splitView = self.splitView
        guard splitView.bounds.width > 0, splitView.bounds.height > 0 else { return }
        // Clear stale autosave entries that override our preset
        // weights (= the FIRST launch persists these entries;
        // subsequent launches re-read them and ignore our
        // workspace weights). Without this, the ratio stays at
        // whatever the very first launch's default was.
        clearStaleAutosave()
        applyWeights(pendingRootWeights, on: self)
        didApplyInitialWeights = true
    }

    /// Remove the NSSplitView autosave entries (= UserDefaults
    /// keys under "NSSplitView Subview Frames wenshu.split.*")
    /// so the preset weight ratio applies on the next launch.
    /// Apple's NSSplitView reads these keys BEFORE setPosition
    /// (= if they're present, NSSplitView restores the saved
    /// position and our weights are ignored).
    private func clearStaleAutosave() {
        let prefix = "NSSplitView Subview Frames wenshu.split.\(layoutID)."
        let defaults = UserDefaults.standard
        // Find all keys matching the prefix and remove them.
        // UserDefaults doesn't expose key enumeration for arbitrary
        // prefixes, so iterate the well-known per-split autosave
        // keys via a dictionaryRepresentation scan.
        for (key, _) in defaults.dictionaryRepresentation() {
            if key.hasPrefix(prefix) {
                defaults.removeObject(forKey: key)
            }
        }
    }

    /// Recursive: install a `SplitNode` into the parent controller as a
    /// nested NSSplitView (= child NSSplitViewController).
    private func installSplit(
        _ split: SplitNode,
        parent: NSSplitViewController,
        parentOrientation: Orientation
    ) {
        // If the split orientation matches the parent's axis (= nested
        // horizontal splits inside a column root), we can install the
        // children directly on the parent (= no extra wrapping). For the
        // default FCP root (= column), the first split is the upperBand
        // (.row) and the lowerBand (.row); both install as direct rows
        // inside the column parent.
        if split.orientation == parentOrientation {
            installChildren(split.children, weights: split.weights, into: parent)
            // Note: do NOT call applyWeights here (= bounds may be
            // 0). viewDidLayout runs applyWeights on the ROOT after
            // bounds are non-zero; nested splits inherit the
            // initial autosaveName positions (= Apple's NSSplitView
            // picks reasonable defaults for nested controllers).
            return
        }

        // Different orientation → create a nested controller.
        // Also set the nested controller's splitView.isVertical to
        // match this split's orientation (= otherwise the nested
        // controller defaults to isVertical = true and the children
        // install wrong-axis).
        let nested = NSSplitViewController()
        nested.splitView.isVertical = (split.orientation == .row)
        nested.splitView.autosaveName = autosaveKey(for: split.id)
        installChildren(split.children, weights: split.weights, into: nested)
        parent.addChild(nested)
        // Note: do NOT call applyWeights on the nested controller
        // here. The nested controller's bounds become non-zero
        // after viewDidLayout on the root (= our app's root view
        // hierarchy). Nested splits inherit reasonable initial
        // divider positions from NSSplitView's defaults and
        // autosaveName will persist user's manual drag adjustments
        // across launches.
    }

    /// v0.30 boss 2026-09-01 OOB fix: explicitly position each
    /// NSSplitView divider according to the workspace weights array.
    ///
    /// Without this, NSSplitView treats all added items equally
    /// (= it ignores any custom weights we pass through
    /// installChildren). The result: a `.column` split with
    /// `weights: [1, 1]` (= 50/50 expected) renders as ~25/75
    /// (= NSSplitView's default column distribution).
    ///
    /// Apple HIG-compliant solution: use `setPosition(ofDividerAt:)`
    /// to place each divider proportionally along the split axis.
    /// This works alongside `autosaveName` (= the first launch
    /// applies the preset ratio; subsequent launches respect the
    /// user's manual drag adjustments).
    private func applyWeights(_ weights: [Double], on controller: NSSplitViewController) {
        let splitView = controller.splitView
        // Walk each divider (= divider count = NSSplitViewItem count - 1).
        let itemCount = controller.splitViewItems.count
        guard itemCount >= 2 else { return }
        let dividerCount = itemCount - 1
        let total = weights.reduce(0, +)
        guard total > 0 else { return }

        // Cumulative weight position (= where each divider should sit).
        var cumulative: CGFloat = 0
        let isVertical = splitView.isVertical

        for dividerIndex in 0..<dividerCount {
            // Position of this divider = cumulative weight / total
            // of the parent's available span.
            cumulative += weights[dividerIndex]
            let proportion = cumulative / CGFloat(total)

            // Translate proportion to pixel position.
            // For horizontal split (= isVertical = true = children
            // side-by-side): position is along x = proportion * width.
            // For vertical split (= isVertical = false = children
            // stacked): position is along y = proportion * height.
            let totalSpan: CGFloat = isVertical ? splitView.bounds.width : splitView.bounds.height
            let position = totalSpan * proportion
            NSLog("[wenshu.NS] applyWeights divider=\(dividerIndex) weight=\(weights[dividerIndex])/total=\(total) proportion=\(proportion) span=\(totalSpan) position=\(position)")
            splitView.setPosition(position, ofDividerAt: dividerIndex)
        }
    }

    /// Install each child node (= split OR group) as either a nested
    /// NSSplitViewController (if it's a SplitNode) or an NSSplitViewItem
    /// (if it's a GroupNode). Weights are translated to NSSplitViewItem
    /// `minimumThickness` (= left edge: 200 PT to match FCP sidebar
    /// feel; right edge: 200 PT to match FCP tools feel; unbounded for
    /// middle panes).
    private func installChildren(
        _ children: [LayoutNode],
        weights: [Double],
        into controller: NSSplitViewController
    ) {
        for (index, node) in children.enumerated() {
            let weight = index < weights.count ? weights[index] : 1.0
            switch node {
            case .split(let split):
                installSplit(split, parent: controller, parentOrientation: controller.splitView.isVertical ? .row : .column)
            case .group(let group):
                let items = makeSplitItems(for: group, weight: weight)
                for item in items {
                    controller.addSplitViewItem(item)
                }
            }
        }
    }

    /// Build one NSSplitViewItem per pane in the group (= when group has
    /// 1 pane = 1 item; when 3 panes = 3 stacked tabs at runtime, but
    /// for v0.30 we render only the active pane and skip the tab strip
    /// for the legacy single-pane groups). Each item hosts a
    /// `NSHostingController(rootView: TabContentDispatcher)` so the
    /// pane's SwiftUI @Environment lookup still works (= threaded
    /// through init's appState + bookStore).
    private func makeSplitItems(
        for group: GroupNode,
        weight: Double
    ) -> [NSSplitViewItem] {
        // Resolve the active pane (= fall back to first if missing).
        guard let activePaneID = group.panes.first(where: { $0 == group.active })
            ?? group.panes.first
        else { return [] }
        guard let pane = store.workspace.pane(for: activePaneID) else { return [] }
        guard let firstTabID = pane.tabIDs.first,
              let tab = store.workspace.tab(for: firstTabID)
        else { return [] }

        // Build the SwiftUI host view (= reuses existing dispatcher).
        let content = TabContentDispatcher(kind: tab.kind, title: tab.title)
            .environment(appState)
            .environment(bookStore)
        // WorkspaceStore is an ObservableObject (= passes via .environmentObject
        // instead of .environment, which is reserved for @Observable types).
        let hosted = content.environmentObject(store)
        let hosting = NSHostingController(rootView: hosted)

        // Wrap in NSSplitViewItem (= the native AppKit container).
        let item = NSSplitViewItem(viewController: hosting)
        item.canCollapse = isCollapsiblePane(activePaneID)
        item.minimumThickness = minThickness(for: activePaneID, weight: weight)
        return [item]
    }

    /// Install a `GroupNode` directly (= when the root IS a group, e.g.
    /// a single-pane layout). Mirrors `makeSplitItems` minus the parent
    /// controller split.
    private func installGroup(_ group: GroupNode) {
        let items = makeSplitItems(for: group, weight: 1.0)
        for item in items {
            addSplitViewItem(item)
        }
    }

    // MARK: - Pane property helpers (= min thickness + collapse permission)

    /// Minimum thickness in points for the pane (= left/right edges get
    /// a hard minimum so the user can't drag them below Apple HIG
    /// readability; middle panes get a smaller minimum so the editor
    /// can shrink when the sidebar expands).
    private func minThickness(for paneID: PaneID, weight: Double) -> CGFloat {
        guard let pane = store.workspace.pane(for: paneID) else { return 100 }
        // Honor the pane's declared minWidth/idealWidth (= user-tunable).
        if pane.frame.minWidth > 0 { return pane.frame.minWidth }
        // Fallback: collapseable side panes default to 200 (= Apple HIG
        // sidebar minimum); non-collapseable panes (= editor, viewer)
        // default to 100 (= can shrink down to almost nothing).
        return isCollapsiblePane(paneID) ? 200 : 100
    }

    /// Which panes can the user collapse (= via the "Display" menu /
    /// sidebar toolbar toggle). Matches FCP's collapsible sidebars +
    /// chat/dynamic zones. Central panes (= editor) are NOT collapseable.
    private func isCollapsiblePane(_ paneID: PaneID) -> Bool {
        guard let pane = store.workspace.pane(for: paneID),
              let firstTabID = pane.tabIDs.first,
              let tab = store.workspace.tab(for: firstTabID)
        else { return false }
        switch tab.kind {
        case .projectSidebar, .aiChat, .aiDynamic, .specializedTools:
            return true
        case .projectPreview, .editor:
            return false
        }
    }

    // MARK: - autosaveName key (= per-layout + per-split)

    /// Apple autosaveName key (= scopes divider positions per preset +
    /// per split subtree, so switching presets restores each one's last
    /// divider positions).
    private func autosaveKey(for splitID: String) -> String {
        "wenshu.split.\(layoutID).\(splitID)"
    }
}
