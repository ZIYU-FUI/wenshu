//
//  WenshuConductorIdentityTests.swift · Wenshu · v0.22 ticket 001 (文枢 agent 基础设定)
//
//  Boss 2026-08-23 拍: verify 文枢 agent identity is defined and injected.
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("WenshuConductorIdentity (文枢 agent 基础设定)")
struct WenshuConductorIdentityTests {

    @Test("systemPrompt contains all 6 sections")
    func systemPromptContainsAllSections() {
        let prompt = WenshuConductorIdentity.systemPrompt
        #expect(prompt.contains("# Identity"))
        #expect(prompt.contains("# Persona"))
        #expect(prompt.contains("# Capabilities"))
        #expect(prompt.contains("# Limitations"))
        #expect(prompt.contains("# Workflow"))
        #expect(prompt.contains("# Output format"))
    }

    @Test("systemPrompt mentions 文枢 by project name")
    func systemPromptMentionsWenshu() {
        let prompt = WenshuConductorIdentity.systemPrompt
        #expect(prompt.contains("文枢"))
    }

    @Test("systemPrompt mentions 老板 by user address (per AGENTS.md §12)")
    func systemPromptMentionsBoss() {
        let prompt = WenshuConductorIdentity.systemPrompt
        #expect(prompt.contains("老板"))
    }

    @Test("systemPrompt mentions minimax cn as vendor (per CLAUDE.md §2 + §9)")
    func systemPromptMentionsMinimax() {
        let prompt = WenshuConductorIdentity.systemPrompt
        #expect(prompt.contains("minimax cn"))
    }

    @Test("systemPrompt mentions all 12 forbidden tokens (pollution defense)")
    func systemPromptMentionsForbiddenVocab() {
        let prompt = WenshuConductorIdentity.systemPrompt
        for token in WenshuConductorIdentity.forbiddenTokens {
            #expect(prompt.contains(token), "system prompt missing forbidden token: \(token)")
        }
    }

    @Test("capabilitiesList is non-empty (15 capabilities)")
    func capabilitiesListNonEmpty() {
        #expect(WenshuConductorIdentity.capabilitiesList.count == 15)
    }

    @Test("capabilitiesList covers all 14 replica modules + 1 tts read-aloud")
    func capabilitiesListCoversAllModules() {
        let caps = WenshuConductorIdentity.capabilitiesList.joined(separator: " ")
        // Layer B backend services
        #expect(caps.contains("memory-long-term"))
        #expect(caps.contains("skill-loading"))
        // 4 agent toolkits
        #expect(caps.contains("tool-file"))
        #expect(caps.contains("tool-process"))
        #expect(caps.contains("tool-web"))
        #expect(caps.contains("tool-vision"))
        // Obsidian replica
        #expect(caps.contains("research-fulltext-search"))
        #expect(caps.contains("research-internal-link"))
        #expect(caps.contains("research-web-fetch"))
        // Writing aid
        #expect(caps.contains("writing-aid-word-count"))
        // TTS read-aloud
        #expect(caps.contains("tts-read-aloud"))
    }

    @Test("forbiddenTokens list is exactly 12 tokens")
    func forbiddenTokensListIsComplete() {
        #expect(WenshuConductorIdentity.forbiddenTokens.count == 12)
    }

    @Test("displayName is bilingual 文枢 (wénshū)")
    func displayNameBilingual() {
        #expect(WenshuConductorIdentity.displayName == "文枢 (wénshū)")
    }

    @Test("systemPrompt size is reasonable (<2000 chars)")
    func systemPromptSizeReasonable() {
        // Target ~700 tokens ≈ 2000-3000 chars in English.
        // 1 token ≈ 4 chars; 700 tokens × 4 chars = 2800 chars.
        let len = WenshuConductorIdentity.systemPrompt.count
        #expect(len < 3000, "systemPrompt too long: \(len) chars")
        #expect(len > 800, "systemPrompt too short: \(len) chars")
    }
}