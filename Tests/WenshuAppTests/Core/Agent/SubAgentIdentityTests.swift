//
//  SubAgentIdentityTests.swift · Wenshu · v0.23 ticket 001
//
//  Five sub-agent identity contract tests for the SubAgentIdentity
//  registry (= hermes-port manifest researcher / writer / analyst /
//  archivist / auditor identities). This file was authored when the
//  wenshu-side identities still mirrored hermes Python tool slugs
//  verbatim; the v2.4 arc (skill cleanup + memory rewire) and the
//  v2.5 arc (keyless web search + hermes-port manifest reconciliation)
//  rewrote several tool lists and identity-tied system prompts:
//
//    v2.4  — memory removed from LLM-facing tool surface
//            (= Auditor now reads WSMemoryProvider.shared via the
//            direct actor path, not via an LLM tool dispatch).
//    v2.5  — researcher tools rewritten to wenshu-side slugs
//            (= web_search + reference_library); archivist no longer
//            dispatches via LLM tools (= storage adapters called
//            directly through WSBookmarkRepository.shared); writer
//            collapsed to paragraph_ai (= the only wenshu-side
//            writing tool today); analyst remains tool-less per
//            AGENTS.md §11 baseline "no placeholder/stub text".
//    v2.6  — archivist prompt identity keyword updated from
//            "long-term memory specialist" to
//            "long-term storage specialist" (= matches the v2.4
//            memory-removed stance + the storage-adapter path).
//
//  These tests assert the v2.5 / v2.6 contracts. Source-side
//  rewrites (= `SubAgentIdentity.swift` + `SubAgentIdentityPermissions`)
//  already shipped; this file aligns its expectations to the
//  shipped source (= no production code is touched in this commit).
//
//  Q112 standing rule (= 1 ticket = 1 source + 1 test commit):
//    Pure test-file addition / edit. No production source touched.
//    AGENTS.md not modified.
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("SubAgentIdentity (5 sub-agents)")
struct SubAgentIdentityTests {

    @Test("all 5 sub-agent names have system prompts")
    func allNamesHaveSystemPrompts() {
        for name in SubAgentIdentity.Name.allCases {
            let prompt = SubAgentIdentity.systemPrompt(name: name)
            #expect(!prompt.isEmpty, "missing system prompt for \(name)")
        }
    }

    @Test("all 5 sub-agent names expose a tools(name:) entry (empty list = valid; = documented below)")
    func allNamesHaveToolLists() {
        // v2.5 contract: each sub-agent returns a `tools` array. The
        // array MAY be empty (= when no LLM-side tool dispatches are
        // intended for that identity; = analyst / archivist / auditor).
        // The contract is "every Name case resolves to a known list",
        // NOT "every list is non-empty".
        //
        // Per-sub-agent empty-list rationale (= §11 baseline no-placeholder
        // + v2.4 + v2.5):
        //   researcher  ->  ["web_search", "reference_library"]         (non-empty)
        //   writer      ->  ["paragraph_ai"]                            (non-empty)
        //   analyst     ->  []                                            (no LLM tools yet)
        //   archivist   ->  []                                            (storage adapters only)
        //   auditor     ->  []                                            (memory now off the LLM tool surface)
        for name in SubAgentIdentity.Name.allCases {
            let tools = SubAgentIdentity.tools(name: name)
            // Type-check + surface area assertion: the call must succeed
            // and produce a (possibly empty) list. The list content is
            // exercised by the per-identity tests below.
            #expect(tools.count >= 0, "tools(name:) must return a list for \(name)")
            // Also verify the dict explicitly carries the v2.5+ non-researcher empty contract.
            switch name {
            case .researcher, .writer:
                #expect(!tools.isEmpty, "\(name) must have non-empty tools")
            case .analyst, .archivist, .auditor:
                #expect(tools.isEmpty, "\(name) must keep its tools list empty post-v2.5 (= §11 no-placeholder)")
            }
        }
    }

    @Test("all 5 sub-agent names have display names")
    func allNamesHaveDisplayNames() {
        for name in SubAgentIdentity.Name.allCases {
            let display = SubAgentIdentity.displayName(name: name)
            #expect(!display.isEmpty, "missing display name for \(name)")
        }
    }

    @Test("Researcher tools = web_search + reference_library (v2.5 wenshu-side slugs)")
    func researcherTools() {
        let tools = SubAgentIdentity.tools(name: .researcher)
        #expect(tools.contains("web_search"),
               "researcher must expose web_search (= KeylessRing, hermes _walk_ring 1:1 port)")
        #expect(tools.contains("reference_library"),
               "researcher must expose reference_library (= wenshu-side grounded-summary store)")
        // Hermetic guarantees: these hermes-side slugs no longer apply
        // post-v2.5 (= hermes -> wenshu-side name bridge).
        #expect(!tools.contains("search"), "legacy hermes slug 'search' not in wenshu research tools (= v2.5)")
        #expect(!tools.contains("web"), "legacy hermes slug 'web' not in wenshu research tools (= v2.5)")
        #expect(!tools.contains("linkgraph"), "linkgraph is not a wenshu LLM tool (= no equivalent yet)")
    }

    @Test("Writer tools = paragraph_ai only (the single wenshu-side writing tool)")
    func writerTools() {
        let tools = SubAgentIdentity.tools(name: .writer)
        #expect(tools == ["paragraph_ai"],
               "writer must expose ONLY paragraph_ai (= v2.5 collapse; no composer / template / wordcount stubs)")
    }

    @Test("Analyst tools = [] (no LLM tools yet; outline / bases / graph not registered)")
    func analystTools() {
        let tools = SubAgentIdentity.tools(name: .analyst)
        // Per AGENTS.md §11 baseline "no placeholder/stub text": analyst
        // exposes no LLM tool until a real outline / bases / graph surface
        // lands in ToolRegistry. The empty list is intentional, not a gap.
        #expect(tools.isEmpty,
               "analyst must NOT have placeholder LLM tools (= §11 baseline; outline / graph future ticket)")
    }

    @Test("Archivist tools = [] (bookmark / backup relocated to WSBookmarkRepository.shared + filesystem direct path)")
    func archivistTools() {
        let tools = SubAgentIdentity.tools(name: .archivist)
        // Per v2.5 + SubAgentIdentity.archivistPrompt:
        // "the bookmark / backup tools are not registered in ToolRegistry yet.
        //  When the runner wires you up, you delegate to
        //  WSBookmarkRepository.shared + filesystem directly".
        // The empty list is the v2.5 contract; = no LLM tool dispatch.
        #expect(tools.isEmpty,
               "archivist must NOT expose LLM tools (= v2.5 storage-adapter path; bookmark / backup not in ToolRegistry)")
        #expect(!tools.contains("bookmark"),
               "bookmark tool is not registered (= v2.5 storage-adapter pattern)")
        #expect(!tools.contains("backup"),
               "backup tool is not registered (= v2.5 storage-adapter pattern)")
        // Hermetic parity assertion: per hermes DELEGATE_BLOCKED_TOOLS,
        // memory writes are main-agent exclusive. Archivist's storage
        // job does NOT include memory writes (= WSMemoryProvider).
        #expect(!tools.contains("memory"),
               "memory writes are main-agent exclusive (= hermes DELEGATE_BLOCKED_TOOLS parity)")
    }

    @Test("Auditor tools = [] (memory removed from LLM-facing tool surface in v2.4)")
    func auditorTools() {
        let tools = SubAgentIdentity.tools(name: .auditor)
        // Per v2.4: memory is now off the LLM tool surface. Auditor
        // reads via WSMemoryProvider.shared (direct actor path; =
        // SubAgentRunner.runAuditorSubAgent), NOT via an LLM tool call.
        // Empty list is the v2.4 contract.
        #expect(tools.isEmpty,
               "auditor must NOT expose memory on the LLM tool surface post-v2.4 (= direct WSMemoryProvider.shared path)")
    }

    @Test("system prompts differ across all 5 agents")
    func systemPromptsDiffer() {
        var seen: Set<String> = []
        for name in SubAgentIdentity.Name.allCases {
            let prompt = SubAgentIdentity.systemPrompt(name: name)
            let hash = String(prompt.hashValue)
            #expect(!seen.contains(hash), "duplicate system prompt for \(name)")
            seen.insert(hash)
        }
    }

    @Test("each prompt mentions its agent role (v2.5 / v2.6 keywords)")
    func eachPromptMentionsRole() {
        // Identity role strings (= per SubAgentIdentity.swift static
        // prompts; = the role appears once per prompt in the
        // "# Identity / You are <Name>" header line).
        #expect(SubAgentIdentity.systemPrompt(name: .researcher).contains("search specialist"),
               "researcher identity role")
        #expect(SubAgentIdentity.systemPrompt(name: .writer).contains("writing specialist"),
               "writer identity role")
        #expect(SubAgentIdentity.systemPrompt(name: .analyst).contains("structure-analysis specialist"),
               "analyst identity role")
        // v2.6: archivist's role string was renamed from
        // "long-term memory specialist" to "long-term storage specialist"
        // (= matches the v2.4 memory-removed stance + storage-adapter
        // direct path; = the old string was a hermes-side artifact).
        #expect(SubAgentIdentity.systemPrompt(name: .archivist).contains("long-term storage specialist"),
               "archivist identity role (= v2.6 storage-specialist rename)")
        // Hermetic: the pre-v2.6 keyphrase must be gone.
        #expect(!SubAgentIdentity.systemPrompt(name: .archivist).contains("long-term memory specialist"),
               "archivist must NOT use the pre-v2.6 'memory specialist' keyphrase (= memory is no longer the focus)")
        #expect(SubAgentIdentity.systemPrompt(name: .auditor).contains("quality-gate specialist"),
               "auditor identity role")
    }

    @Test("Auditor prompt includes verdict format schema")
    func auditorPromptHasVerdictFormat() {
        let prompt = SubAgentIdentity.systemPrompt(name: .auditor)
        // Auditor system prompt carries the verdict format schema (= the
        // exact terms "pass" / "warn" / "fail" / "verdict" appear in the
        // prompt text so the LLM emits a parseable verdict envelope on
        // every audit call).
        #expect(prompt.contains("pass") || prompt.contains("PASS"),
               "auditor prompt must include 'pass' verdict")
        #expect(prompt.contains("warn") || prompt.contains("WARN"),
               "auditor prompt must include 'warn' verdict")
        #expect(prompt.contains("fail") || prompt.contains("FAIL"),
               "auditor prompt must include 'fail' verdict")
        #expect(prompt.contains("verdict"),
               "auditor prompt must mention the verdict schema")
    }

    @Test("all prompts have reasonable size (500-3000 chars)")
    func promptsReasonableSize() {
        for name in SubAgentIdentity.Name.allCases {
            let len = SubAgentIdentity.systemPrompt(name: name).count
            #expect(len > 500, "prompt too short for \(name): \(len)")
            #expect(len < 3000, "prompt too long for \(name): \(len)")
        }
    }
}
