// WenshuConductorImportRouter.swift T4 of the markdown import feature. The production
// `ImportRouter` (= the seam the orchestrator dispatches per file; = defined in
// `ImportService.swift`). History: - 2026-10-09 (initial T4) used the
// `EntityClassifier` actor with a `nil` LLM callback (= the keyword pass + a stub
// fallback). The keyword pass produces CLC letter tags (= "K" / "B" / "N" / ...) and a
// fixed "drafts" book-folder destination, = the user feedback on 2026-10-09: "大量不应该进到五
// 目录的进到了五目录，同时五目录没有进到对应的 目录下，标题也没有显示中文标题", "分类有的只 显示一个字母，不是中文标签，标签没有重新梳理 生成",
// "在打标签时，按真实内容打标签，而不是 去靠图书馆分类". - 2026-10-09 (this rewrite) drops the keyword fallback
// entirely and dispatches every file through a real LLM call (= the same LLMConnector
// the rest of wenshu uses, = no new inference path; = the LLM's role is the "调研员" the
// user asked for in the 2026-10-09 OOB; = the `SystemPrompt.librarianRole` adds the
// prompt fragment that defines this role). The LLM is the single source of truth for
// title (Chinese rewrite), tags (5-8 real-content Chinese terms, no CLC letters),
// summary (one-line Chinese description), and the per-file destination (= bookFolder
// of one of the 5 standard folders, or referenceLibrary for external knowledge). Apple
// canonical pattern: the router is an actor (= it serializes LLM dispatch via its own
// state machine instead of relying on the orchestrator's lock; = the orchestrator
// still does the 4-way parallel dispatch via TaskGroup, but each individual
// `route(_:)` call is serialized at the LLM-boundary inside the actor).

import Foundation

/// The production `ImportRouter` that the sheet uses. Each `route(_:)`
/// invocation makes a real LLM call (= the `LLMConnector` from
/// `WenshuAppDelegateLLMHelpers.activeLLMConnector()`; = the same
/// connector the rest of wenshu ships with out of the box per AGENTS.md §11.2
/// P0 profile list).
actor WenshuConductorImportRouter: ImportRouter {

    /// The resolved LLM connector (= resolved lazily once at first `route(_:)`
    /// call; = the connector is `nonisolated` and `Sendable`; = safe to capture
    /// into the actor's stored state).
    private let connector: any LLMConnector

    /// The model slug (= the user-picked model from `wenshu.llm.model`; = falls
    /// back to the connector's default; = the active connector's `connectorID`
    /// is the canonical default identifier).
    private let modelSlug: String

    /// (= boss 2026-10-10 (see OOB.md #2026-10-10) 看板任务一样, 让一个 agent 跑完"). The
    /// driver (= the wenshu 文档管理员's orchestrator) wraps the SOP lookup + the
    /// agent conversation loop (= replaces the previous round-71/72 multi-turn
    /// LLM pipeline).
    private lazy var driver: ImportAgentDriver = {
        ImportAgentDriver(
            connector: connector,
            modelSlug: modelSlug
        )
    }()

    init(
        connector: (any LLMConnector)? = nil,
        modelSlug: String? = nil
    ) {
        // The connector resolution is intentionally synchronous (=
        // WenshuAppDelegateLLMHelpers.activeLLMConnector() is `nonisolated`; = the cost
        // is one UserDefaults read + one ProviderCatalog lookup; = the actor
        // initializer runs at most once per sheet presentation; = the lookup
        // is cheap enough to not need a lazy property).
        self.connector = connector ?? WenshuAppDelegateLLMHelpers.activeLLMConnector()
        // `LLMCallOptions.model` is non-optional; = the active connector knows its own
        // default model slug (= `connectorID` for the wenshu canonical case; =
        // the connector falls back to its provider default if the user hasn't
        // picked anything in the Settings picker). Passing the active
        // LLMConnector's `connectorID` (= a stable identifier like "anthropic"
        // / "minimax-cn") lets the connector route to the right model family
        // without a wenshu-side hardcoded model list (= AGENTS.md §11.2 P0
        // profile list is the canonical cross-check).
        self.modelSlug = modelSlug ?? WenshuAppDelegateLLMHelpers.activeModelSlug() ?? "default-model"
    }

    /// Classify one file via the LLM (= the prompt asks the LLM to return a
    /// single JSON object with the structured fields the orchestrator needs).
    /// `progress` callback emits human-readable Chinese activity lines (= the
    /// orchestrator wires this into the per-row `activityLog`).
    func route(
        _ input: ImportFileInput,
        progress: (@Sendable (String) async -> Void)? = nil
    ) async throws -> ImportRoutingResult {
        // (= boss 2026-10-09 (see OOB.md #2026-10-09) 就是基于标题重新调研" directive). Body
        // resolution (= three sources, precedence high to low): 1.
        // `input.body` (= the orchestrator's override; = the "title-only"
        // retry path = the orchestrator synthesized a body from the filename +
        // sibling .md names = the source file is unreadable on disk = the
        // router must not try to read it) 2. `try String(contentsOfFile:
        // input.filePath)` (= the normal `importFiles` path; = the source file
        // is readable; = the router reads it from disk) 3. `throw` (= neither
        // is available; = the file was deleted between the orchestrator's walk
        // phase and the route phase; = the orchestrator catches the throw and
        // marks the task .failed with "读取文件失败: ...")
        let body: String
        if let override = input.body {
            body = override
        } else {
            body = try String(contentsOfFile: input.filePath, encoding: .utf8)
        }
        let fallbackTitle = WCIRHelpers.fallbackTitle(from: input.filePath)

        // C2 (= boss 2026-10-10 (see OOB.md #2026-10-10) OOB). In `.reorganize` mode (=
        // the boss's new default mode), the pipeline now makes 3 sequential
        // LLM calls instead of 1 (= each call does 1 thing; = the LLM can't
        // silently drop the extraFiles array; = the user sees each call in
        // real time via the round-70 `activityLog`). Other modes (=
        // .consolidate / .searchAndRewrite) still use 1 LLM call (= backward
        // compat).
        switch input.rewriteMode {
        case .reorganize:
            return try await routeReorganizeMultiTurn(
                input: input,
                body: body,
                fallbackTitle: fallbackTitle,
                progress: progress
            )
        case .consolidate, .searchAndRewrite:
            // .consolidate + .searchAndRewrite unchanged (= 1 LLM call; = the pre-
            // round-71 path).
            return try await routeSingleTurn(
                input: input,
                body: body,
                fallbackTitle: fallbackTitle,
                progress: progress
            )
        }
    }

    /// C2. The single-LLM-call path (= the pre-round-71 behavior; = used by
    /// `.consolidate` + `.searchAndRewrite`; = kept for backward compat).
    private func routeSingleTurn(
        input: ImportFileInput,
        body: String,
        fallbackTitle: String,
        progress: (@Sendable (String) async -> Void)?
    ) async throws -> ImportRoutingResult {
        let userPrompt = WCIRPromptHelpers.userPrompt(
            filePath: input.filePath,
            body: body,
            rewriteMode: input.rewriteMode
        )
        let options = buildLLMCallOptions(input: input, userPrompt: userPrompt)
        // Fire the LLM call (= single turn).
        let response: LLMResponse
        switch input.rewriteMode {
        case .consolidate:
            // Single-turn, no tool loop (= the LLM has no tools so
            // `stopReason` is `endTurn` immediately).
            response = try await connector.send(
                messages: [.user(userPrompt)],
                options: options
            )
        case .searchAndRewrite:
            // Multi-turn tool-use loop (= the LLM can call `web_search`; = the
            // loop terminates on `stopReason = .endTurn` OR after a hard turn
            // cap to prevent runaway token spend).
            response = try await runToolUseLoop(
                initialUserPrompt: userPrompt,
                options: options,
                body: body,
                filePath: input.filePath
            )
        case .reorganize:
            // Unreachable (= the caller's switch dispatched .reorganize to the
            // multi-turn path; = kept for switch exhaustiveness).
            throw NSError(
                domain: "WenshuConductorImportRouter",
                code: 0,
                userInfo: [NSLocalizedDescriptionKey: "unreachable"]
            )
        }
        let raw = response.blocks.map(\.textValue).joined()
        return WCIRHelpers.parseAndMap(
            raw: raw,
            body: body,
            fallbackTitle: fallbackTitle,
            filePath: input.filePath
        )
    }

    /// Build the LLM call options for a route pass. The `.searchAndRewrite`
    /// mode is the ONLY mode that exposes the `web_search` tool schema (=
    /// `consolidate` = LLM no tools = previous behavior); the tool schema
    /// mirrors `WebSearchTool`'s registration (= canonical wenshu tools are NOT
    /// re-implemented here; = the LLM calls the same `web_search` name
    /// regardless of mode).
    private func buildLLMCallOptions(
        input: ImportFileInput,
        userPrompt: String
    ) -> LLMCallOptions {
        let tools: [ToolRegistrySchema] = (input.rewriteMode == .searchAndRewrite)
            ? WCIRToolSchema.webSearchToolSchema
            : []
        return LLMCallOptions(
            model: modelSlug,
            maxTokens: 4096,
            systemPrompt: SystemPrompt.librarianRole(.chinese),
            temperature: 0.2,
            reasoningEffort: nil,
            tools: tools
        )
    }

    /// C2. The 3-phase multi-turn path (= the new default for `.reorganize`; =
    /// the fix for "⚠️ LLM 没返回 extraFiles"). Each phase makes 1 LLM call with a
    /// focused prompt; = the results are merged into 1 `ImportRoutingResult`.
    /// Phase 1/3 = `classifyAndIndex`: - LLM reads A - returns title + summary
    /// + tags - returns rewrittenBody (= the main INDEX file body; = metadata
    /// header + 6 必填子文件路径引用 + 1 段简短概述) - decides the destination folder - does
    /// NOT return extraFiles
    /// Phase 2/3 = `splitRequired`: - LLM reads A again - returns 6 必填
    /// extraFiles (= 核心设定 / 地理或位置 / 体系或规则 / 历史脉络 / 与其他元素的关系 / 关键场景种子)
    /// Phase 3/3 = `splitCustom`: - LLM reads A again - returns 0-5 自定义
    /// extraFiles (= A's non-B content; = "约等于备注")
    private func routeReorganizeMultiTurn(
        input: ImportFileInput,
        body: String,
        fallbackTitle: String,
        progress: (@Sendable (String) async -> Void)?
    ) async throws -> ImportRoutingResult {
        // The wenshu 文档管理员 runs the import via `ConversationLoop.runTurn`;
        // the agent is told via the per-folder SOP what to write; = it calls
        // `writeBookDoc` to land each file on disk. This function is now a
        // thin adapter (= no LLM calls happen here; = delegates to
        // `ImportAgentDriver`).
        await progress?("  🔵 文档管理员 agent 启动 ...")
        // Phase 1: classify the source via a single LLM call (= the SOP
        // lookup is keyed on the folder; = we need this before launching).
        let classification = try await routeSingleTurn(
            input: input,
            body: body,
            fallbackTitle: fallbackTitle,
            progress: progress
        )
        // Phase 2: resolve the book-bound file path + title (= the agent's
        // `writeBookDoc` tool needs the on-disk root, not a bare UUID).
        let (bookPath, bookTitle) = resolveBookPath(input: input)
        // Phase 3: launch the agent against the per-folder SOP (= if no
        // folder = reference library = no SOP = clear failure).
        try await runAgentAgainstFolder(
            input: input,
            body: body,
            classification: classification,
            bookPath: bookPath,
            bookTitle: bookTitle,
            progress: progress
        )
        await progress?("  ✅ 文档管理员 完成")
        return ImportRoutingResult(
            destination: classification.destination,
            title: classification.title,
            summary: classification.summary,
            tags: Set(classification.tags),
            entityType: classification.entityType,
            category: classification.category,
            confidence: classification.confidence,
            rewrittenBody: nil,
            extraFiles: [],
        )
    }

    /// Resolve the book-bound file path + display title for the agent's
    /// `writeBookDoc` tool. Returns `(nil, "参考库")` for reference-library
    /// imports (= the agent will reject writes with a clean "no SOP" error
    /// rather than silently writing to the wrong destination).
    private func resolveBookPath(input: ImportFileInput) -> (String?, String) {
        guard let bookId = input.targetBookId,
              let shelfId = input.targetShelfId,
              let shelvesRoot = WenshuAppDelegate.activeShelvesRoot() else {
            return (nil, "参考库")
        }
        let booksRoot = shelvesRoot
            .appendingPathComponent(shelfId.uuidString, isDirectory: true)
            .appendingPathComponent("books", isDirectory: true)
        let bookPath = booksRoot
            .appendingPathComponent(bookId.uuidString, isDirectory: true)
            .path
        // The picker doesn't yet surface a display name through
        // `ImportFileInput`; = use the file's stem as a stand-in (= the SOP
        // substitutes it as the `{bookTitle}` placeholder).
        let bookTitle = (input.filePath as NSString)
            .lastPathComponent
            .replacingOccurrences(of: ".md", with: "")
        return (bookPath, bookTitle)
    }

    /// Launch the agent against the per-folder SOP. If the LLM classified the
    /// source as reference-library (= no folder = no SOP), surface this as a
    /// clear failed-task outcome (= the user sees "no SOP for reference
    /// library" rather than a raw driver error).
    private func runAgentAgainstFolder(
        input: ImportFileInput,
        body: String,
        classification: ImportRoutingResult,
        bookPath: String?,
        bookTitle: String,
        progress: (@Sendable (String) async -> Void)?
    ) async throws {
        guard let folder = Self.folder(from: classification.destination) else {
            await progress?("  ⚠️ 参考库没有 SOP (= 路由到失败 task)")
            throw NSError(
                domain: "wenshu.import",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey:
                    "reference library imports have no SOP (= per-folder SOPs only apply to book folders). Use a book-bound import instead."]
            )
        }
        let context = ImportAgentBookContext(bookPath: { bookPath })
        let agentInput = ImportAgentDriver.TaskInput(
            filePath: input.filePath,
            body: body,
            bookPath: bookPath ?? "",
            bookTitle: bookTitle,
            targetFolder: folder
        )
        _ = try await driver.run(
            input: agentInput,
            bookContext: context,
            progress: progress
        )
    }

    /// Extract the BookFolder from the routing result's destination (= the
    /// `routeReorganizeMultiTurn` driver needs the folder to look up the SOP).
    /// Returns nil for `.referenceLibrary` destinations (= there is no folder
    /// in the reference library; = the driver will throw `noSOPForFolder`
    /// rather than silently picking a random SOP to apply to a library that has
    /// no folder semantics).
    private static func folder(
        from destination: ImportDestination
    ) -> BookFolder? {
        switch destination {
        case .bookFolder(let folder):
            return folder
        case .referenceLibrary:
            return nil
        }
    }

    // MARK: - Tool-use loop (= searchAndRewrite)

    /// (= the `searchAndRewrite` rewriteMode's LLM-call pattern). Drives the
    /// LLM through a series of `web_search` tool_use blocks; = each tool_use
    /// block is dispatched to `WebSearchTool.shared.execute` and the result is
    /// sent back as a `tool_result` block; = the loop terminates when the LLM
    /// responds with `stopReason = .endTurn` (= the LLM has produced its final
    /// classification + the rewritten body); = a hard turn cap (= 5) prevents
    /// runaway token spend (= the boss's "Token 高消耗" concern; = a search call
    /// that doesn't converge in 5 turns is a clear signal of a misbehaving LLM
    /// or a stale web result; = the orchestrator still produces a result (= the
    /// last response's text is the best effort); = = in practice the LLM
    /// converges in 1-2 turns for typical reference-library imports).
    private func runToolUseLoop(
        initialUserPrompt: String,
        options: LLMCallOptions,
        body: String,
        filePath: String
    ) async throws -> LLMResponse {
        var messages: [LLMMessage] = [.user(initialUserPrompt)]
        let maxTurns = 5
        for turn in 0..<maxTurns {
            let response = try await connector.send(messages: messages, options: options)
            // Check stop reason (= endTurn = LLM finished; = toolUse = LLM wants to call
            // a tool; = maxTokens = LLM hit the cap; = unknown = bail).
            switch response.stopReason {
            case .endTurn:
                return response
            case .maxTokens, .stopSequence, .unknown:
                return response
            case .toolUse:
                break
            }
            // Collect tool_use blocks (= one or more in a single response; = the
            // Anthropic API allows parallel tool_use).
            var toolUseBlocks: [(id: String, name: String, input: String)] = []
            var assistantTextBlocks: [String] = []
            for block in response.blocks {
                switch block {
                case .text(let s):
                    assistantTextBlocks.append(s)
                case .toolUse(let id, let name, let input):
                    toolUseBlocks.append((id, name, input))
                case .thinking, .toolResult:
                    continue
                }
            }
            if toolUseBlocks.isEmpty {
                // LLM said toolUse but didn't emit any tool_use blocks; = the LLM
                // misbehaved; = return the text we have.
                return response
            }
            // Append the assistant message (= the full response blocks, not just text; =
            // the LLMConnector serializes this into the wire request's
            // `messages` array).
            messages.append(LLMMessage(role: .assistant, blocks: response.blocks))
            // Dispatch each tool_use; = collect tool_result blocks for the next request.
            for tool in toolUseBlocks {
                let output: String
                if tool.name == "web_search" {
                    output = await dispatchWebSearch(input: tool.input)
                } else {
                    output = "{\"ok\":false,\"error\":\"unknown tool: \(tool.name)\"}"
                }
                messages.append(.toolResult(
                    toolUseID: tool.id,
                    output: output
                ))
            }
        }
        // Fall through (= turn cap exceeded; = return the last response we have; = in
        // practice unreachable because we return on .endTurn inside the loop).
        return try await connector.send(messages: messages, options: options)
    }

    /// Dispatch a `web_search` tool call. The LLM passes the tool's `input`
    /// field as a JSON string (= the Anthropic shape); = we hand that string
    /// straight to `WebSearchTool.shared.execute` which understands the same
    /// JSON shape (= the canonical wenshu tool dispatcher).
    private func dispatchWebSearch(input: String) async -> String {
        do {
            return try await WebSearchTool.shared.execute(input: input)
        } catch {
            return "{\"ok\":false,\"error\":\"web_search dispatch failed: \(error.localizedDescription)\"}"
        }
    }

    /// Canonical `web_search` tool schema (= mirrors the registration in
    /// `WebSearchTool`; = the LLM sees this schema and decides when to call
    /// `web_search` for an entity).
    // see WCIRToolSchema.webSearchToolSchema (extracted in A19 for §6.6 god-class split).
    // see WCIRHelpers.userPrompt (extracted in A19 for §6.6 god-class split).
    // see WCIRHelpers.rewriteModeBlock (extracted in A19 for §6.6 god-class split).
    // see WCIRHelpers.jsonShape (extracted in A19 for §6.6 god-class split).
    func isContentSame(
        sourceBody: String,
        existingBody: String,
        sourceTitle: String
    ) async throws -> ContentSameResult {
        let userPrompt = WCIRPromptHelpers.contentSamePrompt(
            sourceBody: sourceBody,
            existingBody: existingBody,
            sourceTitle: sourceTitle
        )
        let options = LLMCallOptions(
            model: modelSlug,
            maxTokens: 1024,
            systemPrompt: SystemPrompt.librarianRole(.chinese),
            temperature: 0.1,
            reasoningEffort: nil,
            tools: []
        )
        let response = try await connector.send(
            messages: [.user(userPrompt)],
            options: options
        )
        // Extract the text content from the response (= the LLM returns a structured
        // response with `text` blocks).
        let rawText = response.blocks.compactMap { block -> String? in
            if case let .text(text) = block { return text }
            return nil
        }.joined(separator: "\n")
        // Parse the JSON (= the same defensive parse as Phase 1).
        guard let json = WCIRHelpers.extractFirstJSONObject(rawText) else {
            // Parse failed (= LLM didn't return JSON; = the conservative default is
            // "different" so the user gets the new content rather than a
            // false skip).
            return ContentSameResult(
                isContentSame: false,
                confidence: 0.0,
                reasoning: "LLM 未返回可解析的 JSON；按不同内容处理。"
            )
        }
        guard let data = json.data(using: .utf8),
              let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return ContentSameResult(
                isContentSame: false,
                confidence: 0.0,
                reasoning: "JSON 解析失败；按不同内容处理。"
            )
        }
        let isContentSame = (parsed["isContentSame"] as? Bool) ?? false
        let confidence = (parsed["confidence"] as? Double ?? parsed["confidence"] as? Float as? Double) ?? 0.0
        let reasoning = (parsed["reasoning"] as? String) ?? ""
        return ContentSameResult(
            isContentSame: isContentSame,
            confidence: Float(confidence),
            reasoning: reasoning
        )
    }

    /// Build the user prompt for the content-same decision. The LLM gets 2
    /// bodies + a title (= the title is the same on both sides because Phase 1
    /// found a same-titled file; = the LLM uses the title as a context anchor +
    /// the bodies as evidence).
    // see WCIRHelpers.contentSamePrompt (extracted in A19 for §6.6 god-class split).
    // see WCIRHelpers.shouldSkip (extracted in A19 for §6.6 god-class split).
    // see WCIRHelpers.fallbackTitle (extracted in A19 for §6.6 god-class split).
    // see WCIRHelpers.sanitizeTitle (extracted in A19 for §6.6 god-class split).
    // see WCIRHelpers.stripObsidianBacklinks (extracted in A19 for §6.6 god-class split).
    // see WCIRHelpers.isUselessMetadataLine (extracted in A19 for §6.6 god-class split).

    /// (= boss 2026-10-10 (see OOB.md #2026-10-10) directive). The LLM-supplied
    /// title is NOT trusted as-is (= the LLM can echo the file path, the
    /// filename, an extension, a body fragment, or gibberish; = the "目录树当名字"
    /// bug surfaced repeatedly). The programmatic `sanitizeTitle` check runs
    /// FIRST (= any of the 8 failure modes below returns nil = we use
    /// `fallbackTitle` instead; = the user sees a clean filename-based title
    /// regardless of what the LLM did; = programmatic guarantee beats LLM
    /// trust).
    /// The flow (= boss round-37 spec): 1. `parsed.title` (= the LLM's answer).
    /// 2. \`WCIRHelpers.sanitizeTitle(parsed.title, from: filePath)\` returns
    /// `String?` (= nil = any of the 8 failure modes hit; = use
    /// `fallbackTitle`). 3. The accepted title is trimmed (= sanitizeTitle
    /// returns the trimmed form). 4. The fallback path (`fallbackTitle`) is the
    /// filename without extension (= guaranteed clean).
    /// `static` (= `parseAndMap` is a static method on the actor; = the title
    /// sanitizer doesn't need any actor state; = calling
    /// `WCIRHelpers.sanitizeTitle` keeps the call site free of `self`).
    // see WCIRHelpers.acceptTitle (extracted in A19 for §6.6 god-class split).
    // see WCIRHelpers.extractFirstJSONObject (extracted in A19 for §6.6 god-class split).
    // see WCIRHelpers.parseImportDecision (extracted in A19 for §6.6 god-class split).
    // see WCIRHelpers.bookFolder (extracted in A19 for §6.6 god-class split).

    /// (= boss 2026-10-09 (see OOB.md #2026-10-09) punctuation (= the LLM
    /// sometimes emits `,` to separate what should be two tags, or `()` to wrap
    /// a parenthetical that snuck in; = the wenshu tag facet is a navigation
    /// filter; = the user can only navigate to a tag that matches a real
    /// entity; = punctuation breaks the facet match).
    /// "Punctuation" here = anything that is not a Unicode letter, digit, or
    /// CJK character. CJK Unified Ideographs (= the U+4E00..U+9FFF block +
    /// extensions) are all valid tag characters. CJK punctuation blocks (=
    /// U+3000..U+303F "CJK Symbols and Punctuation", U+FF00 "Halfwidth and
    /// Fullwidth Forms", U+FE30 "CJK Compatibility Forms") are dropped. ASCII
    /// punctuation (= `,` / `.` / `-` / `:` / `(` / `)` / `/` / `'` / `"` / `[`
    /// / `]`) is dropped. Whitespace and underscore are also dropped (= the tag
    /// facet matches on the canonical string; = the user never types spaces or
    /// underscores when navigating).
    // see WCIRHelpers.tagContainsPunctuation (extracted in A19 for §6.6 god-class split).
}
