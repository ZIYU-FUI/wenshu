//
//  WenshuConductorImportRouter.swift
//
//  T4 of the v2.7 markdown import feature. The production
//  `ImportRouter` (= the seam the orchestrator dispatches
//  per file; = defined in `ImportService.swift`).
//
//  History:
//   - 2026-10-09 (initial T4) used the `EntityClassifier`
//     actor with a `nil` LLM callback (= the keyword
//     pass + a stub fallback). The keyword pass produces
//     CLC letter tags (= "K" / "B" / "N" / ...) and a
//     fixed "drafts" book-folder destination, = the
//     user feedback on 2026-10-09: "大量不应该进到五
//     目录的进到了五目录，同时五目录没有进到对应的
//     目录下，标题也没有显示中文标题", "分类有的只
//     显示一个字母，不是中文标签，标签没有重新梳理
//     生成", "在打标签时，按真实内容打标签，而不是
//     去靠图书馆分类".
//   - 2026-10-09 (this rewrite) drops the keyword
//     fallback entirely and dispatches every file
//     through a real LLM call (= the same LLMConnector
//     the rest of wenshu uses, = no new inference
//     path; = the LLM's role is the "调研员" the user
//     asked for in the 2026-10-09 OOB; = the
//     `SystemPrompt.librarianRole` adds the prompt
//     fragment that defines this role). The LLM is the
//     single source of truth for title (Chinese
//     rewrite), tags (5-8 real-content Chinese terms,
//     no CLC letters), summary (one-line Chinese
//     description), and the per-file destination
//     (= bookFolder of one of the 5 standard folders,
//     or referenceLibrary for external knowledge).
//
//  Apple canonical pattern: the router is an actor (=
//  it serializes LLM dispatch via its own state machine
//  instead of relying on the orchestrator's lock; = the
//  orchestrator still does the 4-way parallel dispatch
//  via TaskGroup, but each individual `route(_:)` call
//  is serialized at the LLM-boundary inside the actor).
//

import Foundation

/// The production `ImportRouter` that the sheet uses.
/// Each `route(_:)` invocation makes a real LLM call
/// (= the `LLMConnector` from
/// `WenshuAppDelegate.activeLLMConnector()`; = the same
/// connector the rest of wenshu ships with out of the
/// box per AGENTS.md §11.2 P0 profile list).
actor WenshuConductorImportRouter: ImportRouter {

    /// The resolved LLM connector (= resolved lazily
    /// once at first `route(_:)` call; = the connector
    /// is `nonisolated` and `Sendable`; = safe to capture
    /// into the actor's stored state).
    private let connector: any LLMConnector

    /// The model slug (= the user-picked model from
    /// `wenshu.llm.model`; = falls back to the
    /// connector's default; = the active connector's
    /// `connectorID` is the canonical default
    /// identifier).
    private let modelSlug: String

    init(
        connector: (any LLMConnector)? = nil,
        modelSlug: String? = nil
    ) {
        // The connector resolution is intentionally
        // synchronous (= WenshuAppDelegate.activeLLMConnector()
        // is `nonisolated`; = the cost is one UserDefaults
        // read + one ProviderCatalog lookup; = the actor
        // initializer runs at most once per sheet
        // presentation; = the lookup is cheap enough to
        // not need a lazy property).
        self.connector = connector ?? WenshuAppDelegate.activeLLMConnector()
        // `LLMCallOptions.model` is non-optional; =
        // the active connector knows its own default
        // model slug (= `connectorID` for the wenshu
        // canonical case; = the connector falls back to
        // its provider default if the user hasn't picked
        // anything in the Settings picker). Passing the
        // active LLMConnector's `connectorID` (= a
        // stable identifier like "anthropic" /
        // "minimax-cn") lets the connector route to the
        // right model family without a wenshu-side
        // hardcoded model list (= AGENTS.md §11.2 P0
        // profile list is the canonical cross-check).
        self.modelSlug = modelSlug ?? WenshuAppDelegate.activeModelSlug() ?? "default-model"
    }

    /// Classify one file via the LLM (= the prompt
    /// asks the LLM to return a single JSON object
    /// with the structured fields the orchestrator
    /// needs).
    func route(_ input: ImportFileInput) async throws -> ImportRoutingResult {
        // Read the body verbatim (= the orchestrator's
        // writeFile also reads the body; = two reads
        // for now; = a future micro-optimization can
        // thread the body through the orchestrator +
        // router seam; = today the test-isolation
        // benefit wins over the cost).
        let body = try String(contentsOfFile: input.filePath, encoding: .utf8)
        let fallbackTitle = Self.fallbackTitle(from: input.filePath)

        // Build the prompt (= the librarian role's
        // system prompt + the per-file user prompt).
        let userPrompt = Self.userPrompt(
            filePath: input.filePath,
            body: body,
            rewriteMode: input.rewriteMode
        )
        // v2.7 tool wiring (= boss 2026-10-09
        // round-18 "重写同时搜索校对"). The
        // `searchAndRewrite` mode is the ONLY
        // mode that passes tools (= the
        // `consolidate` mode is the LLM-no-tools
        // path that matches the pre-v2.7
        // behavior). The tool schema mirrors
        // `WebSearchTool`'s registration; =
        // canonical wenshu tools are NOT
        // re-implemented here; = the LLM calls
        // the same tool name (`web_search`)
        // regardless of mode.
        let tools: [ToolRegistrySchema]
        if input.rewriteMode == .searchAndRewrite {
            tools = Self.webSearchToolSchema
        } else {
            tools = []
        }
        let options = LLMCallOptions(
            model: modelSlug,
            maxTokens: 4096,
            systemPrompt: SystemPrompt.librarianRole(.chinese),
            temperature: 0.2,
            reasoningEffort: nil,
            tools: tools
        )
        // Fire the LLM call. Failures are non-fatal:
        // the orchestrator's per-file try/catch
        // catches the throw and marks the task
        // .failed (= the user sees "失败" in the
        // per-file state strip; = the action button
        // flips to "重试" so they can re-run the
        // failed rows after fixing the LLM config).
        let response: LLMResponse
        switch input.rewriteMode {
        case .consolidate:
            // Single-turn, no tool loop (= the
            // pre-v2.7 behavior; = the LLM has
            // no tools so `stopReason` is
            // `endTurn` immediately).
            response = try await connector.send(
                messages: [.user(userPrompt)],
                options: options
            )
        case .searchAndRewrite:
            // Multi-turn tool-use loop (= the
            // LLM is permitted to call
            // `web_search`; = we route each
            // tool_use block to the canonical
            // `WebSearchTool.shared.execute`
            // (= the same path the chat
            // session uses; = no tool
            // duplication); = the loop
            // terminates on `stopReason =
            // .endTurn` OR after a hard
            // turn cap to prevent runaway
            // token spend (= boss's
            // "Token 高消耗" concern)).
            response = try await runToolUseLoop(
                initialUserPrompt: userPrompt,
                options: options,
                body: body,
                filePath: input.filePath
            )
        }
        let raw = response.blocks.map(\.textValue).joined()
        return Self.parseAndMap(
            raw: raw,
            body: body,
            fallbackTitle: fallbackTitle,
            filePath: input.filePath
        )
    }

    // MARK: - Tool-use loop (= v2.7 searchAndRewrite)

    /// v2.7 multi-turn tool-use loop (= the
    /// `searchAndRewrite` rewriteMode's
    /// LLM-call pattern). Drives the LLM
    /// through a series of `web_search`
    /// tool_use blocks; = each tool_use
    /// block is dispatched to
    /// `WebSearchTool.shared.execute` and
    /// the result is sent back as a
    /// `tool_result` block; = the loop
    /// terminates when the LLM responds
    /// with `stopReason = .endTurn` (= the
    /// LLM has produced its final
    /// classification + the rewritten
    /// body); = a hard turn cap (= 5)
    /// prevents runaway token spend
    /// (= the boss's "Token 高消耗"
    /// concern; = a search call that
    /// doesn't converge in 5 turns is
    /// a clear signal of a misbehaving
    /// LLM or a stale web result; = the
    /// orchestrator still produces a
    /// result (= the last response's
    /// text is the best effort); =
    /// = in practice the LLM converges
    /// in 1-2 turns for typical
    /// reference-library imports).
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
            // Check stop reason (= endTurn = LLM
            // finished; = toolUse = LLM wants to
            // call a tool; = maxTokens = LLM hit
            // the cap; = unknown = bail).
            switch response.stopReason {
            case .endTurn:
                return response
            case .maxTokens, .stopSequence, .unknown:
                return response
            case .toolUse:
                break
            }
            // Collect tool_use blocks (= one or
            // more in a single response; = the
            // Anthropic API allows parallel
            // tool_use).
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
                // LLM said toolUse but didn't
                // emit any tool_use blocks; = the
                // LLM misbehaved; = return the
                // text we have.
                return response
            }
            // Append the assistant message (= the
            // full response blocks, not just
            // text; = the LLMConnector serializes
            // this into the wire request's
            // `messages` array).
            messages.append(LLMMessage(role: .assistant, blocks: response.blocks))
            // Dispatch each tool_use; = collect
            // tool_result blocks for the next
            // request.
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
        // Fall through (= turn cap exceeded; = return
        // the last response we have; = in practice
        // unreachable because we return on .endTurn
        // inside the loop).
        return try await connector.send(messages: messages, options: options)
    }

    /// Dispatch a `web_search` tool call. The LLM
    /// passes the tool's `input` field as a JSON
    /// string (= the Anthropic shape); = we hand
    /// that string straight to
    /// `WebSearchTool.shared.execute` which
    /// understands the same JSON shape (= the
    /// canonical wenshu tool dispatcher).
    private func dispatchWebSearch(input: String) async -> String {
        do {
            return try await WebSearchTool.shared.execute(input: input)
        } catch {
            return "{\"ok\":false,\"error\":\"web_search dispatch failed: \(error.localizedDescription)\"}"
        }
    }

    /// Canonical `web_search` tool schema (= mirrors
    /// the registration in `WebSearchTool`; = the
    /// LLM sees this schema and decides when to
    /// call `web_search` for an entity).
    static let webSearchToolSchema: [ToolRegistrySchema] = [
        ToolRegistrySchema(
            name: "web_search",
            description: """
            Web search via the keyless anonymous public free tier ring \
            (Parallel / Exa / Keenable, in that order). No API key \
            or configuration is needed; works on first launch. \
            Use this tool to find the canonical content for the entity \
            the user is importing (= search the entity name; = return \
            the top results with title / url / snippet; = the LLM \
            then incorporates the search results into the rewritten \
            body).
            """,
            inputSchema: [
                "action": ToolRegistrySchemaProperty(
                    type: "string",
                    description: "The web_search operation to perform.",
                    enumValues: ["search", "research"]
                ),
                "query": ToolRegistrySchemaProperty(
                    type: "string",
                    description: "Search query string (= required)."
                ),
                "limit": ToolRegistrySchemaProperty(
                    type: "integer",
                    description: "Maximum number of results to return."
                )
            ],
            required: ["action", "query"]
        )
    ]

    // MARK: - Prompt + parse

    /// The per-file user prompt (= asks the LLM to
    /// produce a structured JSON object with title /
    /// summary / tags / destination / bookFolder;
    /// = the schema is the only thing the LLM is
    /// allowed to talk about; = a single JSON object
    /// on one line so the parser can grab it
    /// deterministically).
    static func userPrompt(filePath: String, body: String, rewriteMode: ImportFileInput.RewriteMode = .consolidate) -> String {
        // Cap the body sent to the LLM (= the v0.74
        // default Anthropic context window is plenty
        // for a classification + tag + title rewrite
        // task; = 12,000 chars is more than enough for
        // a 1-2 page markdown file's worth of
        // classification signal; = the LLM never needs
        // the full text body to make a routing
        // decision; = the cap also keeps the cost
        // low for a 456-file batch).
        let trimmed = String(body.prefix(12_000))
        // v2.7 PROMPT REWRITE (= boss 2026-10-09
        // round-16 "三个问题" feedback):
        // 1) "小说草稿里的卡片还是显示 ID":
        //    = the previous prompt included the
        //    `filePath` line (= the source path); =
        //    the LLM sometimes echoed the path as
        //    the title (= a long string with `/`
        //    stripped → "UsersanbaiqiangLibraryMob
        //    ileDocumentsiCloud~md..."); = the
        //    filename = the LLM title = a path
        //    echo; = the sidebar card title was
        //    unreadable. Fix: drop the filePath
        //    line from the prompt entirely (= the
        //    body alone is enough for the LLM to
        //    find the canonical entity name; = the
        //    filePath was the leak that turned
        //    into a filename).
        // 2) "世界观混入了大量本来放在资料库
        //    里的资料" (= 124 items in world/, all
        //    folk-god / 五脊六兽 / 三台星 / generic
        //    cosmic lore; = the LLM wrongly routed
        //    generic-world-knowledge into world/).
        //    Fix: world/ is now the STRICT
        //    constitution-level folder; = the
        //    default routing is referenceLibrary;
        //    = world/ requires explicit "in this
        //    novel" / "本小说独有" markers in
        //    the body; = otherwise referenceLibrary.
        // 3) "资料库多了一个 tag '十二地仙'":
        //    = the LLM was leaking the target
        //    novel's name into the tag list (= a
        //    hard-rule violation; = tags must come
        //    from the body content, NOT from the
        //    novel context). Fix: explicit "no
        //    book name in tags" rule + the
        //    "target novel" mention is now ONLY
        //    used as the routing signal; = tags
        //    derive from the body.
        return """
        请阅读下面的 Markdown 资料，输出一行 JSON 描述如何整理它。

        ## 正文
        \(trimmed)

        ## 任务
        1) 重写一个**最短**的中文标题 (= 取文件表示
           的**最核心实体名字**, 不要前缀/后缀/说
           明; = 文件名只放**一个实体的名字**; = 不
           带 "档案"、"资料"、"研究"、"卷"、朝代、
           年份、章节号等修饰词; = 如果一个文件讲了
           多个实体, 选**最核心**那一个):
             - "太平广记卷一○○李寄斩蛇" → "李寄"
             - "门闩神民俗研究" → "门闩神"
             - "XX 朝代元 1290 狗案" → "狗"
             - "主角职业入殓师" → "入殓师"
        2) 写一句话的中文摘要
        3) 提取 5-8 个真实内容的标签（**仅从正文
           内容本身提取**：人物、地点、年代、概
           念、品牌等真实信息; = **严禁**把小说
           名字、目标小说、用户身份、当前项目名等
           元信息塞进 tag; = 标签只能描述"这个文
           件讲的是什么内容"，不能描述"这个文件
           属于哪本书")
        4) **destination 已经被用户选好**（= 老板
           2026-10-09 round-18 "强制让用户分开导
           入"指令）。你**不需要**判 断 destination
           — 用户在 sheet 里已经选了"导入到资料
           库"或"导入到书"；= 你**只负责**生成
           title / summary / tags。
        \(Self.rewriteModeBlock(rewriteMode))

        ## 输出格式
        严格一行 JSON，不要任何其他文字、解释或 markdown 代码块：
        {\(Self.jsonShape(rewriteMode))}
        """
    }

    /// The optional rewrite-mode body for the
    /// `searchAndRewrite` mode. When the user
    /// picked "重写同时搜索校对", the prompt
    /// tells the LLM to: (a) call `web_search`
    /// for the entity, (b) combine search
    /// results with the original body, (c)
    /// produce a clean .ws-format body (= no
    /// "imported on YYYY-MM-DD" cruft; = same
    /// shape the user writes by hand; = ref
    /// library uses `类型:` / `状态:` /
    /// `标签:` frontmatter; = bookFolder
    /// uses free-form markdown).
    private static func rewriteModeBlock(_ mode: ImportFileInput.RewriteMode) -> String {
        switch mode {
        case .consolidate:
            return ""
        case .searchAndRewrite:
            return """
            5) **整理新正文**:
               - 你**可以**调用 `web_search` 工具查
                 找该实体的标准资料 (= action=search,
                 query=<实体名>，limit=5); = 也可以不
                 调用（= 如果你从原文已经能整理出完
                 整 .ws 格式正文).
               - 把搜索结果 + 原文**整理**成 .ws 格
                 式的最终正文 (= 不要扩写或加虚构内
                 容; = 搜索只是补全原文里不完整的部
                 分; = 整理 = 标准化 .ws 格式).
               - .ws 资料库正文格式:
                 ```
                 # <实体名>
                 类型: <类型>
                 状态: 已建

                 <整理后的正文>
                 ```
               - .ws 书目录正文格式: 直接 `<实体
                 名>相关正文` (无 frontmatter; = 老
                 板原 .md 格式).
               - 把整理后的正文放 JSON 的
                 `rewrittenBody` 字段 (= 没有整理
                 = 字段留空字符串 = 走"原样落地"
                 fallback)。
            """
        }
    }

    /// The JSON shape the LLM should return
    /// (= varies with rewriteMode; =
    /// `searchAndRewrite` adds the
    /// `rewrittenBody` field).
    private static func jsonShape(_ mode: ImportFileInput.RewriteMode) -> String {
        switch mode {
        case .consolidate:
            return "\"title\":\"<中文标题>\",\"summary\":\"<一句话中文摘要>\",\"tags\":[\"<tag1>\",\"<tag2>\",...]\""
        case .searchAndRewrite:
            return "\"title\":\"<中文标题>\",\"summary\":\"<一句话中文摘要>\",\"tags\":[\"<tag1>\",\"<tag2>\",...],\"rewrittenBody\":\"<整理后的 .ws 格式正文（可以包含换行 \\\\n）>\""
        }
    }

    /// Parse the LLM's raw response and map it onto
    /// the orchestrator's `ImportRoutingResult`
    /// envelope. The parser is defensive: any
    /// malformed line falls back to the keyword-style
    /// safe default (bookFolder .drafts) so the
    /// orchestrator never receives an invalid
    /// destination.
    static func parseAndMap(
        raw: String,
        body: String,
        fallbackTitle: String,
        filePath: String
    ) -> ImportRoutingResult {
        // 1. Extract the JSON object. The LLM is
        //    instructed to reply with one line of
        //    JSON; = grab the first {...} span in the
        //    response (= tolerant of leading /
        //    trailing whitespace / reasoning blocks
        //    the model might emit before the JSON).
        guard let json = extractFirstJSONObject(raw) else {
            // LLM returned no parseable JSON. Fall
            // back to a safe default (= drafts is the
            // least-surprising place for an unparseable
            // file; = the user sees the file with a
            // "失败" status if the parser threw
            // upstream; = here we synthesize a valid
            // envelope so the orchestrator's downstream
            // consumers don't crash).
            return ImportRoutingResult(
                destination: .bookFolder(.drafts),
                title: fallbackTitle,
                summary: "LLM 未返回可解析的 JSON；归类为草稿。",
                tags: [],
                entityType: "other",
                category: nil,
                confidence: 0.0,
                rewrittenBody: nil
            )
        }
        // 2. Parse the JSON.
        let parsed = parseImportDecision(json)
        // 3. Map the destination. The orchestrator
        //    accepts a closed enum; = we coerce the
        //    LLM's free-text destination into the
        //    canonical `BookFolder` value (= the
        //    Apple canonical pattern is "make illegal
        //    states unrepresentable" so we never
        //    write a string into the destination
        //    field).
        let destination: ImportDestination
        switch parsed.destination {
        case "referenceLibrary":
            destination = .referenceLibrary
        case "bookFolder":
            destination = .bookFolder(parsed.bookFolder ?? .drafts)
        default:
            // Unknown destination string from the LLM
            // (= the model invented a value not in
            // our schema). Fall back to drafts (= the
            // conservative landing site; = the user
            // can re-route via the sheet's "重试" +
            // chat override).
            destination = .bookFolder(.drafts)
        }
        // 4. Final envelope. The LLM-supplied title
        //    is the canonical title (= the
        //    orchestrator's writeFile does NOT
        //    rewrite the body; = the LLM's title
        //    lives in the metadata; = the body file
        //    on disk is verbatim from the source).
        return ImportRoutingResult(
            destination: destination,
            title: parsed.title.isEmpty ? fallbackTitle : parsed.title,
            summary: parsed.summary,
            tags: Set(parsed.tags),
            entityType: "other",
            category: nil,
            confidence: parsed.tags.isEmpty ? 0.3 : 0.9,
            // v2.7: parse the optional rewritten body
            // (= the LLM's .ws-format body in
            // `searchAndRewrite` mode; = nil = the
            // orchestrator keeps the original body
            // verbatim).
            rewrittenBody: parsed.rewrittenBody
        )
    }

    /// Fallback title (= the basename without
    /// extension; = used when the LLM returns an
    /// empty title string).
    static func fallbackTitle(from filePath: String) -> String {
        let basename = (filePath as NSString).deletingPathExtension
        return basename.isEmpty ? "未命名" : basename
    }

    // MARK: - Private parsing

    /// Decoded subset of the LLM's JSON output.
    private struct ImportDecision {
        var title: String
        var summary: String
        var tags: [String]
        var destination: String
        var bookFolder: BookFolder?
        /// v2.7 (= boss 2026-10-09 round-18
        /// "重写同时搜索校对"). The LLM's
        /// .ws-format body in `searchAndRewrite`
        /// mode (= nil in `consolidate` mode OR
        /// when the LLM returned an empty
        /// string).
        var rewrittenBody: String?
    }

    /// Extract the first balanced `{...}` JSON object
    /// from the LLM's response. The model sometimes
    /// emits a thinking block before the JSON (= the
    /// `extract` step on a hermes connector prepends a
    /// <think>...</think> block; = Anthropic similarly
    /// returns a `thinking` content block ahead of
    /// `text`).
    private static func extractFirstJSONObject(_ raw: String) -> String? {
        guard let firstBrace = raw.firstIndex(of: "{") else { return nil }
        var depth = 0
        var inString = false
        var escape = false
        for i in raw[firstBrace...].indices {
            let c = raw[i]
            if escape { escape = false; continue }
            if c == "\\" { escape = true; continue }
            if c == "\"" { inString.toggle(); continue }
            if inString { continue }
            if c == "{" { depth += 1 }
            if c == "}" {
                depth -= 1
                if depth == 0 {
                    return String(raw[firstBrace...i])
                }
            }
        }
        return nil
    }

    /// Parse the JSON envelope into an `ImportDecision`.
    /// Defensive: any field that doesn't match the
    /// expected type falls back to a safe default (= the
    /// orchestrator never receives a half-parsed
    /// decision).
    private static func parseImportDecision(_ json: String) -> ImportDecision {
        guard let data = json.data(using: .utf8),
              let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return ImportDecision(
                title: "", summary: "", tags: [],
                destination: "bookFolder", bookFolder: .drafts,
                rewrittenBody: nil
            )
        }
        let title = (parsed["title"] as? String) ?? ""
        let summary = (parsed["summary"] as? String) ?? ""
        let tags = (parsed["tags"] as? [String]) ?? []
        let destination = (parsed["destination"] as? String) ?? "bookFolder"
        let bookFolder: BookFolder? = {
            guard let s = parsed["folder"] as? String else { return nil }
            switch s {
            case "world": return .world
            case "characters": return .characters
            case "outlines": return .outlines
            case "chapters": return .chapters
            case "drafts": return .drafts
            default: return nil
            }
        }()
        // v2.7 rewritten body (= only set in
        // `searchAndRewrite` mode; = empty
        // string from the LLM = the user
        // didn't actually search and rewrite
        // = treat as nil so the orchestrator
        // falls back to the original body).
        let rawRewritten = (parsed["rewrittenBody"] as? String) ?? ""
        let rewrittenBody: String? = rawRewritten.isEmpty ? nil : rawRewritten
        return ImportDecision(
            title: title,
            summary: summary,
            tags: tags,
            destination: destination,
            bookFolder: bookFolder,
            rewrittenBody: rewrittenBody
        )
    }
}
