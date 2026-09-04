//
//  PromptBuilderTests.swift · Wenshu · TICKET-HERMES-GAP-001
//
//  Golden-parity tests for the new PromptBuilder (= direct port of
//  hermes `agent/prompt_builder.py` per the 2026-09-04 gap audit §2.1 #4).
//
//  These tests mirror the 5 PromptBuilder golden cases specified in
//  the GAP-001 ticket. Each test produces a deterministic output for
//  the same input (= byte-stable invariant per AGENTS.md §11.3
//  cache-stable requirement). The Swift port asserts the expected
//  composition shape; future hermes-side behavior changes are caught
//  by golden-file regeneration
//  (= `Tests/WenshuAppTests/Agent/PortedFromHermes/scripts/generate_golden.py`).
//
//  Test surface:
//    1. testBuildSystemPrompt_stableTier — fixed system prompt + empty
//       context bundle + empty memory + empty skill → deterministic output
//       (= stable tier + empty dynamic tier).
//    2. testBuildSystemPrompt_withContext — fixed system prompt +
//       non-empty context bundle → dynamic tier contains the context entries.
//    3. testBuildSystemPrompt_withMemory — fixed system prompt +
//       non-empty memory → dynamic tier contains the memory entries.
//    4. testBuildSystemPrompt_withSkill — fixed system prompt +
//       non-empty skill registry → dynamic tier contains the skill summary.
//    5. testBuildSystemPrompt_fullTier — fixed system prompt + everything
//       non-empty → full dynamic tier (all 5 sections present).
//
//  All tests use the synchronous PromptBuilder.dynamicTier(...) entry
//  point (= the pure helper), not the full conversation-loop pipeline.
//  Composition is deterministic across runs (= no Date, no random).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("PromptBuilder (TICKET-HERMES-GAP-001)")
struct PromptBuilderTests {

    // MARK: - Test 1: stable tier only

    @Test("buildSystemPrompt_stableTier: empty context + memory + skill -> stable tier + empty dynamic")
    func testBuildSystemPromptStableTier() {
        // Empty inputs across the board -> only the stable tier appears,
        // and the dynamic tier is empty (no ephemeral hint + no other
        // sections). Byte-stable invariant: identical inputs → identical
        // outputs across runs.
        let bundle = ContextEngine.ContextBundle(
            memories: [],
            characterContext: [],
            worldContext: [],
            foreshadowContext: []
        )

        let dynamic = PromptBuilder.dynamicTier(
            contextBundle: bundle,
            memories: [],
            skills: [],
            callerExtras: [:],
            ephemeralHint: ""
        )
        let stable = PromptBuilder.stableTierOnly()

        // Stable tier = non-empty wenshu identity string
        #expect(!stable.isEmpty)
        // Stable tier contains the canonical 文枢 (= wenshu) identity anchor
        #expect(stable.contains("文枢"))
        // Dynamic tier = empty when no inputs
        #expect(dynamic.isEmpty)

        // Compose the full PromptBuilder and verify the joined output
        let builder = PromptBuilder(stableTier: stable, dynamicTier: dynamic)
        #expect(builder.joinedPrompt == stable)

        // Byte-stability across 100 calls (= cache-stable invariant)
        let first = builder.joinedPrompt
        var last = first
        for _ in 0..<100 {
            last = PromptBuilder(
                stableTier: PromptBuilder.stableTierOnly(),
                dynamicTier: PromptBuilder.dynamicTier(
                    contextBundle: bundle,
                    memories: [],
                    skills: [],
                    callerExtras: [:],
                    ephemeralHint: ""
                )
            ).joinedPrompt
        }
        #expect(first == last)
    }

    // MARK: - Test 2: context bundle renders

    @Test("buildSystemPrompt_withContext: non-empty context bundle -> dynamic tier contains context entries")
    func testBuildSystemPromptWithContext() {
        let bundle = ContextEngine.ContextBundle(
            memories: [],
            characterContext: ["Alice: protagonist", "Bob: antagonist"],
            worldContext: ["Era: medieval", "Magic system: rune-based"],
            foreshadowContext: ["The lost crown will return in chapter 12"]
        )

        let dynamic = PromptBuilder.dynamicTier(
            contextBundle: bundle,
            memories: [],
            skills: [],
            callerExtras: [:],
            ephemeralHint: ""
        )

        // Dynamic tier is non-empty
        #expect(!dynamic.isEmpty)
        // Contains the context sections (= rendered by renderContextBundle)
        #expect(dynamic.contains("Characters:"))
        #expect(dynamic.contains("Alice: protagonist"))
        #expect(dynamic.contains("Bob: antagonist"))
        #expect(dynamic.contains("World:"))
        #expect(dynamic.contains("Era: medieval"))
        #expect(dynamic.contains("Magic system: rune-based"))
        #expect(dynamic.contains("Foreshadowing:"))
        #expect(dynamic.contains("The lost crown will return in chapter 12"))

        // Deterministic across runs (= byte-stable)
        let first = dynamic
        var last = first
        for _ in 0..<50 {
            last = PromptBuilder.dynamicTier(
                contextBundle: bundle,
                memories: [],
                skills: [],
                callerExtras: [:],
                ephemeralHint: ""
            )
        }
        #expect(first == last)
    }

    // MARK: - Test 3: memory entries render

    @Test("buildSystemPrompt_withMemory: non-empty memory -> dynamic tier contains memory entries")
    func testBuildSystemPromptWithMemory() {
        let memories: [MemoryAdapter.MemoryEntry] = [
            MemoryAdapter.MemoryEntry(
                id: "mem-1",
                source: "outline/chapter-3.md",
                snippet: "Alice discovers the hidden door",
                relevanceScore: 0.95
            ),
            MemoryAdapter.MemoryEntry(
                id: "mem-2",
                source: "characters/alice.md",
                snippet: "Alice's backstory: orphan raised by wolves",
                relevanceScore: 0.72
            )
        ]

        let dynamic = PromptBuilder.dynamicTier(
            contextBundle: ContextEngine.ContextBundle(
                memories: [],
                characterContext: [],
                worldContext: [],
                foreshadowContext: []
            ),
            memories: memories,
            skills: [],
            callerExtras: [:],
            ephemeralHint: ""
        )

        // Dynamic tier is non-empty
        #expect(!dynamic.isEmpty)
        // Memory section header present
        #expect(dynamic.contains("Relevant memories:"))
        // Memory entries sorted by relevance (descending) — mem-1 first
        let mem1Idx = dynamic.range(of: "outline/chapter-3.md")?.lowerBound
        let mem2Idx = dynamic.range(of: "characters/alice.md")?.lowerBound
        #expect(mem1Idx != nil)
        #expect(mem2Idx != nil)
        if let mem1Idx, let mem2Idx {
            #expect(mem1Idx < mem2Idx)  // higher relevance first
        }
        // Snippet content present
        #expect(dynamic.contains("Alice discovers the hidden door"))
        #expect(dynamic.contains("orphan raised by wolves"))

        // Deterministic across runs
        let first = dynamic
        var last = first
        for _ in 0..<50 {
            last = PromptBuilder.dynamicTier(
                contextBundle: ContextEngine.ContextBundle(
                    memories: [],
                    characterContext: [],
                    worldContext: [],
                    foreshadowContext: []
                ),
                memories: memories,
                skills: [],
                callerExtras: [:],
                ephemeralHint: ""
            )
        }
        #expect(first == last)
    }

    // MARK: - Test 4: skill summary renders

    @Test("buildSystemPrompt_withSkill: non-empty skill registry -> dynamic tier contains skill summary")
    func testBuildSystemPromptWithSkill() {
        let skills: [SkillAdapter.Skill] = [
            SkillAdapter.Skill(name: "narrative-craft", description: "Long-form prose techniques", enabled: true),
            SkillAdapter.Skill(name: "wenshu-pollution-defense", description: "12 xianxia token defense chain", enabled: true),
            SkillAdapter.Skill(name: "apple-hig-grep", description: "Apple HIG lookup before custom code", enabled: false)  // disabled
        ]

        let dynamic = PromptBuilder.dynamicTier(
            contextBundle: ContextEngine.ContextBundle(
                memories: [],
                characterContext: [],
                worldContext: [],
                foreshadowContext: []
            ),
            memories: [],
            skills: skills,
            callerExtras: [:],
            ephemeralHint: ""
        )

        // Dynamic tier is non-empty
        #expect(!dynamic.isEmpty)
        // Skill summary header present
        #expect(dynamic.contains("Available skills:"))
        // Enabled skills listed (= 2 enabled, 1 disabled)
        #expect(dynamic.contains("- narrative-craft"))
        #expect(dynamic.contains("Long-form prose techniques"))
        #expect(dynamic.contains("- wenshu-pollution-defense"))
        #expect(dynamic.contains("12 xianxia token defense chain"))
        // Disabled skill excluded from summary
        #expect(!dynamic.contains("- apple-hig-grep"))

        // Deterministic across runs (= alphabetical sort)
        let first = dynamic
        var last = first
        for _ in 0..<50 {
            last = PromptBuilder.dynamicTier(
                contextBundle: ContextEngine.ContextBundle(
                    memories: [],
                    characterContext: [],
                    worldContext: [],
                    foreshadowContext: []
                ),
                memories: [],
                skills: skills,
                callerExtras: [:],
                ephemeralHint: ""
            )
        }
        #expect(first == last)
    }

    // MARK: - Test 5: full tier (everything non-empty)

    @Test("buildSystemPrompt_fullTier: everything non-empty -> full dynamic tier with all sections")
    func testBuildSystemPromptFullTier() {
        let bundle = ContextEngine.ContextBundle(
            memories: [],
            characterContext: ["Alice: protagonist"],
            worldContext: [],
            foreshadowContext: []
        )
        let memories: [MemoryAdapter.MemoryEntry] = [
            MemoryAdapter.MemoryEntry(
                id: "mem-1",
                source: "outline.md",
                snippet: "First chapter outline",
                relevanceScore: 0.88
            )
        ]
        let skills: [SkillAdapter.Skill] = [
            SkillAdapter.Skill(name: "narrative-craft", description: "Long-form prose", enabled: true)
        ]
        let callerExtras = [
            "today": "2026-09-04",
            "user_request": "draft chapter 1"
        ]
        let ephemeralHint = "Tuesday, sunny"

        let dynamic = PromptBuilder.dynamicTier(
            contextBundle: bundle,
            memories: memories,
            skills: skills,
            callerExtras: callerExtras,
            ephemeralHint: ephemeralHint
        )
        let stable = PromptBuilder.stableTierOnly()

        // Compose the full PromptBuilder and verify per-provider builders
        let builder = PromptBuilder(stableTier: stable, dynamicTier: dynamic)

        // All 5 dynamic-tier sections present:
        // 1. Context bundle
        #expect(dynamic.contains("Characters:"))
        #expect(dynamic.contains("Alice: protagonist"))
        // 2. Memory retrieval
        #expect(dynamic.contains("Relevant memories:"))
        #expect(dynamic.contains("First chapter outline"))
        // 3. Skill summary
        #expect(dynamic.contains("Available skills:"))
        #expect(dynamic.contains("narrative-craft"))
        // 4. Caller extras (= "Key: Value" lines)
        #expect(dynamic.contains("Caller extras:"))
        #expect(dynamic.contains("today: 2026-09-04"))
        #expect(dynamic.contains("user_request: draft chapter 1"))
        // 5. Ephemeral hint (= final section, back-compat with v0.35 literal)
        #expect(dynamic.contains("Context: Tuesday, sunny"))

        // Per-provider builders
        // 1. Anthropic: array of blocks
        let anthropic = builder.buildAnthropicSystem()
        #expect(anthropic.count == 2)  // stable + dynamic
        #expect(anthropic[0]["type"] as? String == "text")
        #expect(anthropic[0]["text"] as? String == stable)
        #expect(anthropic[0]["cache_control"] as? [String: String] == ["type": "ephemeral"])
        #expect(anthropic[1]["type"] as? String == "text")
        #expect(anthropic[1]["text"] as? String == dynamic)
        // Dynamic block has NO cache_control (= per-message cache markers
        // carry the cache hint, not the system block)
        #expect(anthropic[1]["cache_control"] == nil)

        // 2. OpenAI: single system message dict
        let openai = builder.buildOpenAISystem()
        #expect(openai["role"] as? String == "system")
        let openaiContent = openai["content"] as? String ?? ""
        #expect(openaiContent.contains(stable))
        #expect(openaiContent.contains(dynamic))
        #expect(openaiContent.contains("\n\n---\n\n"))

        // 3. Gemini: plain joined string
        let gemini = builder.buildGeminiSystemInstruction()
        #expect(gemini.contains(stable))
        #expect(gemini.contains(dynamic))
        #expect(gemini.contains("\n\n---\n\n"))

        // Full deterministic byte-stability across runs
        let first = builder.joinedPrompt
        var last = first
        for _ in 0..<50 {
            last = PromptBuilder(
                stableTier: PromptBuilder.stableTierOnly(),
                dynamicTier: PromptBuilder.dynamicTier(
                    contextBundle: bundle,
                    memories: memories,
                    skills: skills,
                    callerExtras: callerExtras,
                    ephemeralHint: ephemeralHint
                )
            ).joinedPrompt
        }
        #expect(first == last)
    }
}