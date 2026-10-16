//
//  ImportServiceLLMDispatch.swift
//
//  2 LLM-dispatch helpers extracted from ImportService.swift
//  (= §6.6 god-class split + discoverability: dispatchLLM +
//  markLLMFailed = 96 LOC moved out of the main file into this
//  dedicated cross-file `extension ImportService` module).
//
//  Why extracted (= §6.6 god-class split + discoverability): the main
//  `actor ImportService` is 1143 LOC = 1.9x the 600-LOC cap. The 2
//  LLM-dispatch helpers are a single concern (= "dispatch the LLM
//  with retry" + "surface a user-readable error on LLM failure").
//  Putting them in a dedicated file named after the concern
//  (= ImportServiceLLMDispatch.swift) lets the next reader find
//  the LLM dispatch logic by name.
//
//  The 2 funcs are instance methods on `ImportService` (as a
//  cross-file extension). The `private func` was relaxed to `func`
//  (= internal scope; = required for the cross-file extension
//  access). `lastDispatchError` (= was `private var`) is now `var`
//  (= internal scope; = the cross-file extension can read/write it).
//

import Foundation

extension ImportService {

    /// Phase 3: dispatch the LLM with retry. Returns the routing result on
    /// success; sets `lastDispatchError` and returns nil on failure (= the
    /// caller then calls `markLLMFailed` to surface a user-readable error).
    func dispatchLLM(
        input: ImportFileInput,
        target: ImportTarget,
        router: ImportRouter,
        tasksBox: TasksBox,
        i: Int,
        activeProvider: String,
        onProgress: (@Sendable ([ImportTask]) async -> Void)?
    ) async -> ImportRoutingResult? {
        let maxLLMAttempts = 3
        lastDispatchError = nil
        await appendActivity(
            to: tasksBox, i: i,
            message: "调用 LLM (\(target.rewriteMode.label)) 分类 + 重组 (provider: \(activeProvider)) ...",
            onProgress: onProgress
        )
        for attempt in 1...maxLLMAttempts {
            do {
                // Pass the activityLog appender as the progress callback so the
                // router's per-phase log lines land in the per-row activityLog.
                let result = try await router.route(input) { message in
                    await self.appendActivity(
                        to: tasksBox, i: i,
                        message: message,
                        onProgress: onProgress
                    )
                }
                tasksBox.value[i].routing = result
                if attempt > 1 {
                    NSLog("WSImport: LLM route succeeded on attempt \(attempt) for task \(i)")
                }
                // Log the LLM's response summary (= the user gets to SEE what the
                // LLM returned: title, tags, # of extraFiles, etc.).
                let routingSummary = """
                LLM 返回: title="\(result.title)", tags=\(result.tags.sorted().joined(separator: ", ")), extraFiles=\(result.extraFiles.count) 个
                """
                await appendActivity(
                    to: tasksBox, i: i,
                    message: routingSummary,
                    onProgress: onProgress
                )
                for (i2, ef) in result.extraFiles.enumerated() {
                    let marker = ef.required ? "[必填]" : "[自定义]"
                    await appendActivity(
                        to: tasksBox, i: i,
                        message: "  子文件 \(i2 + 1)/\(result.extraFiles.count) \(marker) \(ef.folder.directoryName)/\(ef.title).md",
                        onProgress: onProgress
                    )
                }
                if result.extraFiles.isEmpty {
                    await appendActivity(
                        to: tasksBox, i: i,
                        message: "⚠️ LLM 没返回 extraFiles — 6 必填+N 自定义 没拆",
                        onProgress: onProgress
                    )
                }
                return result
            } catch {
                lastDispatchError = error
                NSLog("WSImport: LLM route attempt \(attempt)/\(maxLLMAttempts) failed: \(error.localizedDescription)")
                if attempt < maxLLMAttempts {
                    // Exponential backoff: 1s, 2s, 4s. (= 7s total before final failure).
                    let delaySeconds = pow(2.0, Double(attempt - 1))
                    try? await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
                }
            }
        }
        return nil
    }


    /// Phase 3 failure handler (= the LLM dispatch failed after all retries).
    /// Surfaces a user-readable error that names the connector + quotes the
    /// underlying error + offers a one-line fix checklist (= verify network +
    /// verify API key in Settings → Providers).
    func markLLMFailed(
        tasksBox: TasksBox,
        i: Int,
        activeProvider: String,
        lastError: Error?,
        onProgress: (@Sendable ([ImportTask]) async -> Void)?
    ) async {
        tasksBox.value[i].state = .failed
        let nsError = lastError as NSError?
        let underlying = nsError?.localizedDescription ?? "未知错误"
        let errorCode = nsError.map { " (code=\($0.code))" } ?? ""
        tasksBox.value[i].errorMessage = """
            LLM 路由失败 (3 次重试) — provider: \(activeProvider)\(errorCode)
            底层错误: \(underlying)
            排查: 1) 网络可达 \(activeProvider) 的 endpoint 2) Settings → Providers 里 \(activeProvider) 的 API key 还在 3) 试重试按钮
            """
        await onProgress?(tasksBox.value)
    }


}
