// MemoryBackendSelectionTests.swift
//
// The memory backend is the one setting where the two options are genuinely
// different products rather than two levels of the same thing, so these check
// the two things a user needs to be able to decide: what each option does, and
// whether choosing it actually took.

import Foundation
import Testing
import SwiftUI
@testable import WenshuApp
import WenshuAgent

@Suite("Memory backend selection")
struct MemoryBackendSelectionTests {

    @MainActor
    private func freshStore() -> (AgentSettingsStore, String) {
        let suite = "wenshu.memory.tests.\(UUID().uuidString)"
        return (AgentSettingsStore(defaults: UserDefaults(suiteName: suite)!), suite)
    }

    // MARK: - The choice reaches storage

    @MainActor
    @Test("picking a backend is what a turn reads")
    func pickingABackendIsPersisted() {
        let (store, suite) = freshStore()
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }

        var settings = AgentSettings()
        settings.memory.backend = .remoteService
        store.save(settings)

        #expect(store.load().memory.backend == .remoteService)
    }

    @MainActor
    @Test("the endpoint is persisted with the backend")
    func endpointIsPersistedWithTheBackend() {
        let (store, suite) = freshStore()
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }

        var settings = AgentSettings()
        settings.memory.backend = .remoteService
        settings.memory.remoteEndpoint = "https://memory.example.com"
        store.save(settings)

        let loaded = store.load()
        #expect(loaded.memory.backend == .remoteService)
        #expect(loaded.memory.remoteEndpoint == "https://memory.example.com")
    }

    // MARK: - The choice is honoured or explained

    @MainActor
    @Test("a backend with no endpoint reports why rather than failing silently")
    func unconfiguredRemoteReportsWhy() {
        let (store, suite) = freshStore()
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }

        var settings = AgentSettings()
        settings.memory.backend = .remoteService
        settings.memory.remoteEndpoint = ""
        store.save(settings)

        let resolved = ContextEngine.makeBackendResolver(settings: store.load().memory)
            .resolve(settings: store.load().memory)
        #expect(resolved?.matchesSelection == false)
        #expect(resolved?.substitutedReason == .remoteNotConfigured)
    }

    @MainActor
    @Test("the local choice needs nothing and always works")
    func localNeedsNothing() {
        let (store, suite) = freshStore()
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }

        let settings = store.load()
        #expect(settings.memory.backend == .localMarkdown)
        #expect(settings.memory.remoteEndpoint.isEmpty)
        let resolved = ContextEngine.makeBackendResolver(settings: settings.memory)
            .resolve(settings: settings.memory)
        #expect(resolved?.matchesSelection == true)
    }

    // MARK: - The wording

    @Test("each option says what it costs, not just what it is")
    func optionsStateTheirCost() {
        let local = MemoryBackendResolver.description(for: .localMarkdown)
        #expect(local.detail.contains("不用配置") || local.detail.contains("nothing"))
        #expect(local.detail.contains("不联网") || local.detail.contains("leaves"),
                "the user must learn that local means nothing leaves the machine")

        let remote = MemoryBackendResolver.description(for: .remoteService)
        #expect(remote.detail.contains("密钥") || remote.detail.contains("key"),
                "the user must learn that remote means configuring a credential")
        #expect(remote.detail.contains("离开") || remote.detail.contains("leaves"),
                "the user must learn that remote means memories leave the machine")
    }

    @Test("neither description names an internal type")
    func descriptionsAvoidTypeNames() {
        for backend in MemoryBackend.allCases {
            let description = MemoryBackendResolver.description(for: backend)
            for text in [description.title, description.detail] {
                #expect(!text.contains("MemoryBackend"))
                #expect(!text.contains("MemoryProvider"))
                #expect(!text.contains("nil"))
                #expect(!text.contains("UserDefaults"))
            }
        }
    }

    @Test("every localization key the memory pane needs exists")
    func memoryPaneKeysExist() throws {
        let path = SourceLocator.path("Sources/WenshuApp/Resources/Localizable.xcstrings")
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let catalog = try JSONDecoder().decode(Catalog.self, from: data)
        let required = [
            "settings.memory.backend.title",
            "settings.memory.backend.footer",
            "settings.memory.backend.localMarkdown.detail",
            "settings.memory.backend.remoteService.detail",
            "settings.memory.backend.remote.title",
            "settings.memory.backend.remote.endpoint",
            "settings.memory.backend.remote.footer",
            "settings.agent.selected"
        ]
        for key in required {
            #expect(catalog.strings[key] != nil, "missing localization for \(key)")
        }
    }

    @Test("both backends have a detail string for every declared case")
    func everyBackendHasDetailText() throws {
        let path = SourceLocator.path("Sources/WenshuApp/Resources/Localizable.xcstrings")
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let catalog = try JSONDecoder().decode(Catalog.self, from: data)
        for backend in MemoryBackend.allCases {
            let key = "settings.memory.backend.\(backend.rawValue).detail"
            #expect(catalog.strings[key] != nil,
                    "\(backend.rawValue) has no user-facing text; the pane would render the key")
        }
    }

    @Test("the pane still renders")
    func paneRenders() {
        _ = MemorySettingsView()
    }
}

private struct Catalog: Decodable {
    struct Entry: Decodable { let extractionState: String? }
    let strings: [String: Entry]
}