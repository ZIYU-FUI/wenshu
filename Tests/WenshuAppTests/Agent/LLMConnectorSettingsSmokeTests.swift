//
//  LLMConnectorSettingsSmokeTests.swift · Wenshu · §11.2 connector-profile gap-fill
//
//  Smoke test: verify the Settings -> LLM Connector picker (= the
//  LLMConnectorSettingsView backed by `ConnectorProfileState.allDefaults`)
//  contains ALL 7 LLM connector profiles per AGENTS.md §11.2:
//
//    1. anthropic
//    2. openai-codex
//    3. minimax-cn
//    4. deepseek
//    5. gemini
//    6. ollama
//    7. openrouter
//
//  This is the single-source-of-truth that the Settings pane is wired
//  to the §11.2 profile matrix. If any future refactor drops a profile
//  from `allDefaults`, the Settings pane will silently lose that entry
//  and this test will fail.
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("LLMConnectorSettingsView smoke (§11.2 gap-fill)")
struct LLMConnectorSettingsSmokeTests {

    @Test("ConnectorProfileState.allDefaults contains all 7 §11.2 profile slugs")
    func testAllDefaultsContainsAllSevenSlugs() {
        let defaults = ConnectorProfileState.allDefaults
        let slugs = Set(defaults.map { $0.provider.slug })

        let required: Set<String> = [
            "anthropic",
            "openai-codex",
            "minimax-cn",
            "deepseek",
            "gemini",
            "ollama",
            "openrouter"
        ]

        #expect(slugs == required,
                "Expected all 7 §11.2 slugs in ConnectorProfileState.allDefaults. Missing: \(required.subtracting(slugs)). Extra: \(slugs.subtracting(required)).")
    }

    @Test("ConnectorProfileState.allDefaults has 7 entries (= AGENTS.md §11.2 row count)")
    func testAllDefaultsHasSevenEntries() {
        #expect(ConnectorProfileState.allDefaults.count == 7)
    }

    @Test("Default active connector is 'anthropic' (highest-tier per §11.2)")
    func testDefaultActiveConnector() {
        let view = LLMConnectorSettingsView()
        #expect(view.activeConnectorID == "anthropic")
    }
}
