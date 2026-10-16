//
//  ImportServiceProcessFile.swift
//
//  processFile extracted from ImportService.swift
//  (= §6.6 god-class split + discoverability: the 75-LOC `processFile`
//  per-file pipeline moved out of the main file into a dedicated
//  cross-file `extension ImportService` module).
//
//  Why extracted (= §6.6 god-class split + discoverability): the main
//  `actor ImportService` is 646 LOC = 1.08x the 600-LOC cap. The
//  `processFile` is a single concern (= "the per-file pipeline
//  = route + write main file + write extra files + record in cache").
//  Putting it in a dedicated file named after the concern
//  (= ImportServiceProcessFile.swift) lets the next reader find the
//  per-file pipeline by name.
//
//  The `func` was already internal (= relaxed in A71). The method
//  stays on `ImportService` (= instance method on the actor).
//

import Foundation

extension ImportService {
    /// Run the per-file pipeline (= route → write → done) for a single task.
    /// The Semaphore-shaped TaskGroup in the importFiles loop calls this
    /// method. State transitions per file (= matches the boss's 2026-10-09
    /// "分析、编辑、完成、失败" spec; = the per-file pipeline flips states back-to-back in
    /// sequence; = the sheet sees a single file's life cycle tick in real
    /// time): - .pending → .routing (= already set by the TaskGroup seed) -
    /// .routing → .writing (= LLM call returned; = the routing decision is the
    /// destination + tags + title) - .writing → .done (= the file lands on
    /// disk; = the body is byte-equal to the source body) - any state → .failed
    /// (= the LLM call or the file write threw; = the row's `errorMessage`
    /// carries the cause)
    func processFile(
        taskIndex i: Int,
        input: ImportFileInput,
        target: ImportTarget,
        router: ImportRouter,
        cacheBox: CacheBox,
        tasksBox: TasksBox,
        onProgress: (@Sendable ([ImportTask]) async -> Void)?
    ) async {
        // Phase 3: route + enrich (= the LLM dispatch; = the slow part).
        // Retries up to 3 times with exponential backoff (1s, 2s, 4s; = transient
        // LLM errors = rate limit / network blip / load spike; = 95% of cases
        // clear within 7s per the connector team's 2026-10-09 metrics).
        let activeProvider = WenshuAppDelegateLLMHelpers.activeConnectorSlug()
        let routing: ImportRoutingResult? = await dispatchLLM(
            input: input,
            target: target,
            router: router,
            tasksBox: tasksBox,
            i: i,
            activeProvider: activeProvider,
            onProgress: onProgress
        )
        guard var routing = routing else {
            await markLLMFailed(
                tasksBox: tasksBox,
                i: i,
                activeProvider: activeProvider,
                lastError: lastDispatchError,
                onProgress: onProgress
            )
            return
        }
        // Apply the user's pinned destination (= boss's "用户在 导入 书的 时候 ， 要选 择二 级目 录" feedback).
        switch target.destination {
        case .referenceLibrary:
            routing.destination = .referenceLibrary
        case .book:
            if let folder = target.bookFolder {
                routing.destination = .bookFolder(folder)
            } else if case .referenceLibrary = routing.destination {
                // Fallback: the LLM routed to .referenceLibrary but the user picked a
                // book (= no 2nd-level folder picked; = .drafts is the safe default).
                routing.destination = .bookFolder(.drafts)
            }
        }
        tasksBox.value[i].routing = routing
        // Phase 4: write the main file + loop through extraFiles.
        // State flips .routing → .writing → .done inside this single function call.
        tasksBox.value[i].state = .writing
        await onProgress?(tasksBox.value)
        do {
            try await writeMainFileAndExtras(
                routing: routing,
                target: target,
                router: router,
                cacheBox: cacheBox,
                tasksBox: tasksBox,
                i: i,
                onProgress: onProgress
            )
        } catch let error as ImportServiceError
        where error == .contentSameSkipped {
            // Phase 2 LLM said "skip" (= the existing file is already correct);
            // = the inner writeFile already set state = .skipped + skippedReason
            // before throwing the sentinel; = we just break out.
            await onProgress?(tasksBox.value)
            return
        } catch {
            tasksBox.value[i].state = .failed
            tasksBox.value[i].errorMessage = "写入失败: \(error.localizedDescription)"
        }
        // Emit after the terminal state transition (= .done or .failed).
        await onProgress?(tasksBox.value)
    }

}
