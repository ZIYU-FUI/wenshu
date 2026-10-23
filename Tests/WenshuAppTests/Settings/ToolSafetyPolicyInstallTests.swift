import Foundation
import Testing
import WenshuAgent
@testable import WenshuApp

/// The app's half of the tool-safety policy: the facts the app owns are
/// installed where the package's rules read them.
@Suite("The app installs the tool-safety policy")
@MainActor
struct ToolSafetyPolicyInstallTests {

    private func makeStore() -> (AgentSettingsStore, UserDefaults) {
        let suiteName = "wenshu.tests.toolsafety.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        return (AgentSettingsStore(defaults: defaults), defaults)
    }

    @Test("Loading the settings installs the mutating tools from the catalogue")
    func loadInstallsTheMutatingTools() {
        let (store, defaults) = makeStore()
        defer { defaults.removePersistentDomain(forName: defaults.description) }

        _ = store.load()

        let expected = Set(
            ToolCatalogue.all.filter { $0.mutates }.map { $0.name }
        )
        #expect(!expected.isEmpty, "the catalogue flags mutating tools")
        #expect(
            ToolSafetyPolicy.values.mutatingToolNames == expected,
            "the installed mutating set must be the catalogue's"
        )
    }

    @Test("The approval setting is installed, and it changes the refusal")
    func approvalSettingIsInstalled() {
        let (store, defaults) = makeStore()
        defer { defaults.removePersistentDomain(forName: defaults.description) }

        var settings = AgentSettings()
        settings.tools.autoApprove = false
        store.save(settings)
        _ = store.load()
        #expect(
            ToolSafetyPolicy.values.autoApprove == false,
            "the default must not approve the hazard class"
        )
        #expect(
            ToolSafetyPolicy.refusal(toolName: "process") != nil,
            "the hazard class must be refused by default"
        )

        settings.tools.autoApprove = true
        store.save(settings)
        _ = store.load()
        #expect(
            ToolSafetyPolicy.values.autoApprove == true,
            "the user's choice must reach the runtime"
        )
        #expect(
            ToolSafetyPolicy.refusal(toolName: "process") == nil,
            "an approved hazard class must run"
        )
    }

    @Test("The unbounded tools are named")
    func unboundedToolsAreNamed() {
        let (store, defaults) = makeStore()
        defer { defaults.removePersistentDomain(forName: defaults.description) }

        _ = store.load()
        #expect(
            ToolSafetyPolicy.values.unboundedToolNames.contains("web_search"),
            "a search is unbounded and must be capped"
        )
    }
}
