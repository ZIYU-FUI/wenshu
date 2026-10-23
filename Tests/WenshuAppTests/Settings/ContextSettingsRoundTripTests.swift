//
//  ContextSettingsRoundTripTests.swift · Wenshu
//
//  The rule under test: the numbers the user saved in the settings screen
//  are the numbers the package's runtime uses.
//
//  The persistence half (= the settings store reads back what the screen
//  wrote) lives here. The runtime half (= the compressor and the recall
//  reading the numbers) is proven in the package suite,
//  `ContextOverridesTests`.
//
//  Before this change the store read the four numbers back and nothing
//  read them afterwards: the screen was not lying about the values, it was
//  lying about their EFFECT.
//

import Foundation
import Testing
import WenshuAgent
@testable import WenshuApp

@Suite("Context settings round trip")
struct ContextSettingsRoundTripTests {

    @MainActor
    private func freshStore() -> (AgentSettingsStore, String) {
        let suite = "wenshu.context.settings.tests.\(UUID().uuidString)"
        return (AgentSettingsStore(defaults: UserDefaults(suiteName: suite)!), suite)
    }

    /// The holder is one process-wide value, so a test restores what it
    /// found before it returns.
    @MainActor
    private func withInstalledNumbers(_ body: () -> Void) {
        let previous = ContextOverrides.values
        defer { ContextOverrides.install(previous) }
        body()
    }

    @MainActor
    @Test("the saved compression numbers reach the runtime")
    func savedCompressionNumbersReachTheRuntime() {
        let (store, suite) = freshStore()
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }

        var settings = AgentSettings()
        settings.context.compressionThreshold = 0.42
        settings.context.compressionKeepRatio = 0.75

        withInstalledNumbers {
            store.save(settings)
            #expect(ContextOverrides.compressionThreshold == 0.42,
                    "the threshold the user saved is the threshold the compressor uses")
            #expect(ContextOverrides.keepFraction == 0.75,
                    "the keep ratio the user saved is the ratio the compressor keeps")
        }
    }

    @MainActor
    @Test("the saved memory cap reaches the runtime")
    func savedMemoryCapReachesTheRuntime() {
        let (store, suite) = freshStore()
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }

        var settings = AgentSettings()
        settings.memory.maxEntries = 17

        withInstalledNumbers {
            store.save(settings)
            #expect(ContextOverrides.memoryCap == 17,
                    "the cap the user saved is the cap the recall uses")
        }
    }

    @MainActor
    @Test("the saved numbers survive a reload")
    func savedNumbersSurviveAReload() {
        let (store, suite) = freshStore()
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }

        var settings = AgentSettings()
        settings.context.compressionThreshold = 0.61
        settings.context.compressionKeepRatio = 0.24
        settings.memory.maxEntries = 9
        store.save(settings)

        let loaded = store.load()
        #expect(loaded.context.compressionThreshold == 0.61)
        #expect(loaded.context.compressionKeepRatio == 0.24)
        #expect(loaded.memory.maxEntries == 9)
    }
}
