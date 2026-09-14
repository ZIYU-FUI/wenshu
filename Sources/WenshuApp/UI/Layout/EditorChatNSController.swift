// EditorChatNSController.swift · Wenshu · v1.0.0-m1-shell
//
// Native AppKit split container for the wenshu editor column.
//
// Why NSSplitViewController (= not SwiftUI VSplitView)?
// ----------------------------------------------------
//
// v1.0.0-m1-shell boss 2026-09-10 OOB 'keynote 那种演讲者注释,
// 划出来的分区, 是否有官方的 API':
// the canonical Apple HIG pattern for Keynote's 'presenter notes'
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

extension Notification.Name {
    /// v1.0.0-m1-shell boss 2026-09-10 OOB '菜单栏 View > Show/Hide
    /// Chat Zone': posted when the user toggles the chat zone
    /// visibility from the menu bar. The `EditorChatNSController`
    /// (= the detail column's NSSplitViewController child) listens
    /// and calls `splitViewItems[chat].animator().isCollapsed.toggle()`.
    static let wenshuToggleChatZone = Notification.Name("wenshu.editor.toggleChatZone")
}

/// Native AppKit split container (= editor on top, chat zone on bottom).
/// Hosts SwiftUI views via `NSHostingController`.
@MainActor
final class EditorChatNSController: NSSplitViewController {

    /// Stable identifier for the chat zone item (= used by the menu
    /// action to find the right item to toggle).
    static let chatItemIdentifier = "wenshu.editor.chat"

    /// Persisted divider position (= Apple HIG autosave behavior; =
    /// the user's manual drag positions survive app relaunch).
    private static let autosaveName = "wenshu.editor.split.autosave"

    /// Reference to the chat-zone split item (= set in viewDidLoad).
    /// Stored so the menu action can call `isCollapsed.toggle()`
    /// on it (= the canonical Apple Keynote speaker-notes API).
    private var chatItem: NSSplitViewItem?

    /// External dependencies the SwiftUI views need (passed through
    /// `NSHostingController(rootView:).environment(...)`).
    private let conductor: WenshuConductor?
    // Phase 5 ticket 10a: ChatSessionStore deleted. Chat persistence lives
    // in WSChatRepository.shared (= @MainActor SwiftData wrapper).
    // v1.0.0-m1-shell boss 2026-09-12 OOB '文档打开链路修复:
    // 文档在中栏编辑器区打开. 不要单独 windows. 编辑器区就是
    // 文档的编辑区, 打开的文档是编辑状态. 编辑器使用 SM 我们引入
    // 的一个第三方 md 编辑器, 后端已经接好了': inject
    // AppState + BookStore into the editor pane's
    // NSHostingController (= the SwiftUI @Environment chain
    // breaks at the AppKit NSSplitViewController boundary; =
    // EditorPlaceholder's @Environment(AppState.self) +
    // @Environment(BookStore.self) won't see the parent
    // NavigationSplitView's environment; = the editor pane
    // would always render the empty-state hint even with tabs
    // in appState.openTabs; = without this injection, the
    // editor pane is just a placeholder regardless of double-
    // click on a card).
    private let appState: AppState?
    private let bookStore: BookStore?

    init(
        conductor: WenshuConductor?,
        appState: AppState? = nil,
        bookStore: BookStore? = nil
    ) {
        self.conductor = conductor
        self.appState = appState
        self.bookStore = bookStore
        super.init(nibName: nil, bundle: nil)
    }

    /// v0.71 P1 batch 4 dual-axis audit fix (= Q99 Standards axis
    /// HIGH): required `init?(coder:)` is a non-isolated context
    /// (= Objective-C bridging requirement) and was calling
    /// `super.init` (= MainActor-isolated from `NSViewController`)
    /// without an actor hop = actor-isolation violation that the
    /// Swift 6 strict concurrency checker accepts only because
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

        // v1.0.0-m1-shell: Apple HIG thin divider style (= the
        // canonical Keynote speaker-notes divider; = the
        // Apple-standard 1 PT hairline; = matches Pages / Numbers /
        // Keynote).
        self.splitView.dividerStyle = .thin
        // v1.0.0-m1-shell boss 2026-09-10 OOB '左右结构的, 不能上下吗':
        // switch the split view to vertical layout (= editor on top,
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
        // Autosave the divider position (= Apple HIG default
        // behavior; = the user's drag-to-resize survives relaunch).
        self.splitView.autosaveName = Self.autosaveName

        // Top pane (= editor).
        let editorRoot = EditorPlaceholder()
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
        )
        let chatItemLocal = NSSplitViewItem(viewController: chatViewController)
        chatItemLocal.canCollapse = true   // Keynote speaker-notes pattern
        chatItemLocal.minimumThickness = 100
        addSplitViewItem(chatItemLocal)
        self.chatItem = chatItemLocal

        // v1.0.0-m1-shell boss 2026-09-10 OOB '菜单栏 View > Show/Hide
        // Chat Zone': observe the wenshuToggleChatZone notification
        // posted by AppRootScene's CommandGroup(after: .toolbar). When
        // the user clicks View > Show Chat Zone in the macOS menu
        // bar, the AppState's chatVisible flag flips AND we get the
        // notification; we mirror the flag onto the native NSSplitViewItem
        // by toggling isCollapsed via animator() (= the native Keynote
        // speaker-notes collapse animation).
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleChatToggleNotification),
            name: .wenshuToggleChatZone,
            object: nil
        )
    }

    /// v0.71 P1 batch 8 dual-axis followup (= Q99 Standards axis HIGH):
    /// remove the selector-based NotificationCenter observer added in
    /// viewDidLoad (= HIGH leak: NotificationCenter retains `self`
    /// forever if no `removeObserver` runs; = the editor chat
    /// controller leaks on pane close). Apple HIG canonical lifecycle
    /// is `addObserver` paired with explicit `removeObserver` in
    /// `deinit` (= the controller is `final` so a single deinit
    /// covers all instances).
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func handleChatToggleNotification() {
        toggleChatZone()
    }

    /// Programmatic toggle (= called from the menu bar View >
    /// Show/Hide Chat Zone item). Uses `animator()` so the collapse
    /// / expand animates per NSSplitView's standard animation.
    /// This is the canonical Apple HIG Keynote speaker-notes API.
    func toggleChatZone() {
        // v0.71 P1 batch 7 dual-axis followup (= Q99 Standards axis LOW):
        // added NSLog when chatItem is nil (= was a silent no-op before;
        // = the menu can fire before viewDidLoad runs in a cold launch
        // race; = logging makes the misfire visible for diagnostics
        // without changing the no-op behavior).
        guard let item = chatItem else {
            NSLog("[wenshu.editorChat] toggleChatZone called before viewDidLoad set chatItem (cold-launch race); ignoring")
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
    // Phase 5 ticket 10a: ChatSessionStore deleted. Chat persistence lives
    // in WSChatRepository.shared (= @MainActor SwiftData wrapper).
    // v1.0.0-m1-shell boss 2026-09-12 OOB '文档打开链路修复':
    // thread appState + bookStore through the SwiftUI →
    // AppKit boundary so the editor pane's @Environment
    // lookups (= AppState + BookStore) actually resolve.
    let appState: AppState?
    let bookStore: BookStore?

    func makeNSViewController(context: Context) -> EditorChatNSController {
        let controller = EditorChatNSController(
            conductor: conductor,
            appState: appState,
            bookStore: bookStore
        )
        return controller
    }

    func updateNSViewController(_ nsViewController: EditorChatNSController, context: Context) {
        // No-op for now (= editor + chat content is static; = the
        // chat zone's internal state lives in ChatZoneView itself).
    }
}

// v1.0.0-m1-shell boss 2026-09-12 OOB '文档打开链路修复': helper
// that applies AppState + BookStore to a SwiftUI view IF they're
// non-nil (= the editor pane's NSHostingController is created in
// AppKit code where the SwiftUI @Environment chain doesn't
// propagate; = this helper bridges AppState + BookStore across the
// boundary without forcing every caller to know the env keys).
extension View {
    @ViewBuilder
    func applyOptionalEnvironment(appState: AppState?, bookStore: BookStore?) -> some View {
        if let appState = appState, let bookStore = bookStore {
            self.environment(appState).environment(bookStore)
        } else if let appState = appState {
            self.environment(appState)
        } else if let bookStore = bookStore {
            self.environment(bookStore)
        } else {
            self
        }
    }
}
