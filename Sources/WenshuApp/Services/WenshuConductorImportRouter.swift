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
            body: body
        )
        let options = LLMCallOptions(
            model: modelSlug,
            maxTokens: 2048,
            systemPrompt: SystemPrompt.librarianRole(.chinese),
            temperature: 0.2,
            reasoningEffort: nil,
            tools: []
        )
        // Fire the LLM call. Failures are non-fatal:
        // the orchestrator's per-file try/catch
        // catches the throw and marks the task
        // .failed (= the user sees "失败" in the
        // per-file state strip; = the action button
        // flips to "重试" so they can re-run the
        // failed rows after fixing the LLM config).
        let response = try await connector.send(
            messages: [.user(userPrompt)],
            options: options
        )
        let raw = response.blocks.map(\.textValue).joined()
        return Self.parseAndMap(
            raw: raw,
            body: body,
            fallbackTitle: fallbackTitle,
            filePath: input.filePath
        )
    }

    // MARK: - Prompt + parse

    /// The per-file user prompt (= asks the LLM to
    /// produce a structured JSON object with title /
    /// summary / tags / destination / bookFolder;
    /// = the schema is the only thing the LLM is
    /// allowed to talk about; = a single JSON object
    /// on one line so the parser can grab it
    /// deterministically).
    static func userPrompt(filePath: String, body: String) -> String {
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

        ## 输出格式
        严格一行 JSON，不要任何其他文字、解释或 markdown 代码块：
        {"title":"<中文标题>","summary":"<一句话中文摘要>","tags":["<tag1>","<tag2>",...]}
        """
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
                confidence: 0.0
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
            confidence: parsed.tags.isEmpty ? 0.3 : 0.9
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
                destination: "bookFolder", bookFolder: .drafts
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
        return ImportDecision(
            title: title,
            summary: summary,
            tags: tags,
            destination: destination,
            bookFolder: bookFolder
        )
    }
}
