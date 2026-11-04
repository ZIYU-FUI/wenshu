//
//  WenshuAppDelegate+SubAgentDrainLoop.swift · Wenshu
//
//  Extension on `WenshuAppDelegate` (= the sub-agent drain loop: the
//  runner that drains pending `BackgroundDelegationHandle` records,
//  and the start / stop pair the launch and the shutdown path call).
//
//  The delegate's declaration, its constants and its stored state live
//  in `WenshuAppDelegate.swift`; the loop lives here.
//
//  The loop's state lives here too: a stored STATIC property is legal in an
//  extension (= the tree does it in fourteen files), so the runner and the
//  drain task the loop owns stay `private` to this file and cross no seam.
//
//  The file-level logger is this file's own (= the tree's convention:
//  every file that logs declares its own file-level `private let`
//  logger; = the subsystem and the category are the delegate's, = so
//  the log lines land where they always landed).
//

import Foundation
import os
import WenshuAgent
import WenshuData

private let wenshuLogger = Logger(subsystem: "com.wenshu", category: "wenshuappdelegate")

extension WenshuAppDelegate {
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
            auditorStorage: auditor,
            // The ledger every run writes to. Without it the rows
            // never exist, = and the archive pane has nothing to
            // show. The repository is the shared singleton (= the
            // same one the chat writes through).
            ledger: SubAgentLedger(repository: WSChatRepository.shared),
            // Where a finished run's result goes. = Without it the
            // user sees a dispatch receipt and then silence.
            resultDelivery: SubAgentResultDelivery(repository: LiveChatRepository.shared),
            // The card that shows a research delegation's progress.
            // = Without it the card stays in "running" forever, = and
            // the board lists intentions instead of outcomes.
            kanbanBridge: SubAgentKanbanBridge(repository: WSKanbanRepository.shared)
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
}
