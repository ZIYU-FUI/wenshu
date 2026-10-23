//
//  PromptSettingsRoundTripTests.swift
//
//  The persistence half of the prompt guidance: what the user flipped in
//  the settings screen is what the next turn reads.
//
//  The consumption half (= the tier builder obeying those values) is
//  proven in the package suite, `PromptGuidanceReachesThePromptTests`.
//

import Foundation
import Testing
@testable import WenshuApp
import WenshuAgent

@Suite("Prompt settings round trip")
struct PromptSettingsRoundTripTests {

    @MainActor
    private func freshStore() -> (AgentSettingsStore, String) {
        let suite = "wenshu.prompt.settings.tests.\(UUID().uuidString)"
        return (AgentSettingsStore(defaults: UserDefaults(suiteName: suite)!), suite)
    }

    @MainActor
    @Test("every prompt switch survives a save and a load")
    func switchesRoundTrip() {
        let (store, suite) = freshStore()
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }

        var settings = AgentSettings()
        settings.prompt.identityEnabled = false
        settings.prompt.providerGuidanceEnabled = false
        settings.prompt.memoryGuidanceEnabled = false
        settings.prompt.skillGuidanceEnabled = false
        settings.prompt.toolGuidanceEnabled = false
        settings.prompt.helpGuidanceEnabled = false
        settings.prompt.includeProjectContextFiles = false
        settings.prompt.includeBookContext = false
        settings.prompt.includeEnvironmentHints = false
        settings.prompt.projectContextFileMaxChars = 12_345

        store.save(settings)
        let loaded = store.load()

        #expect(loaded.prompt.identityEnabled == false)
        #expect(loaded.prompt.providerGuidanceEnabled == false)
        #expect(loaded.prompt.memoryGuidanceEnabled == false)
        #expect(loaded.prompt.skillGuidanceEnabled == false)
        #expect(loaded.prompt.toolGuidanceEnabled == false)
        #expect(loaded.prompt.helpGuidanceEnabled == false)
        #expect(loaded.prompt.includeProjectContextFiles == false)
        #expect(loaded.prompt.includeBookContext == false)
        #expect(loaded.prompt.includeEnvironmentHints == false)
        #expect(loaded.prompt.projectContextFileMaxChars == 12_345)
    }

    @MainActor
    @Test("a store with nothing written reads the package defaults")
    func freshStoreReadsDefaults() {
        let (store, suite) = freshStore()
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }
        #expect(store.load().prompt == PromptSettings())
    }

    @MainActor
    @Test("a switch written by an older install reads as its default")
    func anOlderInstallReadsTheDefault() {
        let suite = "wenshu.prompt.settings.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let store = AgentSettingsStore(defaults: defaults)
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }

        // One field written, the rest untouched (= what an install that
        // predates a switch looks like after a version bump).
        defaults.set(false, forKey: "wenshu.agent.prompt.identityEnabled")
        let loaded = store.load()
        #expect(loaded.prompt.identityEnabled == false)
        #expect(loaded.prompt.memoryGuidanceEnabled == PromptSettings().memoryGuidanceEnabled)
    }

    @MainActor
    @Test("a corrupt switch reads as the default rather than throwing")
    func corruptSwitchFallsBack() {
        let suite = "wenshu.prompt.settings.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let store = AgentSettingsStore(defaults: defaults)
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }

        defaults.set("nope", forKey: "wenshu.agent.prompt.identityEnabled")
        #expect(store.load().prompt.identityEnabled == PromptSettings().identityEnabled)
    }

    @MainActor
    @Test("the saved switch is the one the turn reads")
    func theSavedSwitchIsWhatTheTurnReads() {
        let (store, suite) = freshStore()
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }

        var settings = AgentSettings()
        settings.prompt.identityEnabled = false
        store.save(settings)

        // The turn reads the settings the store produced, and the tier
        // obeys them: the identity block is gone.
        let tier = PromptTierBuilder.stableTier(
            settings: store.load().prompt,
            provider: .unknown,
            locale: .english
        )
        #expect(!tier.contains("You are an AI assistant"))
    }
}
