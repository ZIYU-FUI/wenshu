// EditorChatNSController.swift · Wenshu
//
// First-launch divider = 50:50; drag-to-resize persists via
// product NSSplitView autosaveName. Implementation:
//   - product NSSplitView autosaveName handles drag persistence
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
// The Apple pattern for Keynote's 'presenter notes'
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
// The product way to get the Keynote speaker-notes
// hide/show + animated toggle is the AppKit NSSplitViewController.
//
// Implementation:
// - `EditorChatNSController: NSSplitViewController`
// - 2 `NSSplitViewItem`s: top = editor, bottom = chat zone
// - chat zone `NSSplitViewItem.canCollapse = true`
// - each item hosts an `NSHostingController(rootView: SwiftUIView)`
// - dividerStyle = .thin (= matches product thin divider pattern)
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


/// Native AppKit split container (= editor on top, chat zone on bottom).
/// Hosts SwiftUI views via `NSHostingController`.
@MainActor
final class EditorChatNSController: NSSplitViewController {

    /// Stable identifier for the chat zone item (= used by the menu
    /// action to find the right item to toggle).
    static let chatItemIdentifier = "wenshu.editor.chat"

    /// Persisted divider position (= product NSSplitViewController
    /// built-in autosave behavior; = the user's drag positions
    /// survive app relaunch automatically; = no manual UserDefaults
    /// flag needed). Apple docs:
    /// developer.apple.com/documentation/appkit/nssplitviewcontroller
    /// 'When you set this property, the system automatically
    /// preserves the user's split-view configuration.'
    static let autosaveName = "wenshu.editor.split.autosave"

    /// Previously used a one-shot UserDefaults flag
    /// (= wenshu.editor.split.didSetFirstLaunchPosition) to force
    /// 50:50 on first launch; = problem: once the flag was set,
    /// the user's drag always overrode it; = no way to recover
    /// the 50:50 default after the first launch. product fix:
    /// ONLY use the autosaveName mechanism. Drop the manual flag
    /// + let Apple autosave handle persistence; = the
    /// first-launch 50:50 position is set via setPosition() in
    /// viewDidAppear (= AFTER the view is in the window
    /// hierarchy; = so Apple's autosave writes the 50:50 value to
    /// UserDefaults; = subsequent launches read it back via the
    /// same autosave path; = user drag overrides as expected).
    static let firstLaunchSetKey = "wenshu.editor.split.firstLaunchDidSet"

    /// Reference to the chat-zone split item (= set in viewDidLoad).
    /// Stored so the menu action can call `isCollapsed.toggle()`
    /// on it (= the Apple Keynote speaker-notes API).
    var chatItem: NSSplitViewItem?

    /// The share of the axis the divider holds (= the user's own
    /// position). The number the layout asserts.
    ///
    /// Why it is read out of the LAYOUT and not from the stored
    /// payload: the payload is written by AppKit as the layout
    /// settles, so a payload read back after an assert into it moves
    /// the target on every pass and the two numbers never settle. The
    /// layout's own share is the truth (= AppKit restores the
    /// divider from the payload, and the user's drag moves it).
    var assertedShare: CGFloat?

    /// The divider's latch: the state that spans layout passes.
    ///
    /// Why a value type and not five fields on the controller: the
    /// latch's LIFECYCLE is where the defect lived (= the resize latch
    /// was set when the axis moved and was released only by a repair
    /// write, = so a resize that ended ON the asserted share left it
    /// set, = and the user's NEXT drag was then answered with a repair
    /// that overwrote the drag), and a lifecycle can only be tested if
    /// it can be driven without a window.
    var dividerLatch = DividerLatch()

    /// The share below which two reads are the same position.
    ///
    /// A share is a fraction of the axis, so the tolerance is a
    /// fraction too: 0.5% of the axis is well under one point on any
    /// axis the editor is laid out on, and well over the rounding of
    /// the frames the layout hands out.
    static let shareTolerance: CGFloat = 0.005

    /// The extent below which a moved axis is the same axis.
    ///
    /// A half point is under the rounding AppKit hands out in the
    /// frames the layout reads, so a pass whose extent moved by less
    /// than this is the same layout and not a resize.
    static let extentTolerance: CGFloat = 0.5

    /// The extent a pane may grow past before the thickness cap is
    /// rewritten.
    ///
    /// The cap (= the split's own extent) stops a pane from claiming
    /// more than the axis carries, and it is written in QUANTA rather
    /// than on every frame: a resize animation delivers a layout pass
    /// per frame with a different extent each time, and a write in
    /// every one of those passes re-arms the window's update-constraints
    /// pass (= the pass AppKit's runaway-layout guard counts). The cap
    /// is rounded UP, so it never sits below the extent and never
    /// clamps a pane the layout has legitimately grown.
    static let thicknessQuantum: CGFloat = 64

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
    let environment: EditorChatEnvironment

    /// The editor's split item (= the one that hosts the editor's
    /// content).
    var editorSplitItem: NSSplitViewItem?

    /// The chat's split item (= the one that hosts the chat zone's
    /// content). It is also the item the "Show/Hide Chat Zone"
    /// command collapses.
    var chatSplitItem: NSSplitViewItem?

    /// The size the parent ALLOCATED last (= the parent's own number).
    ///
    /// Why it is cached: the reported size has to be a function of the
    /// parent's own layout. When the parent proposes nothing (= its
    /// ideal-size pass), the last number the parent allocated is the
    /// closest parent-owned value; the inner split's own size is
    /// never reported back up (= the outer split would negotiate the
    /// detail column's width against it, = a second, competing
    /// number in the same negotiation).
    ///
    /// Why only a REAL allocation is kept (= a finite, positive
    /// number): SwiftUI's proposal stream is not one number per
    /// layout. Measured 2026-10-27 with a headless probe of this
    /// app's own shape (= a NavigationSplitView whose detail hosts the
    /// representable, with an inspector beside it): every layout pass
    /// proposes 0 (= the ideal-size pass), then infinity (= the
    /// unbounded pass), then sometimes nothing, and only then the real
    /// allocation (= 740 PT at the screenshot's width). The stream
    /// REPEATS that cycle for the life of the window.
    ///
    /// Merging the last proposal of any kind therefore leaves the
    /// recorder holding INFINITY once the unbounded pass has run, and
    /// infinity is not a width: every comparison against it passes, so
    /// the width rule read infinity, judged every width viable, and
    /// never resolved to stacked. That is the layout this card names
    /// (= the arrangement never returns to stacked), and it survived
    /// the first fix because the rule's arithmetic was right and its
    /// INPUT was degenerate.
    var lastParentProposal: ProposedViewSize?

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
}
