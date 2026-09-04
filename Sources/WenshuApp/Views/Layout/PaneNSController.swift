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
        layoutID: String,
        installObservers: Bool = true,
        subtree: LayoutNode? = nil
    ) {
        self.store = store
        self.appState = appState
        self.bookStore = bookStore
        self.layoutID = layoutID
        // v0.30 boss 2026-09-01 OOB (zone toggle fix): nested
        // PaneNSController instances (= created by installSplit's
        // different-orientation branch) render only the subtree
        // they own. The previous design had every nested instance
        // re-read `store.workspace.root` (= the FULL tree) in
        // buildLayout, which then re-entered installSplit at the
        // top level and recursed forever. Passing the subtree
        // explicitly here makes nested controllers render exactly
        // what their parent assigned them.
        //
        // Also: when invoked from installSplit's
        // different-orientation branch (= the only nested path),
        // the parent has ALREADY called `installChildren(children,
        // into: nested)` on line 984 (= immediately after `let
        // nested = PaneNSController(...)`). Running buildLayout
        // here too would double-install the children (= 8 items
        // for a 4-pane band = crash in applyWeights' divider
        // iteration). The `installObservers: false` path already
        // signals "nested instance"; we extend it to also skip
        // buildLayout. `installObservers: true` (= the public
        // entrypoint from FCPLayout.makeSplitController) keeps
        // the full buildLayout path so the root controller still
        // gets its tree built.
        self.subtree = subtree ?? store.workspace.root
        super.init(nibName: nil, bundle: nil)
        // Swap the default NSSplitView with WenshuSplitView
        // (= NSSplitView subclass with adjustSubviews override that
        // makes pane frames touch). This must run BEFORE any code
        // accesses `self.view` (= triggers NSSplitViewController's
        // internal viewDidLoad that defaults the view to a vanilla
        // NSSplitView; too late to swap after that). Per
        // NSSplitViewController.h header: "To provide a custom
        // NSSplitView, set the splitView property anytime before
        // self.viewLoaded is YES." We swap immediately after
        // super.init and before buildLayout (= which calls self.view).
        self.splitView = WenshuSplitView()
        if installObservers {
            buildLayout()
        }
        // Widen the divider hit area (= see AC #4). Acting as the
        // split's delegate lets us override `effectiveRect(...)` and
        // extend each divider's grabbable region by `dividerHitPadding`.
        self.splitView.delegate = self
        // v0.30 boss 2026-09-01 OOB (zone toggle fix): nested
        // PaneNSController instances are created by installSplit
        // (= the parent child-controller path), so they re-enter this
        // init. Without the `installObservers` gate, every nested
        // controller would also register the `.wenshuToggleZone`
        // observer and `applyPersistedZoneVisibility` would run
        // repeatedly for every fold. Keep the observers on the
        // root only (= single source of truth) — nested instances
        // just hold the `paneKindByItem` map that the root walks.
        guard installObservers else { return }
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
        // v0.32 boss 2026-09-02 OOB ('用 macOS 自带液态玻璃,
        // 跟随系统设置'): removed the
        // .liquidGlassOpacityChanged NotificationCenter observer
        // (= the user-tunable slider + cross-instance notification
        // was deleted; Apple .glassEffect auto-applies via the
        // system without per-app notification plumbing).
        applyDividerStyleForCurrentOpacity()
        // v0.30 boss 2026-09-01 OOB (zone toggle startup sync): apply the
        // persisted `wenshu.zoneVisible.*` bools from UserDefaults to
        // the matching NSSplitViewItems NOW (= not on a notification,
        // because no toggle has happened yet on a fresh launch). Without
        // this, items always start expanded even when the user previously
        // hid a zone (= every launch reopens hidden zones = boss
        // feedback '已经失效'). Read defaults directly (= no AppStorage
        // dance in this AppKit class) to keep the AppKit side free of
        // SwiftUI property wrappers. The same call is repeated from
        // viewDidLayout after the first weights apply (= NSSplitView's
        // autosaveName round-trip can otherwise override the fold we
        // set here).
        applyPersistedZoneVisibility()
    }

    /// Apply `wenshu.zoneVisible.*` defaults to the matching
    /// NSSplitViewItems. Runs once at init.
    ///
    /// v0.30 boss 2026-09-01 OOB: recursively walks self + every
    /// nested PaneNSController child. Without the recursion, the
    /// root's `splitViewItems` only contains the upper-band and
    /// lower-band nested controllers (= wrap-mode items, canCollapse
    /// = false), so the per-pane TabKind match never finds anything
    /// to fold on a 6-zone layout. The nested controllers are where
    /// the actual pane NSSplitViewItems live (= canCollapse = true).
    private func applyPersistedZoneVisibility() {
        let defaults = UserDefaults.standard
        let mapping: [(String, TabKind)] = [
            ("wenshu.zoneVisible.projectSidebar", .projectSidebar),
            ("wenshu.zoneVisible.projectPreview", .projectPreview),
            ("wenshu.zoneVisible.specializedTools", .specializedTools),
            ("wenshu.zoneVisible.aiChat", .aiChat),
            ("wenshu.zoneVisible.aiDynamic", .aiDynamic)
        ]
        // Flatten self + nested children controllers. The root walk
        // is required because nested PaneNSController instances are
        // created by `installSplit` and live as root.splitViewItems
        // (= wrap-mode items, canCollapse = false). The per-pane
        // TabKind lookup goes through `paneKindByItem`, populated
        // by `makeSplitItems` at install time (= works regardless of
        // whether NSHostingController has laid out its SwiftUI tree).
        var controllers: [NSSplitViewController] = [self]
        var queue: [NSSplitViewController] = [self]
        while let next = queue.first {
            queue.removeFirst()
            for child in next.children {
                if let splitChild = child as? PaneNSController {
                    controllers.append(splitChild)
                    queue.append(splitChild)
                }
            }
        }
        for (key, kind) in mapping {
            guard defaults.object(forKey: key) != nil else { continue }
            let shouldHide = !defaults.bool(forKey: key)
            guard shouldHide else { continue }
            for controller in controllers {
                guard let paneController = controller as? PaneNSController else { continue }
                for (idx, item) in controller.splitViewItems.enumerated() {
                    guard item.canCollapse else { continue }
                    guard let tab = paneController.paneKindByItem[idx] else { continue }
                    if tab == kind {
                        item.isCollapsed = true
                    }
                }
            }
        }
    }

    /// v0.30 boss 2026-09-01 OOB (Step 1 = restore API default): do NOT
    /// set the divider style programmatically. Apple NSSplitView
    /// uses `.thick` by default (= the legacy divider visual). The
    /// Liquid Glass slider does NOT influence the divider in this
    /// interim state. Pane separation is conveyed by pane chrome
    /// background-color difference (= the slider controls each pane's
    /// background tint independently); the divider line is left at
    /// Apple default.
    ///
    /// Per boss 2026-09-01 OOB: "if there is no corresponding API,
    /// do not implement it" — Apple NSSplitView.DividerStyle is an
    /// enum with no alpha API; controlling the divider visual at all
    /// is off the table until boss picks an implementation that
    /// satisfies all constraints (= visually 1 PT hairline + hidden
    /// when slider = 0 + does not break the layout).
    ///
    /// Step 2 (= TBD): a different divider implementation that
    /// satisfies all three constraints. Candidates boss can
    /// choose between (recorded for the follow-up spec):
    /// - A: keep .thick as Apple default (= current Step 1 state).
    /// - B: Subclass NSSplitView (= WenshuSplitView) constructed
    ///   BEFORE super.init (= cannot swap self.splitView post-init
    ///   per the b26639d65 layout-breaking precedent; the subclass
    ///   must be installed at view-creation time).
    /// - C: Drop NSSplitView entirely and build the 6-zone layout
    ///   with SwiftUI HStack / VStack dividers (= SwiftUI does not
    ///   expose a custom divider alpha either, but the divider
    ///   would be SwiftUI-native and controllable via overlay).
    private func applyDividerStyleForCurrentOpacity() {
        // v0.30 boss 2026-09-01 OOB (divider final design):
        //   - Width: 1 PT (= Apple default dividerStyle .thin;
        //     boss accepted the Apple limit and pivoted from the
        //     earlier .paneSplitter / 0-width / no-line attempts
        //     to the standard HIG hairline).
        //   - Visual: a visible 1 PT hairline in system dark color
        //     (= 100% opaque alpha=1, dark-mode-measured sRGB approx (0.09,
        //     0.09, 0.09); auto-adapts to light / dark mode). Per
        //     boss OOB "if a gap is required, I want a 1 PT visible
        //     system dark 100% opaque line".
        //   - Drag: works regardless of the tint. AppKit routes
        //     mouseDown events to the divider subview's hit-area;
        //     the effectiveRect delegate override (= 4 PT padding)
        //     still extends the hit-area to make the divider easy
        //     to grab.
        //   - Slider: does NOT influence the divider (= per Apple
        //     API surface there is no per-alpha control on the
        //     divider; boss rule = "if no corresponding API, do
        //     not implement it").
        //
        // The adjustSubviews override on WenshuSplitView (= the
        // subclass this controller sets as self.splitView in init)
        // still makes pane frames touch (= the 1 PT hairline is
        // drawn by the divider subview itself, not by a gap in the
        // pane layout).
        for splitView in allSplitViews() {
            applyDividerStyle(.thin, to: splitView)
        }
    }

    /// Walk the controller + nested NSSplitViewControllers to
    /// collect every NSSplitView (= the root + each nested split).
    private func allSplitViews() -> [NSSplitView] {
        var result: [NSSplitView] = [splitView]
        for child in children {
            if let nested = child as? NSSplitViewController {
                result.append(nested.splitView)
            }
        }
        return result
    }

    /// v0.30 boss 2026-09-01 OOB: 1 PT ok + paneSplitter + hit-area
    /// hidden was wrong (= Apple .paneSplitter leaves an 8 PT
    /// physical gap between subviews even with dividerColor alpha=0;
    /// the gap is what the boss sees as a 'wide divider line').
    /// Real fix = subclass NSSplitView and override adjustSubviews
    /// to shift each non-divider subview's origin so the frames
    /// touch (= no visible gap between panes). The divider subview
    /// is still mounted at its Apple-default width (= 8 PT for
    /// .paneSplitter, 1 PT for .thin / .thick); AppKit still
    /// routes mouseDown events to it (= drag works).
    // paint divider subview with `Color.white.opacity(0.25)` (= 1 PT
    // hairline visible against any pane background; per boss OOB
    // round "if a gap is required, I want a 1 PT visible hairline").
    // The `Color.white.opacity(0.25)` recipe is from wenshu commit
    // `62bb205bb` (= known-good on macOS 26+; visible on dark mode
    // and adaptive on light mode).
    @MainActor
    final class WenshuSplitView: NSSplitView {
        override func draw(_ dirtyRect: NSRect) {
            // No-op: the divider subview itself is the only thing
            // NSSplitView draws between subviews. The 1 PT hairline
            // tint is set on the divider subview's wantsLayer +
            // backgroundColor in `paintDividerHairline(...)` below;
            // this empty override exists for documentation / safety.
        }

        override func adjustSubviews() {
            // Apple's default layout (= super) sets each subview
            // width according to its divider position weight +
            // leaves a 1 PT or 8 PT (= depends on dividerStyle)
            // gap between adjacent subviews (= the NSSplitView.h
            // header doc: "Delegates that respond to this message
            // should adjust the frames of the uncollapsed subviews
            // so that they exactly fill the split view with room
            // for dividers in between"). The room for dividers is
            // exactly the gap the boss sees as the 'wide line'.
            //
            // Fix = after super, walk the subviews. For each
            // non-divider subview, set its frame.origin to the
            // previous non-divider subview's maxX (= makes the
            // frames touch = no gap). Keep the divider subview's
            // frame at its current bounds (= AppKit's internal
            // divider hit-area is preserved = drag still works).
            //
            // v0.32 boss 2026-09-02 OOB ('线看不出来就不重要了;
            // 你所有用的颜色, 都是 API 给的, 不要自定义'): the
            // divider subview is NOT painted (= no NSColor /
            // custom RGB blend). Adjacent panes are differentiated
            // by pane background NSColor (= Apple API only).
            // The divider subview remains mounted (= Apple default;
            // drag hit-area preserved) but renders nothing.
            super.adjustSubviews()

            let isVert = isVertical
            let bounds = self.bounds
            var running: CGFloat = 0
            for subview in subviews {
                let className = String(describing: type(of: subview))
                if className.contains("Divider") {
                    // Place the divider subview at running (= the
                    // gap between the previous pane and the next)
                    // and keep its current width (= Apple default
                    // hit-area for the chosen dividerStyle =
                    // 8 PT for .paneSplitter, 1 PT for .thin /
                    // .thick). The hit-area is preserved so drag
                    // still works; the divider is just sandwiched
                    // between two touching pane frames instead of
                    // an additional gap.
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
                } else {
                    // Content pane: shift origin to running (= the
                    // previous subview's maxX, whether divider or
                    // content). The pane's width is kept at the
                    // value super computed (= Apple's
                    // weight-based layout from setPosition).
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
                    running = isVert
                        ? subview.frame.maxX
                        : subview.frame.maxY
                }
            }
            // The last content subview now extends past the
            // divider region (= maxX > bounds.max). Trim it back
            // so the total fills bounds exactly. This is necessary
            // because Apple's super layout reserved gap room
            // between the last subview and the bounds edge; that
            // gap is now in the last subview's width.
            if let lastContent = subviews.last(where: {
                !String(describing: type(of: $0)).contains("Divider")
            }) {
                if isVert {
                    let excess = lastContent.frame.maxX - bounds.maxX
                    if excess > 0 {
                        lastContent.frame = NSRect(
                            x: lastContent.frame.origin.x,
                            y: 0,
                            width: lastContent.frame.width - excess,
                            height: bounds.height
                        )
                    }
                } else {
                    let excess = lastContent.frame.maxY - bounds.maxY
                    if excess > 0 {
                        lastContent.frame = NSRect(
                            x: 0,
                            y: lastContent.frame.origin.y,
                            width: bounds.width,
                            height: lastContent.frame.height - excess
                        )
                    }
                }
            }
        }
    }

    /// v0.30 boss 2026-09-01 OOB (divider Step 1 = API default): the
    /// observer still receives the notification but does not mutate
    // v0.32 boss 2026-09-02 OOB: removed the
    /// \`handleLiquidGlassOpacityChanged\` @objc selector (= the
    /// NotificationCenter observer that called it was deleted in
    /// init). Apple canonical .glassEffect auto-applies system-wide
    /// without per-instance notification plumbing.

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
    ///
    /// v0.30 boss 2026-09-01 OOB (zone toggle fix): walks self + all
    /// nested PaneNSController children. The root controller's
    /// splitViewItems only contain wrap-mode items for the
    /// upper/lower bands (= canCollapse = false), so the per-pane
    /// TabKind match never found anything to fold without the
    /// recursion. See applyPersistedZoneVisibility() for the
    /// matching initial-state logic.
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
        // Flatten self + nested children PaneNSControllers. Each
        // PaneNSController instance owns the `paneKindByItem` map
        // for its subtree (= populated by `makeSplitItems` at install
        // time), so the lookup goes straight from item to TabKind
        // without depending on the SwiftUI hosting tree having laid
        // out (= which only happens after init, so the original
        // `firstTabKind(for:)` heuristic silently returned nil on
        // startup). Keep observers on the root only via the
        // `installObservers` init gate so a single notification
        // triggers exactly one fold per matching pane.
        var controllers: [NSSplitViewController] = [self]
        var queue: [NSSplitViewController] = [self]
        while let next = queue.first {
            queue.removeFirst()
            for child in next.children {
                if let splitChild = child as? PaneNSController {
                    controllers.append(splitChild)
                    queue.append(splitChild)
                }
            }
        }
        for controller in controllers {
            guard let paneController = controller as? PaneNSController else { continue }
            for (idx, item) in controller.splitViewItems.enumerated() {
                guard item.canCollapse else { continue }
                guard let tab = paneController.paneKindByItem[idx] else { continue }
                if tab == kind {
                    // v0.34 B-12 (= boss 2026-09-02 OOB '各区显示隐藏
                    // 也存在同样的 bug = 因为只记录显隐不也记录其他,
                    // 导致显隐多次后, 视图完全混乱'): capture full
                    // 6-zone state BEFORE hiding (= Q38 boss "全状态
                    // snapshot" decision applied to the per-zone toggle
                    // path too, mirroring ticket 02's expand path). When
                    // restoring (= un-hiding), the toggleZone re-runs the
                    // capture-then-collapse branch, which is a no-op when
                    // the snapshot JSON already matches the desired layout
                    // state (= idempotent re-toggle under spec).
                    let willHide = !item.isCollapsed
                    if willHide {
                        captureZoneToggleSnapshot(slot: slot)
                    }
                    // v0.34 boss 2026-09-02 OOB '5 个 toolbar button 缺
                    // push/pop 动画, 用 apple api 默认': route through
                    // NSSplitViewItem.animator() (= AppKit canonical
                    // animated property proxy) for the default AppKit
                    // collapse/expand transition (= the same
                    // push/pop animation as Finder sidebar hide/show,
                    // Mail message pane hide/show, etc.). Plain
                    // `item.isCollapsed.toggle()` (= the prior form)
                    // is an instant snap (= no transition).
                    item.animator().isCollapsed.toggle()
                    // B-12: restore full state after un-hiding (= mirror
                    // of ticket 02's restoreEditorExpandSnapshot; here
                    // we restore on a single-zone un-hide so multi-toggle
                    // sequences converge to the user's intended layout
                    // instead of accumulating stale state).
                    if !willHide {
                        restoreZoneToggleSnapshot()
                    }
                }
            }
        }
        // v0.30 boss 2026-09-01 OOB (auto-fill band on full
        // collapse): after toggling, re-pin the root divider so
        // the upper band fills the whole root height when the
        // lower band is now fully hidden. Only the root observer
        // (= us, since `installObservers: true` is the root-only
        // path) actually has a root divider to move, but the
        // guard inside adjustRootForCollapsedBands makes it safe
        // to call from anywhere.
        adjustRootForCollapsedBands()
    }

    /// v0.34 B-12: capture the 6 zone's isCollapsed state + per-zone
    /// split weight (= holdingPriority.rawValue) to UserDefaults JSON
    /// under key `wenshu.zoneToggle.snapshot`. Mirror of ticket 02's
    /// `captureEditorExpandSnapshot` (= separate key + slot parameter so
    /// the editor-expand and zone-toggle paths don't interfere).
    /// `slot` = the slot being hidden, recorded in the JSON for
    /// diagnostics (= which toggle triggered this snapshot).
    private func captureZoneToggleSnapshot(slot: ZoneSlot) {
        var snapshot: [String: Any] = [:]
        snapshot["triggeredBy"] = zoneSlotKey(slot)
        // 1. 6 zone isCollapsed state (= canonical ZoneSlot string names
        // via zoneSlotKey from ticket 02).
        var zoneVisible: [String: Bool] = [:]
        for s in allZoneSlots() {
            zoneVisible[zoneSlotKey(s)] = isZoneVisible(s)
        }
        snapshot["zoneVisible"] = zoneVisible
        // 2. Per-zone split weight (= holdingPriority.rawValue from
        // NSSplitViewItem). Reuse zoneSlotKey for stable keys.
        var weights: [String: Double] = [:]
        for s in allZoneSlots() {
            if let w = currentZoneSplitWeight(s) {
                weights[zoneSlotKey(s)] = w
            }
        }
        snapshot["weights"] = weights
        // 3. Serialize to JSON for UserDefaults.
        if let data = try? JSONSerialization.data(withJSONObject: snapshot, options: []),
           let json = String(data: data, encoding: .utf8) {
            UserDefaults.standard.set(json, forKey: "wenshu.zoneToggle.snapshot")
        }
    }

    /// v0.34 B-12: read snapshot JSON, restore per-zone weight first
    /// then visibility (= mirror of ticket 02's restoreEditorExpandSnapshot;
    /// separate snapshot key = doesn't conflict with editor-expand restore).
    private func restoreZoneToggleSnapshot() {
        guard let json = UserDefaults.standard.string(forKey: "wenshu.zoneToggle.snapshot"),
              let data = json.data(using: .utf8),
              let snapshot = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        else { return }
        // Weight first (= so visibility flip later applies the correct
        // starting frame). Reuse applyEditorSplitWeight-equivalent helper:
        // extend to a generic per-slot weight applier.
        if let weights = snapshot["weights"] as? [String: Double] {
            for s in allZoneSlots() {
                if let w = weights[zoneSlotKey(s)] {
                    applyZoneSplitWeight(s, weight: w)
                }
            }
        }
        // Zone visibility restore (= call toggleZone if state differs).
        if let zoneVisible = snapshot["zoneVisible"] as? [String: Bool] {
            for s in allZoneSlots() {
                let key = zoneSlotKey(s)
                guard let wantVisible = zoneVisible[key] else { continue }
                let isVisible = isZoneVisible(s)
                if wantVisible != isVisible {
                    toggleZone(s)
                }
            }
        }
    }

    /// v0.34 B-12: read a non-editor zone's current split weight (= same
    /// holdingPriority.rawValue technique as ticket 02's
    /// currentEditorSplitWeight, but generalized to any ZoneSlot).
    private func currentZoneSplitWeight(_ slot: ZoneSlot) -> Double? {
        guard let kind = zoneSlotToTabKind(slot) else { return nil }
        for (idx, item) in splitViewItems.enumerated() {
            guard let tab = paneKindByItem[idx], tab == kind else { continue }
            return Double(item.holdingPriority.rawValue)
        }
        // Recurse into children (= same flatten as handleToggleZone).
        for child in children {
            if let splitChild = child as? PaneNSController,
               let weight = splitChild.currentZoneSplitWeight(slot) {
                return weight
            }
        }
        return nil
    }

    /// v0.34 B-12: apply a per-zone split weight (= mirror of ticket 02's
    /// applyEditorSplitWeight, generalized to any ZoneSlot).
    private func applyZoneSplitWeight(_ slot: ZoneSlot, weight: Double) {
        guard let kind = zoneSlotToTabKind(slot) else { return }
        let clamped = NSLayoutConstraint.Priority(Float(max(0.0, min(weight, 1.0))))
        for (idx, item) in splitViewItems.enumerated() {
            guard let tab = paneKindByItem[idx], tab == kind else { continue }
            item.holdingPriority = clamped
        }
        for child in children {
            if let splitChild = child as? PaneNSController {
                splitChild.applyZoneSplitWeight(slot, weight: weight)
            }
        }
    }

    // v0.34 ticket 02 (= spec .scratch/v0.34-editor-preview-and-expand/spec.md).
    // Mirror of handleToggleZone for the editor-expand path:
    // when @AppStorage("wenshu.editorMaximized") flips, the
    // EditorExpandShrinkTrailingButton posts
    // Notification.Name.wenshuEditorMaximizedChanged with the
    // new Bool as the object payload. We then either:
    //
    //   (a) snapshot the 6 zone's isCollapsed state + editor zone
    //       split weight to UserDefaults JSON BEFORE hiding the
    //       5 non-editor zones (= Q38 boss decision: 全状态
    //       snapshot, not just zone visible), so shrink restore
    //       can return to the exact pre-expand layout;
    //
    //   (b) read the snapshot JSON and restore the same 6 zone
    //       state on shrink (= reverse order matters: editor
    //       weight first, then visibility).
    //
    // Notification flow (= boss 9/2 B-04 pattern, see AppCommands
    // + AppNotifications.swift for the single source of truth).
    @objc func handleEditorMaximizedChanged(_ notification: Notification) {
        let maximize = (notification.object as? Bool) ?? false
        if maximize {
            captureEditorExpandSnapshot()
            collapseAllNonEditorZones()
        } else {
            restoreEditorExpandSnapshot()
        }
        // Same auto-fill band pin as handleToggleZone (= keep upper
        // band filling root height when lower band goes fully
        // hidden on expand).
        adjustRootForCollapsedBands()
    }

    /// v0.34 ticket 02: capture the 6 zone's isCollapsed state + the
    /// editor zone's current split weight (= Q38 boss "全状态 snapshot"
    /// decision). Written to UserDefaults BEFORE any layout mutation,
    /// so the restore path reads back the exact pre-expand layout.
    private func captureEditorExpandSnapshot() {
        var snapshot: [String: Any] = [:]
        // 1. 6 zone isCollapsed state (canonical ZoneSlot string names).
        // ZoneSlot is a plain enum (= not String-backed, no rawValue);
        // use String(describing:) for stable JSON keys (= case names).
        var zoneVisible: [String: Bool] = [:]
        for slot in allZoneSlots() {
            zoneVisible[zoneSlotKey(slot)] = isZoneVisible(slot)
        }
        snapshot["zoneVisible"] = zoneVisible
        // 2. Editor zone split weight (= for restoring the editor's
        // relative size on shrink). Nil if editor not measurable
        // (= safe default = nil).
        snapshot["editorWeight"] = currentEditorSplitWeight()
        // 3. Serialize to JSON for UserDefaults.
        if let data = try? JSONSerialization.data(withJSONObject: snapshot, options: []),
           let json = String(data: data, encoding: .utf8) {
            UserDefaults.standard.set(json, forKey: "wenshu.editorExpand.snapshot")
        }
    }

    /// v0.34 ticket 02: read snapshot from UserDefaults, restore 6 zone
    /// isCollapsed + editor split weight (= reverse of capture, so editor
    /// weight first, then visibility).
    private func restoreEditorExpandSnapshot() {
        guard let json = UserDefaults.standard.string(forKey: "wenshu.editorExpand.snapshot"),
              let data = json.data(using: .utf8),
              let snapshot = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        else { return }
        // Editor weight first (= so visibility flip later applies the
        // correct starting frame).
        if let weight = snapshot["editorWeight"] as? Double {
            applyEditorSplitWeight(weight)
        }
        // Zone visibility restore.
        if let zoneVisible = snapshot["zoneVisible"] as? [String: Bool] {
            for slot in allZoneSlots() {
                let key = zoneSlotKey(slot)
                guard let wantVisible = zoneVisible[key] else { continue }
                let isVisible = isZoneVisible(slot)
                if wantVisible != isVisible {
                    toggleZone(slot)
                }
            }
        }
    }

    /// v0.34 ticket 02: stable JSON key for a ZoneSlot case (= mirror
    /// Swift's `\(slot)` interpolation, which yields "projectSidebar"
    /// etc.; used as the dictionary key in the snapshot JSON).
    private func zoneSlotKey(_ slot: ZoneSlot) -> String {
        switch slot {
        case .projectSidebar:   return "projectSidebar"
        case .projectPreview:   return "projectPreview"
        case .editor:           return "editor"
        case .specializedTools: return "specializedTools"
        case .aiChat:           return "aiChat"
        case .aiDynamic:        return "aiDynamic"
        }
    }

    /// v0.34 ticket 02: explicit list of all ZoneSlot cases (= ZoneSlot
    /// is not CaseIterable; mirror the enum's 6-case definition here).
    private func allZoneSlots() -> [ZoneSlot] {
        [.projectSidebar, .projectPreview, .editor,
         .specializedTools, .aiChat, .aiDynamic]
    }

    /// v0.34 ticket 02: query isCollapsed across self + nested
    /// PaneNSControllers for a ZoneSlot. True = zone is currently
    /// visible (= not collapsed). Helper for captureEditorExpandSnapshot.
    private func isZoneVisible(_ slot: ZoneSlot) -> Bool {
        let kind = zoneSlotToTabKind(slot)
        guard let kind else { return true }
        for (idx, item) in splitViewItems.enumerated() {
            guard let tab = paneKindByItem[idx], tab == kind else { continue }
            return !item.isCollapsed
        }
        // Check nested controllers (= same flatten as handleToggleZone).
        for child in children {
            if let splitChild = child as? PaneNSController,
               let visible = splitChild.isZoneVisibleRecursive(kind) {
                return visible
            }
        }
        return true
    }

    private func isZoneVisibleRecursive(_ kind: TabKind) -> Bool? {
        for (idx, item) in splitViewItems.enumerated() {
            guard let tab = paneKindByItem[idx], tab == kind else { continue }
            return !item.isCollapsed
        }
        for child in children {
            if let splitChild = child as? PaneNSController,
               let visible = splitChild.isZoneVisibleRecursive(kind) {
                return visible
            }
        }
        return nil
    }

    /// v0.34 ticket 02: collapse the 5 non-editor zones (= hide sidebar /
    /// preview / tools / chat / dynamic; editor stays visible and takes
    /// the freed space).
    private func collapseAllNonEditorZones() {
        let nonEditor: [ZoneSlot] = [.projectSidebar, .projectPreview,
                                    .specializedTools, .aiChat, .aiDynamic]
        for slot in nonEditor where isZoneVisible(slot) {
            toggleZone(slot)
        }
    }

    /// v0.34 ticket 02: ZoneSlot → TabKind canonical mapping (= mirror
    /// of the switch in handleToggleZone, factorised out for reuse).
    private func zoneSlotToTabKind(_ slot: ZoneSlot) -> TabKind? {
        switch slot {
        case .projectSidebar: return .projectSidebar
        case .projectPreview: return .projectPreview
        case .editor: return .editor
        case .specializedTools: return .specializedTools
        case .aiChat: return .aiChat
        case .aiDynamic: return .aiDynamic
        }
    }

    /// v0.34 ticket 02: read the editor zone's current split weight.
    /// Returns nil if the editor isn't measureable from this controller
    /// (= e.g. nested in a child; the root observer's call still works).
    private func currentEditorSplitWeight() -> Double? {
        for (idx, item) in splitViewItems.enumerated() {
            guard let tab = paneKindByItem[idx], tab == .editor else { continue }
            // NSSplitViewItem.holdingPriority is NSLayoutConstraint.Priority
            // (= wraps a Float); use .rawValue to get the underlying
            // value, then Double-promote for JSON serialization.
            return Double(item.holdingPriority.rawValue)
        }
        // Recurse into children (= same flatten as handleToggleZone).
        for child in children {
            if let splitChild = child as? PaneNSController,
               let weight = splitChild.currentEditorSplitWeight() {
                return weight
            }
        }
        return nil
    }

    /// v0.34 ticket 02: restore the editor zone's prior split weight
    /// (= `holdingPriority` is AppKit's canonical property for this;
    /// same value captured in currentEditorSplitWeight). If the
    /// weight argument is nil, no-op (= safe default).
    private func applyEditorSplitWeight(_ weight: Double) {
        // NSLayoutConstraint.Priority(rawValue:) takes a Float directly
        // (= no String coercion needed). Clamp to [0, 1] to avoid
        // out-of-range priority warnings (= rawValue > 1 is invalid).
        let clamped = NSLayoutConstraint.Priority(Float(max(0.0, min(weight, 1.0))))
        for (idx, item) in splitViewItems.enumerated() {
            guard let tab = paneKindByItem[idx], tab == .editor else { continue }
            item.holdingPriority = clamped
        }
        for child in children {
            if let splitChild = child as? PaneNSController {
                splitChild.applyEditorSplitWeight(weight)
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
    /// v0.30 boss 2026-09-01 OOB (zone toggle fix): records each
    /// installed NSSplitViewItem's TabKind by its positional
    /// index in `controller.splitViewItems` (NOT by
    /// ObjectIdentifier; see `makeSplitItems` for why). Keyed by
    /// `Int` (= index) so lookup at viewDidLayout / notification
    /// handling time works regardless of whether NSSplitViewController
    /// re-wrapped the items. Index 0 is enough for v0.30 because
    /// every GroupNode renders exactly one pane (= multi-pane
    /// groups are flattened by `makeSplitItems`).
    private var paneKindByItem: [Int: TabKind] = [:]
    /// v0.30 boss 2026-09-01 OOB (zone toggle fix): the subtree this
    /// controller renders. The root instance renders `store.workspace.root`
    /// (= the full tree); nested instances render the SplitNode they
    /// were assigned by their parent installSplit call. Without this
    /// distinction, every nested controller would re-enter installSplit
    /// at the top of the tree (= infinite recursion + stack overflow).
    private let subtree: LayoutNode

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
        // v0.30 boss 2026-09-01 OOB (zone toggle fix): read the
        // subtree this controller owns (= NOT `store.workspace.root`,
        // which would re-enter installSplit at the top of the full
        // tree when called on a nested instance).
        switch subtree {
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
        // v0.30 boss 2026-09-01 OOB (zone toggle fix): read the
        // owned subtree, not store.workspace.root (= see buildLayout).
        if case .split(let rootSplit) = subtree {
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
        guard !self.didApplyInitialWeights else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard !self.didApplyInitialWeights else { return }
            guard !self.pendingWeights.isEmpty else { return }
            guard self.splitView.bounds.width > 0, self.splitView.bounds.height > 0 else { return }
            for (controller, weights) in self.pendingWeights {
                self.applyWeights(weights, on: controller)
            }
            self.didApplyInitialWeights = true
            self.applyPersistedZoneVisibility()
            self.applyDividerStyleForCurrentOpacity()
            self.adjustRootForCollapsedBands()
        }
    }

    /// v0.30 boss 2026-09-01 OOB (auto-fill band on full collapse):
    /// when both panes of the lower band (= chat + dynamic) are
    /// collapsed, push the root column divider all the way to the
    /// bottom edge so the upper band fills the entire root height.
    /// When at least one lower pane is visible, restore the
    /// preset 50/50 weights. Runs on the ROOT controller only.
    private func adjustRootForCollapsedBands() {
        guard case .split(let rootSplit) = subtree else { return }
        guard rootSplit.orientation == .column else { return }
        guard self.splitView.bounds.height > 0 else { return }
        let rootItems = self.splitViewItems
        guard rootItems.count == 2 else { return }
        let lowerItem = rootItems[1]
        var lowerCollapsed = true
        var lowerHasCollapseable = false
        func walk(_ controller: NSSplitViewController) {
            for item in controller.splitViewItems {
                if item.canCollapse {
                    lowerHasCollapseable = true
                    if !item.isCollapsed {
                        lowerCollapsed = false
                    }
                }
                if let child = item.viewController as? NSSplitViewController {
                    walk(child)
                }
            }
        }
        walk(lowerItem.viewController as? NSSplitViewController ?? lowerItem.viewController as! NSSplitViewController)
        let totalHeight = self.splitView.bounds.height
        if lowerHasCollapseable && lowerCollapsed {
            self.splitView.setPosition(totalHeight, ofDividerAt: 0)
        } else {
            self.splitView.setPosition(totalHeight * 0.5, ofDividerAt: 0)
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
        // v0.30 boss 2026-09-01 OOB (zone toggle fix): instantiate
        // PaneNSController (= not the bare NSSplitViewController) so
        // applyPersistedZoneVisibility / handleToggleZone can walk
        // the controller tree and find each pane's TabKind via the
        // `paneKindByItem` dictionary recorded by `makeSplitItems`.
        // Without this, the nested controllers are untyped wrappers
        // (= no TabKind lookup → no startup fold, no menu-toggle
        // fold). The splitView / autosaveName wiring below mirrors
        // the bare-NSSplitViewController path so the visual behaviour
        // is unchanged.
        let nested = PaneNSController(
            store: store,
            appState: appState,
            bookStore: bookStore,
            layoutID: split.id,
            installObservers: false,
            subtree: .split(split)
        )
        nested.splitView.isVertical = (split.orientation == .row)
        nested.splitView.autosaveName = autosaveKey(for: split.id)
        installChildren(split.children, weights: split.weights, into: nested)
        // v0.30 boss 2026-09-01 OOB (zone toggle fix): the nested
        // controller skipped its own buildLayout (= avoids
        // double-installing the children above), so its
        // pendingWeights is empty. Register the nested's own
        // weight entry here so viewDidLayout's deferred
        // applyWeights still positions the band dividers
        // correctly.
        nested.pendingWeights.append((nested, split.weights))
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
        let itemCount = controller.splitViewItems.count
        guard itemCount >= 2 else { return }
        let dividerCount = itemCount - 1
        let total = weights.reduce(0, +)
        guard total > 0 else { return }

        var cumulative: CGFloat = 0
        let isVertical = splitView.isVertical

        for dividerIndex in 0..<dividerCount {
            cumulative += weights[dividerIndex]
            let proportion = cumulative / CGFloat(total)

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
                // v0.30 boss 2026-09-01 OOB (zone toggle fix): pass
                // the target controller (= `into:`) through to
                // makeSplitItems so the per-controller
                // `paneKindByItem` map is populated on the right
                // instance. Without this, a nested controller's
                // groups would land in the ROOT's map (= the lookup
                // in applyPersistedZoneVisibility would miss every
                // nested pane because nested.paneKindByItem stays
                // empty). The previous implicit `self.makeSplitItems`
                // form rooted the map on whichever PaneNSController
                // instance happened to be running the install pass.
                let items = makeSplitItems(for: group, weight: weight, on: controller)
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
    ///
    /// v0.30 boss 2026-09-01 OOB (zone toggle fix): the `on` parameter
    /// is the PaneNSController that will OWN the `paneKindByItem`
    /// entry. It may be `self` (= caller is the owner) or a nested
    /// controller (= caller is the root installChildren, target is a
    /// nested controller's splitView). Without explicit ownership the
    /// previous implicit `self` form rooted the map on whichever
    /// instance happened to be running the install pass.
    private func makeSplitItems(
        for group: GroupNode,
        weight: Double,
        on owner: NSSplitViewController
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
        // v0.30 boss 2026-09-01 OOB (zone toggle fix): record the
        // mapping by the item's *index* within the OWNER
        // controller's `splitViewItems` array (NOT by
        // ObjectIdentifier; Apple may re-wrap NSSplitViewItem
        // instances between install and viewDidLayout). The
        // positional index is stable (= the i-th item at install
        // time stays the i-th item at notification time, because
        // `makeSplitItems` always returns exactly one item per
        // group and `installChildren` calls `addSplitViewItem` in
        // left-to-right order). The map lives on the owner (= the
        // controller whose splitView will hold the item, which may
        // be `self` or a nested controller).
        if let ownerPaneController = owner as? PaneNSController {
            ownerPaneController.paneKindByItem[owner.splitViewItems.count] = tab.kind
        }
        return [item]
    }

    /// Install a `GroupNode` directly (= when the root IS a group, e.g.
    /// a single-pane layout). Mirrors `makeSplitItems` minus the parent
    /// controller split.
    private func installGroup(_ group: GroupNode) {
        let items = makeSplitItems(for: group, weight: 1.0, on: self)
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
    /// sidebar toolbar toggle). Boss 2026-09-01 OOB rule: everything
    /// except the editor is collapsible (= the editor is the one
    /// pane the user is always writing in; collapsing it would
    /// hide the work surface). Sidebar / preview / tools / chat /
    /// dynamic all follow the standard FCP hide/show affordance.
    private func isCollapsiblePane(_ paneID: PaneID) -> Bool {
        guard let pane = store.workspace.pane(for: paneID),
              let firstTabID = pane.tabIDs.first,
              let tab = store.workspace.tab(for: firstTabID)
        else { return false }
        switch tab.kind {
        case .projectSidebar, .projectPreview, .specializedTools, .aiChat, .aiDynamic:
            return true
        case .editor:
            return false
        }
    }

    // MARK: - Apple HIG canonical zone toggle (= boss 2026-09-02 OOB)

    /// Apple-style public toggle for a single zone. Called by the 5
    /// toolbar buttons + the 5 menu items (= boss rule: no wenshu-side
    /// notification or UserDefaults round-trip; NSSplitView's own
    /// `autosaveName` persists the per-item collapsed flag
    /// natively). Implemented as a thin wrapper around the
    /// `handleToggleZone(_:)` notification observer below.
    func toggleZone(_ slot: ZoneSlot) {
        let kind: TabKind
        switch slot {
        case .projectSidebar:   kind = .projectSidebar
        case .projectPreview:   kind = .projectPreview
        case .editor:           kind = .editor
        case .specializedTools: kind = .specializedTools
        case .aiChat:           kind = .aiChat
        case .aiDynamic:        kind = .aiDynamic
        }
        // Apple canonical animation. Reuse the notification path so
        // callers (= toolbar + menu) get identical behavior.
        NotificationCenter.default.post(name: .wenshuToggleZone, object: slot)
        _ = kind  // (= identity; the notification carries `slot`)
    }

    /// Cmd+Shift+R "恢复默认布局" reset action. Un-collapse every
    /// pane (= Apple NSSplitViewItem.isCollapsed = false) and
    /// re-apply the canonical preset weights (= setPosition on the
    /// owning split). WorkspaceView's `.wenshuResetLayout` observer
    /// calls this after refreshing WorkspaceStore, so the menu
    /// command actually un-collapses the on-screen layout (= not
    /// just the data model).
    @objc func restoreAllZones() {
        NSLog("[wenshu.reset] restoreAllZones() enter; found \(collectPaneControllers().count) controller(s)")
        for controller in collectPaneControllers() {
            var flipped = 0
            for item in controller.splitViewItems {
                guard item.canCollapse else { continue }
                if item.isCollapsed {
                    item.isCollapsed = false
                    flipped += 1
                }
            }
            NSLog("[wenshu.reset] controller \(type(of: controller)) un-collapsed \(flipped) item(s)")
        }
        // Re-apply the preset divider positions (= Apple
        // NSSplitView's setPosition(ofDividerAt:) on the divider
        // that owns each band). Without this, the visible panes
        // keep whatever width they had after the last user drag
        // (= autosaveName).
        NSLog("[wenshu.reset] applying \(pendingWeights.count) pending weight(s)")
        for (controller, weights) in pendingWeights {
            applyWeights(weights, on: controller)
        }
        adjustRootForCollapsedBands()
        NSLog("[wenshu.reset] restoreAllZones() exit")
    }

    /// Editor-zone "expand" trailing button action. Hide every
    /// collapsible zone (= sidebar + preview + tools + chat +
    /// dynamic) in one call. Apple HIG canonical = walk + flip
    /// each via animator().
    @objc func toggleAllNonEditorZones() {
        for controller in collectPaneControllers() {
            for (idx, item) in controller.splitViewItems.enumerated() {
                guard item.canCollapse else { continue }
                guard let tabKind = controller.paneKindByItem[idx] else { continue }
                guard tabKind != .editor else { continue }
                item.animator().isCollapsed.toggle()
            }
        }
    }

    /// Flatten self + every nested PaneNSController child into an
    /// array. The root controller hosts wrap-mode items (= the
    /// upper-band and lower-band nested controllers live as
    /// root.splitViewItems); the per-pane NSSplitViewItems live on
    /// the nested controllers.
    private func collectPaneControllers() -> [PaneNSController] {
        var result: [PaneNSController] = [self]
        var queue: [NSSplitViewController] = [self]
        while let next = queue.first {
            queue.removeFirst()
            for child in next.children {
                if let splitChild = child as? PaneNSController {
                    result.append(splitChild)
                    queue.append(splitChild)
                }
            }
        }
        return result
    }

    // MARK: - autosaveName key (= per-layout + per-split)

    /// Apple autosaveName key (= scopes divider positions per preset +
    /// per split subtree, so switching presets restores each one's last
    /// divider positions).
    private func autosaveKey(for splitID: String) -> String {
        "wenshu.split.\(layoutID).\(splitID)"
    }
}
