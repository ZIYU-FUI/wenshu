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
        return """
        请阅读下面的 Markdown 资料，输出一行 JSON 描述如何整理它。

        ## 资料信息
        - 文件路径: \(filePath)
        - 正文:
        \(trimmed)

        ## 任务
        1) 重写一个清晰的中文标题 (= 如果原文已经有 H1，可以基于它改写得更清楚；如果没有，提取正文核心)
        2) 写一句话的中文摘要
        3) 提取 5-8 个真实内容的标签（不要图书馆分类字母 K/B/N 之类；必须是从正文中看到的人物、地点、年代、概念、品牌等真实信息）
        4) 判断归类到哪本书的哪个目录。
           这是最关键的一步 —— 调研 vs 书内设定 有一条非常清晰的界限：

        调研（= referenceLibrary）= 这是**真实世界已经存在的资料**，是小说作者参考用的输入。
           包括：
             - 古代文献原文 / 选段：例如《太平广记》某卷、《夷坚志》某则、《酉阳杂俎》某条、《搜神记》某篇
             - 历史人物 / 神话传说的客观叙述：例如"灶神的起源"、"城隍信仰在唐宋的演变"
             - 现实世界的资料：地方志、考古报告、宗教民俗研究摘录
           这些资料的共同特征 = **它们的存在不依赖任何小说** = 即使把目标小说删掉，这些资料仍然有意义。
           → 全部进 `referenceLibrary`，**不要进任何 book folder**。

        书内设定（= bookFolder，folder ∈ {world, characters, outlines, chapters, drafts}）= 目标小说**自己创造**的内容。
           包括：
             - 世界观：例如目标小说所在朝代表、目标小说的神祇等级体系（不是《封神榜》的通用神祇 = 目标小说的特定设定）
             - 角色：主角/配角的人物卡、出场设定、人物关系图
             - 大纲 / 章节：目标小说的章节大纲、未完成的章节草稿、写作计划
             - 草稿：目标小说的人物对话草稿、场景草稿、随手记下的情节碎片
           这些内容的共同特征 = **它们专属于目标小说** = 把这些内容脱离小说看就没有意义。
           → 进对应的 bookFolder。

        决策流程（按顺序判断）：
          1. 这段文字在脱离目标小说后还有没有独立意义？
              是 → `referenceLibrary`
              否 → 继续
          2. 这是目标小说的哪一类设定？→ world / characters / outlines / chapters / drafts

        ## 输出格式
        严格一行 JSON，不要任何其他文字、解释或 markdown 代码块：
        {"title":"<中文标题>","summary":"<一句话中文摘要>","tags":["<tag1>","<tag2>",...],"destination":"referenceLibrary"}
        或
        {"title":"<中文标题>","summary":"<一句话中文摘要>","tags":["<tag1>","<tag2>",...],"destination":"bookFolder","folder":"<world|characters|outlines|chapters|drafts>"}
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
