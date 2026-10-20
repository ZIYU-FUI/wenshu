//
//  TriggerClosureWiringTests.swift · Wenshu · HERMES-AGENT-SMC-READYNESS
//
//  Focused tests verifying the production wiring for the audit's
// .
//
//  Tests:
//    1. palette seeder populates the 35 hub commands (= M2 fix)
//    2. palette seeder populates 5 sub-agent entries (= M2 fix)
//    3. palette seeder populates zone-toggle entries (= M2 fix)
//    4. palette seeder populates Settings section entries (= M2 fix)
//    5. SkillKeywordBootstrap registers the 35 hub commands (= M1 fix)
//    6. SkillKeywordBootstrap enables natural-language alias match (= M1 fix)
//    7. production conductor wires ToolRegistry.shared (= M5 fix)
//    8. activeLLMConnector returns a usable connector for any slug (= M14 fix)
//    9. palette dynamic-zone entry dispatches .navigateTo("kanban") (= M3 fix)
//

import Foundation
import SwiftData
import Testing
import WenshuAgent
import WenshuData
@testable import WenshuApp

@Suite("HERMES-AGENT-SMC-READYNESS — production trigger wiring")
struct TriggerClosureWiringTests {
    /// Per-test in-memory SwiftData container (= tests don't share state via
    /// WSPersistenceContainer.shared). Each WSKanbanRepository is its own
    /// @MainActor-isolated object with its own ModelContext.
    ///  migration from KanbanStore actor.
    @MainActor
    private static func makeKanbanRepository() throws -> WSKanbanRepository {
        let container = try WSPersistenceContainer.makeInMemoryContainer()
        return WSKanbanRepository(container: container)
    }

    @Test("production WenshuConductor builds tools from ToolRegistry.shared (not an empty dict)")
    @MainActor
    func testProductionConductor_toolsDictIncludesToolRegistryEntries() async throws {
        let registry = ToolRegistry.shared
        // HERMES-AGENT-SMC-READYNESS v0.41 fix: trigger the production
        // tool-bootstrap path (= fire each tool file's
        // `public static let _registryBootstrap` lazy init) so the
        // test environment mirrors what the AppKit binary does at
        // launch. Per ToolRegistryEndToEndTests.swift header (= the
        // established v0.40 test pattern), these static lets only
        // fire on first type access; a test that does NOT reference
        // the tool types will see an empty registry and falsely
        // report "production wiring broken". Mirroring production
        // = referencing each known tool type's bootstrap exactly
        // the way `applicationDidFinishLaunching` does.
        _ = ReadFileTool._registryBootstrap
        _ = WriteFileTool._registryBootstrap
        _ = AVMediaTools._registryBootstrap
        _ = BookManagerTool._registryBootstrap
        _ = FileTools._registryBootstrap
        _ = KanbanStoreTool._registryBootstrap
        _ = ProcessTools._registryBootstrap
        _ = TodoStoreTool._registryBootstrap
        _ = HermesTodoTool._registryBootstrap
        _ = VisionTools._registryBootstrap
        _ = WebTools._registryBootstrap
        // Allow the fire-and-forget `Task { await register(...) }`
        // blocks to schedule. 50 ms matches `toolRegistryWarmupMs`
        // (= the same window `buildTools(from:)` uses).
        try? await Task.sleep(nanoseconds: 50_000_000)
        let allNames = await registry.getAllToolNames()
        #expect(allNames.count >= 1,
                "ToolRegistry.shared should have at least one registered tool in the test process (got \(allNames.count))")
        let tools = WenshuConductor.buildToolsSync(from: registry)
        let reachableDefaults = await WenshuConductor.defaultToolNames.filter { name in
            tools[name] != nil
        }
        #expect(!reachableDefaults.isEmpty,
                "buildTools must surface at least one default-name handler when the shared registry has it (reachable: \(reachableDefaults))")
    }

    @Test("activeLLMConnector never returns nil and honours an explicit slug")
    @MainActor
    func testActiveLLMConnector_resolvesSlugThenFallsBackToConfiguredProvider() async {
        let priorValue = UserDefaults.standard.string(forKey: "wenshu.llm.activeConnector")
        defer {
            if let prior = priorValue {
                UserDefaults.standard.set(prior, forKey: "wenshu.llm.activeConnector")
            } else {
                UserDefaults.standard.removeObject(forKey: "wenshu.llm.activeConnector")
            }
        }

        // Resolution order (= activeLLMConnector): the configured slug when the
        // catalog knows it, else the first provider holding a keychain key,
        // else anthropic, else minimax-cn. Pinning one fallback here would
        // break on any machine whose keychain holds a different provider,
        // so assert the contract instead: an explicit slug wins, and an
        // unresolvable slug still yields a drivable connector.
        UserDefaults.standard.set("anthropic", forKey: "wenshu.llm.activeConnector")
        let connector1 = WenshuAppDelegateLLMHelpers.activeLLMConnector()
        #expect(connector1.connectorID == "anthropic",
                "anthropic slug must resolve to AnthropicConnector (= M14 fix)")

        let fallbacks = ["unknown-slug-xyz", nil]
        for fallback in fallbacks {
            if let fallback {
                UserDefaults.standard.set(fallback, forKey: "wenshu.llm.activeConnector")
            } else {
                UserDefaults.standard.removeObject(forKey: "wenshu.llm.activeConnector")
            }
            let resolved = WenshuAppDelegateLLMHelpers.activeLLMConnector()
            #expect(!resolved.connectorID.isEmpty,
                    "an unresolvable slug (\(fallback ?? "absent")) must still yield a connector")
        }
    }

}
