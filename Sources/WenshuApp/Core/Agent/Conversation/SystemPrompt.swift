//
//  SystemPrompt.swift · Wenshu · v0.35 ticket 002 sub-step 2
//  + TICKET-HERMES-GAP-001 refactor (2026-09-04).
//  + HERMES-PARTIAL-012 (2026-09-04).
//
//  System prompt builder. Direct port of hermes system_prompt.py
//  (= L113-L507, 536 LOC; provides build_system_prompt_parts +
//  build_system_prompt).
//
//  Two-tier architecture (= cache-stable invariant per AGENTS.md §11.3):
//    - Stable tier (= system identity, byte-stable across all turns in a session):
//      who the agent is, what it should always do, language constraints, etc.
//      This is the part that goes through Anthropic prompt caching
//      (= PromptCaching.applyCacheControl places 1st cache_control breakpoint here).
//    - Dynamic tier (= turn-specific, NOT cached): ephemeral context like
//      "today is Tuesday", caller-supplied extra system message, and (post
//      GAP-001) the composition of ContextEngine + MemoryAdapter +
//      SkillAdapter into a single dynamic block.
//
//  HERMES-PARTIAL-012 adds three new public surfaces over the GAP-001 baseline:
//    - Per-provider guidance blocks (= hermes per-model operational
//      guidance: anthropic / openai / google / ollama / openrouter each
//      get model-family-specific tool-use enforcement + parallel-tool
//      call patterns).
//    - Per-locale overrides (= hermes DEFAULT_AGENT_IDENTITY per language
//      = en / zh / ja / ko / fr / de / es; the agent matches the user's
//      UI language).
//    - Dynamic tier resolution (= hermes tier composition: when a fresh
//      ContextBundle or memory snapshot arrives, the dynamic tier rebuilds;
//      otherwise it returns the cached version).
//
//  Invariant: identical inputs → byte-identical output (= cache hit on
//  subsequent calls within the same session).
//
//  v0.35 ticket 002 sub-step 2 of N (= ticket 002 = PromptCaching +
//  SystemPrompt + cache-stable invariants per spec §3.3 + §0.1 A3).
//
//  TICKET-HERMES-GAP-001 refactor (2026-09-04): SystemPrompt is now a thin
//  wrapper around PromptBuilder. The stable-tier identity string stays
//  here (= canonical byte-stable source). The dynamic-tier composition
//  (= ContextEngine + MemoryAdapter + SkillAdapter + caller extras +
//  ephemeral hint) now lives in PromptBuilder.composeDynamicTier.
//  buildParts/build forward to PromptBuilder. Public API preserved for
//  backwards compat (= existing SystemPromptTests + Golden parity tests
//  keep passing).
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
            taskCompletionGuidance: Bool = true
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
        }
    }

    /// Build the byte-stable system prompt (= hermes build_system_prompt).
    ///
    /// - Parameters:
    ///   - ephemeralHint: Per-turn dynamic context (= today's date, user
    ///     request summary, etc.). NOT cache-stable.
    ///   - callerMessage: Optional caller-supplied extra instruction
    ///     (= appended after the stable tier + dynamic tier).
    /// - Returns: Concatenated system prompt string (= ready to be passed
    ///   to LLMCallOptions.systemPrompt).
    public static func build(
        ephemeralHint: String,
        callerMessage: String? = nil
    ) -> String {
        let parts = buildParts(ephemeralHint: ephemeralHint, callerMessage: callerMessage)
        var sections: [String] = [parts["stable"] ?? ""]
        if let dynamic = parts["dynamic"], !dynamic.isEmpty {
            sections.append(dynamic)
        }
        if let caller = callerMessage, !caller.isEmpty {
            sections.append(caller)
        }
        return sections.joined(separator: "\n\n---\n\n")
    }

    /// Build the system prompt as a dict of tiers (= hermes build_system_prompt_parts).
    ///
    /// - Parameters: same as build().
    /// - Returns: Dict with key "stable" (= byte-stable system identity) and
    ///   optional "dynamic" key (= ephemeral hint rendered through
    ///   PromptBuilder.composeDynamicTier).
    public static func buildParts(
        ephemeralHint: String,
        callerMessage: String? = nil
    ) -> [String: String] {
        return buildParts(options: BuildOptions(
            ephemeralHint: ephemeralHint,
            callerMessage: callerMessage
        ))
    }

    /// Build the system prompt as a dict of tiers with full options
    /// (= HERMES-PARTIAL-012: per-provider + per-locale + dynamic-tier).
    ///
    /// Returns the three hermes tiers:
        * ``stable``   — identity + tool guidance + per-provider operational
          guidance + skills prompt + environment hints + platform hints.
        * ``dynamic``  — caller-supplied system message + ephemeral hint.
        * ``context``  — context files (AGENTS.md, .cursorrules, etc.)
          and locale-specific identity. (Empty by default in wenshu.)
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
            taskCompletionGuidance: options.taskCompletionGuidance
        )

        // Dynamic tier: routed through PromptBuilder (= GAP-001 refactor).
        let dynamic = PromptBuilder.dynamicTier(
            contextBundle: ContextEngine.ContextBundle(
                memories: [],
                characterContext: [],
                worldContext: [],
                foreshadowContext: []
            ),
            memories: [],
            skills: [],
            callerExtras: options.callerMessage.map { ["caller_message": $0] } ?? [:],
            ephemeralHint: options.ephemeralHint
        )
        if !dynamic.isEmpty {
            parts["dynamic"] = dynamic
        }

        return parts
    }

    /// The byte-stable system identity tier (= hermes _build_platform_specific_baseline).
    ///
    /// Invariant: this function MUST produce byte-identical output for any
    /// call (= no Date(), no random, no clock, no environment-derived values).
    /// Cache hits depend on byte stability.
    static func stableTier() -> String {
        return stableTier(
            provider: .unknown,
            locale: .english,
            memoryGuidance: false,
            sessionSearchGuidance: false,
            skillGuidance: false,
            kanbanGuidance: nil,
            parallelToolGuidance: true,
            taskCompletionGuidance: true
        )
    }

    /// Stable tier with full HERMES-PARTIAL-012 options.
    static func stableTier(
        provider: ProviderGuidance,
        locale: Locale,
        memoryGuidance: Bool,
        sessionSearchGuidance: Bool,
        skillGuidance: Bool,
        kanbanGuidance: String?,
        parallelToolGuidance: Bool,
        taskCompletionGuidance: Bool
    ) -> String {
        var sections: [String] = []

        // Identity block (= locale-aware base prompt).
        sections.append(localeIdentityBlock(locale: locale))

        // Per-provider operational guidance.
        sections.append(providerGuidance(provider: provider))

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
        if parallelToolGuidance {
            sections.append(universalGuidance("parallel_tool_call"))
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

    /// Universal guidance block (= hermes TASK_COMPLETION_GUIDANCE +
    /// PARALLEL_TOOL_CALL_GUIDANCE + the per-tool guidance blocks).
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
        case "parallel_tool_call":
            return """
            Parallel-tool-call guidance:
            - Batch independent tool calls into a single assistant turn rather
              than emitting one call per turn.
            - The runtime already runs independent calls concurrently; batching
              cuts round-trips and the resent-context cost that compounds
              over a long conversation.
            """
        default:
            return ""
        }
    }
}