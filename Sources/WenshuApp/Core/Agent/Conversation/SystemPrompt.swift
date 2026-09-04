//
//  SystemPrompt.swift · Wenshu · v0.35 ticket 002 sub-step 2
//  + TICKET-HERMES-GAP-001 refactor (2026-09-04).
//
//  System prompt builder. Direct port of hermes system_prompt.py
//  (= L113-L507, 536 LOC; provides build_system_prompt_parts + build_system_prompt).
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
        var parts: [String: String] = [:]

        // Stable tier (= byte-stable across all turns in a session)
        parts["stable"] = stableTier()

        // Dynamic tier: routed through PromptBuilder (= GAP-001 refactor).
        // Empty context bundle + empty memories + empty skills + empty
        // caller extras = the dynamic tier reduces to "Context: <hint>"
        // for backwards compat with the v0.35 literal placeholder. The
        // full per-turn composition (ContextEngine + MemoryAdapter +
        // SkillAdapter) lands in ConversationLoop.runConversation via
        // the convenience PromptBuilder init.
        let dynamic = PromptBuilder.dynamicTier(
            contextBundle: ContextEngine.ContextBundle(
                memories: [],
                characterContext: [],
                worldContext: [],
                foreshadowContext: []
            ),
            memories: [],
            skills: [],
            callerExtras: callerMessage.map { ["caller_message": $0] } ?? [:],
            ephemeralHint: ephemeralHint
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
    ///
    /// Exposed as `internal` (= not `private`) so PromptBuilder can
    /// compose the stable tier from the canonical source. The function
    /// itself was `private` pre-GAP-001; widening visibility is the only
    /// change.
    static func stableTier() -> String {
        return """
        You are an AI assistant embedded in 文枢 (= Wenshu), a long-form novel
        authoring tool for macOS. Wenshu is a writing tool, not an LLM platform.
        You help the user write novels, develop characters, plan story arcs,
        and refine prose.

        Operating principles:
        - Respond in the same language the user uses.
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
        - (more tools land in subsequent tickets per the connector layer spec)
        """
    }
}