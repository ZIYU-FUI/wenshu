//
//  ImportServiceRetryEntry.swift
//
//  retryFailedTasksTitleOnly + appendActivity extracted from
//  ImportService.swift (= §6.6 god-class split + discoverability:
//  83 LOC moved out of the main file into this dedicated
//  cross-file `extension ImportService` module).
//
//  Why extracted (= §6.6 god-class split + discoverability): the main
//  `actor ImportService` is 562 LOC = just under the 600-LOC cap.
//  The 2 retry-entry helpers are a single concern (= "re-run the
//  failed tasks with a title-only synthesized body" + "log per-row
//  activity"). Putting them in a dedicated file named after the
//  concern (= ImportServiceRetryEntry.swift) lets the next reader
//  find the retry-entry logic by name.
//
//  The 2 funcs are instance methods on `ImportService` (as a
//  cross-file extension). The `private func` was already relaxed
//  to `func` (= internal scope; = required for the cross-file
//  extension access).
//

import Foundation

extension ImportService {
    // MARK: - title-only retry

    /// Re-run the failed "读取文件失败" tasks (= the source `.md` file was unreadable
    /// on disk; = the user clicked "重新调研所有失败" in the sheet's progress panel; =
    /// the orchestrator bypasses the disk read by constructing a minimal body
    /// from the filename + the sibling `.md` names in the same source
    /// directory; = the LLM produces a `.ws`-format body via web search; = the
    /// new body is written verbatim by the same `writeFile` path as the normal
    /// `importFiles` flow). Design (= boss round-36 "在进度面板底部 加一个'重新调研所有失败'聚合按钮"
    /// directive): - Filter `tasks` for `.state == .failed` AND `errorMessage`
    /// starts with "读取文件失败" (= LLM-routing failures are NOT retried here; =
    /// those are bugs, not file failures; = the user can re-import the whole
    /// directory if the LLM is misconfigured). - Re-seed the matching tasks as
    /// `.routing` with `errorMessage = nil` (= the row's "失败" pill flips back
    /// to "分析中" = the sheet's progress strip animates smoothly). - Construct a
    /// `body` per file (= the filename as the title + a sibling-context list of
    /// the other `.md` names in the same source directory = LLM has enough to
    /// produce metadata + a clean .ws body). - Force `rewriteMode =
    /// .searchAndRewrite` (= the LLM will use `web_search` to fill in the
    /// entity's canonical content; = the missing source file is the trigger for
    /// the search; = the user explicitly opted into the higher-token mode by
    /// clicking "重新调研"). - Reuse the `importFiles` 5-way parallel TaskGroup
    /// pattern (= `processFile` is the same function = the only difference is
    /// the `ImportFileInput.body` is non-nil = the router uses it; = the
    /// `writeFile` step uses the LLM's `rewrittenBody` = the original file is
    /// never read again). - Returns the new `tasks` array (= the sheet's
    /// `onProgress` is called as tasks transition; = the sheet re-renders). Why
    /// not just re-call `importFiles`? Because `importFiles` re-walks the
    /// source directory and creates new `ImportTask` rows (= the sheet would
    /// have to track task identity across calls; = the progress strip would
    /// jitter; = the "重新调研" button is the "patch the failures" seam, not the
    /// "re-run the whole batch" seam).
    func retryFailedTasksTitleOnly(
        tasks: [ImportTask],
        into target: ImportTarget,
        router: ImportRouter,
        onProgress: (@Sendable ([ImportTask]) async -> Void)? = nil
    ) async -> [ImportTask] {
        // Step 1: filter (= only the "读取文件失败" subset; = LLM-routing
        // failures and write failures are excluded; = the user clicked
        // "重新调研" with the explicit understanding that this is the
        // "I trust the filename + LLM search alone" path).
        let candidateIndices = ImportServiceDispatchHelpers.filterRetryCandidates(tasks: tasks)
        // Step 2: compute the sibling-context list ONCE (= the user's
        // whole source directory; = all .md files in the same folder as
        // the failed file; = the LLM uses the list as "what other
        // entities are nearby, what categories exist").
        let contextByPath = ImportServiceTitleOnlyHelpers.siblingContextMap(for: tasks)
        // Step 3: load the sidecar cache ONCE (= we need the
        // `lastTitleOnlyRetriedHash` to dedup repeat clicks; = the
        // dedup logic runs in the orchestrator; = the per-sourcePath
        // title-only body hash comparison decides whether the retry
        // would produce a different LLM result).
        let cacheFile = target.cacheRoot.appendingPathComponent("import-cache.json")
        let cache = ImportServiceCache.readCache(cacheFile: cacheFile)
        // Step 4: per-file smart skip (= boss's "不要浪费" rule; = if
        // the previous retry had the same body hash, the LLM output
        // would be byte-identical = skip; = otherwise dispatch).
        let tasksBox = TasksBox(value: tasks)
        let retryIndices = selectRetryIndices(
            tasksBox: tasksBox,
            cache: cache,
            contextByPath: contextByPath
        )
        // Step 5: re-seed the matching tasks (.failed → .routing,
        // errorMessage = nil) + emit progress so the sheet sees the
        // state transition (= the row flips to "分析中").
        for i in retryIndices {
            tasksBox.value[i].state = .routing
            tasksBox.value[i].errorMessage = nil
        }
        await onProgress?(tasksBox.value)
        // Step 6: same 5-way parallel TaskGroup as `importFiles` (= the
        // only difference is the `ImportFileInput` carries a non-nil
        // `body`; = `processFile` is unchanged; = `writeFile` uses
        // the LLM's `rewrittenBody` and never touches the unreadable file).
        let cacheBox = CacheBox(value: cache)
        await runRetryTaskGroup(
            tasksBox: tasksBox,
            tasks: tasks,
            retryIndices: retryIndices,
            contextByPath: contextByPath,
            target: target,
            router: router,
            cacheBox: cacheBox,
            onProgress: onProgress
        )
        // Step 7: stamp every retried task's cache entry with
        // `lastTitleOnlyRetriedAt = now` + the title-only body hash
        // (= the next user click on "重新调研" will see the stamp and
        // skip the LLM = the boss's "不要再浪费" rule).
        stampRetriedHashes(
            tasksBox: tasksBox,
            retryIndices: retryIndices,
            contextByPath: contextByPath,
            cacheBox: cacheBox
        )
        ImportServiceCache.writeCache(cacheFile: cacheFile, cache: cacheBox.value)
        return tasksBox.value
    }



    /// (= boss 2026-10-10 (see OOB.md #2026-10-10) feedback). Append a single
    /// line to a task's activityLog (= the per-row scrolling terminal- like
    /// view in the sheet). Capped at 30 entries (= old entries drop off; = 30
    /// is enough to show the recent activity without scrolling forever). Also
    /// triggers onProgress so the sheet UI updates immediately.
    func appendActivity(
        to tasksBox: TasksBox,
        i: Int,
        message: String,
        onProgress: (@Sendable ([ImportTask]) async -> Void)?
    ) async {
        tasksBox.value[i].activityLog.append(message)
        // Cap at 30 (= the oldest entries drop off; = prevents unbounded growth).
        if tasksBox.value[i].activityLog.count > 30 {
            tasksBox.value[i].activityLog.removeFirst(
                tasksBox.value[i].activityLog.count - 30
            )
        }
        await onProgress?(tasksBox.value)
    }


}
