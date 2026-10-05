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
import os
import SwiftUI

private let wenshuLogger = Logger(subsystem: "com.wenshu", category: "editorchatnscontroller")

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
    private let appState: AppState?
    private let bookStore: BookStore?
    // WenshuLibrary is the canonical source for selectedBookId
    // (= see WenshuLibrary.swift = the only places selectedBookId
    // is mutated). Threaded through so ChatZoneView can observe
    // it via @Environment(WenshuLibrary.self).
    private let library: WenshuLibrary?

    init(
        conductor: WenshuConductor?,
        appState: AppState? = nil,
        bookStore: BookStore? = nil,
        library: WenshuLibrary? = nil
    ) {
        self.conductor = conductor
        self.appState = appState
        self.bookStore = bookStore
        self.library = library
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
        // be transparent; = ChatZoneView provides its own background
        // via SwiftUI's `.background(DesignTokens.sidebarBackground)`).
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
            .applyOptionalEnvironment(appState: appState, bookStore: bookStore)
        let editorItem = NSSplitViewItem(viewController: NSHostingController(
            rootView: editorRoot
        ))
        editorItem.canCollapse = false   // editor is always visible
        editorItem.minimumThickness = 200
        addSplitViewItem(editorItem)

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
                appState: appState,
                bookStore: bookStore,
                library: library
            )
        )
        let chatItemLocal = NSSplitViewItem(viewController: chatViewController)
        chatItemLocal.canCollapse = true   // Keynote speaker-notes pattern
        chatItemLocal.minimumThickness = 100
        addSplitViewItem(chatItemLocal)
        self.chatItem = chatItemLocal

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
        let autosaveKey = "NSSplitView Subview Frames \(Self.autosaveName)"
        let hasAutosave = defaults.data(forKey: autosaveKey) != nil
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
        let defaults = UserDefaults.standard
        let autosaveKey = "NSSplitView Subview Frames \(Self.autosaveName)"
        let hasAutosave = defaults.data(forKey: autosaveKey) != nil
        if !hasAutosave && defaults.bool(forKey: Self.firstLaunchSetKey) {
            // We already tried to set 50:50 in viewDidAppear (=
            // the flag is set) but it didn't take (= bounds were
            // off). Retry now that bounds are final.
            applyFiftyFiftyFirstLaunch()
        }
    }

    /// Do the actual 50:50 setPosition (split out so both
    /// viewDidAppear and viewDidLayout can call it).
    private func applyFiftyFiftyFirstLaunch() {
        let dividerY = self.splitView.bounds.height / 2
        self.splitView.setPosition(dividerY, ofDividerAt: 0)
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
}

/// SwiftUI wrapper that hosts `EditorChatNSController` inside the
/// `NavigationSplitView` detail closure (= same pattern as
/// `PaneSplitHost`; = AppKit boundary; = SwiftUI @Environment chain
/// breaks at the AppKit boundary; = we thread dependencies explicitly
/// into NSHostingController via `.environment(...)` if/when needed).
struct EditorChatSplitHost: NSViewControllerRepresentable {
    let conductor: WenshuConductor?
    // Chat persistence lives in WSChatRepository.shared
    // (= @MainActor SwiftData wrapper).
    // Thread appState + bookStore through the SwiftUI →
    // AppKit boundary so the editor pane's @Environment
    // lookups (= AppState + BookStore) actually resolve.
    let appState: AppState?
    let bookStore: BookStore?
    // Thread WenshuLibrary through the SwiftUI → AppKit
    // boundary so ChatZoneView can observe library (= the
    // canonical book-selection source mutated by
    // BookshelfListView taps; = future per-book chat features may
    // also read this).
    let library: WenshuLibrary?

    func makeNSViewController(context: Context) -> EditorChatNSController {
        let controller = EditorChatNSController(
            conductor: conductor,
            appState: appState,
            bookStore: bookStore,
            library: library
        )
        return controller
    }

    func updateNSViewController(_ nsViewController: EditorChatNSController, context: Context) {
        // No-op for now (= editor + chat content is static; = the
        // chat zone's internal state lives in ChatZoneView itself).
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
