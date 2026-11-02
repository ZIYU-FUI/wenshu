//
//  WenshuConductorToolBuilder.swift
//
//  Tool-building factory extracted from WenshuConductor.swift in A115.
//  `buildToolsSync` was 233 LOC = 3.88x the §6.6 60-LOC function cap.
//

import Foundation
import WenshuAgent
import os

extension WenshuConductor {

    static func buildToolsSync(from registry: ToolRegistry) -> [String: any Tool] {
        // Hot path: cache hit (= NSLock-guarded sync read = nanoseconds).
        //
        // The cache is the one this task scoped (= the process-wide
        // one unless a test installed its own; = see
        // `withToolCacheForTesting(from:perform:)`).
        let cache = Self.currentToolCache
        if let cached = cache.cachedTools {
            return cached
        }

        // Cold path: fix for "agent not
        // … (= 21 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // cache is hot before ChatView.init fires.
        let registry = registry
        Task.detached(priority: .userInitiated) {
            let tools = await Self.buildTools(from: registry)
            // The cache this call read, captured (= the detached task
            // does not inherit the caller's task-local scope, so it
            // writes to the instance the caller chose, not to
            // whichever one is current when the task runs).
            cache.cachedTools = tools
        }
        return [:]
    }

    /// The tool cache this call reads and fills.
    ///
    /// A test can install a cache of its own with
    /// `withToolCacheForTesting(from:perform:)`. The scope exists so
    /// a suite's verdict does not depend on the process-wide cache's
    /// warmth, which is the order the suites happen to run in.
    private static var currentToolCache: ToolCache {
        _scopedToolCache ?? toolCache
    }

    /// The scoped tool cache (= nil = the process-wide one).
    @TaskLocal
    private static var _scopedToolCache: ToolCache?

    /// Test-only: run `body` with a tool cache of its own, filled
    /// from `registry` before the body starts.
    ///
    /// The process-wide cache is cold until the first call fills it,
    /// and the cold path hands the caller an empty dict (= the fill
    /// lands on a detached task). A suite that reads the cache
    /// therefore sees a different answer depending on whether another
    /// suite got there first. A suite that installs a cache of its own
    /// sees the same answer every time.
    ///
    /// Production code never calls this.
    static func withToolCacheForTesting<R>(
        from registry: ToolRegistry,
        perform body: @Sendable () async throws -> R
    ) async rethrows -> R {
        let cache = ToolCache()
        cache.cachedTools = await buildTools(from: registry)
        return try await $_scopedToolCache.withValue(cache) {
            try await body()
        }
    }

        // / thread-safe cache for `buildToolsSync`. Uses `NSLock` instead of an
        // … (= 5 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // / via `cachedTools` return instantly when the cache is hot.
        private final class ToolCache: @unchecked Sendable {
            private let lock = NSLock()
            private var _cachedTools: [String: any Tool]?
            var cachedTools: [String: any Tool]? {
                get {
                    lock.lock()
                    defer { lock.unlock() }
                    return _cachedTools
                }
                set {
                    lock.lock()
                    defer { lock.unlock() }
                    _cachedTools = newValue
                }
            }
        }

        // / Process-wide singleton cache (= thread-safe via `NSLock`). Reads from
        // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // / hop).
        private static let toolCache = ToolCache()

        // / Pre-warm the tool cache (= the canonical production pattern). Call from
        // … (= 18 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // / freshly-constructed dict).
        internal func registeredToolNames() -> [String] {
            tools.keys.sorted()
        }

        // MARK: - Book scope guard wiring (see OOB.md #2026-09-25)
        // … (= 26 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // / / delete / rename book) is also NOT in the set (= see spec L30).
        func wireBookScopeGuard(
            currentChatBookID: UUID?,
            bookDirectory: URL?
        ) {
            let entityActor = BookEntityActor(
                bookDirectoryProvider: { bookDirectory },
                currentChatBookIDProvider: { currentChatBookID }
            )
            let chapterActor = BookChapterActor(
                bookDirectoryProvider: { bookDirectory },
                currentChatBookIDProvider: { currentChatBookID }
            )
            let outlineActor = BookOutlineActor(
                bookDirectoryProvider: { bookDirectory },
                currentChatBookIDProvider: { currentChatBookID }
            )

            tools["book_entity"] = BookEntityTool(actor: entityActor)
            tools["book_chapter"] = wrapWithChapterFocusLock(
                BookChapterTool(actor: chapterActor),
                toolName: "book_chapter"
            )
            tools["book_outline"] = BookOutlineTool(actor: outlineActor)
            // edit-chapter-tool 2026-09-28: hermes edit_file 1:1.
            // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // so ChatToolDiffPreview's input is stable across both.
            tools["book_edit_chapter"] = wrapWithChapterFocusLock(
                EditChapterTool(
                    actor: EditChapterActor(bookDirectoryProvider: { bookDirectory })
                ),
                toolName: "book_edit_chapter"
            )
        }

        // / chapter-focus-lock 2026-09-28: wrap a Tool whose entry point may throw
        // … (= 6 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // / without touching this wrapper).
        private func wrapWithChapterFocusLock(_ inner: any Tool, toolName: String) -> any Tool {
            ChapterFocusLockWrappedTool(inner: inner, toolName: toolName)
        }

        // / chapter-focus-lock 2026-09-28: thin Tool wrapper that retries once after
        // … (= 4 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // / it has access to the locator without re-binding globals.
        actor ChapterFocusLockWrappedTool: Tool {
            let inner: any Tool
            let toolName: String

            init(inner: any Tool, toolName: String) {
                self.inner = inner
                self.toolName = toolName
            }

            func execute(input: String) async throws -> String {
                do {
                    return try await inner.execute(input: input)
                } catch let lockError as ChapterFocusLockedError {
                    // The dialog owns the decision (= the user's Allow / Deny
                    // button resumes it), = so the wrapper waits here.
                    let decision: Bool = await Self.awaitPresenterDecision(
                        chapterPath: lockError.chapterPath ?? "",
                        toolName: self.toolName,
                        summary: Self.summarizeInput(input)
                    )
                    guard decision else {
                        // Deny: the focus was never released, = so the user's
                        // tab keeps the lock and the LLM receives the error.
                        throw DatasetLockDeniedByBoss(chapterPath: lockError.chapterPath)
                    }
                    // Allow: release the focus for the length of the inner
                    // call, = then hand it back (= the tab the user was
                    // editing is active again).
                    let snapshot = await Self.releaseFocus()
                    do {
                        let result = try await inner.execute(input: input)
                        await Self.restoreFocus(snapshot)
                        return result
                    } catch {
                        await Self.restoreFocus(snapshot)
                        throw error
                    }
                }
            }

            /// The tab that owned the focus when the dialog opened, and the
            /// id the release swapped in (= the restore stands down when the
            /// user has moved on to another tab).
            struct FocusSnapshot: Sendable {
                let tabID: UUID
                let releasedTabID: UUID
            }

            /// Release the focus for the length of an allowed write.
            ///
            /// The focused path is read through the active tab, = so
            /// clearing it points the active tab at nothing and the guard
            /// sees no focused chapter. Nil when nothing was focused.
            @MainActor
            static func releaseFocus() -> FocusSnapshot? {
                guard let appState = AppStateLocator.shared.appState,
                      appState.focusedChapterPath != nil else { return nil }
                let tabID = appState.activeTabId
                appState.focusedChapterPath = nil
                return FocusSnapshot(tabID: tabID, releasedTabID: appState.activeTabId)
            }

            /// Hand the focus back after an allowed write.
            ///
            /// The focused path is a read of the active tab, = so the tab is
            /// what has to be restored. A tab the user switched to in the
            /// meantime wins, = and a closed tab is not resurrected.
            @MainActor
            static func restoreFocus(_ snapshot: FocusSnapshot?) {
                guard let snapshot,
                      let appState = AppStateLocator.shared.appState else { return }
                guard appState.activeTabId == snapshot.releasedTabID else { return }
                guard appState.openTabs.contains(where: { $0.id == snapshot.tabID }) else { return }
                appState.activeTabId = snapshot.tabID
            }

            // / Compact human-readable summary of the LLM's tool input. (= e.g.
            // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // / so the user sees what the LLM intends before deciding.
            static func summarizeInput(_ input: String) -> String {
                guard let data = input.data(using: .utf8),
                      let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    return input
                }
                if let old = obj["old_text"] as? String, let new = obj["new_text"] as? String {
                    let oldTrimmed = old.trimmingCharacters(in: .whitespacesAndNewlines)
                    let newTrimmed = new.trimmingCharacters(in: .whitespacesAndNewlines)
                    if oldTrimmed.isEmpty {
                        return "add: \(newTrimmed.prefix(80))"
                    }
                    return "edit: \(oldTrimmed.prefix(60)) -> \(newTrimmed.prefix(60))"
                }
                if let body = obj["body"] as? String {
                    return "write: \(body.prefix(80))"
                }
                return input
            }

            // / Bridge to the presenter (= awaiting the dialog decision without
            // … (= 3 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // / and reading the result.
            static func awaitPresenterDecision(
                chapterPath: String,
                toolName: String,
                summary: String
            ) async -> Bool {
                return await withCheckedContinuation { continuation in
                    Task { @MainActor in
                        let decision = await ChapterFocusLockDialogPresenter.shared.present(
                            chapterPath: chapterPath,
                            toolName: toolName,
                            summary: summary
                        )
                        continuation.resume(returning: decision)
                    }
                }
            }
        }

        // / Test-only: inject a tool directly into the tools dict. Used by the
        // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // / key. Production code never calls this method.
        func setToolForTest(_ name: String, _ tool: any Tool) {
            tools[name] = tool
        }
    }

    // MARK: - Tool-pipeline logger (= 12 standard P1-02 try? )
    // … (= 4 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // their error path).
    extension WenshuConductor {
        static let toolLogger = Logger(subsystem: "com.wenshu.app", category: "agent.conductor.tool")
}
