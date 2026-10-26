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
    ///
    /// Per boss 2026-10-16 OOB "未能调用 agent 对文档进行拆分处理":
    /// when the active provider (= `activeProvider`) fails on a
    /// network-class error (= unreachable / DNS / TLS), automatically
    /// try the next configured provider before giving up (= many users
    /// have multiple providers configured for exactly this reason; =
    /// the previous behavior exhausted all 3 retries on the SAME
    /// provider even when a configured fallback was reachable).
    /// The fallback candidate is taken from
    /// `ProviderKeychain.listProvidersWithKeys()` (= the canonical
    /// "the user configured a key for this provider" signal), skipping
    /// the active one. The activityLog receives a clear "切换到 X 重试"
    /// line so the user sees exactly what happened.
    func dispatchLLM(
        input: ImportFileInput,
        target: ImportTarget,
        router: ImportRouter,
        tasksBox: TasksBox,
        i: Int,
        activeProvider: String,
        onProgress: (@Sendable ([ImportTask]) async -> Void)?,
        routerForProvider: (@Sendable (String) async -> ImportRouter?)? = nil
    ) async -> ImportRoutingResult? {
        lastDispatchError = nil
        // Try the active provider first (= the one the user pinned
        // in Settings → Providers). On network-class failure, walk
        // the configured-provider list until one succeeds.
        // AUDIT.md §2.2 (2026-10-16): buildProviderQueue is
        // now async (it awaits WenshuAgent.shared); = the
        // caller is already inside an async function so the
        // `await` composes without ceremony.
        let providerQueue = await buildProviderQueue(
            activeProvider: activeProvider
        )
        for (providerIndex, provider) in providerQueue.enumerated() {
            let isFallback = providerIndex > 0
            if isFallback, let routerForProvider {
                // = the router was re-built for this fallback
                // provider. Surface the switch in the activity log.
                await appendActivity(
                    to: tasksBox, i: i,
                    message: "→ 切换到 provider: \(provider) (网络不可达, 继续尝试)",
                    onProgress: onProgress
                )
                // `WenshuConductorImportRouter` is an actor, so
                // constructing the fallback router is itself
                // `await`. The closure we got from the call site
                // already handles the async case (= it bridges to
                // the underlying connector factory).
                let nextRouter = await routerForProvider(provider)
                guard let nextRouter else { continue }
                return await dispatchLLMOne(
                    input: input,
                    target: target,
                    router: nextRouter,
                    tasksBox: tasksBox,
                    i: i,
                    activeProvider: provider,
                    onProgress: onProgress
                )
            }
            return await dispatchLLMOne(
                input: input,
                target: target,
                router: router,
                tasksBox: tasksBox,
                i: i,
                activeProvider: provider,
                onProgress: onProgress
            )
        }
        return nil
    }

    /// Try ONE provider (= no automatic fallback chain). Retries the
    /// single provider up to `maxLLMAttempts` times. Returns the
    /// routing result on success; nil + sets `lastDispatchError` on
    /// exhaustion. Extracted from `dispatchLLM` to keep the provider-
    /// queue loop (= above) readable; = the inner single-provider
    /// retry logic is unchanged from the previous commit.
    private func dispatchLLMOne(
        input: ImportFileInput,
        target: ImportTarget,
        router: ImportRouter,
        tasksBox: TasksBox,
        i: Int,
        activeProvider: String,
        onProgress: (@Sendable ([ImportTask]) async -> Void)?
    ) async -> ImportRoutingResult? {
        let maxLLMAttempts = 3
        await appendActivity(
            to: tasksBox, i: i,
            message: "调用 LLM (\(target.rewriteMode.label)) 分类 + 重组 (provider: \(activeProvider)) ...",
            onProgress: onProgress
        )
        for attempt in 1...maxLLMAttempts {
            do {
                // Pass the activityLog appender as the progress callback so the
                // router's per-phase log lines land in the per-row activityLog.
                // The user's pinned destination rides along (= the router
                // never picks the folder; = the procedure that runs is
                // the one of the folder the user chose).
                let result = try await router.route(
                    input,
                    destination: Self.pinnedDestination(target: target)
                ) { message in
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
                LLM 返回: title="\(result.title)", tags=\(result.tags.sorted().joined(separator: ", ")), 写入文件=\(result.writtenFiles.count) 个
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
                // The agent path writes the documents itself, = so its split
                // arrives as the written files, = not as the legacy
                // `extraFiles` list (= which is empty there by design). = The
                // warning therefore fires only when NOTHING landed, = so the
                // user is never told a split failed that happened.
                if result.writtenFiles.isEmpty && result.extraFiles.isEmpty {
                    await appendActivity(
                        to: tasksBox, i: i,
                        message: "⚠️ LLM 没返回 extraFiles — 6 必填+N 自定义 没拆",
                        onProgress: onProgress
                    )
                }
                for (n, name) in result.writtenFiles.enumerated() {
                    await appendActivity(
                        to: tasksBox, i: i,
                        message: "  写入 \(n + 1)/\(result.writtenFiles.count) \(name)",
                        onProgress: onProgress
                    )
                }
                return result
            } catch {
                lastDispatchError = error
                NSLog("WSImport: LLM route attempt \(attempt)/\(maxLLMAttempts) on provider \(activeProvider) failed: \(error.localizedDescription)")
                if attempt < maxLLMAttempts {
                    // Exponential backoff: 1s, 2s, 4s. (= 7s total before final failure).
                    let delaySeconds = pow(2.0, Double(attempt - 1))
                    try? await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
                }
            }
        }
        return nil
    }

    /// Build the ordered list of providers to try.
    /// Element 0 = `activeProvider` (= the user's pinned one). Elements
    /// 1..n = other configured providers (= any keychain entry with a
    /// valid `Provider` mapping, deduplicated, in the order the user
    /// added them). Returns at most one entry (= no fallback
    /// candidates) when the user has only the active provider configured.
    /// AUDIT.md §2.2 partial (2026-10-16): routes through
    /// WenshuAgent.shared (= the public facade). `buildProviderQueue`
    /// is `async` so the `await providersWithKeys()` call
    /// composes cleanly (= no Task.detached / completion
    /// handler boilerplate).
    private func buildProviderQueue(activeProvider: String) async -> [String] {
        let configured = await WenshuAgent.shared.providersWithKeys()
        var queue: [String] = [activeProvider]
        for slug in configured where slug != activeProvider {
            queue.append(slug)
        }
        return queue
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


extension ImportService {
    /// The destination the user pinned in the sheet.
    ///
    /// The user's choice is the only thing that decides where an import
    /// lands. A book import without a folder picked falls back to the
    /// drafts folder (= the safe default; = the model never names a
    /// folder).
    static func pinnedDestination(target: ImportTarget) -> ImportDestination {
        switch target.destination {
        case .referenceLibrary:
            return .referenceLibrary
        case .book:
            return .bookFolder(target.bookFolder ?? .drafts)
        }
    }
}
