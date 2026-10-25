//
//  ImportServiceMainFileWriter.swift
//
//  2 main-file-write helpers extracted from ImportService.swift
//  (= §6.6 god-class split + discoverability: writeMainFileAndExtras
//  + writeOneExtraFile = 136 LOC moved out of the main file into
//  this dedicated cross-file `extension ImportService` module).
//
//  Why extracted (= §6.6 god-class split + discoverability): the main
//  `actor ImportService` is 1051 LOC = 1.75x the 600-LOC cap. The 2
//  main-file-write helpers are a single concern (= "write the main
//  .md file and iterate over the LLM's extra files"). Putting them
//  in a dedicated file named after the concern
//  (= ImportServiceMainFileWriter.swift) lets the next reader find
//  the main-file write logic by name.
//
//  The 2 funcs are instance methods on `ImportService` (as a
//  cross-file extension). The `private func` was relaxed to `func`
//  (= internal scope; = required for the cross-file extension access).
//

import Foundation

extension ImportService {


    /// Phase 4: write the main file (= per the rewriteMode) + loop through the
    /// LLM's `extraFiles` and write each one to its folder. The state
    /// transitions to .done on success (= or .failed on write error; = the
    /// caller catches and surfaces the error to the user).
    func writeMainFileAndExtras(
        routing: ImportRoutingResult,
        target: ImportTarget,
        router: ImportRouter,
        cacheBox: CacheBox,
        tasksBox: TasksBox,
        i: Int,
        onProgress: (@Sendable ([ImportTask]) async -> Void)?
    ) async throws {
        // The agent is the only writer in the reorganize mode. The
        // agent's procedure writes the documents; = the orchestrator's own
        // write path would write the same files a second time, from a
        // body the model produced elsewhere. The mode is checked here so
        // the rule holds whatever the routing result carries.
        if target.rewriteMode == .reorganize {
            tasksBox.value[i].state = .done
            tasksBox.value[i].destination = routing.destination
            return
        }
        let sourceFileName = (tasksBox.value[i].sourcePath as NSString).lastPathComponent
        await appendActivity(
            to: tasksBox, i: i,
            message: "读取源文件 \(sourceFileName)",
            onProgress: onProgress
        )
        let originalBody = try String(
            contentsOfFile: tasksBox.value[i].sourcePath,
            encoding: .utf8
        )
        let bodySizeKB = Double(originalBody.utf8.count) / 1024.0
        await appendActivity(
            to: tasksBox, i: i,
            message: String(format: "源文件 = %.1f KB, %d 行", bodySizeKB, originalBody.components(separatedBy: "\n").count),
            onProgress: onProgress
        )
        // The folder is sourced from the routing result; for the
        // reference-library destination, the LLM picks a "concept" folder
        // (= world/characters/...) for the `category` but the file lands in
        // the flat reference library; = .drafts is the safe default.
        let folder: BookFolder = {
            if case .bookFolder(let f) = routing.destination { return f }
            return .drafts
        }()
        let bodyToWrite = ImportServiceBodyWriter.computeBodyToWrite(
            originalBody: originalBody,
            rewrittenBody: routing.rewrittenBody,
            folder: folder,
            rewriteMode: target.rewriteMode
        )
        let extraFilesTotal = routing.extraFiles.count
        tasksBox.value[i].extraFilesTotal = extraFilesTotal
        tasksBox.value[i].extraFilesDone = 0
        // Log the main folder + write it.
        let mainFolderName: String
        switch routing.destination {
        case .referenceLibrary: mainFolderName = "资料库"
        case .bookFolder(let f): mainFolderName = f.directoryName
        }
        await appendActivity(
            to: tasksBox, i: i,
            message: "写主文件 (\(mainFolderName)/...)",
            onProgress: onProgress
        )
        // Write each extra file (= LLM's split-out content). Extra file
        // write failures are non-fatal: main file stays .done; = the failed
        // extra file is recorded separately in tasksBox.
        for (extraIndex, extra) in routing.extraFiles.enumerated() {
            try await writeOneExtraFile(
                extra: extra,
                extraIndex: extraIndex,
                extraFilesTotal: extraFilesTotal,
                target: target,
                tasksBox: tasksBox,
                i: i,
                onProgress: onProgress
            )
        }
        // Write the main file (if there's a body).
        if !bodyToWrite.isEmpty {
            try await writeFile(
                body: bodyToWrite,
                routing: routing,
                contentHash: tasksBox.value[i].contentHash,
                target: target,
                sourcePath: tasksBox.value[i].sourcePath,
                cache: &cacheBox.value,
                router: router,
                tasksBox: tasksBox,
                i: i
            )
            let bodyKB = Double(bodyToWrite.utf8.count) / 1024.0
            await appendActivity(
                to: tasksBox, i: i,
                message: String(format: "✅ 主文件写入成功 (%.1f KB)", bodyKB),
                onProgress: onProgress
            )
        }
        tasksBox.value[i].state = .done
        tasksBox.value[i].destination = routing.destination
        // The writeFile appended the new entry to its inout cache; = the
        // shared `cacheBox.value` is now the canonical source of truth.
    }



    /// Write one extra file (= a single entry from `routing.extraFiles`). Logs
    /// the success/failure to the per-row activityLog (= the user sees a row
    /// per extra file). Failures are non-fatal (= they don't throw; = the row's
    /// `extraFilesDone` counter still advances).
    func writeOneExtraFile(
        extra: ExtraFile,
        extraIndex: Int,
        extraFilesTotal: Int,
        target: ImportTarget,
        tasksBox: TasksBox,
        i: Int,
        onProgress: (@Sendable ([ImportTask]) async -> Void)?
    ) async throws {
        do {
            try await writeExtraFile(
                extra: extra,
                target: target,
                tasksBox: tasksBox,
                i: i,
                extraIndex: extraIndex
            )
            let bodyKB = Double(extra.body.utf8.count) / 1024.0
            let marker = extra.required ? "[必填]" : "[自定义]"
            await appendActivity(
                to: tasksBox, i: i,
                message: String(
                    format: "  ✅ 子文件 %d/%d %@ %@/%@.md (%.1f KB)",
                    extraIndex + 1, extraFilesTotal,
                    marker,
                    extra.folder.directoryName,
                    extra.title,
                    bodyKB
                ),
                onProgress: onProgress
            )
        } catch {
            NSLog(
                "[wenshu.import] extraFile %d (%@) failed: %@",
                extraIndex, extra.title, String(describing: error)
            )
            await appendActivity(
                to: tasksBox, i: i,
                message: "  ❌ 子文件 \(extraIndex + 1)/\(extraFilesTotal) \(extra.title).md 写失败: \(String(describing: error))",
                onProgress: onProgress
            )
        }
        tasksBox.value[i].extraFilesDone += 1
    }


}
