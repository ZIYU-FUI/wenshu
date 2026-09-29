import SwiftUI
import AppKit

/// AppDelegate: WenshuCore runtime + macOS app init
final class WenshuAppDelegate: NSObject, NSApplicationDelegate {
    // bossverificationfix (Boss 8/25 OOB Spec axis GAP): one-time migration
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

    // Swift 6 strict concurrency fix (= the dual-axis sweep pattern):
    // was `nonisolated(unsafe) static var` (= race-prone).
    // Replaced with @MainActor accessors (= safe under any
    // concurrency model). Reads via @MainActor; writes via @MainActor.
    @MainActor private static var _openSettings: OpenSettingsAction?
    @MainActor static var openSettings: OpenSettingsAction? {
        get { _openSettings }
        set { _openSettings = newValue }
    }

    /// user-attached login keychain (= the InMemoryKeychainStore stub
    /// prevents SecItemCopyMatching from blocking wenshu main thread
    /// on the Keychain permission modal during dev/verify). Gated by
    /// WENSHU_DEBUG_INMEMORY_KEYCHAIN env var (= 1 = use in-memory stub,
    /// 0 = use real Apple keychain). Production builds never set this.
    ///
    /// don't require the keychain — I can't test chat remotely otherwise, I can only poke at the UI': add the same
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
    // Chat history now lives in
    // WSChatRepository.shared (= @MainActor SwiftData wrapper).
    // No per-actor sqlite3 bootstrap needed.
    // Swift 6 strict concurrency fix: was `nonisolated(unsafe) static var`
    // (= race-prone). Replaced with @MainActor accessor (= safe;
    // = SwiftUI-compliant).
    @MainActor private static var _sharedConductor: WenshuConductor?
    @MainActor static var sharedConductor: WenshuConductor? {
        get { _sharedConductor }
        set { _sharedConductor = newValue }
    }



    @MainActor @objc func resetLayout(_ sender: Any?) {
        NSLog("[wenshu.reset] NSMenu resetLayout(_:) called, posting")
        NotificationCenter.default.post(name: .wenshuResetLayout, object: nil)
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        // debug override takes effect before any Keychain access.
        _ = Self.sharedKeychainBackend
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
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
        // ( removed ChatSessionStore from this bootstrap)
        // unsafeMutablePointer / instance var — static let yes immutable,
// bossverificationfix (Boss 8/24 'chat, '):
        // add NSLog for chat store init + bootstrap errors (silent catch
        // makes debugging hard), and post .wenshuChatStoreReady notification
        // so ChatView can retry load when store becomes available.
        // SwiftData migration history (= per v1.55 sqlite3-zero arc):
        // WSMigrationRunner + WSMigrationPerStore were removed (= the
        // one-shot legacy sqlite3 importer). Legacy `.ws/chat.sqlite`
        // files (= pre-v0.72 data written by the deleted
        // ChatSessionStore actor) are now treated as orphaned files
        // (= no importer reads them; = no chat history migrates from
        // raw sqlite to SwiftData). New chat history lives entirely
        // in SwiftData
        // (= WSChatRepository.shared writes to ZWSCHATMESSAGE; = see
        // WenshuAppDelegate.swift:178-204 below).
        //
        // Idempotency note: previously this hook ran
        // `Task { try await WSMigrationRunner.migrateIfNeeded() }` once per launch.
        // Post-v1.55d that call is gone (= no code path left; = the entire
        // legacy-import mechanism is deleted alongside the file removal).

        // bossverificationfix (Boss 8/25 OOB 'yes .ws file'):
        // Chat persistence location = wenshu warehouse (anbaiqiang.ws/) if set,
        // else fall back to legacy ~/Library/Application Support/wenshu/chat.sqlite.
        // chat data must be part of the warehouse file so the
        // customer can copy the warehouse to another Mac and continue the
        // session history directly.
        let warehousePath = UserDefaults.standard.string(forKey: "wenshu.libraryPath")
        let chatDbPath: String? = warehousePath.map { path in
            // Warehouse is the directory selected via onboarding (.ws folder).
            // Place chat.sqlite inside it.
            (path as NSString).appendingPathComponent("chat.sqlite")
        }

        //  sub-task 1b.3: activate the warehouse ModelContainer.
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
        // Post-: all 7 of the planned sqlite3 stores are deleted
        // (= KanbanStore + TodoStore + MemoryStore + LinkIndex + ChatSessionStore +
        // BookmarkStore + WenshuWorkspace). The warehouse container is the canonical
        // SwiftData home for all live data. Post-v1.55d (= sqlite3 fully
        // removed): the one-shot legacy sqlite3 importer
        // (WSMigrationPerStore + WSMigrationRunner + SQLiteConstants) is DELETED
        // (= no legacy `.ws/*.sqlite` file is read by wenshu anymore; = legacy
        // chat.sqlite etc. become orphaned files on disk; = no chat history
        // migration). New chat history is written directly to SwiftData
        // (= WSChatRepository.shared → ZWSCHATMESSAGE).
        // HermesKanbanDB + FullTextSearch were REMOVED in v1.55
        // sqlite3-zero (= Apple-default-first + zero SPM dep).
        // `import SQLite3` count in production code = 0 (= was 2 pre-v1.55d:
        // SQLiteConstants.swift SQLITE_TRANSIENT helper + WSMigrationPerStore
        // raw-sqlite3 import; = both files removed).
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

        // bossverificationfix (Boss 8/25 OOB Spec axis GAP): one-time migration
        // from legacy chat.sqlite to warehouse (preserves chat history when
        // user first picks a .ws warehouse in onboarding).
        if let warehouse = warehousePath {
            Self.migrateLegacyChatIfNeeded(warehousePath: warehouse, chatDbPath: chatDbPath)
        }

        // : ChatSessionStore actor + sqlite3 raw connection
        // removed. Chat history now lives in WSChatRepository.shared
        // (= @MainActor SwiftData wrapper; = warehouse container activated
        // above). No per-actor sqlite3 chat store bootstrap needed.
        Self.sharedConductor = WenshuConductor(
            runtime: Self.sharedRuntime,
            verifier: Self.sharedVerifier
        )
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

        // Sub-agent runner drain loop (= v2.7d team-link consolidation):
        // Start the sub-agent runner drain loop after all other
        // bootstraps (= the SwiftData container + conductor + runtime
        // + connector must be ready before the runner first fires).
        // The runner reads from AsyncDelegationRegistry.shared (= the
        // singleton the LLM-facing DelegateResearchTool writes to; =
        // see v2.7 arc §11.17 history note for the shared-singleton
        // rationale). Idempotent: calling startSubAgentDrainLoop
        // twice is a no-op.
        Self.startSubAgentDrainLoop()
    }

    func applicationWillTerminate(_ notification: Notification) {
        // bossverificationfix (v2.7d): cancel the sub-agent drain
        // loop (= future handles do not start; = the in-flight LLM
        // call, if any, continues to completion via the runner's own
        // cancellation-handling path).
        Self.stopSubAgentDrainLoop()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    /// Sub-agent runner (= the engine that drains pending
    /// `BackgroundDelegationHandle` records and runs each sub-agent
    /// in its own `ConversationLoop`). One per app (= process-lifetime).
    /// Created lazily on first drain (= after `AsyncDelegationRegistry.shared`
    /// is reachable).
    private nonisolated(unsafe) static var sharedSubAgentRunner: SubAgentRunner?

    /// Background Task that calls `runner.drainPending()` on a loop
    /// (= 1s sleep when no handles are pending; = no sleep when handles
    /// are running). Cancelled in `applicationWillTerminate`.
    private nonisolated(unsafe) static var subAgentDrainTask: Task<Void, Never>?

    /// Start the sub-agent runner drain loop (= v2.7d team-link
    /// consolidation): every 1s (= or sooner when a new handle lands),
    /// the runner picks up pending `BackgroundDelegationHandle` records
    /// from `AsyncDelegationRegistry.shared` (= the source-of-truth
    /// the LLM-facing `DelegateResearchTool` writes to) and runs
    /// each sub-agent in its own `ConversationLoop` with the
    /// sub-agent's system prompt + tool subset.
    ///
    /// Threading:
    ///   - The drain task is `Task.detached(priority: .background)`
    ///     (= runs off MainActor; = the LLM round-trip inside the
    ///     runner does not block UI).
    ///   - The runner itself is `@MainActor` (= its `drainPending`
    ///     method hops to MainActor per call).
    ///   - Cancel via `subAgentDrainTask?.cancel()` in
    ///     `applicationWillTerminate` (= the in-flight LLM call
    ///     continues to completion; = future handles do not start).
    ///
    /// Idempotency: calling `startSubAgentDrainLoop` twice is a no-op
    /// (= the second call returns immediately if `subAgentDrainTask`
    /// is already non-nil). This makes the method safe to call from
    /// any post-launch hook (= e.g. a future "reconnect" path).
    @MainActor
    static func startSubAgentDrainLoop() {
        // Idempotency guard (= already running).
        guard subAgentDrainTask == nil else { return }

        // Lazy runner creation (= resolves the active LLM connector
        // at startup time; = mirrors `WenshuAppDelegate.activeLLMConnector()`
        // used by the main agent's ChatView). ToolRegistry.shared is
        // safe to read here (= it's an actor; = init is synchronous).
        //
        // v2.7d storage adapters: Archivist + Auditor sub-agents
        // bypass the LLM tool dispatch path (= their domains are
        // deterministic storage / memory reads). Inject
        // LiveArchivistStorage + LiveAuditorStorage at startup so
        // the runner's per-agent dispatch can route Archivist +
        // Auditor to the storage path instead of runRealSubAgent.
        let archiveRoot: URL
        if let path = UserDefaults.standard.string(forKey: "wenshu.libraryPath") {
            archiveRoot = URL(fileURLWithPath: path).appendingPathComponent("archives", isDirectory: true)
        } else {
            archiveRoot = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("wenshu-archives", isDirectory: true)
        }
        let archivist = LiveArchivistStorage(archiveRoot: archiveRoot)
        let auditor = LiveAuditorStorage()
        let runner = SubAgentRunner(
            connector: activeLLMConnector(),
            toolRegistry: ToolRegistry.shared,
            archivistStorage: archivist,
            auditorStorage: auditor
        )
        sharedSubAgentRunner = runner

        subAgentDrainTask = Task.detached(priority: .background) {
            // Detached loop: drain pending handles; = sleep 1s when
            // nothing pending (= no busy-wait). The runner's
            // `drainPending()` method processes up to `maxBatchSize`
            // handles per call (= 3 by default; = caps burst rate).
            while !Task.isCancelled {
                let n = await runner.drainPending()
                if n == 0 {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                }
            }
        }
        NSLog("[wenshu.subagent] drain loop started")
    }

    /// Stop the sub-agent runner drain loop (= v2.7d cancel path).
    /// Called from `applicationWillTerminate`. The in-flight LLM
    /// call (= if any) continues to completion; = future handles do
    /// not start.
    @MainActor
    static func stopSubAgentDrainLoop() {
        subAgentDrainTask?.cancel()
        subAgentDrainTask = nil
        sharedSubAgentRunner = nil
        NSLog("[wenshu.subagent] drain loop stopped")
    }

    /// 
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
    nonisolated static func activeLLMConnector() -> any LLMConnector {
        let slug = UserDefaults.standard.string(forKey: "wenshu.llm.activeConnector")
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
