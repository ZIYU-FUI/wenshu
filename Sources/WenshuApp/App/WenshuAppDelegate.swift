import SwiftUI
import AppKit

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

    // v0.21 ticket 01 (redo #7): SwiftUI 14+ OpenSettingsAction (LayoutShellView .onAppear, OpenSettingsAction.callAsFunction()).
    // v0.72 Q99 dual-axis fix: was `nonisolated(unsafe) static var` (= race-prone under Swift 6
    // strict concurrency). Replaced with @MainActor accessors (= Swift 6 strict concurrency; = NSLock not needed) (= safe under any
    // concurrency model). Reads via @MainActor; writes via @MainActor.
    @MainActor private static var _openSettings: OpenSettingsAction?
    @MainActor static var openSettings: OpenSettingsAction? {
        get { _openSettings }
        set { _openSettings = newValue }
    }

    /// v0.28 followup: debug Keychain override for cua / dev env without
    /// user-attached login keychain (= the InMemoryKeychainStore stub
    /// prevents SecItemCopyMatching from blocking wenshu main thread
    /// on the Keychain permission modal during dev/verify). Gated by
    /// WENSHU_DEBUG_INMEMORY_KEYCHAIN env var (= 1 = use in-memory stub,
    /// 0 = use real Apple keychain). Production builds never set this.
    ///
    /// v1.0.0-m1-shell boss 2026-09-10 OOB '做一个远程调试模式, 打开
    /// 后, 不要钥匙, 远程我也测试不了聊天, 只能调 ui': add the same
    /// UserDefaults override (= `wenshu.debugNoKeychain = YES`) for
    /// the boss's off-site UI iteration. The boss-set UserDefaults
    /// flip persists across launches (= the canonical 'remote debug
    /// mode' toggle = no keychain modal prompts = boss can iterate
    /// on UI without touching macOS Keychain). ProviderKeychain.backend
    /// also reads this UserDefaults (= two paths converge to the same
    /// InMemoryKeychainStore = no race condition on first keychain
    /// access).
    static let sharedKeychainBackend: Void = {
        if ProcessInfo.processInfo.environment["WENSHU_DEBUG_INMEMORY_KEYCHAIN"] == "1" {
            ProviderKeychain.setBackendForTesting(InMemoryKeychainStore())
            NSLog("[wenshu.debug] keychain backend = InMemoryKeychainStore (env var override)")
        } else if UserDefaults.standard.bool(forKey: "wenshu.debugNoKeychain") {
            ProviderKeychain.setBackendForTesting(InMemoryKeychainStore())
            NSLog("[wenshu.debug] keychain backend = InMemoryKeychainStore (UserDefaults override)")
        }
    }()

    static let sharedRuntime = AgentRuntime()
    static let sharedVerifier = WenshuVerifier()
    // Phase 5 ticket 10a: chat history now lives exclusively in
    // WSChatRepository.shared (= @MainActor SwiftData wrapper).
    // No per-actor sqlite3 bootstrap needed.
    // v0.72 Q99 dual-axis fix: was `nonisolated(unsafe) static var` (= race-prone).
    // Replaced with @MainActor accessor (= safe; = SwiftUI-compliant).
    @MainActor private static var _sharedConductor: WenshuConductor?
    @MainActor static var sharedConductor: WenshuConductor? {
        get { _sharedConductor }
        set { _sharedConductor = newValue }
    }



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
        // v0.21 ticket 06: synccreate KanbanStore + WenshuConductor (static let actor init)
        // (Phase 5 ticket 10a removed ChatSessionStore from this bootstrap)
        // unsafeMutablePointer / instance var — static let yes immutable,
// v0.24 bossverificationfix (Boss 8/24 'chat, '):
        // add NSLog for chat store init + bootstrap errors (silent catch
        // makes debugging hard), and post .wenshuChatStoreReady notification
        // so ChatView can retry load when store becomes available.
        // v0.72 SwiftData migration: trigger one-time sqlite3 → SwiftData migration
        // (idempotent; = skipped if WSManifest.migratedFromRawSqliteAt is set).
        // Runs BEFORE chat history is read (= so any chat data that needs migrating
        // is in SwiftData by the time ChatView reads).
        Task { @MainActor in
            do {
                try await WSMigrationRunner.migrateIfNeeded()
            } catch {
                NSLog("[wenshu.migration] FAILED: %@", String(describing: error))
            }
        }

        // v0.24 bossverificationfix (Boss 8/25 OOB 'yes .ws file'):
        // Chat persistence location = wenshu warehouse (anbaiqiang.ws/) if set,
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

        // Phase 5 ticket 1 sub-task 1b.3: activate the warehouse ModelContainer.
        //
        // When the warehouse URL is set (= UserDefaults "wenshu.libraryPath"),
        // makeContainerForWarehouse tries to build a SwiftData ModelContainer
        // inside that warehouse directory (= boss 8/25 OOB "chat data must live
        // in .ws warehouse" rule).
        //
        // On success: all Repository.shared singletons (= WSChatRepository,
        // WSKanbanRepository, etc.) will read from the warehouse container.
        //
        // On failure: activateWarehouseContainer(nil) keeps the default
        // Application Support path (= silent fallback; = logged for diagnosis).
        //
        // This runs BEFORE any chat-history view reads from the repository
        // (= so SwiftData repositories are ready before any view reads from them).
        // Post-Phase 5 ticket 10b: all 7 of the planned sqlite3 stores are deleted
        // (= KanbanStore + TodoStore + MemoryStore + LinkIndex + ChatSessionStore +
        // BookmarkStore + WenshuWorkspace). The warehouse container is the canonical SwiftData
        // home for all live data (= phase 4 migration runner imports legacy data
        // on first launch via WSMigrationRunner.migrateIfNeeded).
        // Remaining legacy sqlite3 actors (= separate from the per-store
        // "Stores" pattern): HermesKanbanDB + FullTextSearch (= helper indices,
        // not chat/kanban/toDo/memory persistence) and WSMigrationPerStore's
        // one-shot raw-sqlite3 importers (= read the LEGACY file paths that
        // users may have on disk from before the migration; = not a per-launch
        // save path).
        let warehouseURL = warehousePath.map { URL(fileURLWithPath: $0) }
        do {
            let warehouseContainer = try WSPersistenceContainer.makeContainerForWarehouse(warehouseURL)
            WSPersistenceContainer.activateWarehouseContainer(warehouseContainer)
            NSLog("[wenshu.persistence] warehouse container activated: %@",
                  warehouseURL?.path ?? "<none>")
        } catch {
            NSLog("[wenshu.persistence] warehouse container activation FAILED: %@",
                  String(describing: error))
            WSPersistenceContainer.activateWarehouseContainer(nil)
        }

        // v0.24 bossverificationfix (Boss 8/25 OOB Spec axis GAP): one-time migration
        // from legacy chat.sqlite to warehouse (preserves chat history when
        // user first picks a .ws warehouse in onboarding).
        if let warehouse = warehousePath {
            Self.migrateLegacyChatIfNeeded(warehousePath: warehouse, chatDbPath: chatDbPath)
        }

        // Phase 5 ticket 10a: ChatSessionStore actor + sqlite3 raw connection
        // removed. Chat history now lives in WSChatRepository.shared
        // (= @MainActor SwiftData wrapper; = warehouse container activated
        // above). No per-actor sqlite3 chat store bootstrap needed.
        Self.sharedConductor = WenshuConductor(
            runtime: Self.sharedRuntime,
            verifier: Self.sharedVerifier
        )
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
