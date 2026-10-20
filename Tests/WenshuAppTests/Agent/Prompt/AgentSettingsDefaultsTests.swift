// AgentSettingsDefaultsTests.swift
//
// The defaults in these initialisers are the contract. A future mechanism adds
// its field here rather than hardcoding a value at the call site, so this test
// is what catches a knob that shipped with the wrong default.

import Foundation
import Testing
@testable import WenshuAgent

@Suite("Agent settings defaults")
struct AgentSettingsDefaultsTests {

    @Test("an empty settings value enables every prompt section")
    func promptDefaultsEnableEverything() {
        let settings = PromptSettings()
        #expect(settings.identityEnabled)
        #expect(settings.providerGuidanceEnabled)
        #expect(settings.memoryGuidanceEnabled)
        #expect(settings.skillGuidanceEnabled)
        #expect(settings.toolGuidanceEnabled)
        #expect(settings.helpGuidanceEnabled)
        #expect(settings.includeProjectContextFiles)
        #expect(settings.includeBookContext)
        #expect(settings.includeEnvironmentHints)
    }

    @Test("an empty tool set means every tool, not no tool")
    func emptyVisibleToolsMeansEverything() {
        #expect(PromptSettings().visibleTools.isEmpty)
    }

    @Test("a zero context-file cap means derive from the window")
    func zeroCapMeansAutomatic() {
        #expect(PromptSettings().projectContextFileMaxChars == 0)
    }

    @Test("memory defaults to the local backend")
    func memoryDefaultsToLocalMarkdown() {
        let memory = MemorySettings()
        #expect(memory.backend == .localMarkdown)
        #expect(memory.enabled)
        #expect(memory.remoteEndpoint.isEmpty, "a remote endpoint is meaningless for the local backend")
    }

    @Test("both memory backends stay available")
    func bothBackendsExist() {
        #expect(MemoryBackend.allCases.count == 2)
        #expect(MemoryBackend.allCases.contains(.localMarkdown))
        #expect(MemoryBackend.allCases.contains(.remoteService))
    }

    @Test("aggregate settings compose from per-subsystem defaults")
    func aggregateMatchesPerSubsystemDefaults() {
        #expect(AgentSettings().prompt == PromptSettings())
        #expect(AgentSettings().turn == TurnSettings())
        #expect(AgentSettings().context == ContextSettings())
        #expect(AgentSettings().recovery == RecoverySettings())
        #expect(AgentSettings().memory == MemorySettings())
        #expect(AgentSettings().tools == ToolSettings())
    }

    @Test("changing one subsystem leaves the others at their defaults")
    func subsystemsAreIndependent() {
        var settings = AgentSettings()
        settings.memory.backend = .remoteService
        #expect(settings.memory.backend == .remoteService)
        #expect(settings.prompt == PromptSettings())
        #expect(settings.turn == TurnSettings())
    }

    @Test("the package reads no UserDefaults for agent behaviour")
    func packageDoesNotOwnPersistence() {
        // The settings types are plain values on purpose: the app layer owns
        // storage and injection. Two keys written from here would prove the
        // package had started reaching for global state.
        let before = UserDefaults.standard.string(forKey: "wenshu.memory.retentionDays")
        var settings = MemorySettings()
        settings.retentionDays = 7
        #expect(settings.retentionDays == 7)
        #expect(UserDefaults.standard.string(forKey: "wenshu.memory.retentionDays") == before)
    }

    @Test("settings are Sendable so a runtime can hold them across actors")
    func settingsCrossActorBoundaries() {
        func requireSendable<T: Sendable>(_ value: T) -> T { value }
        #expect(requireSendable(AgentSettings()) == AgentSettings())
        #expect(requireSendable(TurnNotes()) == TurnNotes())
        #expect(requireSendable(PromptAssembly()) == PromptAssembly())
    }
}