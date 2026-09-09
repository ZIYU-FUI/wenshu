import SwiftUI
import AppKit
import Lucide

/// AppDelegate: WenshuCore runtime + macOS app init
final class WenshuAppDelegate: NSObject, NSApplicationDelegate {
    // v0.24 bossverificationfix (Boss 8/25 OOB Spec axis GAP): one-time migration
    // from legacy chat.sqlite to warehouse. Preserves chat history when
    // user first picks a .ws warehouse in onboarding (= avoids silent data loss).
    // Idempotent: if legacy file doesn't exist or new file already exists, skip.
    private static func migrateLegacyChatIfNeeded(warehousePath: String, chatDbPath: String?) {
        guard let chatDbPath = chatDbPath else { return }
        let fm = FileManager.default
        // Legacy path: ~/Library/Application Support/wenshu/chat.sqlite
        guard let appSupport = try? fm.url(for: .applicationSupportDirectory,
                                            in: .userDomainMask,
                                            appropriateFor: nil,
                                            create: false)
                .appendingPathComponent("wenshu", isDirectory: true)
                .appendingPathComponent("chat.sqlite") else {
            return
        }
        // Skip if legacy file doesn't exist
        guard fm.fileExists(atPath: appSupport.path) else { return }
        let newURL = URL(fileURLWithPath: chatDbPath)
        // Skip if new file already exists (= no overwrite)
        guard !fm.fileExists(atPath: newURL.path) else { return }
        // Ensure warehouse directory exists
        let warehouseDir = (chatDbPath as NSString).deletingLastPathComponent
        if !fm.fileExists(atPath: warehouseDir) {
            try? fm.createDirectory(atPath: warehouseDir, withIntermediateDirectories: true)
        }
        // Copy legacy → warehouse
        do {
            try fm.copyItem(at: appSupport, to: newURL)
            NSLog("[wenshu.chatStore] migrated legacy chat.sqlite to %@", chatDbPath)
        } catch {
            NSLog("[wenshu.chatStore] legacy chat migration FAILED: %@", String(describing: error))
        }
    }

    
    // v0.21 ticket 01 (redo #7): SwiftUI 14+ OpenSettingsAction (LayoutShellView .onAppear, OpenSettingsAction.callAsFunction())
    nonisolated(unsafe) static var openSettings: OpenSettingsAction?

    /// v0.28 followup: debug Keychain override for cua / dev env without
    /// user-attached login keychain (= the InMemoryKeychainStore stub
    /// prevents SecItemCopyMatching from blocking wenshu main thread
    /// on the Keychain permission modal during dev/verify). Gated by
    /// WENSHU_DEBUG_INMEMORY_KEYCHAIN env var (= 1 = use in-memory stub,
    /// 0 = use real Apple keychain). Production builds never set this.
    static let sharedKeychainBackend: Void = {
        if ProcessInfo.processInfo.environment["WENSHU_DEBUG_INMEMORY_KEYCHAIN"] == "1" {
            ProviderKeychain.setBackendForTesting(InMemoryKeychainStore())
            NSLog("[wenshu.debug] keychain backend = InMemoryKeychainStore (debug override)")
        }
    }()

    static let sharedRuntime = AgentRuntime()
    static let sharedVerifier = WenshuVerifier()
    static let sharedChatStore: ChatSessionStore? = {
        // v0.21 ticket 06: actor init static let (Swift 6 strict concurrency)
        // nil, applicationDidFinishLaunching redocreate var sharedChatStore
        return nil
    }()
    static nonisolated(unsafe) var sharedConductor: WenshuConductor?

    static nonisolated(unsafe) var sharedChatStoreRef: ChatSessionStore?  // code-review H1: unsafe var let nil

    static let sharedkanbanStore: KanbanStore? = nil  //, applicationDidFinishLaunching

    // v0.21 ticket 01 (redo #7): "show" → "restoredefaultlayout" NSMenu action (Q28: NSMenu in progress 6, SwiftUI commands)
    @MainActor @objc func resetLayout(_ sender: Any?) {
        NSLog("[wenshu.reset] NSMenu resetLayout(_:) called, posting")
        NotificationCenter.default.post(name: .wenshuResetLayout, object: nil)
    }


    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        // v0.28 followup: force-evaluate sharedKeychainBackend so the
        // debug override takes effect before any Keychain access.
        _ = Self.sharedKeychainBackend
        // v0.30 boss 8/31 followup (= Spec C2 fix): install a receiver
        // for .wenshuImportRequested (= fired by the zone-header
        // button). Previously the button was producer-only; this
        // commit adds the matching listener that opens an NSOpenPanel
        // for the user to select an external .ws file or research
        // material to import into the library.
        NotificationCenter.default.addObserver(
            forName: .wenshuImportRequested,
            object: nil,
            queue: .main
        ) { _ in
            let panel = NSOpenPanel()
            // v0.40 apple-001 i18n sweep (boss real-device test 2026-09-07):
            // NSOpenPanel title + message are user-visible strings
            // (= they appear in the open dialog title bar + body).
            // Per Apple HIG, all user-visible strings must go through
            // the platform's i18n framework (NSLocalizedString /
            // .stringsdict) so the dialog auto-localizes per system
            // language. Hard-coded Chinese strings lock the dialog
            // to Chinese forever (= breaks users on non-zh-Hans systems).
            panel.title = WenshuI18n.t("openpanel.import.title")
            panel.message = WenshuI18n.t("openpanel.import.message")
            panel.allowsMultipleSelection = true
            panel.canChooseFiles = true
            panel.canChooseDirectories = false
            if panel.runModal() == .OK {
                NSLog("[wenshu.import] user selected \(panel.urls.count) file(s)")
            }
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // v0.28 followup Boss UX round 9 (Boss 2026-08-29 OOB 'wait,
        // button, not okdouble-click, ' =
        // titlebarAppearsTransparent + titleVisibility = .hidden
        // removes traffic lights AND double-click-to-zoom
        // (= breaks macOS standard window controls). Don't do that.
        // Keep the macOS native titlebar (= 28 PT compact with
        // traffic lights + double-click-to-zoom) and put the titlebar
        // icons INSIDE it via .toolbar { ToolbarItem(.principal) }
        // (= exactly macOS standard = native toolbar buttons next to
        // traffic lights = matches Apple Pages / Xcode / Mail etc.).
        //
        // v0.21 ticket 06: synccreate ChatSessionStore + KanbanStore + WenshuConductor (static let actor init)
        // unsafeMutablePointer / instance var — static let yes immutable,
// v0.24 bossverificationfix (Boss 8/24 'chat, '):
        // add NSLog for chat store init + bootstrap errors (silent catch
        // makes debugging hard), and post .wenshuChatStoreReady notification
        // so ChatView can retry load when store becomes available.
        // v0.24 bossverificationfix (Boss 8/25 OOB 'yes .ws file'):
        // ChatSessionStore location = wenshu warehouse (anbaiqiang.ws/) if set,
        // else fall back to legacy ~/Library/Application Support/wenshu/chat.sqlite.
        // Per boss spec: chat data must be part of the warehouse file so the
        // customer can copy the warehouse to another Mac and continue the
        // session history directly.
        let warehousePath = UserDefaults.standard.string(forKey: "wenshu.libraryPath")
        let chatDbPath: String? = warehousePath.map { path in
            // Warehouse is the directory selected via onboarding (.ws folder).
            // Place chat.sqlite inside it.
            (path as NSString).appendingPathComponent("chat.sqlite")
        }
        // v0.24 bossverificationfix (Boss 8/25 OOB Spec axis GAP): one-time migration
        // from legacy chat.sqlite to warehouse (preserves chat history when
        // user first picks a .ws warehouse in onboarding).
        if let warehouse = warehousePath {
            Self.migrateLegacyChatIfNeeded(warehousePath: warehouse, chatDbPath: chatDbPath)
        }

        let chatStore: ChatSessionStore?
        do {
            let store = try ChatSessionStore(path: chatDbPath)
            try store.bootstrap()
            chatStore = store
            // v0.24 bossverificationfix (Standards F3): log caller-side path (chatDbPath)
            // instead of store.dbPath — keeps dbPath encapsulated (= private).
            NSLog("[wenshu.chatStore] init OK: store created at %@", chatDbPath ?? "<legacy>")
        } catch {
            chatStore = nil
            // v0.24 bossverificationfix: also log the attempted path on failure
            // (was missing path info, made debugging hard).
            NSLog("[wenshu.chatStore] init FAILED at %@: %@", chatDbPath ?? "<legacy>", String(describing: error))
        }
        Self.sharedChatStoreRef = chatStore  // code-review H1
        if chatStore != nil {
            NotificationCenter.default.post(name: .wenshuChatStoreReady, object: nil)
        }
        let kanbanStore: KanbanStore?
        do {
            let store = try KanbanStore()
            try store.bootstrap()
            kanbanStore = store
        } catch {
            kanbanStore = nil
        }
        if let kanbanStore = kanbanStore {
            Self.sharedConductor = WenshuConductor(
                runtime: Self.sharedRuntime,
                verifier: Self.sharedVerifier,
                kanbanStore: kanbanStore,
                sessionStore: chatStore
            )
        }
        // v0.21 ticket 06: NSApp.mainMenu applicationWillFinishLaunching (=, SwiftUI)
        // v0.20 ticket 01: startregister wenshu agent (zone chat UI)
        let card = AgentCard(
            name: "wenshu",
            description: "wenshu 本地主 agent, 接 MiniMax key, 支持 chat UI",
            skills: ["chat", "memory", "kanban"],
            endpoint: "in-process://wenshu"
        )
        let protocol_ = AgentProtocol(agentCard: card, verifier: Self.sharedVerifier)
        Task { @MainActor in
            await Self.sharedRuntime.register(AgentRegistration(
                name: "wenshu", card: card, process: protocol_
            ))
        }
        NSApp.activate(ignoringOtherApps: true)
        if ProcessInfo.processInfo.environment["WS_SCREENSHOT"] == "1" {
            SelfScreenshot.run()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    /// v0.37 trigger closure seeders (= commit 266c1c425 followup):
    /// canonical LLM connector resolver used by the production ChatView
    /// long-running-goal button (= M14 fix) and the unit-test
    /// TriggerClosureWiringTests. The resolver reads the
    /// `wenshu.llm.activeConnector` UserDefaults slug (= the connector
    /// profile the user picked in LLMConnectorSettingsView) and falls
    /// back to AnthropicConnector for missing / unknown / unsupported
    /// apiMode (= never nil, matches wenshu defensive-defaults rule).
    ///
    /// Why this lives on WenshuAppDelegate (= not just on WorkspaceView):
    /// unit tests run in a swift-test helper process that does not
    /// mount the full view hierarchy, so WorkspaceView.activeLLMConnector
    /// (= private) is unreachable from the test target. Exposing the
    /// same logic on WenshuAppDelegate (= module-internal) keeps the
    /// test + production in lockstep without leaking the view API.
    nonisolated(unsafe) static func activeLLMConnector() -> any LLMConnector {
        let slug = UserDefaults.standard.string(forKey: "wenshu.llm.activeConnector")
        // v0.40 followup: unknown slug (= no UserDefaults key, or a slug that
        // ProviderCatalog cannot resolve) must fall back to AnthropicConnector
        // (NOT ProviderCatalog's .minimaxCn default). The unit test contract in
        // TriggerClosureWiringTests pins this so the production long-running-goal
        // button can never hit a connector it cannot drive (= AnthropicConnector
        // is the canonical native-protocol connector wenshu ships with out of the
        // box per AGENTS.md §11.2 P0 profile list). When the user has not picked
        // a connector OR has picked one we don't ship, route to Anthropic.
        let provider: Provider
        if let slug = slug, let resolved = Provider.by(slug: slug) {
            provider = resolved
        } else {
            // Anchor the AnthropicConnector fallback on the explicit
            // "anthropic" Provider (= real Anthropic API, not the
            // anthropic-compatible MinimaxConnector).
            provider = Provider.by(slug: "anthropic") ?? .minimaxCn
        }
        switch provider.apiMode {
        case "anthropic_messages":
            // MinimaxConnector is the Anthropic-compatible wrapper
            // (= wenshu's default provider per AGENTS.md §11.2);
            // AnthropicConnector is the native Anthropic API.
            if provider.slug == "anthropic" {
                return AnthropicConnector()
            }
            return MinimaxConnector()
        case "openai_chat":
            return OpenAICompatibleConnector(provider: provider)
        default:
            // Gemini + any other apiMode lands here until the matching
            // connector lands (= Gemini native connector is a separate
            // ticket per ConnectorTestButton.runTest).
            return AnthropicConnector()
        }
    }
}
