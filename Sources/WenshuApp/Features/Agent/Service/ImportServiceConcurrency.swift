//
//  ImportServiceConcurrency.swift
//
//  3 concurrency helpers extracted from ImportService.swift
//  (= §6.6 god-class split + discoverability: runConcurrentPipeline
//  + enqueueTask + makeProcessFileInput = 88 LOC moved out of the
//  main file into this dedicated cross-file `extension ImportService`
//  module).
//
//  Why extracted (= §6.6 god-class split + discoverability): the main
//  `actor ImportService` is 907 LOC = 1.5x the 600-LOC cap. The 3
//  concurrency helpers are a single concern (= "the 5-way parallel
//  TaskGroup that dispatches the LLM and writes the files"). Putting
//  them in a dedicated file named after the concern
//  (= ImportServiceConcurrency.swift) lets the next reader find the
//  concurrency logic by name.
//
//  The 3 funcs are instance methods on `ImportService` (as a
//  cross-file extension). The `private func` was relaxed to `func`
//  (= internal scope; = required for the cross-file extension access).
//

import Foundation

extension ImportService {



    /// Phase 3+4 = unified per-file pipeline (= the orchestrator's 5-way
    /// parallel TaskGroup; = the actor's serialized state mutation is safe
    /// across the concurrent `processFile` calls; = `CacheBox` / `TasksBox` are
    /// the class-wrapper workaround that hold the shared mutable state the
    /// TaskGroup needs to mutate from concurrent contexts).
    func runConcurrentPipeline(
        dispatchIndices: [Int],
        target: ImportTarget,
        router: ImportRouter,
        cacheBox: CacheBox,
        tasksBox: TasksBox,
        onProgress: (@Sendable ([ImportTask]) async -> Void)?
    ) async {
        await withTaskGroup(of: Void.self) { (group: inout TaskGroup<Void>) in
            var inFlight = 0
            var nextIndex = 0
            // Seed the first `maxParallel` tasks (= 5 today; = the LLM
            // pressure knob; = the LLMConnector adapter handles its own
            // provider-side rate limiting). The drain loop below
            // refills via `enqueueTask` (= same shape as the seed).
            while inFlight < target.maxParallel, nextIndex < dispatchIndices.count {
                inFlight += 1
                let i = dispatchIndices[nextIndex]
                nextIndex += 1
                await enqueueTask(
                    group: &group,
                    tasksBox: tasksBox,
                    taskIndex: i,
                    target: target,
                    router: router,
                    cacheBox: cacheBox,
                    onProgress: onProgress
                )
            }
            // Drain + refill (= each completed task frees a slot in the
            // semaphore; = the next pending task is seeded; = the
            // pipeline keeps 5 files in flight concurrently for the
            // entire batch).
            while await group.next() != nil {
                inFlight -= 1
                if nextIndex < dispatchIndices.count, tasksBox.value[dispatchIndices[nextIndex]].state == .pending {
                    inFlight += 1
                    let j = dispatchIndices[nextIndex]
                    nextIndex += 1
                    await enqueueTask(
                        group: &group,
                        tasksBox: tasksBox,
                        taskIndex: j,
                        target: target,
                        router: router,
                        cacheBox: cacheBox,
                        onProgress: onProgress
                    )
                }
            }
        }
    }


    /// Mark the task `.routing` + emit progress + enqueue the `processFile`
    /// task on the TaskGroup. Used by both the seed loop (= first `maxParallel`
    /// tasks) and the drain loop (= refilling slots as tasks complete) so the
    /// per-task dispatch is in one place.
    func enqueueTask(
        group: inout TaskGroup<Void>,
        tasksBox: TasksBox,
        taskIndex i: Int,
        target: ImportTarget,
        router: ImportRouter,
        cacheBox: CacheBox,
        onProgress: (@Sendable ([ImportTask]) async -> Void)?
    ) async {
        tasksBox.value[i].state = .routing
        await onProgress?(tasksBox.value)
        let input = makeProcessFileInput(tasksBox: tasksBox, i: i, target: target)
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
    }


    /// Build the `ImportFileInput` for a non-retry (= the body field is nil; =
    /// `processFile` reads the body from disk).
    func makeProcessFileInput(
        tasksBox: TasksBox,
        i: Int,
        target: ImportTarget
    ) -> ImportFileInput {
        return ImportFileInput(
            filePath: tasksBox.value[i].sourcePath,
            targetBookId: target.bookId,
            targetShelfId: target.shelfId,
            rewriteMode: target.rewriteMode
        )
    }


}
