//
//  ImportServiceRetryPipeline.swift
//
//  4 title-only retry pipeline helpers extracted from ImportService.swift
//  (= §6.6 god-class split + discoverability: selectRetryIndices +
//  runRetryTaskGroup + makeTitleOnlyInput + stampRetriedHashes = 168
//  LOC moved out of the main file into this dedicated cross-file
//  `extension ImportService` module).
//
//  Why extracted (= §6.6 god-class split + discoverability): the main
//  `actor ImportService` is 809 LOC = 1.35x the 600-LOC cap. The 4
//  retry-pipeline helpers are a single concern (= "re-run the failed
//  tasks with a title-only synthesized body"). Putting them in a
//  dedicated file named after the concern
//  (= ImportServiceRetryPipeline.swift) lets the next reader find
//  the retry logic by name.
//
//  The 4 funcs are instance methods on `ImportService` (as a
//  cross-file extension). The `private func` was relaxed to `func`
//  (= internal scope; = required for the cross-file extension access).
//

import Foundation

extension ImportService {


    /// Step 4: per-file smart skip (= boss's "不要浪费" rule; = if the previous
    /// retry had the same body hash, the LLM output would be byte-identical =
    /// skip (= mark the task `.skipped`, not `.routing`); = otherwise dispatch
    /// (= the LLM would produce a different result; = included in
    /// `retryIndices`).
    func selectRetryIndices(
        tasksBox: TasksBox,
        cache: [String: CacheEntry],
        contextByPath: [String: String]
    ) -> [Int] {
        var retryIndices: [Int] = []
        for i in tasksBox.value.indices {
            // Skip non-candidate tasks (= the per-file dedup runs on
            // every row to keep the loop simple; = non-candidates are
            // neither `.failed` nor "读取文件失败" so they'll never
            // match the cache).
            guard tasksBox.value[i].state == .failed,
                  tasksBox.value[i].errorMessage?.hasPrefix("读取文件失败") ?? false else {
                continue
            }
            let siblingContext = contextByPath[tasksBox.value[i].sourcePath] ?? ""
            let synthesizedBody = ImportServiceTitleOnlyHelpers.titleOnlyBody(
                fileName: (tasksBox.value[i].sourcePath as NSString).lastPathComponent,
                siblingContext: siblingContext
            )
            let bodyHash = ImportServiceHashing.sha256(synthesizedBody)
            if let cached = cache[tasksBox.value[i].sourcePath],
               cached.lastTitleOnlyRetriedHash == bodyHash {
                // Already retried with the SAME body hash = the LLM output
                // would be byte-identical to the last attempt = skip
                // (= no LLM token spent; = the row flips to "已跳过"
                // instead of "分析中" → "完成" so the user sees what
                // happened).
                tasksBox.value[i].state = .skipped
                tasksBox.value[i].errorMessage = nil
                continue
            }
            // No prior retry OR a prior retry with a DIFFERENT body hash
            // = the LLM would produce a different result = run the LLM.
            retryIndices.append(i)
        }
        return retryIndices
    }


    /// Step 6: same 5-way parallel TaskGroup as `importFiles` (= the only
    /// difference is the `ImportFileInput` carries a non-nil `body`; =
    /// `processFile` is unchanged; = `writeFile` uses the LLM's `rewrittenBody`
    /// and never touches the unreadable file).
    func runRetryTaskGroup(
        tasksBox: TasksBox,
        tasks: [ImportTask],
        retryIndices: [Int],
        contextByPath: [String: String],
        target: ImportTarget,
        router: ImportRouter,
        cacheBox: CacheBox,
        onProgress: (@Sendable ([ImportTask]) async -> Void)?
    ) async {
        await withTaskGroup(of: Void.self) { (group: inout TaskGroup<Void>) in
            var inFlight = 0
            var nextIndex = 0
            let dispatchIndices = retryIndices
            while inFlight < target.maxParallel, nextIndex < dispatchIndices.count {
                let i = dispatchIndices[nextIndex]
                let input = makeTitleOnlyInput(
                    tasks: tasks,
                    i: i,
                    contextByPath: contextByPath,
                    target: target
                )
                group.addTask { [self] in
                    await self.processFile(
                        taskIndex: i,
                        input: input,
                        target: target,
                        router: router,
                        cacheBox: cacheBox,
                        tasksBox: tasksBox,
                        onProgress: onProgress
                    )
                }
                inFlight += 1
                nextIndex += 1
            }
            while await group.next() != nil {
                inFlight -= 1
                if nextIndex < dispatchIndices.count {
                    let i = dispatchIndices[nextIndex]
                    let input = makeTitleOnlyInput(
                        tasks: tasks,
                        i: i,
                        contextByPath: contextByPath,
                        target: target
                    )
                    group.addTask { [self] in
                        await self.processFile(
                            taskIndex: i,
                            input: input,
                            target: target,
                            router: router,
                            cacheBox: cacheBox,
                            tasksBox: tasksBox,
                            onProgress: onProgress
                        )
                    }
                    inFlight += 1
                    nextIndex += 1
                }
            }
        }
    }


    /// Build the `ImportFileInput` for a title-only retry (= the `body` field
    /// is the synthesized body the LLM will ingest; = the source file is
    /// unreadable on disk so `processFile` reads the body from this field
    /// rather than opening the file).
    func makeTitleOnlyInput(
        tasks: [ImportTask],
        i: Int,
        contextByPath: [String: String],
        target: ImportTarget
    ) -> ImportFileInput {
        let siblingContext = contextByPath[tasks[i].sourcePath] ?? ""
        let synthesizedBody = ImportServiceTitleOnlyHelpers.titleOnlyBody(
            fileName: (tasks[i].sourcePath as NSString).lastPathComponent,
            siblingContext: siblingContext
        )
        return ImportFileInput(
            filePath: tasks[i].sourcePath,
            targetBookId: target.bookId,
            targetShelfId: target.shelfId,
            rewriteMode: .searchAndRewrite,
            body: synthesizedBody
        )
    }


    /// Step 7: stamp every retried task's cache entry with
    /// `lastTitleOnlyRetriedAt = now` + the title-only body hash (= the next
    /// user click on "重新调研" will see the stamp and skip the LLM = the boss's
    /// "不要再浪费" rule).
    func stampRetriedHashes(
        tasksBox: TasksBox,
        retryIndices: [Int],
        contextByPath: [String: String],
        cacheBox: CacheBox
    ) {
        for i in retryIndices {
            let sourcePath = tasksBox.value[i].sourcePath
            let siblingContext = contextByPath[sourcePath] ?? ""
            let synthesizedBody = ImportServiceTitleOnlyHelpers.titleOnlyBody(
                fileName: (sourcePath as NSString).lastPathComponent,
                siblingContext: siblingContext
            )
            let bodyHash = ImportServiceHashing.sha256(synthesizedBody)
            if var entry = cacheBox.value[sourcePath] {
                entry.lastTitleOnlyRetriedAt = Date()
                entry.lastTitleOnlyRetriedHash = bodyHash
                cacheBox.value[sourcePath] = entry
            } else {
                cacheBox.value[sourcePath] = CacheEntry(
                    contentHash: "orphan-" + ImportServiceHashing.sha256(sourcePath),
                    destination: .referenceLibrary,
                    writtenAt: Date(),
                    lastTitleOnlyRetriedAt: Date(),
                    lastTitleOnlyRetriedHash: bodyHash
                )
            }
        }
    }


}
