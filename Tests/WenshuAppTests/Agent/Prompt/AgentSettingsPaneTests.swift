// AgentSettingsPaneTests.swift
//
// The pane is the only place a user can reach any of the B and C work, so
// these check the round trip: what the pane writes is what a turn reads.

import Foundation
import Testing
import SwiftUI
@testable import WenshuApp
import WenshuAgent

@Suite("Agent settings pane")
struct AgentSettingsPaneTests {

    @MainActor
    private func freshStore() -> (AgentSettingsStore, UserDefaults, String) {
        let suite = "wenshu.agent.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        return (AgentSettingsStore(defaults: defaults), defaults, suite)
    }

    @MainActor
    @Test("the pane renders without a store behind it")
    func paneRenders() {
        _ = AgentSettingsStore(defaults: UserDefaults(suiteName: "wenshu.render.\(UUID().uuidString)")!)
        _ = AgentSettingsPane().body
    }

    // MARK: - Round trip

    @MainActor
    @Test("what the store writes is what it reads back")
    func storeRoundTrips() {
        let (store, defaults, suite) = freshStore()
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }

        var settings = AgentSettings()
        settings.memory.backend = .remoteService
        settings.memory.remoteEndpoint = "https://memory.example.com"
        settings.memory.retentionDays = 30
        settings.prompt.visibleTools = ["book_chapter", "todo"]
        settings.recovery.checkStopGates = false
        settings.recovery.continueOnTruncation = false
        settings.turn.maxIterations = 40

        store.save(settings)
        let loaded = store.load()

        #expect(loaded.memory.backend == .remoteService)
        #expect(loaded.memory.remoteEndpoint == "https://memory.example.com")
        #expect(loaded.memory.retentionDays == 30)
        #expect(loaded.prompt.visibleTools == ["book_chapter", "todo"])
        #expect(loaded.recovery.checkStopGates == false)
        #expect(loaded.recovery.continueOnTruncation == false)
        #expect(loaded.turn.maxIterations == 40)
        #expect(defaults.string(forKey: "wenshu.agent.memory.backend") == "remoteService")
    }

    @MainActor
    @Test("a fresh store reads the package defaults")
    func freshStoreReadsDefaults() {
        let (store, _, suite) = freshStore()
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }
        #expect(store.load() == AgentSettings())
        #expect(store.loadEnabledPresetIDs().isEmpty)
    }

    @MainActor
    @Test("a setting introduced later reads as its default rather than failing")
    func unknownSettingsFallBackToDefaults() {
        let (store, defaults, suite) = freshStore()
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }

        // Write one field, leave the rest untouched (= what an older install
        // looks like after a version bump).
        defaults.set("remoteService", forKey: "wenshu.agent.memory.backend")
        let loaded = store.load()
        #expect(loaded.memory.backend == .remoteService)
        #expect(loaded.memory.retentionDays == MemorySettings().retentionDays)
        #expect(loaded.recovery == RecoverySettings())
        #expect(loaded.turn.maxIterations == TurnSettings().maxIterations)
    }

    @MainActor
    @Test("a corrupt stored value reads as the default rather than throwing")
    func corruptValueFallsBack() {
        let (store, defaults, suite) = freshStore()
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }
        defaults.set(Data("not json".utf8), forKey: "wenshu.agent.recovery")
        #expect(store.load().recovery == RecoverySettings())
    }

    // MARK: - Presets through the store

    @MainActor
    @Test("applying a preset writes both the tool set and the preset ids")
    func applyingPresetWritesBoth() {
        let (store, _, suite) = freshStore()
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }

        var settings = AgentSettings()
        store.applyPresets(["writing"], to: &settings)
        #expect(store.loadEnabledPresetIDs() == ["writing"])
        #expect(store.load().prompt.visibleTools.contains("todo"))
        #expect(!store.load().prompt.visibleTools.contains("process"))
    }

    @MainActor
    @Test("a preset selection reaches what the conductor asks for")
    func presetSelectionReachesTheConductor() {
        let (store, _, suite) = freshStore()
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }

        var settings = AgentSettings()
        store.applyPresets(["writing"], to: &settings)
        let loaded = store.load()
        let names = ToolCatalogue.exposedNames(settings: loaded.prompt)
        #expect(names.contains("todo"))
        #expect(!names.contains("process"))
        #expect(!names.contains("web_search"))
    }

    @MainActor
    @Test("turning on system keeps everything")
    func systemPresetKeepsEverything() {
        let (store, _, suite) = freshStore()
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }

        var settings = AgentSettings()
        store.applyPresets(["system"], to: &settings)
        let names = ToolCatalogue.exposedNames(settings: store.load().prompt)
        #expect(names.contains("process"))
        #expect(names.contains("todo"))
    }

    // MARK: - The pane is reachable

    @Test("the settings sidebar lists the agent pane")
    func agentPaneIsListed() {
        #expect(SettingView.SettingsPane.allCases.contains(.agent))
        #expect(SettingView.SettingsPane.agent.icon == "wand.and.stars")
    }

    @Test("every string the pane asks for exists in the catalog")
    func paneStringsAreLocalized() throws {
        let path = SourceLocator.path("Sources/WenshuApp/Resources/Localizable.xcstrings")
        let url = URL(fileURLWithPath: path)
        let data = try Data(contentsOf: url)
        let catalog = try JSONDecoder().decode(StringCatalog.self, from: data)
        let source = String(decoding: data, as: UTF8.self)
        let required = [
            "settings.pane.agent",
            "settings.agent.presets.title", "settings.agent.presets.footer",
            "settings.agent.tools.title", "settings.agent.tools.footer",
            "settings.agent.category.writing", "settings.agent.category.navigation",
            "settings.agent.category.research", "settings.agent.category.media",
            "settings.agent.category.system",
            "settings.agent.behaviour.title", "settings.agent.behaviour.footer",
            "settings.agent.behaviour.checkStopGates",
            "settings.agent.behaviour.continueOnTruncation",
            "settings.agent.behaviour.retryOnEmptyReply",
            "settings.agent.behaviour.maxIterations"
        ]
        for key in required {
            #expect(catalog.strings[key] != nil, "missing localization for \(key)")
            #expect(source.contains("\"\(key)\""), "\(key) is not in the catalog")
        }
    }
}

/// Minimal shape of the string catalog, so the test reads the file without
/// depending on Apple's private type.
private struct StringCatalog: Decodable {
    struct Entry: Decodable { let extractionState: String? }
    let strings: [String: Entry]
}