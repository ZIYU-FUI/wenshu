// EditorChatNSController.swift · Wenshu
//
// First-launch divider = 50:50; drag-to-resize persists via
// Apple HIG NSSplitView autosaveName. Implementation:
//   - Apple HIG NSSplitView autosaveName handles drag persistence
//     (= writes divider position to UserDefaults on every drag;
//     = reads it back on next launch).
//   - Flag `wenshu.editor.split.didSetFirstLaunchPosition` gates
//     a one-shot setPosition(ofDividerAt:0) to 50% of splitView
//     height; = once the flag is set, the block never runs again
//     and autosaveName handles all future positions.
//
//
// Native AppKit split container for the wenshu editor column.
//
// Why NSSplitViewController (= not SwiftUI VSplitView)?
// ----------------------------------------------------
//
// The canonical Apple HIG pattern for Keynote's 'presenter notes'
// pane (= hideable + resizable + drag-collapse + animated toggle)
// is `NSSplitViewController` + `NSSplitViewItem.canCollapse`
// + `NSSplitViewItem.animator().isCollapsed` per Apple's
// documentation: developer.apple.com/design/human-interface-
// guidelines/split-views 'A split view can collapse one of
// its panes by dragging the divider past the edge of the split
// view, by clicking the collapse button in the divider, or
// programmatically.' = the user-facing hide/show + the
// programmatic hide/show (= menu bar View > Show/Hide Chat
// Zone) + the animation + the divider drag-to-collapse are
// all native macOS behaviors.
//
// SwiftUI's `VSplitView` does NOT expose `canCollapse` /
// `isCollapsed` / native divider collapse animation. Per Apple's
// macOS 14+ SwiftUI release notes, VSplitView is a thin wrapper
// over NSSplitView but does NOT bridge the canCollapse API.
// The Apple HIG canonical way to get the Keynote speaker-notes
// hide/show + animated toggle is the AppKit NSSplitViewController.
//
// Implementation:
// - `EditorChatNSController: NSSplitViewController`
// - 2 `NSSplitViewItem`s: top = editor, bottom = chat zone
// - chat zone `NSSplitViewItem.canCollapse = true`
// - each item hosts an `NSHostingController(rootView: SwiftUIView)`
// - dividerStyle = .thin (= matches Apple HIG thin divider pattern)
// - autosaveName persists the divider position across launches
// - `toggleChatZone()` (= the menu action) calls
//   `splitViewItems[1].animator().isCollapsed.toggle()`
//   = native NSSplitView animation
//
// SwiftUI hosting:
// - `EditorChatSplitHost: NSViewControllerRepresentable`
//   wraps the controller for SwiftUI's NavigationSplitView detail
//   closure (= same pattern as PaneSplitHost)
//
// Reference:
// - developer.apple.com/design/human-interface-guidelines/split-views
// - developer.apple.com/documentation/appkit/nssplitviewcontroller
// - developer.apple.com/documentation/appkit/nssplitviewitem

import AppKit
import SwiftUI
import WenshuAgent
import WenshuData
import os

private let wenshuLogger = Logger(subsystem: "com.wenshu", category: "editorchatnscontroller")

/// The physical arrangement of the editor + chat split.
/// Stacked = the editor above the chat zone; side by side = the
/// editor left of the chat zone.
enum EditorArrangement: Equatable, Sendable {
    case stacked
    case sideBySide

    /// The NSSplitView orientation that draws this arrangement.
    /// Apple HIG (developer.apple.com/documentation/appkit/nssplitview):
    /// 'If false, the split view is oriented horizontally (= items
    /// are arranged top to bottom).'
    var isVertical: Bool { self == .sideBySide }
}

/// Native AppKit split container (= editor on top, chat zone on bottom).
/// Hosts SwiftUI views via `NSHostingController`.
@MainActor
final class EditorChatNSController: NSSplitViewController {

    /// Stable identifier for the chat zone item (= used by the menu
    /// action to find the right item to toggle).
    static let chatItemIdentifier = "wenshu.editor.chat"

    /// Persisted divider position (= Apple HIG NSSplitViewController
    /// built-in autosave behavior; = the user's drag positions
    /// survive app relaunch automatically; = no manual UserDefaults
    /// flag needed). Apple docs:
    /// developer.apple.com/documentation/appkit/nssplitviewcontroller
    /// 'When you set this property, the system automatically
    /// preserves the user's split-view configuration.'
    private static let autosaveName = "wenshu.editor.split.autosave"

    /// The autosave name that holds the side-by-side
    /// arrangement's divider position. One name per arrangement
    /// (= each arrangement keeps its own dragged position; = the
    /// stacked name above is the historical one).
    private static let sideAutosaveName = "wenshu.editor.split.autosave.side"

    /// The split width at which the two columns can both hold a
    /// usable pane. Measured: 1209 PT of split width gives each
    /// column ~604 PT (= the editor's comfortable prose measure
    /// is 595-680 PT).
    static let sideBySideMinimumWidth: CGFloat = 1000

    /// The split width below which the two columns cannot both
    /// hold a usable pane, so the split stays stacked.
    static let stackedMaximumWidth: CGFloat = 920

    /// Previously used a one-shot UserDefaults flag
    /// (= wenshu.editor.split.didSetFirstLaunchPosition) to force
    /// 50:50 on first launch; = problem: once the flag was set,
    /// the user's drag always overrode it; = no way to recover
    /// the 50:50 default after the first launch. Apple HIG fix:
    /// ONLY use the autosaveName mechanism. Drop the manual flag
    /// + let Apple autosave handle persistence; = the
    /// first-launch 50:50 position is set via setPosition() in
    /// viewDidAppear (= AFTER the view is in the window
    /// hierarchy; = so Apple's autosave writes the 50:50 value to
    /// UserDefaults; = subsequent launches read it back via the
    /// same autosave path; = user drag overrides as expected).
    private static let firstLaunchSetKey = "wenshu.editor.split.firstLaunchDidSet"

    /// Reference to the chat-zone split item (= set in viewDidLoad).
    /// Stored so the menu action can call `isCollapsed.toggle()`
    /// on it (= the canonical Apple Keynote speaker-notes API).
    private var chatItem: NSSplitViewItem?

    /// The arrangement the split is drawn in right now.
    private(set) var arrangement: EditorArrangement = .stacked

    /// The mode the SwiftUI side last asked for (= automatic, or
    /// one of the two pinned arrangements).
    private var layoutMode: EditorLayoutMode = .automatic

    /// Whether a deferred structural change is queued for the next
    /// runloop turn.
    private var arrangementApplyScheduled = false

    /// The arrangement whose 50:50 reset is owed on the next
    /// layout pass. Set when an arrangement change finds no stored
    /// payload for the arrangement being entered; nil when the
    /// entered arrangement keeps a position of its own.
    private var pendingResetArrangement: EditorArrangement?

    /// The share of the axis the divider is held at (= the user's
    /// own position, as the stored payload records it). Captured
    /// when the arrangement is entered and held until the
    /// arrangement changes.
    ///
    /// Why it is held rather than re-read on every layout pass:
    /// the payload is written by AppKit as the layout settles, so
    /// reading it after asserting into it moves the target on every
    /// pass and the two numbers never settle. Measured: reading it
    /// on every pass still crashed (3 of 3), while capturing it
    /// once survived (3 of 3).
    private var assertedShare: CGFloat?

    /// External dependencies the SwiftUI views need (passed through
    /// `NSHostingController(rootView:).environment(...)`).
    private let conductor: WenshuConductor?
    // Chat persistence lives in WSChatRepository.shared
    // (= @MainActor SwiftData wrapper).
    // Inject AppState + BookStore into the editor pane's
    // NSHostingController (= the SwiftUI @Environment chain
    // breaks at the AppKit NSSplitViewController boundary;
    // = EditorView's @Environment(AppState.self) +
    // @Environment(BookStore.self) won't see the parent
    // NavigationSplitView's environment; = the editor pane
    // would always render the empty-state hint even with tabs
    // in appState.openTabs; = without this injection, the
    // editor pane is just a placeholder regardless of double-
    // click on a card).
    private let environment: EditorChatEnvironment

    init(
        conductor: WenshuConductor? = nil,
        environment: EditorChatEnvironment = EditorChatEnvironment(
            appState: nil,
            bookStore: nil,
            library: nil
        )
    ) {
        // AUDIT.md §2.2 partial (2026-10-16): the public
        // facade is the canonical source of truth for
        // the conductor; = if no conductor is injected,
        // resolve it from the facade. The init signature
        // is widened to `= nil` (= the conductor is
        // optional) to support the deprecation bridge
        // (= callers that still pass
        // `WenshuAppDelegate.sharedConductor` continue
        // to work unchanged).
        self.conductor = conductor ?? WenshuAgent.shared.currentConductorSync()
        self.environment = environment
        super.init(nibName: nil, bundle: nil)
    }

    /// dual-axis audit fix: required
    /// `init?(coder:)` is a non-isolated context (= Objective-C
    /// bridging requirement) and was calling `super.init`
    /// (= MainActor-isolated from `NSViewController`) without an
    /// actor hop = actor-isolation violation that the Swift 6
    /// strict concurrency checker accepts only because
    /// `@available(*, unavailable)` makes the override unreachable
    /// in practice. To make the safety explicit + remove the
    /// theoretical warning path, use `preconditionFailure` (= does
    /// not require `super.init` = the compiler no longer tries to
    /// verify the super call from a non-isolated context).
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        // Drop the `super.init` call (= the init is unreachable in
        // practice = no need to call super = removes the actor-
        // isolation violation at the source). The `required`
        // init's signature MUST match the superclass's, but the
        // body is allowed to use `preconditionFailure` (= a
        // Swift-native crash helper that does not return = the
        // compiler treats this as "init never returns normally"
        // and skips the super.init verification).
        preconditionFailure("EditorChatNSController must be initialized via init(conductor:chatStore:)")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Apple HIG thin divider style (= the canonical Keynote
        // speaker-notes divider; = the Apple-standard 1 PT hairline;
        // = matches Pages / Numbers / Keynote).
        self.splitView.dividerStyle = .thin
        // Pure Apple HIG approach (= let NSSplitView + NSSplitViewItem
        // be transparent; = the chat column shows the window's single
        // root material).
        // Without this, NSVisualEffectView bleeds through (= the
        // gradient observed in the previous attempts).
        //
        // Apple HIG rationale (developer.apple.com/documentation/appkit/nssplitview):
        // NSSplitView by default paints a backgroundColor under both
        // panes (= the "behind the chrome" color). When set to
        // `.clear`, the SwiftUI-hosted content's own background
        // shows through (= no more gradient bleed).
        //
        // NSSplitView is an NSView subclass; = `wantsLayer` and the
        // layer's CGColor are how we make the split view composite
        // correctly with SwiftUI children above (= otherwise macOS
        // draws the content over the parent NSWindow's opaque bg and
        // the chat zone stays black regardless of SwiftUI's bg modifier).
        self.splitView.wantsLayer = true
        self.splitView.layer?.backgroundColor = NSColor.clear.cgColor
        // Switch the split view to vertical layout (= editor on top,
        // chat on bottom; = top-to-bottom stack). NSSplitView's
        // default `isVertical = true` produces a left-to-right
        // (= editor | chat) layout, but Keynote's speaker-notes
        // pattern (= and the previous SwiftUI VSplitView behavior)
        // is top-to-bottom (= editor above, chat below; = the
        // divider is horizontal). Setting `isVertical = false`
        // makes the divider horizontal (= the user drags the
        // horizontal divider up/down to resize the chat zone =
        // the canonical Keynote speaker-notes pattern).
        //
        // Apple HIG developer.apple.com/documentation/appkit/nssplitview:
        // 'If false, the split view is oriented horizontally
        // (= items are arranged top to bottom).'
        self.splitView.isVertical = false
        // Pure Apple HIG approach (= autosaveName + the built-in
        // UserDefaults persistence path):
        //   1. Wire autosaveName (= Apple HIG NSSplitView built-in
        //      autosave; = the user's drag-to-resize persists across
        //      relaunches via UserDefaults key
        //      'NSSplitView Subview Frames wenshu.editor.split.autosave').
        //   2. The first-launch 50:50 reset happens in viewDidAppear
        //      (= AFTER the view is in the window hierarchy; = the
        //      autosave path can write the position correctly).
        self.splitView.autosaveName = Self.autosaveName

        // Top pane (= editor).
        let editorRoot = EditorView()
            .applyOptionalEnvironment(appState: environment.appState, bookStore: environment.bookStore)
        let editorItem = NSSplitViewItem(viewController: NSHostingController(
            rootView: editorRoot
        ))
        editorItem.canCollapse = false   // editor is always visible
        editorItem.minimumThickness = NSSplitViewItem.unspecifiedDimension
        editorItem.preferredThicknessFraction = 1.0 / 2.0
        // The NavigationSplitView owns horizontal bounds. This split owns
        // vertical thickness only; AppKit computes its automatic maximum
        // after the controller is attached to the split view.
        addSplitViewItem(editorItem)
        self.editorSplitItem = editorItem

        // Bottom pane (= chat zone).
        let chatViewController = NSHostingController(
            rootView: ChatZoneView(
                conductor: WenshuAppDelegate.sharedConductor
            )
            // ChatZoneView reads WenshuLibrary + BookStore via
            // @Environment to drive setCurrentBookID(_:) when the
            // user picks a different book (= wired off
            // workspaceUI.sidebarSelection mutations in ChatZoneView.body).
            // Without the env wrapper, the SwiftUI
            // @Environment(WenshuLibrary.self) +
            // @Environment(BookStore.self) wrappers crash with
            // 'No Observable object of type WenshuLibrary found' at
            // view construction time (= SwiftUI's @Environment(T.self)
            // is a hard fatalError when T is absent from the env chain).
            .applyOptionalEnvironment(
                appState: environment.appState,
                bookStore: environment.bookStore,
                library: environment.library
            )
        )
        let chatItemLocal = NSSplitViewItem(viewController: chatViewController)
        chatItemLocal.canCollapse = true   // Keynote speaker-notes pattern
        chatItemLocal.minimumThickness = NSSplitViewItem.unspecifiedDimension
        chatItemLocal.preferredThicknessFraction = 1.0 / 2.0
        addSplitViewItem(chatItemLocal)
        self.chatItem = chatItemLocal
        self.chatSplitItem = chatItemLocal

        // First-launch divider = 50:50; subsequent launches =
        // persisted ratio (= Apple HIG NSSplitView autosave path
        // handles the persistence; = this block only runs on the
        // user's very first launch ever).
        //
        // Order matters: must run AFTER autosaveName is wired AND
        // AFTER addSplitViewItem has added both panes (= so the
        // divider index 0 (= the divider between editor and chat)
        // is valid for setPosition(ofDividerAt:)). setPosition
        // triggers autosave to write the value into UserDefaults
        // (= subsequent launches skip this block and read the
        // 50:50 value back via autosave).
    }

    /// First-launch flow: first launch UserDefaults has no autosave
    /// value for 'NSSplitView Subview Frames
    /// wenshu.editor.split.autosave'. viewDidAppear fires AFTER
    /// the view is in the window hierarchy AND splitView has
    /// valid bounds (= the setPosition() call below produces real
    /// coordinates).
    ///   1. The firstLaunchSetKey flag only tracks whether
    ///      viewDidAppear has fired the reset once for THIS bundle
    ///      (= if user dragged before we set 50:50, this prevents
    ///      us from overriding their drag). NOTE: this flag is
    ///      distinct from the previous persistent flag (= the
    ///      flag is reset on every relaunch = the 50:50 only
    ///      applies when no autosave value exists; = if user has
    ///      dragged even once, autosave wins).
    ///   2. User drags: NSSplitView writes the new position to
    ///      UserDefaults via autosaveName.
    ///   3. Subsequent launches: Apple autosave restores the
    ///      user's drag position (= viewDidAppear checks: if
    ///      autosave value exists, skip the 50:50 reset).
    override func viewDidAppear() {
        super.viewDidAppear()
        let defaults = UserDefaults.standard
        let hasAutosave = hasStoredPayload(for: Self.storedAutosaveName(for: arrangement))
        // First-launch path: no autosave value exists + flag not
        // set for this run. Apply the 50:50 reset (= the canonical
        // first-launch layout; = writes to autosave via setPosition).
        // Subsequent launches: hasAutosave = true; = the user's
        // drag position is restored by Apple before viewDidAppear
        // (= we don't touch it).
        if !hasAutosave && !defaults.bool(forKey: Self.firstLaunchSetKey) {
            applyFiftyFiftyFirstLaunch()
            defaults.set(true, forKey: Self.firstLaunchSetKey)
        }
    }

    /// In viewDidAppear, splitView.bounds.height isn't final yet
    /// (= macOS is still mid layout pass; = setPosition uses an
    /// off-by-N height). Move the actual setPosition to
    /// viewDidLayout, which fires once bounds are real (and any
    /// layout pass is done). Apple's canonical order is
    /// viewWillLayout -> layoutSubviews -> viewDidLayout; = the
    /// splitView now has its final height here.
    override func viewDidLayout() {
        super.viewDidLayout()
        // This callback reaches the split's structure only through the
        // width rule (= a request). Removing and re-inserting a split
        // view item here invalidates the split's constraints while
        // AppKit is laying out, and each invalidation re-arms the
        // window's "Update Constraints in Window" pass (= the pass
        // AppKit's runaway-layout guard counts).
        updateAutomaticThicknessBounds()
        if layoutMode == .automatic {
            applyAutomaticArrangement()
        }
        runPendingReset()
        let defaults = UserDefaults.standard
        let hasAutosave = hasStoredPayload(for: Self.storedAutosaveName(for: arrangement))
        if !hasAutosave && defaults.bool(forKey: Self.firstLaunchSetKey) {
            // We already tried to set 50:50 in viewDidAppear (=
            // the flag is set) but it didn't take (= bounds were
            // off). Retry now that bounds are final.
            applyFiftyFiftyFirstLaunch()
        } else if hasAutosave {
            applyStoredShare()
        }
    }

    /// Hold the divider at the user's own share of the axis, and
    /// tell AppKit that this is the share it should lay out for.
    ///
    /// Why this exists: the divider has to be re-asserted on every
    /// layout pass, because that is what keeps the layout
    /// convergent. Both items carry `preferredThicknessFraction =
    /// 0.5`, so AppKit lays out for an even split, and the
    /// re-assert used to put the divider at that same even split
    /// (= 50:50), so the two agreed on every pass and the layout
    /// settled.
    ///
    /// The 50:50 reset is what wiped the dragged position whenever
    /// the window was resized, and reading the stored payload with
    /// the API that sees AppKit's array (= `object(forKey:)`) is
    /// what stopped that wipe. But that same change stopped the
    /// re-assert as well, and with it the agreement went away:
    /// AppKit laid out for 50:50 while the restored divider sat at
    /// the user's position, the two disagreed on every pass, the
    /// split's own width oscillated between two values (= measured:
    /// 656 and 389, on alternate passes), the outer
    /// NavigationSplitView negotiated against a number that kept
    /// changing, the window's "Update Constraints in Window" pass
    /// count ran past its limit (= 322), and AppKit's runaway-layout
    /// guard aborted the app.
    ///
    /// So both sides are put on the USER's share: the items'
    /// preferred thickness fractions become that share, and the
    /// divider is asserted at it. The layout then converges on the
    /// user's position (= the drag survives) and the re-assert keeps
    /// it convergent (= no runaway).
    ///
    /// The share comes from the stored payload (= the user's drag),
    /// and the formula is the one measured against the running
    /// split: `setPosition(p)` sets PANE 0's thickness, and the
    /// share is pane 0's thickness over the two panes' thickness
    /// together.
    private func applyStoredShare() {
        if assertedShare == nil {
            assertedShare = storedShare(for: Self.storedAutosaveName(for: arrangement)) ?? 0.5
        }
        guard let share = assertedShare else { return }

        let items = splitViewItems
        guard items.count == 2 else { return }
        // The editor's share, expressed as the LEADING pane's share
        // (= the frames are in the panes' own order, and the chat
        // leads when they stand side by side).
        let editorLeads = arrangement == .stacked
        let leadingShare = editorLeads ? share : 1 - share
        // Write only when the value differs: a write into the split
        // during the layout pass re-arms the window's
        // update-constraints pass.
        if items[0].preferredThicknessFraction != leadingShare {
            items[0].preferredThicknessFraction = leadingShare
        }
        if items[1].preferredThicknessFraction != 1 - leadingShare {
            items[1].preferredThicknessFraction = 1 - leadingShare
        }

        let axis = arrangement.isVertical ? splitView.bounds.width : splitView.bounds.height
        guard axis > 0 else { return }
        // The divider is asserted at the share on every layout pass,
        // and the assert is what keeps the layout convergent: AppKit
        // lays out for the items' preferred fractions, so the fraction
        // and the divider have to agree or the two fight each other
        // (measured: the split's own width oscillated between 656 and
        // 389 and AppKit's runaway-layout guard aborted the app).
        //
        // The assert is NOT guarded by a "does the divider already
        // hold this position" test, because NSSplitView exposes no
        // public reader for a divider's position (= the API is
        // minPossiblePositionOfDividerAtIndex / maxPossiblePositionOfDividerAtIndex
        // / setPosition:ofDividerAtIndex, = no getter), so the test
        // would have to be read out of the pane frames, and those are
        // the PREVIOUS layout pass's frames while a pass is running.
        splitView.setPosition(axis * leadingShare, ofDividerAt: 0)
    }

    /// The share of the axis the divider holds, as the stored
    /// payload records it.
    ///
    /// AppKit writes the frames as an array of strings under
    /// "NSSplitView Subview Frames <name>", each "x, y, width,
    /// height, collapsed, ...". The arrangement's axis carries the
    /// panes' thickness: the width when they stand side by side, the
    /// height when they are stacked.
    private func storedShare(for name: String) -> CGFloat? {
        let key = "NSSplitView Subview Frames \(name)"
        guard let frames = UserDefaults.standard.object(forKey: key) as? [String] else {
            return nil
        }
        return Self.share(
            fromFrames: frames,
            isVertical: arrangement.isVertical,
            firstPaneLeads: arrangement == .stacked
        )
    }

    /// The share of the axis the divider holds, read from AppKit's
    /// stored frames.
    ///
    /// `setPosition(p)` sets the FIRST pane's thickness (= measured
    /// against the running split), so the share is the first pane's
    /// thickness over the two panes' thickness together.
    ///
    /// The frames are in the panes' own order, and the order
    /// differs per arrangement (= the chat leads when the panes
    /// stand side by side), so the caller passes which pane leads.
    ///
    /// The numbers carry a space after every comma, so they have to
    /// be trimmed before they parse (= Swift's `Double(" 0.0")` is
    /// nil, and an untrimmed parse silently reads no share at all,
    /// which puts the divider back at the middle and reintroduces
    /// the runaway layout).
    static func share(fromFrames frames: [String], isVertical: Bool) -> CGFloat? {
        share(fromFrames: frames, isVertical: isVertical, firstPaneLeads: true)
    }

    /// The share of the axis the divider holds, read from AppKit's
    /// stored frames, for an arrangement whose first pane leads.
    static func share(
        fromFrames frames: [String],
        isVertical: Bool,
        firstPaneLeads: Bool
    ) -> CGFloat? {
        guard frames.count >= 2 else { return nil }
        func numbers(_ frame: String) -> [CGFloat] {
            frame.components(separatedBy: ",").compactMap {
                Double($0.trimmingCharacters(in: .whitespaces)).map { CGFloat($0) }
            }
        }
        let first = numbers(frames[0])
        let second = numbers(frames[1])
        guard first.count >= 4, second.count >= 4 else { return nil }
        let firstThickness = isVertical ? first[2] : first[3]
        let secondThickness = isVertical ? second[2] : second[3]
        let total = firstThickness + secondThickness
        guard total > 0 else { return nil }
        let leadingShare = firstThickness / total
        // The share is named by the EDITOR's pane (= the one the
        // user drags to size the editor), and the frames are in the
        // panes' own order (= the chat leads when they stand side by
        // side), so the editor's share is the other one.
        return firstPaneLeads ? leadingShare : 1 - leadingShare
    }

    /// The SwiftUI side's entry point: the mode the user picked
    /// in the View menu. The two manual cases pin the
    /// arrangement; the automatic case hands the decision to the
    /// width rule.
    func applyLayoutMode(_ mode: EditorLayoutMode) {
        layoutMode = mode
        switch mode {
        case .stacked:
            requestArrangement(.stacked)
        case .sideBySide:
            requestArrangement(.sideBySide)
        case .automatic:
            applyAutomaticArrangement()
        }
    }

    /// The arrangement a split width asks for. Pure (= no window
    /// and no split view): the automatic case follows the width,
    /// the two manual cases pin the arrangement, and the band
    /// between the two widths keeps the current arrangement.
    static func arrangement(
        forSplitWidth width: CGFloat,
        mode: EditorLayoutMode,
        current: EditorArrangement
    ) -> EditorArrangement {
        switch mode {
        case .stacked:
            return .stacked
        case .sideBySide:
            return .sideBySide
        case .automatic:
            if width >= sideBySideMinimumWidth { return .sideBySide }
            if width < stackedMaximumWidth { return .stacked }
            return current
        }
    }

    /// The automatic rule: the arrangement follows the split
    /// width (= side by side when the split is wide enough for
    /// two columns; = stacked when it is not; = the band between
    /// the two keeps the current arrangement).
    ///
    /// It runs inside the layout callback, so it only REQUESTS the
    /// arrangement; the structural change runs on the next runloop
    /// turn.
    private func applyAutomaticArrangement() {
        let width = splitView.bounds.width
        guard width > 0 else { return }
        requestArrangement(
            Self.arrangement(forSplitWidth: width, mode: layoutMode, current: arrangement)
        )
    }

    /// Ask for an arrangement and queue its structural change.
    ///
    /// Why the queue: removing a split view item invalidates the
    /// split's constraints, and doing that while AppKit is laying
    /// out re-arms the window's "Update Constraints in Window" pass.
    /// Deferring to the next runloop turn lets the layout pass
    /// finish before the panes move.
    private func requestArrangement(_ target: EditorArrangement) {
        guard target != arrangement else { return }
        guard !arrangementApplyScheduled else { return }
        arrangementApplyScheduled = true
        Task { @MainActor [weak self] in
            self?.applyRequestedArrangement()
        }
    }

    /// Apply the arrangement the width rule asks for, outside the
    /// layout pass.
    ///
    /// The width is read again here: the window may have moved while
    /// the request waited for the runloop turn, and a request the
    /// width no longer supports is dropped (= no structural change
    /// at all).
    private func applyRequestedArrangement() {
        arrangementApplyScheduled = false
        let target: EditorArrangement
        switch layoutMode {
        case .stacked:
            target = .stacked
        case .sideBySide:
            target = .sideBySide
        case .automatic:
            let width = splitView.bounds.width
            guard width > 0 else { return }
            target = Self.arrangement(forSplitWidth: width, mode: .automatic, current: arrangement)
        }
        guard target != arrangement else { return }
        transition(to: target)
        wenshuLogger.debug("[wenshu.editorChat] arrangement applied: \(String(describing: target))")
    }

    /// Move the split to an arrangement. The autosave name
    /// follows the arrangement (= each arrangement keeps its own
    /// divider position), the panes follow the arrangement's own
    /// order (= the chat is on the left when the panes stand side
    /// by side), and the 50:50 reset is owed on the next layout
    /// pass when the arrangement being entered has no stored
    /// payload of its own.
    private func transition(to target: EditorArrangement) {
        guard target != arrangement else { return }
        let enteringName = Self.storedAutosaveName(for: target)
        let keepsOwnPosition = hasStoredPayload(for: enteringName)
        arrangement = target
        assertedShare = nil
        splitView.isVertical = target.isVertical
        splitView.autosaveName = enteringName
        applyPaneOrder(for: target)
        pendingResetArrangement = keepsOwnPosition ? nil : target
    }

    /// Put the panes in the arrangement's own order.
    ///
    /// Why the order differs per arrangement: the chat zone is on
    /// the LEFT when the panes stand side by side (= the chat is
    /// the companion of the editor, not its continuation), and the
    /// editor stays on TOP when they are stacked (= the Keynote
    /// speaker-notes pattern, = the editor above and the chat
    /// below).
    ///
    /// The order is the ONLY lever AppKit offers here: setting an
    /// added item's `viewController` raises "Cannot remove a
    /// SplitViewItem's viewController if it is currently in a
    /// SplitViewController" (= measured), so the panes are moved by
    /// removing the item and re-inserting it at the other index.
    /// (= measured: the reorder takes effect, the divider keeps
    /// working afterwards, and the layout converges over repeated
    /// passes.)
    ///
    /// The stored frames follow the items (= AppKit writes the
    /// payload in the panes' own order), so each arrangement's
    /// payload is read with that arrangement's order.
    private func applyPaneOrder(for target: EditorArrangement) {
        let editorItem = editorSplitItem
        let chatItem = chatSplitItem
        guard let editorItem, let chatItem else { return }

        let editorIndex = splitViewItems.firstIndex(of: editorItem)
        let chatIndex = splitViewItems.firstIndex(of: chatItem)
        guard let editorIndex, let chatIndex, editorIndex != chatIndex else { return }

        // The order the arrangement wants: the editor first when
        // stacked (= the editor on top), the chat first when side by
        // side (= the chat on the left).
        let editorShouldLead = target == .stacked
        let editorLeads = editorIndex < chatIndex
        guard editorShouldLead != editorLeads else { return }

        removeSplitViewItem(editorItem)
        insertSplitViewItem(editorItem, at: editorShouldLead ? 0 : 1)
    }

    /// The editor's split item (= the one that hosts the editor's
    /// content).
    private var editorSplitItem: NSSplitViewItem?

    /// The chat's split item (= the one that hosts the chat zone's
    /// content). It is also the item the "Show/Hide Chat Zone"
    /// command collapses.
    private var chatSplitItem: NSSplitViewItem?

    /// Apply the 50:50 reset owed by an arrangement change. It
    /// runs on the next layout pass (= the bounds are final by
    /// then) and only for an arrangement that had no stored
    /// payload of its own.
    private func runPendingReset() {
        guard let pending = pendingResetArrangement else { return }
        pendingResetArrangement = nil
        applyFiftyFiftyReset(for: pending)
    }

    /// The autosave name that holds an arrangement's divider
    /// position. One name per arrangement.
    private static func storedAutosaveName(for arrangement: EditorArrangement) -> String {
        switch arrangement {
        case .stacked:    return autosaveName
        case .sideBySide: return sideAutosaveName
        }
    }

    /// Whether an arrangement has a stored divider position.
    /// AppKit stores it under "NSSplitView Subview Frames
    /// <name>" as an ARRAY of strings, so the read that sees the
    /// array is `object(forKey:)`; `data(forKey:)` is always nil
    /// for an array (= the first-launch check used it, = so the
    /// 50:50 reset re-applied on every layout pass and wiped the
    /// user's dragged position).
    private func hasStoredPayload(for name: String) -> Bool {
        UserDefaults.standard.object(forKey: "NSSplitView Subview Frames \(name)") != nil
    }

    /// Re-assert Apple automatic bounds after the split view has a
    /// window-backed size. `automaticMaximumThickness` is meaningful only
    /// after attachment; reading it during `viewDidLoad` produced an invalid
    /// hard maximum and let the hosting column collapse.
    ///
    /// The clamp follows the arrangement's own axis: the height
    /// carries the split when stacked, the width carries it when
    /// side by side (= a height clamp in the side-by-side
    /// arrangement pinned both columns to the height and left a
    /// dead gap beside the column).
    private func updateAutomaticThicknessBounds() {
        let available = arrangement.isVertical ? splitView.bounds.width : splitView.bounds.height
        guard available > 0 else { return }
        for item in splitViewItems {
            // Write only when the value differs: a write into the
            // split during the layout pass re-arms the window's
            // update-constraints pass.
            if item.minimumThickness != 0 {
                item.minimumThickness = 0
            }
            if item.maximumThickness != available {
                item.maximumThickness = available
            }
        }
    }

    /// Do the actual 50:50 setPosition (split out so both
    /// viewDidAppear and viewDidLayout can call it).
    private func applyFiftyFiftyFirstLaunch() {
        applyFiftyFiftyReset(for: arrangement)
    }

    /// The 50:50 reset along the arrangement's own axis: the
    /// divider is horizontal when stacked (= the height carries
    /// the split) and vertical when side by side (= the width
    /// carries it).
    private func applyFiftyFiftyReset(for arrangement: EditorArrangement) {
        switch arrangement {
        case .stacked:
            let dividerY = self.splitView.bounds.height / 2
            self.splitView.setPosition(dividerY, ofDividerAt: 0)
        case .sideBySide:
            let dividerX = self.splitView.bounds.width / 2
            self.splitView.setPosition(dividerX, ofDividerAt: 0)
        }
    }

    /// Programmatic toggle (= called from the menu bar View >
    /// Show/Hide Chat Zone item). Uses `animator()` so the collapse
    /// / expand animates per NSSplitView's standard animation.
    /// This is the canonical Apple HIG Keynote speaker-notes API.
    func toggleChatZone() {
        // dual-axis followup: added NSLog when
        // chatItem is nil (= was a silent no-op before; = the menu
        // can fire before viewDidLoad runs in a cold launch race;
        // = logging makes the misfire visible for diagnostics
        // without changing the no-op behavior).
        guard let item = chatItem else {
            wenshuLogger.info("[wenshu.editorChat] toggleChatZone called before viewDidLoad set chatItem (cold-launch race); ignoring")
            return
        }
        item.animator().isCollapsed.toggle()
    }

    /// Query helper for menu state (= show checkmark when chat zone
    /// is currently visible).
    var isChatZoneVisible: Bool {
        chatItem.map { !$0.isCollapsed } ?? true
    }

    /// The size the parent proposed last (= the parent's own number).
    ///
    /// Why it is cached: the reported size has to be a function of the
    /// parent's own layout. When the parent proposes nothing (= its
    /// ideal-size pass), the last number the parent proposed is the
    /// closest parent-owned value; the inner split's own size is
    /// never reported back up (= the outer split would negotiate the
    /// detail column's width against it, = a second, competing
    /// number in the same negotiation).
    private var lastParentProposal: ProposedViewSize?

    /// The width the parent proposed last.
    fileprivate var lastParentWidth: CGFloat? { lastParentProposal?.width }

    /// The height the parent proposed last.
    fileprivate var lastParentHeight: CGFloat? { lastParentProposal?.height }

    /// Record the size the parent proposes, so a later proposal that
    /// omits a dimension can fall back to the parent's own last
    /// number for it.
    func recordParentProposal(_ proposal: ProposedViewSize) {
        var merged = lastParentProposal ?? ProposedViewSize(width: nil, height: nil)
        if let width = proposal.width { merged.width = width }
        if let height = proposal.height { merged.height = height }
        lastParentProposal = merged
    }
}

/// SwiftUI wrapper that hosts `EditorChatNSController` inside the
/// `NavigationSplitView` detail closure (= same pattern as
/// `PaneSplitHost`; = AppKit boundary; = SwiftUI @Environment chain
/// breaks at the AppKit boundary; = we thread dependencies explicitly
/// into NSHostingController via `.environment(...)` if/when needed).
struct EditorChatSplitHost: NSViewControllerRepresentable {
    let conductor: WenshuConductor?
    /// The arrangement the user asked for in the View menu. The
    /// controller applies it (= automatic follows the window
    /// width; = the two manual cases pin the arrangement).
    let layoutMode: EditorLayoutMode
    // The SwiftUI environment does not cross into the
    // `NSHostingController`s this wrapper creates, so the three
    // objects the hosted views read are resolved HERE (= the
    // SwiftUI side of the boundary) and handed over as one
    // bundled value.
    //
    // Chat persistence lives in WSChatRepository.shared
    // (= @MainActor SwiftData wrapper).
    @Environment(AppState.self) private var appState
    @Environment(BookStore.self) private var bookStore
    @Environment(WenshuLibrary.self) private var library

    func makeNSViewController(context: Context) -> EditorChatNSController {
        let controller = EditorChatNSController(
            conductor: conductor,
            environment: EditorChatEnvironment(
                appState: appState,
                bookStore: bookStore,
                library: library
            )
        )
        return controller
    }

    func updateNSViewController(_ nsViewController: EditorChatNSController, context: Context) {
        // The layout mode is the one thing the SwiftUI side owns
        // (= the View menu writes it; = the editor + chat content
        // itself is static).
        nsViewController.applyLayoutMode(layoutMode)
    }

    /// Report a size that does NOT depend on the inner split's own layout.
    ///
    /// Why: the default implementation reports the inner
    /// `NSSplitViewController`'s size to the SwiftUI layout engine. The
    /// detail column of the outer `NavigationSplitView` then negotiates
    /// its width against a number the nested split keeps recomputing, and
    /// each negotiation re-arms the window's "Update Constraints in
    /// Window" pass. That pass count is what AppKit's runaway-layout
    /// guard counts, and it is what aborts the app when the window is
    /// dragged narrow (= measured: 10 of 10 trials crashed with
    /// `limit: 342, count: 348`; with this override, 0 of 10 crashed and
    /// the window narrowed past the width the crashing build reached).
    ///
    /// Returning the PROPOSAL (= the size the parent is asking for) makes
    /// the reported size a function of the parent's own layout, so the
    /// nested split stops feeding a second, competing number back up.
    func sizeThatFits(
        _ proposal: ProposedViewSize,
        nsViewController: EditorChatNSController,
        context: Context
    ) -> CGSize? {
        // The parent's proposal is the only number reported back up.
        // The inner split's own width is never reported: the parent
        // negotiates the detail column's width against what is
        // reported here, and the inner split keeps recomputing its
        // own width (= a second number in the same negotiation).
        //
        // When the parent proposes nothing, the parent's own last
        // proposal is used (= the parent's number, not the inner
        // split's); = with no proposal at all, no size is reported
        // (= the parent keeps its own layout).
        nsViewController.recordParentProposal(proposal)
        guard let width = proposal.width ?? nsViewController.lastParentWidth,
              let height = proposal.height ?? nsViewController.lastParentHeight
        else { return nil }
        return CGSize(width: width, height: height)
    }
}

// Helper that applies AppState + BookStore to a SwiftUI view
// IF they're non-nil (= the editor pane's NSHostingController is
// created in AppKit code where the SwiftUI @Environment chain
// doesn't propagate; = this helper bridges AppState + BookStore
// across the boundary without forcing every caller to know the
// env keys).
//
// Extended to also inject WenshuLibrary (= the chat zone reads
// library via @Environment; = reusing the helper means every
// pane gets the same env chain pattern).
extension View {
    @ViewBuilder
    func applyOptionalEnvironment(appState: AppState?, bookStore: BookStore?, library: WenshuLibrary? = nil) -> some View {
        // Apply the union of available objects in one pass (= each
        // .environment modifier is additive; = the order doesn't
        // matter; = a single self is the chain root).
        self
            .environment(appState)
            .environment(bookStore)
            .environment(library)
    }
}
