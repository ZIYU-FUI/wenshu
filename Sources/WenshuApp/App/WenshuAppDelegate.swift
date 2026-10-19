import AppKit
import SwiftUI
import WenshuData
import os

private let wenshuLogger = Logger(subsystem: "com.wenshu", category: "wenshuappdelegate")

/// AppDelegate: WenshuCore runtime + macOS app init
final class WenshuAppDelegate: NSObject, NSApplicationDelegate {
    // wenshu-verification-fix ((see OOB.md #2026-08-25) Spec axis GAP): one-time
    // migration from legacy chat.sqlite to warehouse. Preserves chat history when
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
            wenshuLogger.info("[wenshu.chatStore] migrated legacy chat.sqlite to \(chatDbPath)")
        } catch {
            wenshuLogger.info("[wenshu.chatStore] legacy chat migration FAILED: \(String(describing: error))")
        }
    }

    // Swift 6 strict concurrency fix (= the dual-axis sweep pattern): was
    // `nonisolated(unsafe) static var` (= race-prone). Replaced with @MainActor
    // accessors (= safe under any concurrency model). Reads via @MainActor; writes
    // via @MainActor.
    @MainActor private static var _openSettings: OpenSettingsAction?
    @MainActor static var openSettings: OpenSettingsAction? {
        get { _openSettings }
        set { _openSettings = newValue }
    }

    /// user-attached login keychain (= the InMemoryKeychainStore stub prevents
    /// SecItemCopyMatching from blocking wenshu main thread on the Keychain
    /// permission modal during dev/verify). Gated by
    /// WENSHU_DEBUG_INMEMORY_KEYCHAIN env var (= 1 = use in-memory stub, 0 =
    /// use real Apple keychain). Production builds never set this.
    /// don't require the keychain — I can't test chat remotely otherwise, I can
    /// only poke at the UI': add the same UserDefaults override (=
    /// `wenshu.debugNoKeychain = YES`) for off-site UI iteration. The user-set
    /// UserDefaults flip persists across launches (= the canonical 'remote
    /// debug mode' toggle = no keychain modal prompts = the user can iterate on
    /// UI without touching macOS Keychain). ProviderKeychain.backend also reads
    /// this UserDefaults (= two paths converge to the same
    /// InMemoryKeychainStore = no race condition on first keychain access).
    static let sharedKeychainBackend: Void = {
        if ProcessInfo.processInfo.environment["WENSHU_DEBUG_INMEMORY_KEYCHAIN"] == "1" {
            ProviderKeychain.setBackendForTesting(InMemoryKeychainStore())
            wenshuLogger.info("[wenshu.debug] keychain backend = InMemoryKeychainStore (env var override)")
        } else if UserDefaults.standard.bool(forKey: "wenshu.debugNoKeychain") {
            ProviderKeychain.setBackendForTesting(InMemoryKeychainStore())
            wenshuLogger.info("[wenshu.debug] keychain backend = InMemoryKeychainStore (UserDefaults override)")
        }
    }()

    static let sharedRuntime = AgentRuntime()
    // AUDIT.md §2.2 partial (2026-10-16 boss "把切换包的事清干净"
    // arc): the `sharedVerifier` static was deleted; = the
    // verifier actor is now a thin bridge to WenshuAgent.shared
    // (= the canonical LLM call entry point; = no static
    // verifier instance is needed at the AppDelegate level).
    // Chat history now lives in WSChatRepository.shared (= @MainActor SwiftData wrapper).
    // No per-actor sqlite3 bootstrap needed. Swift 6 strict concurrency fix: was
    // `nonisolated(unsafe) static var` (= race-prone). Replaced with @MainActor
    // accessor (= safe; = SwiftUI-compliant).
    // AUDIT.md §2.2 partial (2026-10-16): `WenshuAppDelegate
    // .sharedConductor` was the static source of truth for
    // the conductor instance. After the WenshuAgent.shared
    // facade landed, the public facade is the canonical
    // owner (= the WenshuAppDelegate installs the conductor
    // once at app launch via `WenshuAgent.shared.install
    // Conductor(_:)`; = the public facade also publishes
    // to a nonisolated snapshot via the new
    // `currentConductorSync()` method). This static now
    // reads from the facade snapshot; = future callers
    // should call `WenshuAgent.shared.currentConductorSync()`
    // directly (= this static is the deprecation bridge
    // for the remaining 4 init-param callers that need a
    // `var` to read at init time).
    @MainActor static var sharedConductor: WenshuConductor? {
        WenshuAgent.shared.currentConductorSync()
    }

    @MainActor @objc func resetLayout(_ sender: Any?) {
        wenshuLogger.info("[wenshu.reset] NSMenu resetLayout(_:) called, posting")
        NotificationCenter.default.post(name: .wenshuResetLayout, object: nil)
    }

    // SwiftData library upgrade panel wiring (see OOB.md #2026-10-06). WenshuAppDelegate
    // owns the state and the retry closure because the Window scene body in
    // AppRootScene has no constructor arguments (= Scene content closures are
    // static). applicationDidFinishLaunching populates both fields BEFORE opening
    // the panel window; = the Window body reads them via these static accessors.
    // Threading: MainActor (= both the panel view and the AppDelegate's launch
    // hook live on the main thread).
    @MainActor static var sharedMigrationState: LibraryMigrationState?
    @MainActor static var sharedMigrationRetry: (() -> Void)?

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        // debug override takes effect before any Keychain access.
        _ = Self.sharedKeychainBackend
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // One-shot legacy cleanup: drop the 'wenshu.libraryPath' UserDefaults string (=
        // retired when the active library became a security-scoped bookmark
        // via LibraryBookmark; see State/ActiveLibrary.swift). The previous
        // bind wrote the .ws bundle path to UserDefaults.standard on every
        // launch (= via LibraryRootView.s @AppStorage binding)
        // user still has the legacy string in UserDefaults. After this commit,
        // no production code reads 'wenshu.libraryPath' (= all reads go
        // through ActiveLibrary.path), so the legacy string is dead weight (=
        // it would still bind through the @AppStorage binding in
        // LibraryRootView, = now removed in a follow-up commit). Dropping it
        // here means the next launch starts clean.
        if UserDefaults.standard.string(forKey: "wenshu.libraryPath") != nil {
            UserDefaults.standard.removeObject(forKey: "wenshu.libraryPath")
        }
        // button, not okdouble-click, ' = titlebarAppearsTransparent + titleVisibility =
        // .hidden removes traffic lights AND double-click-to-zoom (= breaks
        // macOS standard window controls). Don't do that. Keep the macOS
        // native titlebar (= 28 PT compact with traffic lights + double-click-
        // to-zoom) and put the titlebar icons INSIDE it via .toolbar {
        // ToolbarItem(.principal) } (= exactly macOS standard = native toolbar
        // buttons next to traffic lights = matches Apple Pages / Xcode / Mail
        // etc.). ( removed ChatSessionStore from this bootstrap)
        // unsafeMutablePointer / instance var — static let yes immutable,
// wenshu-verification-fix ((see OOB.md #2026-08-24) — 'chat,'):
        // add NSLog for chat store init + bootstrap errors (silent catch makes debugging
        // hard), and post .wenshuChatStoreReady notification so ChatView can
        // retry load when store becomes available. SwiftData migration history
        // (= per sqlite3-zero arc): WSMigrationRunner + WSMigrationPerStore
        // were removed (= the one-shot legacy sqlite3 importer). Legacy
        // `.ws/chat.sqlite` files (= previous data written by the deleted
        // ChatSessionStore actor) are now treated as orphaned files (= no
        // importer reads them; = no chat history migrates from raw sqlite to
        // SwiftData). New chat history lives entirely in SwiftData (=
        // WSChatRepository.shared writes to ZWSCHATMESSAGE; = see
        // WenshuAppDelegate.swift:178-204 below). Idempotency note: previously
        // this hook ran `Task { try await WSMigrationRunner.migrateIfNeeded()
        // }` once per launch. Post-migration that call is gone (= no code path
        // left; = the entire legacy-import mechanism is deleted alongside the
        // file removal).

        // wenshu-verification-fix ((see OOB.md #2026-08-25) — 'yes .ws file'): Chat
        // persistence location = wenshu warehouse (anbaiqiang.ws/) if set,
        // else fall back to legacy ~/Library/Application
        // Support/wenshu/chat.sqlite. chat data must be part of the warehouse
        // file so the customer can copy the warehouse to another Mac and
        // continue the session history directly.
        let warehousePath = ActiveLibrary.path
        let chatDbPath: String? = warehousePath.map { path in
            // Warehouse is the directory selected via onboarding (.ws folder). Place
            // chat.sqlite inside it.
            (path as NSString).appendingPathComponent("chat.sqlite")
        }

        // sub-task 1b.3: activate the warehouse ModelContainer. When the warehouse URL is
        // set (= UserDefaults "wenshu.libraryPath"), makeContainerForWarehouse
        // tries to build a SwiftData ModelContainer inside that warehouse
        // directory ((see OOB.md #2026-08-25) — 'chat data must live in .ws
        // warehouse' rule). On success: all Repository.shared singletons (=
        // WSChatRepository, WSKanbanRepository, etc.) will read from the
        // warehouse container. On failure: activateWarehouseContainer(nil)
        // keeps the default Application Support path (= silent fallback; =
        // logged for diagnosis). This runs BEFORE any chat-history view reads
        // from the repository (= so SwiftData repositories are ready before
        // any view reads from them). Post-: all 7 of the planned sqlite3
        // stores are deleted (= KanbanStore + TodoStore + MemoryStore +
        // LinkIndex + ChatSessionStore + BookmarkStore + WenshuWorkspace). The
        // warehouse container is the canonical SwiftData home for all live
        // data. Post-migration (= sqlite3 fully removed): the one-shot legacy
        // sqlite3 importer (WSMigrationPerStore + WSMigrationRunner +
        // SQLiteConstants) is DELETED (= no legacy `.ws/*.sqlite` file is read
        // by wenshu anymore; = legacy chat.sqlite etc. become orphaned files
        // on disk; = no chat history migration). New chat history is written
        // directly to SwiftData (= WSChatRepository.shared → ZWSCHATMESSAGE).
        // HermesKanbanDB + FullTextSearch were REMOVED in the migration
        // sqlite3-zero (= Apple-default-first + zero SPM dep). `import
        // SQLite3` count in production code = 0 (= was 2 pre-migration:
        // SQLiteConstants.swift SQLITE_TRANSIENT helper + WSMigrationPerStore
        // raw-sqlite3 import; = both files removed). save path).
        let warehouseURL = warehousePath.map { URL(fileURLWithPath: $0) }
        do {
            let warehouseContainer = try WSPersistenceContainer.makeContainerForWarehouse(warehouseURL)
            WSPersistenceContainer.activateWarehouseContainer(warehouseContainer)
            wenshuLogger.info("[wenshu.persistence] warehouse container activated: \(warehouseURL?.path ?? "<none>")")
        } catch {
            wenshuLogger.info("[wenshu.persistence] warehouse container activation FAILED: \(String(describing: error))")
            WSPersistenceContainer.activateWarehouseContainer(nil)
        }

        // wenshu-verification-fix ((see OOB.md #2026-08-25) Spec axis GAP): one-time
        // migration from legacy chat.sqlite to warehouse (preserves chat
        // history when user first picks a .ws warehouse in onboarding).
        if let warehouse = warehousePath {
            Self.migrateLegacyChatIfNeeded(warehousePath: warehouse, chatDbPath: chatDbPath)
        }

        // SwiftData library upgrade check (see OOB.md #2026-10-06). When the user's .ws
        // Info.plist WSSchemaVersion is below ModelsSchemaV2 (= the current
        // SwiftData version), open the migration panel BEFORE the main app
        // mounts the NavigationSplitView (= the columns would otherwise read
        // half-migrated SwiftData state). The panel runs the .lightweight V1
        // -> V2 migration driven by WenshuMigrationPlan (= 002 ticket); = on
        // success the main window appears and the user continues normally.
        // NOTE (= TODO): the trigger condition `LibraryInfo(wsRoot:
        // ...).needsMigration` compares Info.plist's WSSchemaVersion (=
        // application-layer schema version) against CURRENT_SCHEMA_VERSION (=
        // which is 1 today; = same as the SwiftData ModelsSchemaV1). To
        // actually trigger the migration path for real users, the .ws
        // Info.plist's WSSchemaVersion would need to be BUMPED to 2 in a
        // future release (= the .ws layout-side bump happens via
        // LibraryMigrator.writeOrUpdateSchemaVersion when
        // CURRENT_SCHEMA_VERSION is raised). For this commit the wire-up is in
        // place (= panel + state + openWindow + AppState flag); = the trigger
        // fires when the bump arrives (= no manual trigger needed; = the next
        // CURRENT_SCHEMA_VERSION bump lands the migration on every user's next
        // launch automatically).
        if let warehousePath, let wsRoot = URL(string: "file://\(warehousePath)") {
            WenshuAppDelegateSwiftDataMigration.attemptSwiftDataMigrationIfNeeded(wsRoot: wsRoot)
        }

        // : ChatSessionStore actor + sqlite3 raw connection removed. Chat history now
        // lives in WSChatRepository.shared (= @MainActor SwiftData wrapper; =
        // warehouse container activated above). No per-actor sqlite3 chat
        // store bootstrap needed.
        // AUDIT.md §2.2 partial (2026-10-16): the conductor
        // instance is now built first, then installed into
        // the public facade (= WenshuAgent.shared is the
        // canonical owner; = the AppDelegate no longer holds
        // the canonical reference).
        let conductorInstance = WenshuConductor(
            runtime: Self.sharedRuntime,
            // P0-AGENT-LOOP (2026-10-16 boss OOB "agent 没有达到 agent 的标准"):
            // the conductor used to be constructed without a connector,
            // which forced every call through `runLegacyConductorPipeline`
            // (= 1 LLM call + 1 reply, = no tool dispatch loop). = the
            // user saw the model say "let me check that for you" with no
            // follow-up (= the "small liar" bug). The fix is to give the
            // conductor the active connector so it routes through
            // `runConversationLoopPath` (= the ReAct loop with
            // `maxAgentTurns = 10`).
            connector: WenshuAppDelegateLLMHelpers.activeLLMConnector()
        )
        // AUDIT.md §2.2 partial (2026-10-16 boss "把切换包的事
        // 清干净" arc): the bridge setter is deleted; = the
        // install goes directly through the public facade.
        // The `WenshuAppDelegate.sharedConductor` getter (= the
        // deprecation bridge for SwiftUI `var` callers like
        // ChatZoneView, ChatView, ChatSessionViewModel,
        // EditorChatNSController) still reads from the
        // facade's nonisolated snapshot.
        Task { await WenshuAgent.shared.installConductor(conductorInstance) }

        // Warm the provider-with-keys cache (= AUDIT.md §2.2 partial:
        // ChatView.hasUsableKey + ChatZoneView's empty-state gate
        // both read the sync-cached variant via
        // `WenshuAgent.shared.hasProvidersWithKeysCached()`). The
        // cache is empty until something calls `providersWithKeys()`.
        // `providersWithKeys()` now posts `.wenshuProviderKeychainChanged`
        // on the main queue when the contents change (= the canonical
        // trigger ChatZoneView + ChatView already subscribe to), so
        // a single warm-up at launch both fills the cache and
        // tells the SwiftUI tree to re-evaluate the empty-state
        // overlay (= no leftover "请先在设置中设置..." card after
        // a launch when a key is already present).
        Task { await WenshuAgent.shared.providersWithKeys() }

        let card = AgentCard(
            name: "wenshu",
            description: "wenshu 本地主 agent, 接 MiniMax key, 支持 chat UI",
            skills: ["chat", "memory", "kanban"],
            endpoint: "in-process://wenshu"
        )
        // AUDIT.md §2.2 partial (2026-10-16 boss "把切换包的事
        // 清干净" arc): AgentProtocol no longer takes a
        // WenshuVerifier (= the verifier is a thin bridge to
        // WenshuAgent.shared). The A2A protocol handler now uses
        // the canonical conductor (= fetched from the public
        // facade) as its LLM call entry point. (= the
        // applicationDidFinishLaunching function is sync; = the
        // facade's currentConductorSync() is the nonisolated
        // snapshot accessor; = no `await` needed here.)
        let protocol_ = AgentProtocol(agentCard: card, conductor: WenshuAgent.shared.currentConductorSync())
        Task { @MainActor in
            await Self.sharedRuntime.register(AgentRegistration(
                name: "wenshu", card: card, process: protocol_
            ))
        }
        // P3 / P0 agent arc 2026-10-16: route the conductor through
        // WenshuAgent.shared (= the public facade; = the 14 caller
        // migration enabler). `WenshuConductor()` already has the
        // active connector wired (per the P0-AGENT-LOOP rationale
        // above), so installing it on the facade propagates that
        // fix to every future caller that uses WenshuAgent.shared
        // .chat() / .currentConductor().
        Task { await WenshuAgent.shared.installConductor(conductorInstance) }

        NSApp.activate(ignoringOtherApps: true)
        if ProcessInfo.processInfo.environment["WS_SCREENSHOT"] == "1" {
            SelfScreenshot.run()
        }

        // Sub-agent runner drain loop (= the team-link consolidation): Start the sub-
        // agent runner drain loop after all other bootstraps (= the SwiftData
        // container + conductor + runtime + connector must be ready before the
        // runner first fires). The runner reads from
        // AsyncDelegationRegistry.shared (= the singleton the LLM-facing
        // DelegateResearchTool writes to; = see the arc §11.17 history note
        // for the shared-singleton rationale). Idempotent: calling
        // startSubAgentDrainLoop twice is a no-op.
        Self.startSubAgentDrainLoop()
        // 2026-10-14: enable macOS 27 Window Tabs (= NSWindow tabbingMode = .preferred)
        // for every window the app owns (= the canonical "框架自带" tab mechanism;
        // = the View → Show Tab Bar menu command toggles this state; = the
        // system-drawn tab bar appears under the window title bar; = cmd+T /
        // cmd+shift+B work natively; = no wenshu code maintains the tab list).
        // This is the Apple HIG 1:1 path the boss asked for (= the
        // "NSWindow.tabbingMode = .preferred" path from the 2026-10-14 OOB).
        // The wenshu business tabs (= the per-document editor tabs in the
        // editor zone) are still wenshu-managed; = the Window Tabs and the
        // business tabs are orthogonal (= the Window Tabs = a whole window per
        // document, the business tabs = many documents in one window). The
        // boss can compare the two visual side by side. 2026-10-14 v2 (= boss
        // 2026-10-14 (see OOB.md #2026-10-14) directive): the Window Tabs
        // feature is REMOVED. The `tabbingMode = .preferred` path that the
        // previous block enabled is REVERTED below (= the iteration variable
        // is empty; = no window gets `tabbingMode = .preferred`; = no
        // `tabbingIdentifier` is set; = the macOS 27 "Show Tab Bar" / "Show
        // All Tabs" menu items in the View menu become unavailable (= the
        // framework hides them when no window in the app is tabbing-enabled)).
        // The `NSWindow.allowsAutomaticWindowTabbing = false` static guard
        // below (= set once at app launch; = affects every future NSWindow the
        // app creates; = the canonical AppKit guard for "this app does not use
        // window tabbing") is the final lock = even if some third-party
        // framework enables it, the OS-level menu hooks still hide the View
        // menu items. Reason for removal (= the boss 2026-10-14 "每一下 都独立 持久化
        // 一份数 据" / "这不 是我们 想要的 东西" root cause): each macOS Window Tab creates
        // an independent NSWindow; = each NSWindow hydrates its own SwiftData
        // ModelContainer (= the warehouse file is shared on disk but each
        // window opens its own sqlite handle + its own in-memory SwiftData
        // cache; = a 12-tab set = 12 sqlite handles + 12 caches; = memory +12x
        // + 12 write-coordination risks). The wenshu business tabs (= the
        // single-window- N-docs pattern) share ONE SwiftData container (= the
        // canonical wenshu 1:1 pattern; = the user opens many docs in one
        // window; = the data is consistent across docs because they share the
        // same SwiftData instance). The macOS Window Tabs is the opposite
        // pattern (= the Xcode / Preview pattern; = each tab = independent
        // document = independent state). The mismatch is fundamental; = the
        // fix is to disable Window Tabs entirely.
        for window in NSApp.windows {
            // Intentionally empty (= the 2026-10-14 v1 implementation here set
            // `tabbingMode = .preferred`; = the v2 directive disables the
            // feature; = the loop body is kept as a marker so the next
            // engineer sees where window-tabbing was previously toggled
            // and where to re-add it if the boss later reverts the
            // directive).
            _ = window
        }
        // 2026-10-14 v2: hard-disable macOS Window Tabs at the AppKit framework level (=
        // the canonical AppKit "this app does not support window tabbing"
        // switch; = set once at app launch; = affects every NSWindow the app
        // creates thereafter; = the macOS 27 View menu's "Show Tab Bar" /
        // "Show All Tabs" items disappear entirely when this is false; = users
        // cannot enable window tabbing from anywhere in the app; = the menu
        // hook the boss wants "封起 来" is closed).
        NSWindow.allowsAutomaticWindowTabbing = false
    }

    func applicationWillTerminate(_ notification: Notification) {
        // bossverificationfix: cancel the sub-agent drain loop (= future handles do not
        // start; = the in-flight LLM call, if any, continues to completion via
        // the runner's own cancellation-handling path).
        Self.stopSubAgentDrainLoop()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    /// Sub-agent runner (= the engine that drains pending
    /// `BackgroundDelegationHandle` records and runs each sub-agent in its own
    /// `ConversationLoop`). One per app (= process-lifetime). Created lazily on
    /// first drain (= after `AsyncDelegationRegistry.shared` is reachable).
    private nonisolated(unsafe) static var sharedSubAgentRunner: SubAgentRunner?

    /// Background Task that calls `runner.drainPending()` on a loop (= 1s sleep
    /// when no handles are pending; = no sleep when handles are running).
    /// Cancelled in `applicationWillTerminate`.
    private nonisolated(unsafe) static var subAgentDrainTask: Task<Void, Never>?

    /// Start the sub-agent runner drain loop (= the team-link consolidation):
    /// every 1s (= or sooner when a new handle lands), the runner picks up
    /// pending `BackgroundDelegationHandle` records from
    /// `AsyncDelegationRegistry.shared` (= the source-of-truth the LLM-facing
    /// `DelegateResearchTool` writes to) and runs each sub-agent in its own
    /// `ConversationLoop` with the sub-agent's system prompt + tool subset.
    /// Threading: - The drain task is `Task.detached(priority: .background)` (=
    /// runs off MainActor; = the LLM round-trip inside the runner does not
    /// block UI). - The runner itself is `@MainActor` (= its `drainPending`
    /// method hops to MainActor per call). - Cancel via
    /// `subAgentDrainTask?.cancel()` in `applicationWillTerminate` (= the
    /// in-flight LLM call continues to completion; = future handles do not
    /// start).
    /// Idempotency: calling `startSubAgentDrainLoop` twice is a no-op (= the
    /// second call returns immediately if `subAgentDrainTask` is already
    /// non-nil). This makes the method safe to call from any post-launch hook
    /// (= e.g. a future "reconnect" path).
    @MainActor
    static func startSubAgentDrainLoop() {
        // Idempotency guard (= already running).
        guard subAgentDrainTask == nil else { return }

        // Lazy runner creation (= resolves the active LLM connector at startup time; =
        // mirrors `WenshuAppDelegateLLMHelpers.activeLLMConnector()` used by the main
        // agent's ChatView). ToolRegistry.shared is safe to read here (= it's
        // an actor; = init is synchronous). adapters: Archivist + Auditor sub-
        // agents bypass the LLM tool dispatch path (= their domains are
        // deterministic storage / memory reads). Inject LiveArchivistStorage +
        // LiveAuditorStorage at startup so the runner's per-agent dispatch can
        // route Archivist + Auditor to the storage path instead of
        // runRealSubAgent.
        let archiveRoot: URL
        if let path = ActiveLibrary.path {
            archiveRoot = URL(fileURLWithPath: path).appendingPathComponent("archives", isDirectory: true)
        } else {
            archiveRoot = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("wenshu-archives", isDirectory: true)
        }
        let archivist = LiveArchivistStorage(archiveRoot: archiveRoot)
        let auditor = LiveAuditorStorage()
        let runner = SubAgentRunner(
            connector: WenshuAppDelegateLLMHelpers.activeLLMConnector(),
            toolRegistry: ToolRegistry.shared,
            archivistStorage: archivist,
            auditorStorage: auditor
        )
        sharedSubAgentRunner = runner

        subAgentDrainTask = Task.detached(priority: .background) {
            // Detached loop: drain pending handles; = sleep 1s when nothing pending (= no
            // busy-wait). The runner's `drainPending()` method processes
            // up to `maxBatchSize` handles per call (= 3 by default; =
            // caps burst rate).
            while !Task.isCancelled {
                let n = await runner.drainPending()
                if n == 0 {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                }
            }
        }
        wenshuLogger.info("[wenshu.subagent] drain loop started")
    }

    /// Stop the sub-agent runner drain loop (= v2.7d cancel path). Called from
    /// `applicationWillTerminate`. The in-flight LLM call (= if any) continues
    /// to completion; = future handles do not start.
    @MainActor
    static func stopSubAgentDrainLoop() {
        subAgentDrainTask?.cancel()
        subAgentDrainTask = nil
        sharedSubAgentRunner = nil
        wenshuLogger.info("[wenshu.subagent] drain loop stopped")
    }

// (extracted to WenshuAppDelegateLLM.swift in A35; = see that file)
// (= the 3 LLM/connector helper static funcs = activeConnectorSlug
// + activeLLMConnector + activeModelSlug = 106 LOC moved out of
// the main delegate class.)

    // SwiftData library upgrade entry point (see OOB.md #2026-10-06). Wired from
    // applicationDidFinishLaunching; = called once per launch with the user's
    // active .ws root. Detection: read Info.plist's WSSchemaVersion (= the
    // application-layer schema version), compare against ModelsSchemaV2 (= the
    // current SwiftData version). When the application layer is below, we open the
    // migration panel and run the 3-stage pipeline. 3-stage pipeline (= real
    // progress; = not a fake timer): preparing = back up the user's
    // .ws/WenshuStore.store to .ws/migration-backups/v<old>-<ts>.store; =
    // bookkeeping so a catastrophic migration failure never costs the user their
    // library. executing = ModelContainer init with the plan in place (= SwiftData
    // runs WenshuMigrationPlan.lightweight V1 -> V2 internally); = this is where
    // the real schema diff is applied. finalizing = write the new WSSchemaVersion
    // (= 2) to the .ws Info.plist so the next launch skips the panel (= the user
    // is on V2). The pipeline drives LibraryMigrationState (= 003 ticket) through
    // begin / beginExecuting / beginFinalizing / complete / fail; = the
    // LibraryMigrationPanel renders that state. The retry closure is stashed on
    // the AppDelegate so the panel's 重试 button can call back into here (= re-runs
    // the same pipeline). Idempotent: if needsMigration is false (= the user's .ws
    // is already on the current schema version), the function returns immediately
    // without opening the panel or touching state.
    // (445 extracted to WenshuAppDelegateSwiftDataMigration.swift in A41; = see that file)


    /// AppState bridge for the migration panel. Set once by the AppRootScene
    /// via .onAppear (= before any openWindow call).
    @MainActor static var sharedAppState: AppState?

    /// Setter for the openWindow action (= AppRootScene's .commands block
    /// injects it once via .onAppear). The migration entry point reads it to
    /// open the panel window.
    @MainActor static var openWindowAction: OpenWindowAction?
    // (513 extracted to WenshuAppDelegateSwiftDataMigration.swift in A41; = see that file)

    // (568 extracted to WenshuAppDelegateSwiftDataMigration.swift in A41; = see that file)

    // (589 extracted to WenshuAppDelegateSwiftDataMigration.swift in A41; = see that file)


    /// (= boss 2026-10-10 (see OOB.md #2026-10-10) agent needs the on-disk
    /// shelvesRoot (= to resolve a target book's directory at write time).
    /// Without an active library (= first-launch / pre-onboarding), returns
    /// nil.
    nonisolated static func activeShelvesRoot() -> URL? {
        guard let wsRoot = ActiveLibrary.path else { return nil }
        let url = URL(fileURLWithPath: wsRoot)
        return url.appendingPathComponent("shelves", isDirectory: true)
    }
}
