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
        // v2.7 round-36 (= boss 2026-10-09 "在
        // 红字后面，加一个小操作文字，
        // 就是基于标题重新调研" directive).
        // Body resolution (= three sources,
        // precedence high to low):
        // 1. `input.body` (= the orchestrator's
        //    override; = the "title-only" retry
        //    path = the orchestrator synthesized
        //    a body from the filename + sibling
        //    .md names = the source file is
        //    unreadable on disk = the router
        //    must not try to read it)
        // 2. `try String(contentsOfFile: input.filePath)`
        //    (= the normal `importFiles` path; =
        //    the source file is readable; = the
        //    router reads it from disk)
        // 3. `throw` (= neither is available; =
        //    the file was deleted between the
        //    orchestrator's walk phase and the
        //    route phase; = the orchestrator
        //    catches the throw and marks the
        //    task .failed with "读取文件失败: ...")
        let body: String
        if let override = input.body {
            body = override
        } else {
            body = try String(contentsOfFile: input.filePath, encoding: .utf8)
        }
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
        3) 提取**最多 3 个**真实内容的标签（= 老板
           2026-10-09 round-20 "限制资料库文档的
           标签数量，要最有用的，只能有 3 个标
           签" 反馈; = **不要 5-8 个, 只能 1-3
           个**; = 仅从正文内容本身提取: 人物 /
           地点 / 年代 / 概念 / 品牌等真实信
           息; = **严禁**把小说名字、目标小
           说、用户身份、当前项目名等元信息
           塞进 tag; = 标签只能描述"这个文件
           讲的是什么内容"，不能描述"这个文
           件属于哪本书"; = **严格 3 个以内**;
           = 资料库 sidebar 的 tag facet 用
           户筛选用, 太多 tag = 难以导航)
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
            return """
            5) **整理正文** (= consolidate 模式也要
               标准化 .ws 格式; = 老板 2026-10-09
               round-20 "重写后格式不统一" 反馈;
               = 现在的 consolidate 模式只是
               "原样落地" 没有整理, 老板要统一
               格式, 不只是 searchAndRewrite 整
               理):
               - 输出**整理后的 .ws 格式正文**到
                 `rewrittenBody` 字段 (= 即使你没
                 有搜索, 也要把原文按 .ws 格式
                 标准化; = 不写 = 字段留空 = 走
                 "原样落地" fallback).
            """
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
               - .ws 资料库正文格式 (= 老板 2026-10-09
                 round-25 "不要参考 MD 的格式，而
                 是盘点文枢的功能，做出文枢
                 的头部格式" directive; = 抛弃
                 老板旧 MD 的 `类型/状态/核心
                 信息/详细描述` 模板; = **从头**
                 设计 = 基于文枢 `Reference`
                 struct 字段):
                 ```
                 # <实体名>

                 实体类型: <character | location | event | concept | artifact | organization | era | work | other>
                 标签: <tag1>; <tag2>; <tag3>
                 摘要: <一句话中文摘要>

                 <自由 markdown 正文 — 内容随你; 不
                  要分 "核心信息 / 详细描述"; 不
                  要 frontmatter 之外的字段名>
                 ```
                 - 头信息**必须**包含 3 行 (= 老板
                   2026-10-09 round-25 "头部信息
                   必须包含哪些"):
                   1. `实体类型: <值>` (= 必填; =
                      .ws `Reference.entityType`;
                      = 9 个枚举值; = 没填 = 后
                      端无法分类 = 卡片 facet
                      失灵)
                   2. `标签: <值1>; <值2>; <值3>`
                      (= 必填; = .ws `Reference.tags`;
                      = ≤ 3 个; = `; ` 分隔; = 资料
                      库 sidebar tag facet 唯一
                      的导航源)
                   3. `摘要: <值>` (= 必填; = .ws
                      `Reference.summary`; = 一句
                      话; = 卡片副标题)
                 - 头信息**可选**:
                   - `出处: <值>` (= .ws `Reference.source`;
                     = 资料库 = 资料来源 (e.g.
                     "《太平广记》卷一○○"))
                   - `链接: <值>` (= .ws `Reference.url`;
                     = 资料库 = web URL)
                 - **严禁**写 (= 这些字段文枢已经
                   用别的机制管理, 不写在 .md body):
                   - `类型: ...` / `状态: ...` (= 没
                     意义; = 文枢不维护 status 字
                     段; = `状态: 已建` 这种字段
                     是冗余的)
                   - `核心信息:` / `详细描述:` (= 不
                     需要分节; = 自由写)
                   - `反链:` / `tags:` / `标签:` 在正
                     文 = 跟 metadata 重复
                   - `上次更新: ...` / `created: ...` /
                     `modified: ...` (= entities.json
                     有 `createdAt` / `updatedAt`)
                   - `../` / `[[...]]` (= Obsidian
                     link; = 关系走 .ws 关系链
                     字段, 不在 .md 里)
                   - `<!-- ... -->` (= Obsidian plugin
                     痕迹)
               - .ws 书目录正文格式: 直接 `<实体
                 名>相关正文` (无 frontmatter; =
                 老板原 .md 格式).
               - **保留** (= 重要结构): `# 标题` /
                 `## 子标题` / `### 子标题` /
                 `**加粗**: value` / bullet `-` / 段落.
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
            // CRITICAL: `rewrittenBody` must be a
            // single-line JSON string (= the
            // string-value `\\n` is the JSON
            // escape for newline; = the LLM
            // should NOT emit a literal newline
            // inside the string-value; = the
            // previous prompt said "可以包含换行
            // \\\\n" which the LLM took as
            // permission to insert a real
            // newline; = the JSON parser then
            // bailed; = the boss 2026-10-09
            // round-23 saw "LLM 未返回可解
            // 析的 JSON；归类为草稿" cards
            // with the source path as the
            // fallback title). Fix: tell the
            // LLM to use JSON-escaped `\n`
            // (= \\n) only; = the orchestrator
            // un-escapes after parsing.
            return "\"title\":\"<中文标题>\",\"summary\":\"<一句话中文摘要>\",\"tags\":[\"<tag1>\",\"<tag2>\",...],\"rewrittenBody\":\"<整理后的 .ws 格式正文; 用 \\\\n 表示换行, 不要在字符串值里写真实换行>\""
        }
    }

    /// Parse the LLM's raw response and map it onto
    /// the orchestrator's `ImportRoutingResult`
    /// envelope. The parser is defensive: any
    /// malformed line falls back to the keyword-style
    /// safe default (bookFolder .drafts) so the
    /// orchestrator never receives an invalid
    /// destination.
    /// v2.7 round-66 commit F (= boss
    /// 2026-10-10 "我选
    /// 故事宪法，直
    /// 接跳到了步
    /// 骤 3，没
    /// 有重新
    /// 分析是
    /// 不是
    /// 内容
    /// 相同
    /// " 反馈).
    /// Phase 2 LLM
    /// decision: are
    /// the source body
    /// and the existing
    /// body "the same
    /// content"? (= a
    /// separate LLM
    /// call from the
    /// Phase 1 routing;
    /// = the orchestrator
    /// invokes this
    /// ONLY when
    /// Phase 1 found a
    /// same-titled file
    /// in the destination
    /// folder; = most
    /// imports never
    /// reach this
    /// path).
    /// The LLM is
    /// asked to return
    /// a JSON object
    /// with 3 fields:
    /// `isContentSame` (=
    /// true / false),
    /// `confidence` (=
    /// 0.0 - 1.0), and
    /// `reasoning` (=
    /// a short Chinese
    /// explanation
    /// shown to the
    /// user).
    func isContentSame(
        sourceBody: String,
        existingBody: String,
        sourceTitle: String
    ) async throws -> ContentSameResult {
        let userPrompt = Self.contentSamePrompt(
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
        // Extract the text content from the
        // response (= the LLM returns a
        // structured response with
        // `text` blocks).
        let rawText = response.blocks.compactMap { block -> String? in
            if case let .text(text) = block { return text }
            return nil
        }.joined(separator: "\n")
        // Parse the JSON (= the same
        // defensive parse as Phase 1).
        guard let json = Self.extractFirstJSONObject(rawText) else {
            // Parse failed (= LLM
            // didn't return
            // JSON; = the
            // conservative
            // default is
            // "different" so
            // the user gets
            // the new content
            // rather than a
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

    /// Build the user prompt for the
    /// content-same decision. The LLM gets
    /// 2 bodies + a title (= the title is
    /// the same on both sides because
    /// Phase 1 found a same-titled file;
    /// = the LLM uses the title as a
    /// context anchor + the bodies as
    /// evidence).
    private static func contentSamePrompt(
        sourceBody: String,
        existingBody: String,
        sourceTitle: String
    ) -> String {
        // Cap each body to keep the
        // prompt manageable (= the LLM
        // doesn't need the full
        // 10k-char bodies to detect
        // sameness; = 4000 chars per
        // side = 8000 total = well
        // under the 4096-token budget).
        let sBody = String(sourceBody.prefix(4000))
        let eBody = String(existingBody.prefix(4000))
        return """
        你要判断两段 markdown 正文是否讲**同一个内容**。标题都是「\(sourceTitle)」。

        ## 新文件 (= 用户刚刚选择的)
        \(sBody)

        ## 已有文件 (= 已经存在于目标文件夹)
        \(eBody)

        ## 任务
        1) 判断两段正文是否讲同一件事 (= 同样的人物 / 设定 / 故事)
        2) 给一个 0-1 的 confidence (= 1 = 完全相同, 0 = 完全无关)
        3) 写一句话中文 reasoning (= 给用户看的简短解释)

        ## 输出格式
        严格一行 JSON，不要任何其他文字、解释或 markdown 代码块：
        {"isContentSame":<true|false>,"confidence":<0-1>,"reasoning":"<一句话中文解释>"}
        """
    }

    /// v2.7 round-66 commit F:
    /// Decide whether a Phase 2
    /// `ContentSameResult` should
    /// short-circuit the import (=
    /// treat as a no-op skip) or
    /// trigger an overwrite. Centralized
    /// so the threshold is tuned in
    /// one place (= see
    /// `ImportDocumentTemplate.contentSameConfidenceThreshold`).
    static func shouldSkip(
        result: ContentSameResult
    ) -> Bool {
        return result.isContentSame
            && result.confidence >= ImportDocumentTemplate.contentSameConfidenceThreshold
    }

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
            // v2.7 round-37 (= boss "不能用
            // 提示词控制" directive): the
            // title is run through
            // `acceptTitle` (= programmatic
            // sanitization + fallback; = the
            // user never sees a path / a
            // filename-with-extension / a
            // body-fragment / gibberish as a
            // title; = the LLM's trust is
            // zero; = the contract is
            // "title is either the LLM's
            // clean answer or the
            // filename-stem fallback").
            title: Self.acceptTitle(parsed: parsed, filePath: filePath),
            summary: parsed.summary,
            tags: Set(parsed.tags),
            entityType: "other",
            category: nil,
            confidence: parsed.tags.isEmpty ? 0.3 : 0.9,
            // v2.7: parse the optional rewritten body
            // (= the LLM's .ws-format body in
            // `searchAndRewrite` mode; = nil = the
            // orchestrator keeps the original body
            // verbatim). The caller (= ImportService)
            // checks `rewriteMode` and decides whether
            // to use the rewritten body or fall back
            // to the original (= see round-66 commit E
            // for the mode-aware body selection).
            rewrittenBody: parsed.rewrittenBody
        )
    }

    /// Fallback title (= the basename without
    /// the source-file extension; = used when
    /// the LLM returns an empty title string).
    ///
    /// v2.7 round-31 fix (= boss 2026-10-10
    /// "目录树当名字的问题回归了" =
    /// the previous implementation used
    /// `(filePath as NSString).deletingPathExtension`
    /// which only strips the trailing
    /// extension (= `.md`); = the full
    /// path prefix
    /// `/Users/anbaiqiang/Library/Mobile
    /// Documents/iCloud~md/06-...` survived
    /// and became the card title; = the user
    /// saw the path as the title on every
    /// failed-LLM card. The fix: take
    /// `lastPathComponent` (= filename
    /// only) FIRST, then strip the
    /// extension. `lastPathComponent` =
    /// "/Users/.../06-字.md" → "06-字.md"
    /// → "06-字" (= the user's expected
    /// title shape).
    static func fallbackTitle(from filePath: String) -> String {
        let fileName = (filePath as NSString).lastPathComponent
        let stem = (fileName as NSString).deletingPathExtension
        return stem.isEmpty ? "未命名" : stem
    }

    /// v2.7 round-37 (= boss 2026-10-10 "我觉
    /// 的那个名字的问题，不能用提示词控
    /// 制，应该是程序化控制，不能出错"
    /// directive). Programmatic title
    /// sanitization (= the LLM's title is
    /// not trusted; = any of the failure
    /// modes below → the LLM's title is
    /// discarded and `fallbackTitle` is
    /// used; = the user sees a clean
    /// filename-based title regardless of
    /// what the LLM did).
    ///
    /// Failure modes (= each is a single
    /// `if` so adding a new one is a
    /// one-line change):
    /// 1. Empty / whitespace-only title
    ///    (= the LLM returned "" or
    ///    just spaces; = we already
    ///    handled this in the
    ///    `parsed.title.isEmpty` check;
    ///    = now we also reject
    ///    whitespace-only).
    /// 2. Title contains a path
    ///    separator (`/` or `\`) (= the
    ///    LLM copied a path; = the
    ///    user's "目录树当名字" bug
    ///    returns).
    /// 3. Title ends with a file
    ///    extension (= `.md` / `.txt`
    ///    / ...; = the LLM copied a
    ///    filename verbatim).
    /// 4. Title is the same string as
    ///    the source file's full path
    ///    (= the LLM copied
    ///    `input.filePath`; = the
    ///    round-31 failure mode; = we
    ///    now reject it explicitly).
    /// 5. Title is the same string as
    ///    the source file's `lastPathComponent`
    ///    (= the LLM copied the
    ///    filename including `.md`; =
    ///    the round-31 failure mode
    ///    catches the extension strip
    ///    but not the bare
    ///    `lastPathComponent`).
    /// 6. Title length > 50 chars (= the
    ///    LLM likely copied a body
    ///    fragment; = not a real
    ///    title).
    /// 7. Title is mostly digits / spaces
    ///    / punctuation (= the LLM
    ///    returned gibberish; = not a
    ///    real title).
    ///
    /// Note: the LLM can still return a
    /// real, valid title that just
    /// happens to share a character with
    /// a path (= e.g. "冰箱/冷柜 史话"
    /// with a slash; = rejected).
    /// That's the trade-off boss accepted
    /// in round-37 (= "不能用提示词控
    /// 制" = programmatic guarantee
    /// beats LLM trust; = titles that
    /// contain a slash get the
    /// fallback; = the user can rename
    /// the file if the title really
    /// needs a slash).
    static func sanitizeTitle(
        _ candidate: String,
        from filePath: String
    ) -> String? {
        // 1. Empty / whitespace-only.
        let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        // 2. Path separator (= "/"
        // or "\") in the title.
        if candidate.contains("/") || candidate.contains("\\") {
            return nil
        }
        // 3. File extension at the end
        // (= .md / .txt / .markdown /
        // .docx ...). The LLM should
        // strip the extension itself
        // (= the title is the human
        // name of the entity, not the
        // filename).
        let knownExtensions: Set<String> = [
            "md", "markdown", "txt", "text",
            "docx", "doc", "pdf", "rtf",
            "html", "htm"
        ]
        let lower = candidate.lowercased()
        for ext in knownExtensions {
            if lower.hasSuffix("." + ext) {
                return nil
            }
        }
        // 4. Title equals the full
        // source path (= LLM copied
        // `input.filePath`).
        if candidate == filePath { return nil }
        // 5. Title equals the source
        // file's lastPathComponent (= the
        // LLM copied the filename
        // including its extension; = the
        // user wants the
        // extension-stripped form).
        let fileName = (filePath as NSString).lastPathComponent
        if candidate == fileName { return nil }
        // 6. Title too long (= not a
        // real title).
        if candidate.count > 50 { return nil }
        // 7. Mostly digits / spaces /
        // punctuation (= gibberish).
        let alnumCount = candidate.unicodeScalars.filter { scalar in
            CharacterSet.alphanumerics.contains(scalar)
        }.count
        if Double(alnumCount) / Double(max(candidate.count, 1)) < 0.3 {
            return nil
        }
        // 8. Path-prefix match (= the
        // title starts with the user's
        // home directory path or any
        // system-known long directory;
        // = the LLM copied a partial
        // path; = catch the case where
        // the LLM truncated the path
        // but still left enough
        // characters to be a giveaway).
        let homeDir = NSHomeDirectory()
        if !homeDir.isEmpty, candidate.hasPrefix(homeDir) {
            return nil
        }
        // All checks pass; = return the
        // trimmed candidate (= the
        // surrounding whitespace, if
        // any, is stripped).
        return trimmed
    }

    /// v2.7 (= boss 2026-10-09 round-20
    /// "反链不用保留，我们的关系链应该有
    /// 其它的功能" directive; = Obsidian
    /// wikilinks = `[[目标]]` 形式 + plain
    /// relative paths = `../路径` 形式; =
    /// after import these become dead
    /// links in the .ws library; = the
    /// canonical wenshu relation feature
    /// (= the sidebar's linkgraph =
    /// "关系链") is a different surface
    /// that should be derived from
    /// explicit metadata, NOT Obsidian
    /// autolinks; = strip both shapes so
    /// the rewritten body never carries
    /// Obsidian-era link cruft).
    ///
    /// The boss 2026-10-09 round-23 follow-up
    /// (= "而且内部反链在重写的时候
    /// 没有删"; = the previous version
    /// only stripped lines that START with
    /// `../` or `[[`; = Obsidian reverse-
    /// link lines look like:
    ///   `反链:`
    ///   `  - ../../08-3 大类实体/03-物件/物件`
    /// = the inner `../` is NOT at line
    /// start; = the previous matcher
    /// missed it). Fix: use a regex-based
    /// filter that drops any line
    /// containing `../`, `/../`, or
    /// `[[...]]` (= matches every Obsidian
    /// relative-path form regardless of
    /// where it appears in the line; = also
    /// matches wikilink fragments inside
    /// prose, not just at line start).
    static func stripObsidianBacklinks(_ body: String) -> String {
        var stripped: [String] = []
        for line in body.split(separator: "\n", omittingEmptySubsequences: false) {
            let lineStr = String(line)
            let trimmed = lineStr.trimmingCharacters(in: .whitespaces)
            // Drop any line containing a relative
            // upward path (= "../" or "/../"; =
            // catches "- ../../x" / "  ../x" /
            // "[text](../../x)" etc.; = the
            // Obsidian relative-link family).
            if lineStr.contains("../") { continue }
            // Drop any line containing a wikilink
            // fragment (= "[[...]]"; = the
            // Obsidian autolink form).
            if lineStr.contains("[[") { continue }
            // Drop Obsidian-era metadata markers
            // (= boss 2026-10-09 round-24
            // "原来的一些没有用的格式能不
            // 留也不留"; = the .ws library
            // already has `createdAt` /
            // `updatedAt` / `tags` fields; =
            // these lines are noise; = match
            // by prefix on the trimmed line).
            if Self.isUselessMetadataLine(trimmed) {
                continue
            }
            // Drop the "反链:" / "反链 :" header
            // line too (= once we've stripped all
            // the links underneath, the header
            // becomes a dangling marker; = the
            // canonical wenshu "关系链" feature
            // will own this concept; = this line
            // is the Obsidian-era marker).
            if trimmed == "反链" || trimmed == "反链:" || trimmed == "反链 :" {
                continue
            }
            stripped.append(lineStr)
        }
        return stripped.joined(separator: "\n")
    }

    /// v2.7 (= boss 2026-10-09 round-25) = the
    /// .ws reference-library doc header has
    /// exactly 3 required frontmatter lines
    /// (= boss 2026-10-09 round-25 "盘点文枢
    /// 的功能，做出文枢的头部格式" directive;
    /// = the canonical wenshu reference doc
    /// header). Anything that looks like the
    /// OLD pre-v2.7 template (= 类型 / 状态 /
    /// 核心信息 / 详细描述 / 反链 / 上次更新 /
    /// tags / 标签 / author / source / created /
    /// modified / ../ / [[ ]]) is dropped here.
    ///
    /// Match by prefix on the trimmed line.
    /// Each case is the canonical prefix a
    /// source file might use (= Chinese +
    /// English; = the canonical wenshu .md
    /// body never has these).
    private static func isUselessMetadataLine(_ trimmed: String) -> Bool {
        let prefixes: [String] = [
            // The old pre-v2.7 template (= 老板
            // 2026-10-09 round-25 "不要参考
            // MD 的格式，而是盘点文枢的功
            // 能，做出文枢的头部格式" = strip
            // the old template; = the new
            // template uses 实体类型/标签/摘
            // 要 only).
            "类型:",
            "类型 :",
            "状态:",
            "状态 :",
            "核心信息:",
            "核心信息 :",
            "核心:",
            "核心 :",
            "详细描述:",
            "详细描述 :",
            "实体化:",
            "实体化 :",
            // Timestamps (= entities.json has
            // createdAt / updatedAt already).
            "上次更新:",
            "上次更新 :",
            "更新于",
            "创建时间:",
            "创建时间 :",
            "创建于",
            "updated:",
            "updated :",
            "created:",
            "created :",
            "modified:",
            "modified :",
            // Tags (= tags are a separate field
            // in the Reference struct).
            "tags:",
            "tags :",
            "tag:",
            "tag :",
            "标签:",
            "标签 :",
            "tags",
            "tag",
            "标签",
            // Author / source markers (= the
            // .ws Reference struct has a `source`
            // field; = author markers are
            // duplicated if they appear in the
            // body).
            "作者:",
            "作者 :",
            "author:",
            "author :",
            "来源:",
            "来源 :",
            "source:",
            "source :",
        ]
        let lower = trimmed.lowercased()
        for p in prefixes {
            if lower.hasPrefix(p.lowercased()) { return true }
        }
        return false
    }

    /// v2.7 round-37 (= boss 2026-10-10 "我觉
    /// 的那个名字的问题，不能用提示词控
    /// 制，应该是程序化控制，不能出错"
    /// directive). The LLM-supplied title
    /// is NOT trusted as-is (= the LLM
    /// can echo the file path, the
    /// filename, an extension, a body
    /// fragment, or gibberish; = the
    /// "目录树当名字" bug surfaced
    /// repeatedly). The programmatic
    /// `sanitizeTitle` check runs FIRST
    /// (= any of the 8 failure modes
    /// below returns nil = we use
    /// `fallbackTitle` instead; = the
    /// user sees a clean filename-based
    /// title regardless of what the LLM
    /// did; = programmatic guarantee
    /// beats LLM trust).
    ///
    /// The flow (= boss round-37 spec):
    /// 1. `parsed.title` (= the LLM's
    ///    answer).
    /// 2. \`Self.sanitizeTitle(parsed.title,
    ///    from: filePath)\` returns
    ///    `String?` (= nil = any of the
    ///    8 failure modes hit; = use
    ///    `fallbackTitle`).
    /// 3. The accepted title is trimmed
    ///    (= sanitizeTitle returns the
    ///    trimmed form).
    /// 4. The fallback path
    ///    (`fallbackTitle`) is the
    ///    filename without extension
    ///    (= guaranteed clean).
    ///
    /// `static` (= `parseAndMap` is a
    /// static method on the actor; = the
    /// title sanitizer doesn't need any
    /// actor state; = calling
    /// `Self.sanitizeTitle` keeps the
    /// call site free of `self`).
    private static func acceptTitle(parsed: ImportDecision, filePath: String) -> String {
        if let sanitized = Self.sanitizeTitle(parsed.title, from: filePath) {
            return sanitized
        }
        return Self.fallbackTitle(from: filePath)
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
    ///
    /// Boss 2026-10-09 round-23 follow-up: even after
    /// the prompt rewrite (= the LLM should now
    /// produce a single-line JSON; = with escaped
    /// `\n` for newlines inside string values; =
    /// the parser should be tolerant of either form;
    /// = the previous version bailed on the first
    /// unescaped quote inside a string value; = the
    /// round-23 observation was "cards showed the
    /// source path as the title" = the parser bailed
    /// on the LLM's response = the orchestrator
    /// synthesized the fallback envelope). The fix
    /// here: also accept the LLM's literal-newline
    /// form (= replace literal newlines with `\\n`
    /// inside what looks like a string value; = makes
    /// the parser tolerant of either JSON-correct
    /// or "markdown-style" JSON output).
    private static func extractFirstJSONObject(_ raw: String) -> String? {
        guard let firstBrace = raw.firstIndex(of: "{") else { return nil }
        var depth = 0
        var inString = false
        var escape = false
        var sanitized = ""
        for i in raw[firstBrace...].indices {
            let c = raw[i]
            if escape { escape = false; sanitized.append(c); continue }
            if c == "\\" { escape = true; sanitized.append(c); continue }
            if c == "\"" { inString.toggle(); sanitized.append(c); continue }
            if inString {
                // The LLM may have inserted literal
                // newlines inside a string value
                // (= the prompt now forbids this; =
                // older runs or misbehaving models
                // may still produce this form). Convert
                // any literal newline inside a string
                // value to the JSON-escaped `\n` so
                // the rest of the parse can succeed.
                if c == "\n" {
                    sanitized.append("\\n")
                } else if c == "\r" {
                    // Skip CR; = the \n already handled the
                    // line break.
                } else {
                    sanitized.append(c)
                }
                continue
            }
            if c == "{" { depth += 1 }
            if c == "}" {
                depth -= 1
                if depth == 0 {
                    sanitized.append(c)
                    return sanitized
                }
            }
            sanitized.append(c)
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
        let rewrittenBody: String? = rawRewritten.isEmpty ? nil : Self.stripObsidianBacklinks(rawRewritten)
        // v2.7 tag cap (= boss 2026-10-09 round-20
        // "限制资料库文档的标签数量，要最有
        // 用的，只能有 3 个标签" directive; =
        // the LLM was instructed to emit ≤ 3
        // tags; = this is the last-mile cap
        // (= the LLM may emit 4 or 5 if it
        // ignored the prompt; = the cap is
        // here as the canonical gate; = the
        // sidebar tag facet remains
        // navigable).
        let cappedTags = Array(tags.prefix(3))
        // v2.7 (= boss 2026-10-09 round-28
        // "标签不可以与标题重名" directive; =
        // a tag identical to the title is
        // redundant (= the title is the
        // canonical name; = the tag is a
        // navigation facet; = having both
        // is duplicate metadata that
        // clutters the card view AND breaks
        // the v2.6 tag-based filter (= the
        // user clicks the tag to find
        // everything related; = the entity
        // that has the title as a tag
        // always shows up for that tag; =
        // the redundancy is the same as no
        // tag at all)). The LLM was
        // instructed to avoid title-as-tag;
        // this is the last-mile filter that
        // drops it if the LLM still emitted
        // it. Comparison is case- and
        // whitespace-insensitive (= the LLM
        // might emit "活字印刷" as title and
        // " 活字印刷 " as a tag).
        let titleNorm = title.trimmingCharacters(in: .whitespacesAndNewlines)
        // v2.7 (= boss 2026-10-09 round-29
        // "标签不可以带标点" directive; = the
        // sidebar tag facet is a navigation
        // filter (= the user clicks a tag to
        // see every reference carrying that
        // tag); = punctuation in a tag breaks
        // the facet UX (= "民俗神-A民俗神"
        // parses as one opaque tag; = "民俗
        // 神" parses as the same tag with a
        // leading space; = the LLM is
        // sometimes emitting tags like
        // "民俗神-A喜丧" (= entityType
        // codes) or "考古报告, 民俗" (= the
        // comma is meant to be a tag
        // separator that the LLM put inside
        // one tag); = these don't match the
        // user's mental model of "tag = a
        // short, single-token Chinese
        // word"). Drop any tag containing
        // punctuation (= ASCII punctuation +
        // common CJK punctuation; = the
        // remaining tag is letters and digits
        // only; = the LLM was instructed to
        // emit single-word tags without
        // punctuation; = the last-mile filter
        // matches the user expectation).
        let dedupedTags = cappedTags.compactMap { tag -> String? in
            let trimmedTag = tag.trimmingCharacters(in: .whitespacesAndNewlines)
            // Drop empties.
            if trimmedTag.isEmpty { return nil }
            // Drop title-match (= round-28).
            if trimmedTag == titleNorm { return nil }
            // Drop any tag containing punctuation
            // (= the canonical wenshu tag is a
            // short single-token word like "民
            // 俗神" / "唐朝" / "阎罗" / "印
            // 度"; = punctuation in a tag is
            // always an LLM error; = drop it
            // silently; = the user gets fewer
            // tags but every tag is meaningful).
            if Self.tagContainsPunctuation(trimmedTag) {
                return nil
            }
            return trimmedTag
        }
        return ImportDecision(
            title: title,
            summary: summary,
            tags: dedupedTags,
            destination: destination,
            bookFolder: bookFolder,
            rewrittenBody: rewrittenBody
        )
    }

    /// v2.7 (= boss 2026-10-09 round-29) = a
    /// tag that contains any non-letter / non-
    /// digit / non-CJK character is treated as
    /// punctuation (= the LLM sometimes emits
    /// `,` to separate what should be two
    /// tags, or `()` to wrap a parenthetical
    /// that snuck in; = the wenshu tag facet is
    /// a navigation filter; = the user can
    /// only navigate to a tag that matches a
    /// real entity; = punctuation breaks the
    /// facet match).
    ///
    /// "Punctuation" here = anything that is
    /// not a Unicode letter, digit, or CJK
    /// character. CJK Unified Ideographs (= the
    /// U+4E00..U+9FFF block + extensions) are
    /// all valid tag characters. CJK
    /// punctuation blocks (= U+3000..U+303F
    /// "CJK Symbols and Punctuation", U+FF00
    /// "Halfwidth and Fullwidth Forms", U+FE30
    /// "CJK Compatibility Forms") are dropped.
    /// ASCII punctuation (= `,` / `.` / `-` /
    /// `:` / `(` / `)` / `/` / `'` / `"` /
    /// `[` / `]`) is dropped. Whitespace and
    /// underscore are also dropped (= the tag
    /// facet matches on the canonical string;
    /// = the user never types spaces or
    /// underscores when navigating).
    private static func tagContainsPunctuation(_ tag: String) -> Bool {
        // Pre-resolve the underscore scalar (= the
        // `Unicode.Scalar == String` overload doesn't
        // exist; = the comparison is scalar-to-scalar).
        let underscore: Unicode.Scalar = "_"
        for scalar in tag.unicodeScalars {
            // ASCII letters / digits: keep (= use
            // the scalar's `properties` set; =
            // `Unicode.Scalar` has no `.isLetter`
            // / `.isNumber` member directly; =
            // those members live on `Character`).
            if scalar.isASCII {
                let p = scalar.properties
                if p.isASCIIHexDigit || (scalar.value >= 0x41 && scalar.value <= 0x5A)
                    || (scalar.value >= 0x61 && scalar.value <= 0x7A)
                    || (scalar.value >= 0x30 && scalar.value <= 0x39) {
                    continue
                }
            }
            // ASCII underscore: drop (= the
            // user wouldn't navigate to a
            // tag with an underscore in it).
            if scalar == underscore { return true }
            // CJK Unified Ideographs and
            // extensions: keep. CJK
            // Compatibility Ideographs
            // (U+F900..U+FAFF): keep.
            let v = scalar.value
            if (0x4E00...0x9FFF).contains(v)       // CJK Unified
                || (0x3400...0x4DBF).contains(v)   // CJK Ext A
                || (0x20000...0x2A6DF).contains(v) // CJK Ext B
                || (0x2A700...0x2B73F).contains(v) // CJK Ext C
                || (0x2B740...0x2B81F).contains(v) // CJK Ext D
                || (0xF900...0xFAFF).contains(v)   // CJK Compat
                || (0x2F800...0x2FA1F).contains(v) // CJK Compat Suppl
            {
                continue
            }
            // Everything else (= ASCII
            // punctuation, CJK punctuation,
            // whitespace, control chars, emoji,
            // symbols) is rejected.
            return true
        }
        return false
    }
}
