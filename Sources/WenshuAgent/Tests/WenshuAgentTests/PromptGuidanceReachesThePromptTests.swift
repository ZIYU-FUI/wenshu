//
//  PromptGuidanceReachesThePromptTests.swift
//
//  The rule under test: the switch the user flipped is the switch the
//  prompt obeys.
//
//  Before this change the ten switches in `PromptSettings` were stored,
//  shown nowhere, and read by nothing. The tier was assembled from fixed
//  values, and the base turn path did not even pass the settings down.
//
//  These tests drive the RUNTIME CONSUMER (= the tier builder, and the
//  turn that assembles the prompt), because a test that only checks the
//  settings struct proves nothing: the struct is a value, and it does not
//  know what the prompt says.
//

import Foundation
import Testing
@testable import WenshuAgent

@Suite("Prompt guidance reaches the prompt")
struct PromptGuidanceReachesThePromptTests {

    private func tier(_ settings: PromptSettings) -> String {
        PromptTierBuilder.stableTier(
            settings: settings,
            provider: .unknown,
            locale: .english
        )
    }

    // MARK: - The switches

    @Test("the identity block is gone when the user turned it off")
    func identitySwitchRemovesTheBlock() {
        var settings = PromptSettings()
        settings.identityEnabled = false
        #expect(!tier(settings).contains("You are an AI assistant"))
        #expect(tier(PromptSettings()).contains("You are an AI assistant"))
    }

    @Test("the provider notes are gone when the user turned them off")
    func providerGuidanceSwitchRemovesTheBlock() {
        var settings = PromptSettings()
        settings.providerGuidanceEnabled = false
        #expect(!tier(settings).contains("Operational notes"))
    }

    @Test("the memory notes are gone when the user turned them off")
    func memoryGuidanceSwitchRemovesTheBlock() {
        var settings = PromptSettings()
        settings.memoryGuidanceEnabled = false
        #expect(!tier(settings).contains("Memory guidance"))
    }

    @Test("the knowledge notes are gone when the user turned them off")
    func knowledgeGuidanceSwitchRemovesTheBlock() {
        var settings = PromptSettings()
        settings.skillGuidanceEnabled = false
        #expect(!tier(settings).contains("Knowledge guidance"))
    }

    @Test("the tool notes are gone when the user turned them off")
    func toolGuidanceSwitchRemovesTheBlock() {
        var settings = PromptSettings()
        settings.toolGuidanceEnabled = false
        #expect(!tier(settings).contains("Parallel-tool-call guidance"))
    }

    @Test("the project-conventions pointer is gone when the user turned it off")
    func helpGuidanceSwitchRemovesTheBlock() {
        var settings = PromptSettings()
        settings.helpGuidanceEnabled = false
        // The help block points at the documentation; the project context
        // block also mentions conventions, so the marker must be the one
        // only the help block carries.
        #expect(!tier(settings).contains("You run on Wenshu"))
    }

    @Test("the environment notes are gone when the user turned them off")
    func environmentHintsSwitchRemovesTheBlock() {
        var settings = PromptSettings()
        settings.includeEnvironmentHints = false
        #expect(!tier(settings).contains("## Environment"))
    }

    @Test("the book title is gone when the user turned the book off")
    func bookContextSwitchRemovesTheTitle() {
        var settings = PromptSettings()
        settings.includeBookContext = false
        let without = PromptTierBuilder.stableTier(
            settings: settings,
            provider: .unknown,
            locale: .english,
            bookTitle: "The Silent Harbor"
        )
        #expect(!without.contains("The Silent Harbor"))
    }

    @Test("the book title is there when the user left the book on")
    func bookContextSwitchKeepsTheTitle() {
        let with = PromptTierBuilder.stableTier(
            settings: PromptSettings(),
            provider: .unknown,
            locale: .english,
            bookTitle: "The Silent Harbor"
        )
        #expect(with.contains("The Silent Harbor"))
    }

    // MARK: - The tier is still a tier

    @Test("the tier is byte-stable for the same settings")
    func tierIsByteStable() {
        let settings = PromptSettings()
        #expect(tier(settings) == tier(settings))
    }

    @Test("the tier names the provider the runtime is on")
    func tierNamesTheProvider() {
        let prompt = PromptTierBuilder.stableTier(
            settings: PromptSettings(),
            provider: .anthropic,
            locale: .english
        )
        #expect(prompt.contains("Operational notes (Anthropic Claude family)"))
    }

    // MARK: - The guidance names what exists

    @Test("the guidance names no tool the model was not given")
    func guidanceNamesNoMissingTool() {
        let prompt = tier(PromptSettings())
        // A prompt that tells the model to call a tool it was not given
        // produces a call that fails, so the wording must follow the
        // tools wenshu actually has.
        #expect(!prompt.contains("session_search"))
        #expect(!prompt.contains("skill_manage"))
        #expect(prompt.contains("reference_library"))
    }
}
