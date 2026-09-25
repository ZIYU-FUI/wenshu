//
//  AgentBehaviorTests.swift · Wenshu · v2.4 (2026-09-25)
//
//  Tests for the v2.4 agent-behavior settings pane.
//
//  Verifies:
//  - SpeakingStyle enum roundtrips through rawValue.
//  - AgentBehavior.currentSpeakingStyle() returns the default
//    (.literary) when UserDefaults is empty.
//  - AgentBehavior.setCurrentSpeakingStyle() persists the choice
//    so a subsequent currentSpeakingStyle() read returns it.
//  - SystemPrompt.stableTier() honors the speaking style preset
//    (= the system prompt contains the per-style promptGuidance
//    string after switching).
//  - Reading stable tier without a stored setting defaults to
//    .literary (= wenshu's canonical writing-tool register).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("AgentBehavior (v2.4)")
struct AgentBehaviorTests {

    // MARK: - SpeakingStyle enum

    @Test func speakingStyle_allCasesRoundtripThroughRawValue() {
        for style in SpeakingStyle.allCases {
            #expect(SpeakingStyle(rawValue: style.rawValue) == style)
        }
    }

    @Test func speakingStyle_eachStyleHasDistinctLabel() {
        let labels = SpeakingStyle.allCases.map(\.label)
        #expect(Set(labels).count == labels.count)
    }

    @Test func speakingStyle_eachStyleHasDistinctPromptGuidance() {
        let guidance = SpeakingStyle.allCases.map(\.promptGuidance)
        #expect(Set(guidance).count == guidance.count)
    }

    @Test func speakingStyle_promptGuidanceIncludesStyleKeyword() {
        // LLM-side stable contract: every prompt guidance string
        // must include "Speaking style:" + the style's English
        // keyword so the LLM picks up the register reliably.
        let expectedKeywords: [(SpeakingStyle, String)] = [
            (.formal,   "formal"),
            (.casual,   "casual"),
            (.literary, "literary"),
            (.concise,  "concise")
        ]
        for (style, keyword) in expectedKeywords {
            let guidance = style.promptGuidance
            #expect(guidance.contains("Speaking style:"))
            #expect(guidance.contains(keyword))
        }
    }

    // MARK: - UserDefaults bridge

    /// Make a per-test isolated UserDefaults so cross-test
    /// mutations don't leak (= the production code reads
    /// `.standard` via a default param; = tests pass an
    /// explicit `defaults` instance).
    private func makeIsolatedDefaults() -> UserDefaults {
        let suiteName = "wenshu-test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        // Aggressively remove to avoid test cross-pollution.
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    @Test func currentSpeakingStyle_defaultsToLiterary() {
        let defaults = makeIsolatedDefaults()
        let style = AgentBehavior.currentSpeakingStyle(defaults: defaults)
        #expect(style == .literary)
    }

    @Test func currentSpeakingStyle_readsPersistedValue() {
        let defaults = makeIsolatedDefaults()
        AgentBehavior.setCurrentSpeakingStyle(.concise, defaults: defaults)
        let read = AgentBehavior.currentSpeakingStyle(defaults: defaults)
        #expect(read == .concise)
    }

    @Test func currentSpeakingStyle_fallsBackToLiteraryOnGarbageRawValue() {
        let defaults = makeIsolatedDefaults()
        defaults.set("not-a-valid-style", forKey: AgentBehavior.speakingStyleKey)
        let read = AgentBehavior.currentSpeakingStyle(defaults: defaults)
        #expect(read == .literary)
    }

    @Test func setCurrentSpeakingStyle_overwritesPreviousValue() {
        let defaults = makeIsolatedDefaults()
        AgentBehavior.setCurrentSpeakingStyle(.formal, defaults: defaults)
        #expect(AgentBehavior.currentSpeakingStyle(defaults: defaults) == .formal)
        AgentBehavior.setCurrentSpeakingStyle(.casual, defaults: defaults)
        #expect(AgentBehavior.currentSpeakingStyle(defaults: defaults) == .casual)
    }

    // MARK: - SystemPrompt integration

    @Test func systemPrompt_defaultStableTierUsesLiteraryStyleGuidance() {
        let prompt = SystemPrompt.stableTier(
            provider: .unknown,
            locale: .english,
            memoryGuidance: false,
            sessionSearchGuidance: false,
            skillGuidance: false,
            kanbanGuidance: nil,
            parallelToolGuidance: true,
            taskCompletionGuidance: true,
            speakingStyle: .literary
        )
        // The literary guidance must appear somewhere in the
        // rendered system prompt.
        #expect(prompt.contains(SpeakingStyle.literary.promptGuidance))
    }

    @Test func systemPrompt_stableTierHonorsExplicitSpeakingStyle() {
        // When we ask for .concise explicitly (= the parameter
        // default is .literary but a caller can override), the
        // prompt must include the concise guidance and NOT the
        // literary one.
        let prompt = SystemPrompt.stableTier(
            provider: .unknown,
            locale: .english,
            memoryGuidance: false,
            sessionSearchGuidance: false,
            skillGuidance: false,
            kanbanGuidance: nil,
            parallelToolGuidance: true,
            taskCompletionGuidance: true,
            speakingStyle: .concise
        )
        #expect(prompt.contains(SpeakingStyle.concise.promptGuidance))
        #expect(!prompt.contains(SpeakingStyle.literary.promptGuidance))
    }

    @Test func systemPrompt_stableTierSwitchesStyleByChangingParameter() {
        let formal = SystemPrompt.stableTier(
            provider: .unknown,
            locale: .english,
            memoryGuidance: false,
            sessionSearchGuidance: false,
            skillGuidance: false,
            kanbanGuidance: nil,
            parallelToolGuidance: true,
            taskCompletionGuidance: true,
            speakingStyle: .formal
        )
        let casual = SystemPrompt.stableTier(
            provider: .unknown,
            locale: .english,
            memoryGuidance: false,
            sessionSearchGuidance: false,
            skillGuidance: false,
            kanbanGuidance: nil,
            parallelToolGuidance: true,
            taskCompletionGuidance: true,
            speakingStyle: .casual
        )
        #expect(formal.contains(SpeakingStyle.formal.promptGuidance))
        #expect(casual.contains(SpeakingStyle.casual.promptGuidance))
        // Different styles must produce different system prompts.
        #expect(formal != casual)
    }

    @Test func systemPrompt_stableTierPreservesBaseIdentityAcrossStyleChanges() {
        // Setting a different speaking style must NOT strip the
        // canonical identity block (= the locale-aware base
        // prompt that tells the LLM it's an embedded 文枢
        // assistant).
        let baseline = SystemPrompt.stableTier(
            provider: .unknown,
            locale: .english,
            memoryGuidance: false,
            sessionSearchGuidance: false,
            skillGuidance: false,
            kanbanGuidance: nil,
            parallelToolGuidance: true,
            taskCompletionGuidance: true,
            speakingStyle: .literary
        )
        let changed = SystemPrompt.stableTier(
            provider: .unknown,
            locale: .english,
            memoryGuidance: false,
            sessionSearchGuidance: false,
            skillGuidance: false,
            kanbanGuidance: nil,
            parallelToolGuidance: true,
            taskCompletionGuidance: true,
            speakingStyle: .concise
        )
        // Both must mention 文枢 (= the canonical identity).
        #expect(baseline.contains("文枢"))
        #expect(changed.contains("文枢"))
    }
}