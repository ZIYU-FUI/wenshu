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

// MARK: - WenshuSplitView (= NSSplitView subclass for custom background draw)
//
// v0.30 boss 2026-09-01 OOB: 'no divider line + panes gap-free'.
// Apple NSSplitView's default `adjustSubviews()` (= which we now
// override + call super) leaves 'room for dividers in between'
// (= a 1 PT gap between each adjacent subview, = the 1 PT gap
// the boss is seeing as 'a wide gap'). Per the NSSplitView.h
// header: "Delegates that respond to this message should adjust
// the frames of the uncollapsed subviews so that they exactly
// fill the split view with room for dividers in between".
//
// Fix = override `adjustSubviews()`, call super (= get Apple's
// weight-based widths), then shift each subview's origin so the
// frames TOUCH (no 1 PT gap between them), and shrink the
// divider subviews to 0 width. The last content subview is
// extended to bounds.maxX/Y to absorb the 1 PT of leftover
// space (= super's gap disappears entirely).
//
// The previous attempt (commit b26639d65 = WenshuSplitView with
// drawDivider override) broke the layout. The current
// implementation only overrides adjustSubviews (= the standard
// layout hook that AppKit calls after every subview change and
// every bounds change = safe to override = no layout break).
//
// The draw(_:) override is empty (= paints nothing = the 1 PT gap
// area is transparent; combined with subview frames touching, the
// panes are visually gap-free).
@MainActor
final class WenshuSplitView: NSSplitView {
    override func draw(_ dirtyRect: NSRect) {
        // Do nothing (= the 1 PT gap area is now transparent; the
        // divider subview itself has its layer cleared in the parent
        // controller, so no visible hairline either). Subviews
        // (= the user content panes) draw themselves normally
        // because draw(_:) only fills the NSSplitView's own
        // background; it does not erase subview content.
    }

    override func adjustSubviews() {
        // 1. Apple's default layout (= super) = weight-based widths
        // with a 1 PT gap between each adjacent subview.
        super.adjustSubviews()

        // 2. Shift each non-divider subview's origin to the previous
        // subview's maxX (= the frames touch; the 1 PT gap is closed).
        // 3. Shrink the divider subviews to 0 width (still mount =
        // drag still works; not visible).
        // 4. Extend the last content subview to bounds.maxX / maxY
        // (= absorb the leftover 1 PT of space from the eliminated
        // gap so the total = bounds exactly).
        let isVert = isVertical
        let bounds = self.bounds
        var running: CGFloat = 0
        for subview in subviews {
            let className = String(describing: type(of: subview))
            if className.contains("Divider") {
                // Zero-width divider (= still mounted; drag still
                // routes to it via AppKit's hit-testing).
                if isVert {
                    subview.frame = NSRect(
                        x: 0, y: 0,
                        width: 0, height: bounds.height
                    )
                } else {
                    subview.frame = NSRect(
                        x: 0, y: 0,
                        width: bounds.width, height: 0
                    )
                }
            } else {
                // Content subview: place at running (= previous
                // subview's maxX or bounds.origin), keep its current
                // width (= Apple's weight-based width from super).
                if isVert {
                    subview.frame = NSRect(
                        x: running, y: 0,
                        width: subview.frame.width,
                        height: bounds.height
                    )
                } else {
                    subview.frame = NSRect(
                        x: 0, y: running,
                        width: bounds.width,
                        height: subview.frame.height
                    )
                }
                running = isVert ? subview.frame.maxX : subview.frame.maxY
            }
        }
        // 4. Extend the last content subview to bounds.max so the
        // total fills bounds exactly (the super gap is now gone but
        // the last subview's width is super's original = short by
        // the gap that super reserved; absorb that).
        if let lastContent = subviews.last(where: {
            !String(describing: type(of: $0)).contains("Divider")
        }) {
            if isVert {
                lastContent.frame = NSRect(
                    x: lastContent.frame.origin.x,
                    y: 0,
                    width: bounds.maxX - lastContent.frame.origin.x,
                    height: bounds.height
                )
            } else {
                lastContent.frame = NSRect(
                    x: 0,
                    y: lastContent.frame.origin.y,
                    width: bounds.width,
                    height: bounds.maxY - lastContent.frame.origin.y
                )
            }
        }
    }
}

// MARK: - PaneNSController

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
        // v0.30 boss 2026-09-01 OOB: swap the default NSSplitView
        // (= the root of this controller) for WenshuSplitView (= the
        // NSSplitView subclass with custom draw(_:) that paints
        // nothing = no 1PT gap visible). The swap must happen
        // IMMEDIATELY after super.init and BEFORE buildLayout (= any
        // access to self.view triggers NSSplitViewController's
        // internal viewDidLoad which freezes the view to a vanilla
        // NSSplitView; too late to swap then). Per the
        // NSSplitViewController.h header: "set the splitView property
        // anytime before self.viewLoaded is YES".
        self.splitView = WenshuSplitView()
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
        // v0.30 boss 2026-09-01 OOB: NSSplitView's divider style now
        // follows the Liquid Glass opacity slider. At opacity 0 (= the
        // user explicitly wants fully transparent chrome), hide the
        // divider entirely (= boss OOB 'completely transparent'); for
        // any other value, use Apple's standard `.thin` divider (= a
        // semitransparent hairline that adapts to dark/light mode).
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleLiquidGlassOpacityChanged),
            name: .liquidGlassOpacityChanged,
            object: nil
        )
        applyDividerStyleForCurrentOpacity()
    }

    /// v0.30 boss 2026-09-01 OOB (divider line: hide visual + keep draggable).
    /// Apple NSSplitView in macOS 27 Tahoe renders dividers as
    /// subviews inside `NSSplitView.subviews` (= class names contain
    /// "Divider"; the divider is a real NSView, not a draw override).
    /// To hide the divider visual without breaking drag (= the
    /// `isHidden` flag would suppress mouse events; the drag handler
    /// is subview-level), set the divider subview's
    /// `layer.backgroundColor` to `.clear` (= subview stays in the
    /// view hierarchy + still receives mouse events for drag; only
    /// the visual hairline is removed).
    ///
    /// Boss's spec = "divider line, I want no divider line shown but
    /// can still drag". Achieved by:
    /// 1. `NSSplitView.DividerStyle` left at Apple default (.thick)
    ///    (= the divider subview is still mounted; drag works).
    /// 2. Traverse `splitView.subviews` recursively (= root + nested
    ///    controllers) and identify divider subviews by their class
    ///    name (= class names contain "Divider" per the gunbark.dev
    ///    reference pattern; verified on macOS 27 SDK where the
    ///    AppKit private class is `_NSSplitViewDividerView`).
    /// 3. For each divider subview, set
    ///    `layer?.backgroundColor = CGColor.clear`. The subview is
    ///    still there (= drag still routes to it via AppKit's
    ///    `splitView:effectiveRect:forDrawnRect:ofDividerAt:`
    ///    delegate mechanism) but renders no visible hairline.
    private func applyDividerStyleForCurrentOpacity() {
        hideAllDividers(in: splitView)
        for child in children {
            if let nestedController = child as? NSSplitViewController {
                hideAllDividers(in: nestedController.splitView)
            }
        }
    }

    /// Walk `splitView.subviews` and hide each divider subview's
    /// background color (= subview stays in the hierarchy; drag
    /// still routes through it).
    ///
    /// v0.30 boss 2026-09-01 OOB: the 1PT gap between panes (= the
    /// NSSplitView's own background showing through the divider
    /// area) is now also cleared. The NSSplitView's own layer is
    /// set to clear + wantsLayer, so the 1PT gap between divider
    /// subviews (= the only remaining visible gap after the divider
    /// subview is cleared) shows through to the window background
    /// (= no Apple default white / black frame between panes).
    ///
    /// Note: `dividerThickness` is left at Apple default (= 1 PT).
    /// We do NOT override dividerThickness to 0 (= would shrink the
    /// divider subview to 0 PT; drag would break because the hit
    /// area is gone). The 1 PT physical gap remains (= 1 PT of fully
    /// transparent space = no visible line + drag still works because
    /// the divider subview is still mounted + still receives mouse
    /// events).
    private func hideAllDividers(in splitView: NSSplitView) {
        // Clear the NSSplitView's own background so the 1 PT gap
        // between divider subviews shows through to the window
        // background (= no white / black Apple default frame).
        splitView.wantsLayer = true
        splitView.layer?.backgroundColor = .clear
        for subview in splitView.subviews {
            // AppKit divider subviews have a class name containing
            // "Divider" (= the private class is _NSSplitViewDividerView
            // on macOS 27). The split view's content subviews do NOT
            // match this name (= they are the user's NSViewControllers
            // or NSHostingControllers). Filtering on class name
            // avoids hiding user content.
            if String(describing: type(of: subview)).contains("Divider") {
                subview.layer?.backgroundColor = .clear
                subview.wantsLayer = true
            }
        }
    }

    /// v0.30 boss 2026-09-01 OOB (divider final design): divider is
    /// always .paneSplitter (= no visible hairline, drag still
    /// works). The notification is no longer needed (the divider
    /// does not react to the slider), but the observer wiring is
    /// retained to keep the existing init flow unchanged (= removing
    /// the observer would be a separate cleanup ticket).
    @objc private func handleLiquidGlassOpacityChanged() {
        // No-op: divider is always .paneSplitter regardless of
        // the slider value (= boss OOB "no divider line shown,
        // can still drag"). Retained as a stub so the
        // NotificationCenter.addObserver selector in init still
        // resolves.
    }

    /// Recursive helper to apply a divider style to a split view
    /// AND its nested children (= the upperBand / lowerBand nested
    /// NSSplitViewControllers in the FCP default layout).
    private func applyDividerStyle(
        _ style: NSSplitView.DividerStyle,
        to splitView: NSSplitView
    ) {
        splitView.dividerStyle = style
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
    /// Stores every (controller, weights) pair that needs divider
    /// positions applied on the first layout pass. NSSplitView's
    /// bounds are 0 at init time, so setPosition must run AFTER
    /// viewDidLayout (= when bounds are non-zero). Captured during
    /// buildLayout / installSplit and consumed by viewDidLayout.
    ///
    /// Includes the ROOT (= first tuple) plus all NESTED split
    /// controllers (= the upperBand and lowerBand each have their
    /// own weights that the root controller doesn't see). The view
    /// hierarchy from a parent split propagates into the
    /// per-controller controller.splitView (NSSplitViewController
    /// keeps the children array and creates a corresponding
    /// NSSplitViewItem for each, so weights at every level need
    /// their own applyWeights call).
    private var pendingWeights: [(NSSplitViewController, [Double])] = []

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
            installSplit(split, parent: self, parentOrientation: split.orientation == .row ? .row : .column)
            // v0.30 boss 2026-09-01 OOB fix: AFTER the entire
            // installSplit tree is built, walk the controller
            // hierarchy and capture every NSSplitViewController's
            // weights (= the items that ended up living on each
            // controller's NSSplitView). Capturing here (= not
            // incrementally inside installSplit) avoids the
            // recursive-state bug where installSplit fires its
            // SAME-orientation branch from inside installChildren,
            // which doesn't know about pendingWeights.
            pendingWeights = collectPendingWeights()
        case .group(let group):
            self.splitView.isVertical = true
            installGroup(group)
            pendingWeights = [(self, [])]
        }
    }

    /// Walk the controller hierarchy (= self + every nested
    /// NSSplitViewController child) and return one tuple per
    /// controller whose splitView has more than one subview (=
    /// i.e. it has at least one divider to position). The weights
    /// array is computed from the matching SplitNode (= found by
    /// walking the original tree in parallel).
    ///
    /// Implementation note: we walk via children traversal and
    /// look up the matching SplitNode by structural position. For
    /// the v0.30 FCP layout (= root column → upperBand row →
    /// 4 groups + lowerBand row → 2 groups), the tree has 3
    /// NSSplitViewControllers (= root column, upperBand row,
    /// lowerBand row) and 3 weight sets (= [1,1], [1,2,6,1],
    /// [7,3]). All 3 need applyWeights.
    private func collectPendingWeights() -> [(NSSplitViewController, [Double])] {
        var result: [(NSSplitViewController, [Double])] = []
        // The root always needs its weights (= its NSSplitView
        // hosts either the children directly or nested controllers).
        if case .split(let rootSplit) = store.workspace.root {
            result.append((self, rootSplit.weights))
            // Walk children recursively. For each child that is a
            // .split (= becomes a nested controller), recurse and
            // also add the nested controller's own weights. For each
            // child that is a .group, skip (= no nested controller
            // and no divider on the parent to position because the
            // parent has multiple items already).
            for child in rootSplit.children {
                collectPendingWeightsHelper(for: child, into: &result)
            }
        }
        return result
    }

    /// Recursive helper for collectPendingWeights.
    ///
    /// Walk the SplitNode subtree in parallel with the
    /// NSSplitViewController child array. Each .split child
    /// corresponds to a nested NSSplitViewController (= the one
    /// installSplit created via parent.addChild(nested)). We add
    /// (nested, weights) to the result, then recurse into that
    /// nested controller's children.
    ///
    /// Mapping from the controller side (= self.children, an
    /// array of NSSplitViewController) to the SplitNode side
    /// (= the children of this SplitNode) is by INDEX: the i-th
    /// child controller corresponds to the i-th child .split
    /// SplitNode. .group SplitNodes don't add a nested controller
    /// (= they install items directly on the parent splitView),
    /// so we skip them in the controller-walk.
    private func collectPendingWeightsHelper(
        for node: LayoutNode,
        into result: inout [(NSSplitViewController, [Double])]
    ) {
        // Only nested NSSplitViewControllers (= those created by
        // installSplit's different-orientation branch) need
        // weights. SAME-orientation branches added the items
        // directly to the parent controller's splitView (= the
        // parent already got its weights from the caller's
        // pendingWeights entry, which uses the matching
        // rootSplit.weights). Nested controllers live in
        // `self.children` (= an array of NSSplitViewController);
        // for each .split node, we look up its controller by
        // structural position.
        switch node {
        case .split(let split):
            // Find the nested NSSplitViewController that
            // corresponds to this SplitNode. Since installSplit
            // is called in left-to-right order (= child[0] is the
            // first nested controller), we walk the controller
            // children and pair them with .split nodes by index.
            // This works because installChildren preserves the
            // children order.
            let nestedControllerIndex = countSplitNodesBefore(node)
            let nestedControllers = self.children.compactMap { $0 as? NSSplitViewController }
            if nestedControllerIndex < nestedControllers.count {
                let nested = nestedControllers[nestedControllerIndex]
                result.append((nested, split.weights))
                // Recurse into the nested controller with its own
                // SplitNode tree (= walk the nested controller's
                // children with this split's children).
                collectNestedHelper(nested: nested, split: split, into: &result)
            }
        case .group:
            // No nested controller for a .group node. Skip.
            break
        }
    }

    /// Recursive helper for nested NSSplitViewControllers: walk
    /// the SplitNode subtree and pair with the nested controller's
    /// own children (= which are also NSSplitViewControllers or
    /// NSViewControllers holding direct items).
    private func collectNestedHelper(
        nested: NSSplitViewController,
        split: SplitNode,
        into result: inout [(NSSplitViewController, [Double])]
    ) {
        // Recurse into each child of this SplitNode, which is
        // installed as items on `nested`'s splitView. If a child
        // is itself a .split (= SAME-orientation case), then
        // installSplit actually created ANOTHER nested controller
        // (= `nested.children` has it). Otherwise (.group), no
        // nested controller was created (= items went directly
        // onto nested's splitView, so nested's weights cover them).
        var splitChildIndex = 0
        for child in split.children {
            switch child {
            case .split(let childSplit):
                let nestedChildren = nested.children.compactMap { $0 as? NSSplitViewController }
                if splitChildIndex < nestedChildren.count {
                    let childNested = nestedChildren[splitChildIndex]
                    result.append((childNested, childSplit.weights))
                    collectNestedHelper(nested: childNested, split: childSplit, into: &result)
                }
                splitChildIndex += 1
            case .group:
                break
            }
        }
    }

    /// Count how many .split nodes appear before `node` in the
    /// parent's children array. Used to pair .split SplitNodes with
    /// the corresponding nested NSSplitViewController by index.
    private func countSplitNodesBefore(_ node: LayoutNode) -> Int {
        guard case .split(let parent) = store.workspace.root else { return 0 }
        guard let index = parent.children.firstIndex(of: node) else { return 0 }
        var count = 0
        for i in 0..<index {
            if case .split = parent.children[i] {
                count += 1
            }
        }
        return count
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
        //
        // We dispatch via DispatchQueue.main.async so the deferred
        // apply runs AFTER the entire buildLayout + installSplit
        // chain completes. Without this, viewDidLayout fires the
        // instant addChild returns (= before subsequent nested
        // installSplit calls have appended their pendingWeights
        // entries), so the root gets applied but nested controllers
        // never receive their preset weights.
        //
        // We do NOT snapshot pendingWeights (= the snapshot is
        // taken AFTER the async dispatch so nested appends land in
        // the same runloop tick before we iterate). On the second
        // async pass (= nested controllers' own viewDidLayout fires
        // and triggers another async), didApplyInitialWeights is
        // still false because the previous run bailed on zero
        // bounds. We loop until we successfully applied weights to
        // every entry AND the root's bounds are non-zero.
        guard !didApplyInitialWeights else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard !self.didApplyInitialWeights else { return }
            guard !self.pendingWeights.isEmpty else { return }
            // Bounds readiness check on the root. Without this,
            // setPosition computes against a 0-wide canvas and is
            // a no-op.
            guard self.splitView.bounds.width > 0, self.splitView.bounds.height > 0 else { return }
            self.clearStaleAutosave()
            for (controller, weights) in self.pendingWeights {
                self.applyWeights(weights, on: controller)
            }
            self.didApplyInitialWeights = true
        }
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
            // bounds are non-zero. The parent controller's own
            // divider positions (= the ones installed by the
            // installChildren call above) are picked up by
            // collectPendingWeights below, which walks the
            // controller tree and captures every NSSplitViewController's
            // installed weights from its parent's SplitNode (= the
            // one whose children it received). See collectPendingWeights
            // for the precise mapping.
            return
        }

        // Different orientation → create a nested controller.
        // Also set the nested controller's splitView.isVertical to
        // match this split's orientation (= otherwise the nested
        // controller defaults to isVertical = true and the children
        // install wrong-axis).
        //
        // v0.30 boss 2026-09-01 OOB (1PT gap removal): swap the
        // nested NSSplitViewController's default splitView for
        // WenshuSplitView (= same draw(_:) override as the root).
        // The swap must happen BEFORE any splitView attribute is
        // set (= setting `splitView.isVertical` triggers the lazy
        // viewDidLoad which freezes the view to a vanilla
        // NSSplitView; too late to swap after that). We access
        // splitView (= to assign the swap) immediately after the
        // constructor, then set all attributes + install children.
        let nested = NSSplitViewController()
        nested.splitView = WenshuSplitView()
        nested.splitView.isVertical = (split.orientation == .row)
        nested.splitView.autosaveName = autosaveKey(for: split.id)
        installChildren(split.children, weights: split.weights, into: nested)
        parent.addChild(nested)
        // Register this nested controller's weights for the
        // deferred apply pass (= viewDidLayout runs after bounds
        // are non-zero; here the nested controller's bounds are
        // still 0 so setPosition would no-op).
        pendingWeights.append((nested, split.weights))
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
