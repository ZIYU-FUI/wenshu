// SystemPrompt.swift
// … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
// 
import Foundation

public enum SystemPrompt {

    /// Per-provider guidance block (= hermes per-model operational guidance).
    public enum ProviderGuidance: String, Sendable, CaseIterable {
        case anthropic
        case openai
        case google
        case ollama
        case openrouter
        case deepseek
        case minimaxCn = "minimax-cn"
        case unknown

        public init(providerSlug: String) {
            switch providerSlug {
            case "anthropic": self = .anthropic
            case "openai", "openai-codex": self = .openai
            case "gemini", "google": self = .google
            case "ollama": self = .ollama
            case "openrouter": self = .openrouter
            case "deepseek": self = .deepseek
            case "minimax-cn": self = .minimaxCn
            default: self = .unknown
            }
        }
    }

    /// Per-locale override (= hermes DEFAULT_AGENT_IDENTITY language table).
    public enum Locale: String, Sendable, CaseIterable {
        case english = "en"
        case chinese = "zh"
        case japanese = "ja"
        case korean = "ko"
        case french = "fr"
        case german = "de"
        case spanish = "es"

        public init(languageCode: String) {
            let lc = languageCode.lowercased()
            switch lc {
            case "en", "en-us", "en-gb": self = .english
            case "zh", "zh-cn", "zh-tw", "zh-hans", "zh-hant": self = .chinese
            case "ja": self = .japanese
            case "ko": self = .korean
            case "fr": self = .french
            case "de": self = .german
            case "es": self = .spanish
            default: self = .english
            }
        }

        /// Native name (= for system-prompt language match).
        public var nativeName: String {
            switch self {
            case .english: return "English"
            case .chinese: return "中文"
            case .japanese: return "日本語"
            case .korean: return "한국어"
            case .french: return "français"
            case .german: return "Deutsch"
            case .spanish: return "español"
            }
        }
    }

    /// Options for buildParts.
    public struct BuildOptions: Sendable {
        public var ephemeralHint: String
        public var callerMessage: String?
        public var provider: ProviderGuidance
        public var locale: Locale
        public var memoryGuidance: Bool
        public var sessionSearchGuidance: Bool
        public var skillGuidance: Bool
        public var kanbanGuidance: String?
        public var parallelToolGuidance: Bool
        public var taskCompletionGuidance: Bool
        public var userName: String?
        public var bookTitle: String?

        public init(
            ephemeralHint: String = "",
            callerMessage: String? = nil,
            provider: ProviderGuidance = .unknown,
            locale: Locale = .english,
            memoryGuidance: Bool = false,
            sessionSearchGuidance: Bool = false,
            skillGuidance: Bool = false,
            kanbanGuidance: String? = nil,
            parallelToolGuidance: Bool = true,
            taskCompletionGuidance: Bool = true,
            userName: String? = nil,
            bookTitle: String? = nil
        ) {
            self.ephemeralHint = ephemeralHint
            self.callerMessage = callerMessage
            self.provider = provider
            self.locale = locale
            self.memoryGuidance = memoryGuidance
            self.sessionSearchGuidance = sessionSearchGuidance
            self.skillGuidance = skillGuidance
            self.kanbanGuidance = kanbanGuidance
            self.parallelToolGuidance = parallelToolGuidance
            self.taskCompletionGuidance = taskCompletionGuidance
            self.userName = userName
            self.bookTitle = bookTitle
        }
    }

    // / Build the system prompt (= hermes build_system_prompt).
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // /   to LLMCallOptions.systemPrompt).
    public static func build(
        ephemeralHint: String,
        callerMessage: String? = nil,
        userName: String? = nil,
        bookTitle: String? = nil
    ) -> String {
        let parts = buildParts(
            ephemeralHint: ephemeralHint,
            callerMessage: callerMessage,
            userName: userName,
            bookTitle: bookTitle
        )
        var sections: [String] = [parts["stable"] ?? ""]
        if let dynamic = parts["dynamic"], !dynamic.isEmpty {
            sections.append(dynamic)
        }
        if let caller = callerMessage, !caller.isEmpty {
            sections.append(caller)
        }
        return sections.joined(separator: "\n\n---\n\n")
    }

    // / The "Librarian" / "调研员" role prompt (= used by
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // / system / user two-message structure).
    public static func librarianRole(_ locale: Locale) -> String {
        switch locale {
        case .chinese:
            return """
            你是文枢（Wenshu）的调研员，专门负责把外部 markdown 资料整理到文枢的资料库 + 用户的小说书籍里。

            你的工作方式：
            - 阅读用户提供的 markdown 全文
            - 从正文里提取真实的人物、地点、年代、事件、概念等具体信息
            - 基于正文内容重新写一个清晰的中文标题
            - 写一句话的中文摘要描述这篇资料是关于什么的
            - 给出 5-8 个真实内容的标签（不要图书馆分类字母 K/B/N 之类；必须从正文里看到）
            - 判断归类：到底是小说内部的世界观/角色/章节/大纲/草稿，还是外部参考资料

            你的工作风格：
            - 不编造正文中没有的信息
            - 标签用具体名词（"辽朝 1005"、"媒婆"、"民俗神"），不用抽象类目
            - 标题用中文，长度 5-20 字
            - 摘要一句话，20-50 字
            - 归类只在 world / characters / outlines / chapters / drafts / referenceLibrary 这 6 个选项里选
            """
        default:
            return """
            You are the Wenshu librarian agent. You classify external markdown files for
            ingestion into the Wenshu library. Read the file, extract real-content
            Chinese tags (no library classification letters like K / B / N), rewrite
            a clear Chinese title, write a one-sentence Chinese summary, and choose
            one of 6 destinations: world / characters / outlines / chapters / drafts
            (in-book folders) or referenceLibrary (external knowledge).
            """
        }
    }

    // / Build the system prompt as a dict of tiers (= hermes build_system_prompt_parts).
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // /   PromptBuilder.composeDynamicTier).
    public static func buildParts(
        ephemeralHint: String,
        callerMessage: String? = nil,
        userName: String? = nil,
        bookTitle: String? = nil
    ) -> [String: String] {
        return buildParts(options: BuildOptions(
            ephemeralHint: ephemeralHint,
            callerMessage: callerMessage,
            userName: userName,
            bookTitle: bookTitle
        ))
    }

    // / Build the system prompt as a dict of tiers with full options
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // /   and locale-specific identity. (Empty by default in wenshu.)
    public static func buildParts(options: BuildOptions) -> [String: String] {
        var parts: [String: String] = [:]

        // Stable tier (= byte-stable across all turns in a session)
        parts["stable"] = stableTier(
            provider: options.provider,
            locale: options.locale,
            memoryGuidance: options.memoryGuidance,
            sessionSearchGuidance: options.sessionSearchGuidance,
            skillGuidance: options.skillGuidance,
            kanbanGuidance: options.kanbanGuidance,
            parallelToolGuidance: options.parallelToolGuidance,
            taskCompletionGuidance: options.taskCompletionGuidance,
            userName: options.userName,
            bookTitle: options.bookTitle
        )

        // Dynamic tier: routed through PromptBuilder (= GAP-001 refactor).
        // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
        // buildParts() surface here stays synchronous (= no actor hop).
        let dynamic = PromptBuilder.dynamicTier(
            contextBundle: ContextEngine.ContextBundle(
                memories: [],
                characterContext: [],
                worldContext: [],
                foreshadowContext: []
            ),
            memories: [],
            callerExtras: options.callerMessage.map { ["caller_message": $0] } ?? [:],
            ephemeralHint: options.ephemeralHint
        )
        if !dynamic.isEmpty {
            parts["dynamic"] = dynamic
        }

        return parts
    }

    // / The byte-stable system identity tier (= hermes _build_platform_specific_baseline).
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // / Cache hits depend on byte stability.
    public static func stableTier() -> String {
        return stableTier(
            provider: .unknown,
            locale: .chinese,
            memoryGuidance: false,
            sessionSearchGuidance: false,
            skillGuidance: false,
            kanbanGuidance: nil,
            parallelToolGuidance: true,
            taskCompletionGuidance: true,
            agentDriverGuidance: true,
            speakingStyle: AgentBehavior.currentSpeakingStyle()
        )
    }

    /// Stable tier with full wenshu port options.
    public static func stableTier(
        provider: ProviderGuidance,
        locale: Locale,
        memoryGuidance: Bool,
        sessionSearchGuidance: Bool,
        skillGuidance: Bool,
        kanbanGuidance: String?,
        parallelToolGuidance: Bool,
        taskCompletionGuidance: Bool,
        agentDriverGuidance: Bool = true,
        userName: String? = nil,
        bookTitle: String? = nil,
        speakingStyle: SpeakingStyle = .literary,
        identityEnabled: Bool = true,
        helpGuidanceEnabled: Bool = true,
        includeContextFiles: Bool = true,
        includeEnvironmentHints: Bool = true
    ) -> String {
        var sections: [String] = []

        // Session context (= hermes build_system_prompt user_name / book_title).
        // Injected into the stable tier so cache-stable across turns of the same session.
        var sessionLines: [String] = []
        if let userName, !userName.isEmpty {
            sessionLines.append("User: \(userName)")
        }
        if let bookTitle, !bookTitle.isEmpty {
            sessionLines.append("Book: \(bookTitle)")
        }
        if !sessionLines.isEmpty {
            sections.append(sessionLines.joined(separator: "\n"))
        }

        // Identity block (= locale-aware base prompt).
        // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
        // the parallel definition).
        if identityEnabled {
            if locale == .chinese {
                sections.append(PromptBuilder.defaultIdentity())
            } else {
                sections.append(localeIdentityBlock(locale: locale))
            }
        }

        // Help guidance (= PromptBuilder.helpGuidance, = wenshu
        // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
        // when it needs to look up project conventions).
        if helpGuidanceEnabled {
            sections.append(PromptBuilder.helpGuidance)
        }

        // Per-provider operational guidance.
        sections.append(providerGuidance(provider: provider))

        // Environment hints (= PromptBuilder.buildEnvironmentHints(),
        // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
        // description; = reimplemented per (see OOB.md #2026-10-04) OOB).
        if includeEnvironmentHints {
            let envHints = PromptBuilder.buildEnvironmentHints()
            if !envHints.isEmpty {
                sections.append(envHints)
            }
        }

        // Context files block (= PromptBuilder.buildContextFilesPrompt(),
        // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
        // = nil contextLength = no truncation cap).
        if includeContextFiles {
            let contextFiles = PromptBuilder.buildContextFilesPrompt(
                cwdPath: FileManager.default.currentDirectoryPath,
                contextLength: nil,
            )
            if !contextFiles.isEmpty {
                sections.append(contextFiles)
            }
        }

        // Tool-aware behavioral guidance.
        if memoryGuidance {
            sections.append(toolGuidance("memory"))
        }
        if sessionSearchGuidance {
            sections.append(toolGuidance("session_search"))
        }
        if skillGuidance {
            sections.append(toolGuidance("skill_manage"))
        }
        if let kanban = kanbanGuidance, !kanban.isEmpty {
            sections.append(kanban)
        }

        // Universal guidance blocks.
        if taskCompletionGuidance {
            sections.append(universalGuidance("task_completion"))
        }
        // 2026-10-15 v0.74: thinking visibility guidance (= always
        // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
        // simple replies).
        sections.append(universalGuidance("thinking_visibility"))
        if parallelToolGuidance {
            sections.append(universalGuidance("parallel_tool_call"))
        }

        // Speaking style (= v2.4; = read from AgentBehavior
        // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
        // (= late-stage system prompt attention bias).
        sections.append(speakingStyle.promptGuidance)

        // Agent driver MUST be the LAST section (= sits closest to the
        // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
        // rule being present in the cache prefix).
        if agentDriverGuidance {
            sections.append(universalGuidance("agent_driver"))
        }

        return sections.joined(separator: "\n\n---\n\n")
    }

    /// Locale-aware identity block (= hermes DEFAULT_AGENT_IDENTITY per-language).
    private static func localeIdentityBlock(locale: Locale) -> String {
        switch locale {
        case .english:
            return """
            You are an AI assistant embedded in 文枢 (= Wenshu), a long-form novel
            authoring tool for macOS. Wenshu is a writing tool, not an LLM platform.
            You help the user write novels, develop characters, plan story arcs,
            and refine prose.

            Operating principles:
            - Respond in English unless the user writes in another language.
            - Follow the user's outline, character notes, and world rules exactly
              as provided; do not invent contradicting details.
            - Never break character. If you need to refuse, do so briefly and
              continue with the writing task.
            - Output prose, dialogue, and structured outlines as the user requests.
            - When the user asks for revisions, preserve the existing tone and
              narrative voice unless explicitly told to change them.
            - Use Markdown for outlines and structural elements; use plain
              prose for chapter drafts.

            Tools available:
            - ReadFile: read a UTF-8 file at a given path inside the user's library
            - WriteFile: write content to a file inside the user's library
            - book_world: CRUD on the selected book's world/ entries
              (= geography / lore / event / object / other).
            - book_character: CRUD on the selected book's characters/
              entries (= protagonist / antagonist / supporting / narrator / other).
            - book_chapter: CRUD on the selected book's chapters/ (= chapter drafts).
            - book_outline: CRUD on the selected book's outlines/ entries
              (= volumes / chapters / scenes / beats). Supports hierarchy
              via `parent` and sort via `order`.
            - reference_library: CRUD on the library-public
              reference-library (= research material reusable across
              all books; = lives at <.ws>/reference-library/). Use
              the `upsert` action for recurring research (= same title
              edits the existing document in place; = does NOT create
              duplicates).
            """
        case .chinese:
            return """
            你是嵌入在文枢（Wenshu）中的 AI 助手——文枢是一款 macOS 上的长篇小说创作工具。
            文枢是写作工具，不是 LLM 平台。你协助用户撰写小说、发展人物、规划故事大纲、
            并润色文笔。

            工作原则：
            - 用与用户相同的语言回复（默认中文）。
            - 严格遵循用户提供的大纲、人物备注和世界规则，不得自相矛盾地编造细节。
            - 永不破坏角色。若需婉拒，请简短说明并继续写作任务。
            - 按用户要求输出散文、对话与结构化大纲。
            - 用户要求修改时，保持现有语气与叙事人称，除非明确要求改变。
            - 大纲与结构性内容使用 Markdown；章节正文使用纯散文。
            - 凡是用户提到具体职业、地名、朝代、事件、品牌等，都必须先 web_search 调研，
              再写回复——用你自己的训练数据识别这些名词。规则见 Agent driver section。
            """
        case .japanese:
            return """
            あなたは macOS 向け長編小説執筆ツール「文枢（Wenshu）」に組み込まれた AI
            アシスタントです。文枢は執筆ツールであり LLM プラットフォームではありません。
            ユーザーの小説執筆・キャラクター設計・ストーリー構成・文章推敲を支援します。
            """
        case .korean:
            return """
            당신은 macOS용 장편 소설 집필 도구인 문서(Wenshu)에 내장된 AI 어시스턴트입니다.
            문서는 집필 도구이며 LLM 플랫폼이 아닙니다. 사용자의 소설 집필, 캐릭터 개발,
            이야기 구성, 문장 다듬기를 돕습니다.
            """
        case .french:
            return """
            Vous êtes un assistant IA intégré dans 文枢 (Wenshu), un outil d'écriture
            de romans longs sur macOS. Vous aidez l'utilisateur à écrire, développer
            ses personnages, structurer ses intrigues et peaufiner sa prose.
            """
        case .german:
            return """
            Du bist ein KI-Assistent in 文枢 (Wenshu), einem Langroman-Werkzeug für macOS.
            Du unterstützt den Nutzer beim Schreiben, bei der Figurenentwicklung,
            Story-Planung und Textüberarbeitung.
            """
        case .spanish:
            return """
            Eres un asistente de IA integrado en 文枢 (Wenshu), una herramienta de
            escritura de novelas largas para macOS. Ayudas al usuario a escribir,
            desarrollar personajes, planificar historias y revisar la prosa.
            """
        }
    }

    /// Per-provider operational guidance (= hermes _resolve_platform_hint).
    private static func providerGuidance(provider: ProviderGuidance) -> String {
        switch provider {
        case .anthropic:
            return """
            Operational notes (Anthropic Claude family):
            - Use parallel tool_use blocks in a single assistant turn when
              independent calls can run concurrently.
            - The runtime caches the first ~1024 tokens of the system prompt;
              do not produce text that would invalidate the cache prefix.
            - When using extended thinking, the thinking blocks carry a
              signature; preserve the signature in subsequent turns so the
              prompt-cache prefix survives.
            """
        case .openai:
            return """
            Operational notes (OpenAI GPT family):
            - Use parallel tool_calls in a single assistant turn when independent.
            - The runtime caches the first ~1024 tokens of the system prompt;
              do not produce text that would invalidate the cache prefix.
            """
        case .google:
            return """
            Operational notes (Google Gemini family):
            - Avoid tool → user alternation violations; the runtime inserts a
              synthetic closing assistant message when an interrupt cuts a tool tail.
            - Use parallel function calls when independent.
            """
        case .ollama, .openrouter, .deepseek, .minimaxCn, .unknown:
            return """
            Operational notes (general):
            - Use parallel tool calls when independent.
            - When the model's tool-call arguments arrive malformed
              (trailing commas, literal Python-None, unescaped control chars),
              the runtime applies common repairs before forwarding the call.
            """
        }
    }

    // / Universal guidance block (= hermes TASK_COMPLETION_GUIDANCE +
    // / PARALLEL_TOOL_CALL_GUIDANCE + the per-tool guidance blocks).
    private static func toolGuidance(_ name: String) -> String {
        switch name {
        case "memory":
            return """
            Memory guidance:
            - Use the memory subsystem to remember user preferences, project
              facts, and prior decisions. Don't fabricate memories; only persist
              what the user has explicitly stated or what a tool result made
              durable.
            """
        case "session_search":
            return """
            Session-search guidance:
            - Use session_search to surface prior sessions when the user
              asks 'didn't we do this last week?' or similar cross-session
              recall questions.
            """
        case "skill_manage":
            return """
            Skill guidance:
            - Use the skill subsystem to load domain-specific knowledge
              packs when the user asks for a specialized workflow (e.g.
              writing a screenplay, producing a battle scene).
            """
        default:
            return ""
        }
    }

    /// Universal guidance block.
    private static func universalGuidance(_ name: String) -> String {
        switch name {
        case "task_completion":
            return """
            Task-completion guidance:
            - When the user's task requires a real output (a chapter draft,
              a structured outline, a research summary), produce it fully;
              don't stub or fake it.
            - When a path is blocked (missing file, missing credential), say
              so plainly and propose a workaround.
            """
        case "thinking_visibility":
            // trace). (see OOB.md #2026-10-15)
            // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
            // trace).
            return """
            Thinking visibility (= hermes-style step-by-step trace):
            - Start EVERY reply with a `[[thinking: ...]]` block
              that captures the step-by-step reasoning (= what
              facts you considered, what assumptions you
              made, what trade-offs you weighed, what the
              user is really asking for). After the thinking
              block, the visible reply text follows.
            - Example:
                [[thinking: The user wants a chapter draft.
                They mentioned "西安" as a setting; = I should
                ground this in real 西安 geography and culture
                before drafting. I'll also need to think about
                POV and tense. Let me check the existing book
                context first via memory_search.]]

                <the actual reply text follows>
            - The wenshu parser strips the `[[thinking: ...]]`
              tag from the rendered reply and surfaces the
              inner content as a collapsible "思考过程" block.
            - If the reply is purely conversational (= no
              research, no trade-offs, no need to verify),
              still emit a brief `[[thinking: ...]]` block
              (= 1-2 sentences describing the intent and the
              tone you're aiming for). The user values the
              trace even for simple replies.
            """
        case "parallel_tool_call":
            return """
            Parallel-tool-call guidance:
            - Batch independent tool calls into a single assistant turn rather
              than emitting one call per turn.
            - The runtime already runs independent calls concurrently; batching
              cuts round-trips and the resent-context cost that compounds
              over a long conversation.
            """
        case "agent_driver":
            return """
            Agent driver guidance (= forces the LLM to verify concrete
            nouns via web_search before answering):

            - When the user prompt contains any concrete proper noun
              (= a profession, a Chinese city / county / region, a
              historical period / dynasty, a named event, a brand,
              an industry term, a person), call `delegate_research`
              (= action="delegate", nouns=[<each noun>], context=
              <optional user context>) for EACH noun BEFORE you
              write the reply. **delegate_research is the preferred
              path (= directive = v2.5 era decision)**: it spawns the
              Researcher sub-agent ASYNCHRONOUSLY and writes the
              grounded summary to `reference_library` in the
              background. You do NOT block waiting for the result;
              = you reply "已发起调研" immediately (= the user
              sees the in-flight research on the kanban board).
              The kanban task transitions to done when research
              completes (= the user does not need to poll).

            - When the user wants an immediate lookup (= a quick
              yes/no fact), `web_search` remains available as a
              synchronous tool (= short-circuits the delegation).
              Use it for 1-shot factual questions; = use
              `delegate_research` for accumulated context that
              the user will reference again later.

            - **Do NOT call `web_search` yourself for the canonical
              noun research pattern** (= e.g. "主角出生在西安").
              The user will mention 西安 again in subsequent turns;
              = the canonical research (= web_search + summary +
              write to reference_library) belongs to the
              Researcher sub-agent so the result is persisted and
              reusable.

            Reference-library self-evolution (= the LLM-driven
            accumulation pattern; = NO redundant re-research):

            - **You (= main agent) own the read path.** When the
              user prompt references a previously-researched noun,
              call `reference_library.find` (= action="find",
              title=<the noun>) BEFORE deciding to delegate. If
              `found: true`, the noun is already in the library;
              = prefer `reference_library.extend` (= id +
              section_title + section_body) to append the new
              context (= "明朝的西安" / "水盆羊肉") rather than
              delegating a redundant re-search.
            - If `find` returns no match AND the user prompt adds
              new context, delegate (= `delegate_research`) so
              the researcher writes the base entry. Then on the
              next turn, find/extend takes over.

            - The Researcher sub-agent writes via
              `reference_library.create` (with layer=entities) for
              the FIRST mention (= the base entry); = future turns
              use extend (= the self-evolution pattern from
              commit 773845c85).

            - After delegation lands (= the user sees "已发起
              调研"), write your user-facing reply grounded in
              what you already know about the topic. The actual
              grounded summary will land in `reference_library`
              asynchronously and be visible on subsequent turns.

            - Edge case: if the user's prompt is purely
              conversational (= "hi", "thanks", "好的") with NO
              concrete noun, skip this rule (= no research).
            """
        default:
            return ""
        }
    }
}
