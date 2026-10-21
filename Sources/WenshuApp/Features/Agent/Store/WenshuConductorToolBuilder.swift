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
            if let cached = Self.toolCache.cachedTools {
                return cached
            }
    
            // Cold path: fix for "agent not
            // … (= 21 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // cache is hot before ChatView.init fires.
            let registry = registry
            Task.detached(priority: .userInitiated) {
                let tools = await Self.buildTools(from: registry)
                Self.toolCache.cachedTools = tools
            }
            return [:]
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
                // Snapshot the current focus state (= before
                // … (= 6 rationale lines collapsed; = A112 docblock collapse per §1.8)
                // the chapter path; = we use it as the restore key).
                do {
                    return try await inner.execute(input: input)
                } catch let lockError as ChapterFocusLockedError {
                    // chapter-dialog 2026-09-28 T2: replace the MVP
                    // … (= 4 rationale lines collapsed; = A112 docblock collapse per §1.8)
                    // continuation bridge.
                    let allow: Bool = await MainActor.run {
                        // present(...) is the dialog's blocking await;
                        // … (= 4 rationale lines collapsed; = A112 docblock collapse per §1.8)
                        // presenter's continuation.
                        Task { @MainActor in
                            _ = await ChapterFocusLockDialogPresenter.shared.present(
                                chapterPath: lockError.chapterPath ?? "",
                                toolName: self.toolName,
                                summary: Self.summarizeInput(input)
                            )
                        }
                        return true
                    }
                    // Bridge the MainActor.run-presented dialog back to
                    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
                    // decision, not a placeholder).
                    let decision: Bool = await Self.awaitPresenterDecision(
                        chapterPath: lockError.chapterPath ?? "",
                        toolName: self.toolName,
                        summary: Self.summarizeInput(input)
                    )
                    _ = allow
                    if !decision {
                        // Deny path: restore the focus state (= no-op
                        // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
                        // and throw so the LLM receives the error.
                        throw DatasetLockDeniedByBoss(chapterPath: lockError.chapterPath)
                    }
                    // Allow path: clear the focus lock, run the inner
                    // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
                    // goes read-only while the LLM writes).
                    let snapshot: String? = await MainActor.run {
                        AppStateLocator.shared.appState?.focusedChapterPath
                    }
                    await MainActor.run {
                        if let appState = AppStateLocator.shared.appState {
                            appState.focusedChapterPath = nil
                        }
                    }
                    do {
                        return try await inner.execute(input: input)
                    } catch {
                        await MainActor.run {
                            if let appState = AppStateLocator.shared.appState,
                               let snapshot {
                                appState.focusedChapterPath = snapshot
                            }
                        }
                        throw error
                    }
                }
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
