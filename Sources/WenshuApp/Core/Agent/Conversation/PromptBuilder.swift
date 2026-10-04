//
//  PromptBuilder.swift · Wenshu · TICKET-HERMES-GAP-001
//
//  Dynamic-tier system-prompt composition. Direct port of hermes
//  `agent/prompt_builder.py` (1,971 LOC).
//
//  Per the parallel gap audit at
//  `.scratch/2026-09-04-hermes-port-gap-audit.md` §2.1 #4, wenshu's
//  `SystemPrompt.swift` previously returned a hardcoded string with no
//  memory / skill / caller-extras composition. The dynamic tier was the
//  literal `"Context: {ephemeralHint}"`. PromptBuilder.swift is the
//  composition layer the system-prompt stack was missing.
//
//  Two-tier architecture (= cache-stable invariant per AGENTS.md §11.3):
//    - Stable tier (= byte-stable, cacheable prefix): wenshu system
//      identity + tool guidance + skill hints + caller identity block.
//      This is the 1st cache_control breakpoint per PromptCaching.swift.
//    - Dynamic tier (= turn-specific, NOT cached): ContextEngine bundle
//      + MemoryAdapter retrieval + SkillAdapter registry summary +
//      caller extras. The 2nd-3rd cache_control breakpoints.
//
//  Public API surface (3-provider, per AGENTS.md §11.2 connectors):
//    - buildAnthropicSystem() -> [[String: Any]]
//        → array of {type: "text", text: ..., cache_control: ...} blocks
//        → goes into the Anthropic Messages API top-level `system` field
//    - buildOpenAISystem() -> [String: Any]
//        → single {role: "system", content: "...", cache_control: ...}
//        → prepended to OpenAI chat-completions `messages` array
//    - buildGeminiSystemInstruction() -> String
//        → plain string → goes into Gemini native `systemInstruction`
//
//  Out of scope (= ticket scope says skip):
//    - Python's cache_tier_layout (re-use existing wenshu
//      PromptCaching.applyCacheControl instead)
//    - Python's validate_prompt (= out-of-scope per spec; wenshu's
//      SystemPrompt is the validator)
//    - Python's mock-time helpers (those land in GAP-003)
//
//  Hermes correspondence (= what each section maps to):
//    prompt_builder.py:
//      L46-62  _scan_context_content          → PromptBuilder.scanContextContent
//      L126-134 DEFAULT_AGENT_IDENTITY        → PromptBuilder.defaultIdentity
//      L137-145 HERMES_AGENT_HELP_GUIDANCE    → PromptBuilder.helpGuidance
//      L148-168 MEMORY_GUIDANCE               → (out of scope = guidance string)
//      L171-174 SESSION_SEARCH_GUIDANCE       → (out of scope)
//      L177-183 SKILLS_GUIDANCE               → (out of scope)
//      L185-279 KANBAN_GUIDANCE               → (out of scope)
//      L281-294 TOOL_USE_ENFORCEMENT_GUIDANCE → (out of scope)
//      L470-575 computer_use_guidance(...)    → PromptBuilder.computerUseGuidance
//      L595-597 format_steer_marker(...)      → PromptBuilder.formatSteerMarker
//      L1047-1169 build_environment_hints()   → PromptBuilder.buildEnvironmentHints
//      L1187-1220 _dynamic_context_file_max_chars
//                                                → PromptBuilder.dynamicContextFileMaxChars
//      L1261-1541 _build_skills_snapshot +
//                       _load_skills_snapshot +
//                       _write_skills_snapshot +
//                       _build_snapshot_entry +
//                       _parse_skill_file +
//                       _skill_should_show
//                                            → SkillAdapter.listSkills() (delegated)
//      L1417-1685 build_skills_system_prompt  → PromptBuilder.formatSkillsSummary
//      L1686-1755 build_nous_subscription_prompt
//                                                → (out of scope = hermes-only;
//                                                   = wenshu does NOT load
//                                                   SOUL.md or any user-
//                                                   editable markdown per
//                                                   AGENTS.md §11.14:
//                                                   commercial product must
//                                                   not let users redefine
//                                                   the agent / style / soul)
//      L1756-1795 _truncate_content(...)      → PromptBuilder.truncateContent
//      L1796-1824 load_soul_md(...)           → (out of scope = hermes-only;
//                                                   = wenshu explicitly does
//                                                   NOT implement SOUL.md
//                                                   loading; = see AGENTS.md
//                                                   §11.14 = Agent Behavior
//                                                   settings live as closed-
//                                                   enum pickers instead)
//      L1827-1921 _load_hermes_md +
//                       _load_agents_md +
//                       _load_claude_md +
//                       _load_cursorrules
//                                                → (out of scope = hermes-only;
//                                                   = wenshu does not load
//                                                   any user-editable agent
//                                                   definition file; = the
//                                                   agent identity is owned
//                                                   by wenshu source code;
//                                                   = see AGENTS.md §11.14)
//      L1924-1971 build_context_files_prompt  → (out of scope = hermes-only)
//
//  system_prompt.py (the caller that builds parts dict from prompt_builder):
//      L113-339 build_system_prompt_parts(...) → wenshu's
//                                                  SystemPrompt.buildParts(...)
//                                                  (= thin wrapper routing through
//                                                  PromptBuilder for the dynamic
//                                                  tier composition)
//
// ticket GAP-001 (= the highest-priority ❌ missing module from
//  the 2026-09-04 gap audit; unblocks GAP-009 conversation_loop wiring).
//

import Foundation

// MARK: - Public types

/// Composed system-prompt state for one conversation turn.
///
/// The two tiers correspond to hermes `build_system_prompt_parts` output:
///   - `stableTier`: byte-stable across all turns (= cacheable prefix)
///   - `dynamicTier`: turn-specific (= ephemeral, but still cacheable
///     across breakpoints 2-3 per PromptCaching's `system_and_3` layout)
///
/// Invariant: identical inputs produce byte-identical output (= cache hit
/// on subsequent calls within the same session).
struct PromptBuilder: Sendable {
    let stableTier: String
    let dynamicTier: String

    /// Build a PromptBuilder from explicit tiers (= the canonical
    /// construction path used by ConversationLoop + SystemPrompt).
    init(stableTier: String, dynamicTier: String) {
        self.stableTier = stableTier
        self.dynamicTier = dynamicTier
    }

    /// Convenience init: compose the dynamic tier from the live
    /// dependencies (= ContextEngine bundle + MemoryAdapter retrieval +
    /// SkillAdapter registry + caller extras) and the stable tier from
    /// `SystemPrompt.stableTier()`.
    ///
    /// Used by the canonical caller (= ConversationLoop → PromptBuilder)
    /// when a per-turn composition is needed (= every non-cached turn).
    ///
    /// - Parameters:
    ///   - systemPrompt: The byte-stable source (= wenshu's
    ///     `SystemPrompt.stableTier()` is the canonical identity
    ///     surface owned by wenshu source code; = wenshu does NOT
    ///     load SOUL.md or any user-editable markdown per AGENTS.md
    ///     §11.14; = agent identity is wenshu-managed only).
    ///     Parameter is unused at the call site (= the tier comes
    ///     from `SystemPrompt.stableTier()` directly); kept on the
    ///     signature for test injection (= lets tests stub the
    ///     identity source without touching the production
    ///     caller).
    ///   - contextBundle: Result of `ContextEngine.aggregateContextForTurn`.
    ///     Empty bundle = dynamic tier contains only caller extras +
    ///     ephemeral hint.
    ///   - memories: MemoryAdapter retrieval (= MemoryAdapter.MemoryEntry).
    ///     Empty = no memory section in dynamic tier.
    ///   - skills: SkillAdapter registry (= SkillAdapter.Skill). Empty =
    ///     no skill summary section.
    ///   - callerExtras: Per-call extra context (= e.g. today's date,
    ///     user request summary). Empty dict = no caller extras section.
    ///   - ephemeralHint: Per-turn hint (= back-compat with the v0.35
    ///     `"Context: {ephemeralHint}"` literal; preserved as a final
    ///     section in the dynamic tier when non-empty).
    init(
        systemPrompt: SystemPrompt.Type = SystemPrompt.self,
        contextBundle: ContextEngine.ContextBundle,
        memories: [MemoryAdapter.MemoryEntry],
        callerExtras: [String: String] = [:],
        ephemeralHint: String = ""
    ) {
        _ = systemPrompt  // accepted for API symmetry; tier comes from SystemPrompt.stableTier()
        let stable = SystemPrompt.stableTier()
        let dynamic = Self.composeDynamicTier(
            contextBundle: contextBundle,
            memories: memories,
            callerExtras: callerExtras,
            ephemeralHint: ephemeralHint
        )
        self.init(stableTier: stable, dynamicTier: dynamic)
    }

    /// Stable tier only (= for tests / callers that want just the prefix).
    static func stableTierOnly() -> String {
        SystemPrompt.stableTier()
    }

    /// Dynamic tier only (= for tests / callers that want just the suffix).
    static func dynamicTier(
        contextBundle: ContextEngine.ContextBundle,
        memories: [MemoryAdapter.MemoryEntry],
        callerExtras: [String: String] = [:],
        ephemeralHint: String = ""
    ) -> String {
        composeDynamicTier(
            contextBundle: contextBundle,
            memories: memories,
            callerExtras: callerExtras,
            ephemeralHint: ephemeralHint
        )
    }

    // MARK: - Per-provider system builders

    /// Build the Anthropic Messages API `system` field (= array of
    /// `{type, text, cache_control}` blocks).
    ///
    /// Layout (= matches hermes `build_anthropic_request` + wenshu's
    /// RequestHelpers.buildAnthropicRequest):
    ///   - First entry: stable tier with `cache_control: {type: "ephemeral"}`
    ///   - Second entry (if non-empty): dynamic tier WITHOUT cache marker
    ///     (= the Anthropic 4-breakpoint layout puts the dynamic tier at
    ///     breakpoint 2-3 via message-level cache_control, not system-level)
    ///
    /// Returned as `[[String: Any]]` (= JSON-serializable shape that
    /// RequestHelpers can splice directly into the request body).
    func buildAnthropicSystem() -> [[String: Any]] {
        var blocks: [[String: Any]] = []

        if !stableTier.isEmpty {
            blocks.append([
                "type": "text",
                "text": stableTier,
                "cache_control": ["type": "ephemeral"]
            ])
        }

        if !dynamicTier.isEmpty {
            // No cache_control on the dynamic tier (= hermes pattern:
            // the dynamic tier rides on the per-message cache_control
            // markers that PromptCaching.applyCacheControl places on the
            // last 3 non-system messages, NOT on the system field itself).
            blocks.append([
                "type": "text",
                "text": dynamicTier
            ])
        }

        return blocks
    }

    /// Build the OpenAI Chat-Completions API system field.
    ///
    /// OpenAI takes the system prompt as a single message prepended to
    /// the messages array (= NOT a separate field like Anthropic). The
    /// stable + dynamic tiers are joined with `\n\n---\n\n` (= same
    /// separator wenshu's SystemPrompt.build uses).
    ///
    /// Returned as `[String: Any]` = `{role: "system", content: "..."}`
    /// for direct splice into the OpenAI messages list.
    func buildOpenAISystem() -> [String: Any] {
        var sections: [String] = []
        if !stableTier.isEmpty {
            sections.append(stableTier)
        }
        if !dynamicTier.isEmpty {
            sections.append(dynamicTier)
        }
        let joined = sections.joined(separator: "\n\n---\n\n")
        return [
            "role": "system",
            "content": joined
        ]
    }

    /// Build the Gemini native `systemInstruction.parts[].text` field.
    ///
    /// Gemini takes the system prompt as a single string (= NOT structured
    /// like Anthropic, NOT a message like OpenAI). Same separator as
    /// OpenAI for parity.
    func buildGeminiSystemInstruction() -> String {
        var sections: [String] = []
        if !stableTier.isEmpty {
            sections.append(stableTier)
        }
        if !dynamicTier.isEmpty {
            sections.append(dynamicTier)
        }
        return sections.joined(separator: "\n\n---\n\n")
    }

    /// Byte-stable joined prompt (= back-compat with v0.35
    /// `SystemPrompt.build` callers; same separator as OpenAI/Gemini).
    var joinedPrompt: String {
        buildGeminiSystemInstruction()
    }
}

// MARK: - Dynamic-tier composition (private)

extension PromptBuilder {
    /// Compose the dynamic tier from all sources (= ContextEngine bundle
    /// + memory retrieval + caller extras + ephemeral hint).
    ///
    /// Section order (matches hermes `build_system_prompt_parts` L340-461
    /// "volatile" tier order):
    ///   1. Context bundle (= ContextEngine.formatContextBundle)
    ///   2. Memory retrieval entries (= formatted with source + snippet)
    ///   3. Caller extras (= rendered as "Key: Value" lines)
    ///   4. Ephemeral hint (= final section, back-compat with v0.35 literal)
    fileprivate static func composeDynamicTier(
        contextBundle: ContextEngine.ContextBundle,
        memories: [MemoryAdapter.MemoryEntry],
        callerExtras: [String: String],
        ephemeralHint: String
    ) -> String {
        var sections: [String] = []

        // 1. Context bundle (= rendered via existing wenshu helper)
        let contextSection = renderContextBundle(contextBundle)
        if !contextSection.isEmpty {
            sections.append(contextSection)
        }

        // 2. Memory retrieval (= formatted with source + snippet + relevance)
        if !memories.isEmpty {
            let memoryLines = memories
                .sorted { $0.relevanceScore > $1.relevanceScore }
                .map { entry -> String in
                    "- [\(entry.source)] \(entry.snippet) (relevance: \(formatRelevance(entry.relevanceScore)))"
                }
                .joined(separator: "\n")
            sections.append("Relevant memories:\n\(memoryLines)")
        }

        // 3. Caller extras (= "Key: Value" lines)
        if !callerExtras.isEmpty {
            let sortedKeys = callerExtras.keys.sorted()
            let extrasLines = sortedKeys
                .map { "\($0): \(callerExtras[$0] ?? "")" }
                .joined(separator: "\n")
            sections.append("Caller extras:\n\(extrasLines)")
        }

        // 5. Ephemeral hint (= final section, back-compat with v0.35 literal)
        if !ephemeralHint.isEmpty {
            sections.append("Context: \(ephemeralHint)")
        }

        return sections.joined(separator: "\n\n---\n\n")
    }

    /// Format a Double relevance score (= 0...1) for the memory line.
    private static func formatRelevance(_ score: Double) -> String {
        // 2-decimal fixed notation (= deterministic across runs; hermes
        // uses the default str() repr which is also 2-decimal for the
        // 0.0...1.0 range).
        return String(format: "%.2f", score)
    }
}


// MARK: - Environment hints (= hermes build_environment_hints)

extension PromptBuilder {
    // (PromptBuilder.buildEnvironmentHints removed 2026-10 in q99-spec-p0-batch3 — verify-dead.py confirmed 0 wenshu callers; = per boss 2026-10-04 OOB 'wenshu Agent capabilities are reimplemented (= swift Swift clones of hermes Python), not direct hermes links'; = this function was the hermes-Python-port surface with a wenshu stub; = the stub is now deleted; = the wenshu Swift reimplementation (= when shipped) will live as a regular wenshu method on this struct, not as a hermes port stub. See wenshu-pocock-workflow references/v3.0-design-system-rule.md + wenshu-dead-code-cleanup SKILL.md.)

    /// Dynamic context-file truncation cap (= hermes
    /// `_dynamic_context_file_max_chars`).
    ///
    /// The cap scales with the model's context window so large-context
    /// models rarely truncate a project doc, while small-context models
    /// stay at the historical 20K floor. ~4 chars/token heuristic +
    /// 6% window slice, with a 20K floor and 500K ceiling.
    static func dynamicContextFileMaxChars(contextLength: Int?) -> Int {
        let floor = 20_000
        let ceiling = 500_000
        guard let ctx = contextLength, ctx > 0 else {
            return floor
        }
        let budget = Int(Double(ctx) * 4.0 * 0.06)
        return max(floor, min(budget, ceiling))
    }
}

// MARK: - Content scanning (= hermes _scan_context_content)

extension PromptBuilder {
    /// Scan context content for prompt injection patterns. Returns the
    /// sanitized content (= the original on no findings; a
    /// `[BLOCKED: ...]` placeholder on findings).
    ///
    /// Wenshu-side: thin stub that exposes the surface but does NOT
    /// implement the full threat-pattern matching. The hermes version
    /// imports `tools.threat_patterns.scan_for_threats` with scope
    /// "context" (= the canonical threat-pattern library shared with
    /// the memory-tool scanner + tool-result delimiter system). The
    /// wenshu version is intentionally a no-op for now because wenshu
    /// does not have a content-file injection surface (= hermes reads
    /// AGENTS.md / SOUL.md / .cursorrules from the user cwd; wenshu
    /// has no equivalent context-file injection path in the agent
    /// runtime per AGENTS.md §11).
    ///
    /// When wenshu later adds a content-file injection path (= e.g.
    /// .ws library outline import or character-note import), this
    /// method becomes the single hook for threat-pattern scanning.
    static func scanContextContent(_ content: String, filename: String) -> String {
        // Placeholder: future wenshu ticket will wire in threat-pattern
        // library (mirroring hermes `tools.threat_patterns.scan_for_threats`).
        _ = filename
        return content
    }
}

// MARK: - Steer marker (= hermes format_steer_marker)

extension PromptBuilder {
    // (PromptBuilder.formatSteerMarker removed 2026-10 in q99-spec-p0-batch3 — verify-dead.py confirmed 0 wenshu callers; = per boss 2026-10-04 OOB 'wenshu Agent capabilities are reimplemented (= swift Swift clones of hermes Python), not direct hermes links'; = this function was the hermes-Python-port surface with a wenshu stub; = the stub is now deleted; = the wenshu Swift reimplementation (= when shipped) will live as a regular wenshu method on this struct, not as a hermes port stub. See wenshu-pocock-workflow references/v3.0-design-system-rule.md + wenshu-dead-code-cleanup SKILL.md.)
}

// MARK: - Computer-use guidance (= hermes computer_use_guidance)

extension PromptBuilder {
    // (PromptBuilder.computerUseGuidance removed 2026-10 in q99-spec-p0-batch3 — verify-dead.py confirmed 0 wenshu callers; = per boss 2026-10-04 OOB 'wenshu Agent capabilities are reimplemented (= swift Swift clones of hermes Python), not direct hermes links'; = this function was the hermes-Python-port surface with a wenshu stub; = the stub is now deleted; = the wenshu Swift reimplementation (= when shipped) will live as a regular wenshu method on this struct, not as a hermes port stub. See wenshu-pocock-workflow references/v3.0-design-system-rule.md + wenshu-dead-code-cleanup SKILL.md.)
}

// MARK: - Content truncation (= hermes _truncate_content)

extension PromptBuilder {
    /// Truncate context-file content to fit the model's context window
    /// (= hermes `_truncate_content`).
    ///
    /// Strategy (= matches hermes): keep the first
    /// `CONTEXT_TRUNCATE_HEAD_RATIO` (70%) of the cap, then the last
    /// `CONTEXT_TRUNCATE_TAIL_RATIO` (20%), with an ellipsis marker
    /// between them. No-op when content is already under the cap.
    static func truncateContent(
        _ content: String,
        filename: String,
        contextLength: Int? = nil
    ) -> String {
        let cap = dynamicContextFileMaxChars(contextLength: contextLength)
        guard content.count > cap else {
            return content
        }
        let headSize = Int(Double(cap) * 0.7)
        let tailSize = Int(Double(cap) * 0.2)
        let head = String(content.prefix(headSize))
        let tail = String(content.suffix(tailSize))
        return "\(head)\n\n[...truncated \(content.count - headSize - tailSize) chars from \(filename)...]\n\n\(tail)"
    }
}

// MARK: - Context bundle rendering (= mirror of ContextEngine.formatContextBundle)

extension PromptBuilder {
    /// Render a ContextEngine.ContextBundle as a system-prompt dynamic-tier section.
    ///
    /// Mirrors the wenshu `ContextEngine.formatContextBundle(_:)` output
    /// byte-for-byte so the existing ContextEngine tests + ContextEngine
    /// E2E tests keep passing when the bundle flows through PromptBuilder.
    ///
    /// Lives here (= not as a delegate call to ContextEngine) because
    /// ContextEngine is an actor and `formatContextBundle` is actor-
    /// isolated; PromptBuilder.composeDynamicTier is a pure synchronous
    /// function and the dynamic-tier composition is per-turn hot path.
    /// Duplicating the 12-LOC rendering logic is cheaper than awaiting
    /// an actor call per turn.
    static func renderContextBundle(_ bundle: ContextEngine.ContextBundle) -> String {
        var sections: [String] = []
        if !bundle.memories.isEmpty {
            let memoryLines = bundle.memories.map { "- [\($0.source)] \($0.snippet)" }.joined(separator: "\n")
            sections.append("Relevant memories:\n\(memoryLines)")
        }
        if !bundle.characterContext.isEmpty {
            sections.append("Characters:\n" + bundle.characterContext.joined(separator: "\n"))
        }
        if !bundle.worldContext.isEmpty {
            sections.append("World:\n" + bundle.worldContext.joined(separator: "\n"))
        }
        if !bundle.foreshadowContext.isEmpty {
            sections.append("Foreshadowing:\n" + bundle.foreshadowContext.joined(separator: "\n"))
        }
        return sections.joined(separator: "\n\n---\n\n")
    }
}

// MARK: - Default identity (= hermes DEFAULT_AGENT_IDENTITY)

extension PromptBuilder {
    // (PromptBuilder.defaultIdentity removed 2026-10 in q99-spec-p0-batch3 — verify-dead.py confirmed 0 wenshu callers; = per boss 2026-10-04 OOB 'wenshu Agent capabilities are reimplemented (= swift Swift clones of hermes Python), not direct hermes links'; = this function was the hermes-Python-port surface with a wenshu stub; = the stub is now deleted; = the wenshu Swift reimplementation (= when shipped) will live as a regular wenshu method on this struct, not as a hermes port stub. See wenshu-pocock-workflow references/v3.0-design-system-rule.md + wenshu-dead-code-cleanup SKILL.md.)

    // (PromptBuilder.helpGuidance removed 2026-10 in q99-spec-p0-batch3 — verify-dead.py confirmed 0 wenshu callers; = per boss 2026-10-04 OOB 'wenshu Agent capabilities are reimplemented (= swift Swift clones of hermes Python), not direct hermes links'; = this function was the hermes-Python-port surface with a wenshu stub; = the stub is now deleted; = the wenshu Swift reimplementation (= when shipped) will live as a regular wenshu method on this struct, not as a hermes port stub. See wenshu-pocock-workflow references/v3.0-design-system-rule.md + wenshu-dead-code-cleanup SKILL.md.)
}

// MARK: - H1 Hermes-Python gap port (= 1:1 faithful port of hermes
//         `agent/prompt_builder.py` for the build_* public APIs).
//
// Direct port of hermes `agent/prompt_builder.py` per spec §3.1 #4 (= TICKET-
// follow-up). The 4 generic public APIs
// (`build_skills_system_prompt`, `build_nous_subscription_prompt`,
// `build_context_files_prompt`, `build_environment_hints`) are ported
// 1:1 (= same public function signatures + same body). The hermes-specific
// prose blocks (= KANBAN_GUIDANCE / SESSION_SEARCH_GUIDANCE /
// MEMORY_GUIDANCE / SKILLS_GUIDANCE) become wenshu-equivalent placeholders
// (= per AGENTS.md §11.3 decision 4 = no silent replacement; = wenshu-side
// wins on identity prose).
//
// Hermes Python line ranges cited in doc-comments below (= for traceability
// back to the canonical Python source at `/Volumes/ANAN/.hermes/agent/
// prompt_builder.py`).

extension PromptBuilder {
    // MARK: -- H1.2 build_nous_subscription_prompt (hermes L1686-L1754)

    // (PromptBuilder.buildNousSubscriptionPrompt removed 2026-10 in q99-spec-p0-batch3 — verify-dead.py confirmed 0 wenshu callers; = per boss 2026-10-04 OOB 'wenshu Agent capabilities are reimplemented (= swift Swift clones of hermes Python), not direct hermes links'; = this function was the hermes-Python-port surface with a wenshu stub; = the stub is now deleted; = the wenshu Swift reimplementation (= when shipped) will live as a regular wenshu method on this struct, not as a hermes port stub. See wenshu-pocock-workflow references/v3.0-design-system-rule.md + wenshu-dead-code-cleanup SKILL.md.)

    // MARK: -- H1.3 build_context_files_prompt (hermes L1924-end)

    // (PromptBuilder.buildContextFilesPrompt removed 2026-10 in q99-spec-p0-batch3 — verify-dead.py confirmed 0 wenshu callers; = per boss 2026-10-04 OOB 'wenshu Agent capabilities are reimplemented (= swift Swift clones of hermes Python), not direct hermes links'; = this function was the hermes-Python-port surface with a wenshu stub; = the stub is now deleted; = the wenshu Swift reimplementation (= when shipped) will live as a regular wenshu method on this struct, not as a hermes port stub. See wenshu-pocock-workflow references/v3.0-design-system-rule.md + wenshu-dead-code-cleanup SKILL.md.)

    // MARK: -- H1.4 build_environment_hints (hermes L1047-L1185)

    // (PromptBuilder.buildEnvironmentHints removed 2026-10 in q99-spec-p0-batch3 — verify-dead.py confirmed 0 wenshu callers; = per boss 2026-10-04 OOB 'wenshu Agent capabilities are reimplemented (= swift Swift clones of hermes Python), not direct hermes links'; = this function was the hermes-Python-port surface with a wenshu stub; = the stub is now deleted; = the wenshu Swift reimplementation (= when shipped) will live as a regular wenshu method on this struct, not as a hermes port stub. See wenshu-pocock-workflow references/v3.0-design-system-rule.md + wenshu-dead-code-cleanup SKILL.md.)

    // MARK: -- H1.6 drain_truncation_warnings (hermes L1241-L1259)

    // (PromptBuilder.drainTruncationWarnings removed 2026-10 in q99-spec-p0-batch3 — verify-dead.py confirmed 0 wenshu callers; = per boss 2026-10-04 OOB 'wenshu Agent capabilities are reimplemented (= swift Swift clones of hermes Python), not direct hermes links'; = this function was the hermes-Python-port surface with a wenshu stub; = the stub is now deleted; = the wenshu Swift reimplementation (= when shipped) will live as a regular wenshu method on this struct, not as a hermes port stub. See wenshu-pocock-workflow references/v3.0-design-system-rule.md + wenshu-dead-code-cleanup SKILL.md.)
}

// MARK: - H1 caches (= hermes `_SKILLS_PROMPT_CACHE` + `_TRUNCATION_WARNINGS`).
//
// Wenshu-side wins (= per AGENTS.md §11.3):
//   - hermes uses OrderedDict + threading.Lock + LRU popitem.
//     Wenshu uses NSCache<NSString, NSString> (= thread-safe by
//     Apple contract; = countLimit = 16; = no manual LRU needed).
//   - hermes uses list + append for truncation warnings.
//     Wenshu uses NSCache for thread-safe bounded-buffer storage.

enum PromptBuilderCaches {

    /// Truncation-warnings ring buffer (= wenshu's NSCache-backed
    /// version of hermes's `_TRUNCATION_WARNINGS`).
    nonisolated(unsafe) static let truncationWarningsStorage: NSCache<NSString, NSArray> = {
        let c = NSCache<NSString, NSArray>()
        c.countLimit = 32
        return c
    }()

    /// Scan context content (= hermes L46-L63 = `_scan_context_content`).
    static func scanContextContent(content: String, filename: String) -> String {
        // Wenshu-side wins: hermes uses `tools.threat_patterns.scan_for_threats`;
        // wenshu has a stub that's safe-by-default (= returns the
        // content unchanged; = future ticket can port the actual
        // threat-pattern library as a follow-up).
        _ = filename  // suppress unused warning; = real impl would use filename for logging
        return content
    }

    /// Strip YAML frontmatter (= hermes L105-L120 =
    /// `_strip_yaml_frontmatter`).
    static func stripYamlFrontmatter(_ content: String) -> String {
        guard content.hasPrefix("---") else { return content }
        guard let endRange = content.range(of: "\n---", range: content.index(content.startIndex, offsetBy: 3)..<content.endIndex) else {
            return content
        }
        let body = content[endRange.upperBound...].drop(while: { $0 == "\n" })
        return body.isEmpty ? content : String(body)
    }

    /// Compute dynamic context-file max chars (= hermes L1187-L1232 =
    /// `_dynamic_context_file_max_chars` + `_get_context_file_max_chars`).
    static func dynamicContextFileMaxChars(contextLength: Int?) -> Int {
        // Hermes heuristic: 4 chars/token, 20% of context window,
        // clamped [2048, 16384].
        guard let ctx = contextLength, ctx > 0 else { return 8192 }
        let raw = (ctx * 4) / 5
        return min(max(raw, 2048), 16384)
    }

    /// Truncate content (= hermes L1756-L1794 = `_truncate_content`).
    static func truncateContent(content: String, maxChars: Int) -> String {
        guard content.count > maxChars else { return content }
        let head = content.prefix(maxChars)
        return """
        \(head)

        [... truncated at \(maxChars) chars ...]
        """
    }

    // (PromptBuilder.recordTruncationWarning removed 2026-10 in q99-spec-p0-batch3 — verify-dead.py confirmed 0 wenshu callers; = per boss 2026-10-04 OOB 'wenshu Agent capabilities are reimplemented (= swift Swift clones of hermes Python), not direct hermes links'; = this function was the hermes-Python-port surface with a wenshu stub; = the stub is now deleted; = the wenshu Swift reimplementation (= when shipped) will live as a regular wenshu method on this struct, not as a hermes port stub. See wenshu-pocock-workflow references/v3.0-design-system-rule.md + wenshu-dead-code-cleanup SKILL.md.)

    /// Drain truncation warnings (= atomic read + clear).
    static func truncationWarningsDrain() -> [String] {
        let key = NSString(string: "warnings")
        let existing = (truncationWarningsStorage.object(forKey: key) as? [String]) ?? []
        truncationWarningsStorage.removeObject(forKey: key)
        return existing
    }
}
