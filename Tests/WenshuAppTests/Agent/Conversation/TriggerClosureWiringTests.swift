//
//  TriggerClosureWiringTests.swift · Wenshu · HERMES-AGENT-SMC-READYNESS
//
//  Focused tests verifying the production wiring for the audit's
//  M1/M2/M3/M5/M14 missing-trigger findings (= per the audit at
//  .scratch/hermes-agent-smc-readiness-evidence/triggers.md).
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
import Testing
@testable import WenshuApp

@Suite("HERMES-AGENT-SMC-READYNESS — production trigger wiring")
struct TriggerClosureWiringTests {

    @Test("CommandPaletteRegistrySeeder populates the 35 hub commands from SkillAdapter.hubCommands")
    func testCommandPaletteRegistrySeeder_populates35HubCommands() async {
        await CommandPaletteRegistrySeeder.seed()
        let all = await CommandPaletteRegistry.shared.allItems()
        let hubIds = all.filter { $0.id.hasPrefix("palette.hub.") }
        #expect(hubIds.count == SkillAdapter.hubCommands.count,
                "seeder must register one palette entry per hub command (got \(hubIds.count), expected \(SkillAdapter.hubCommands.count))")
        let hubNames = Set(hubIds.map { $0.id.replacingOccurrences(of: "palette.hub.", with: "") })
        for cmd in SkillAdapter.hubCommands {
            #expect(hubNames.contains(cmd.name),
                    "hub command '\(cmd.name)' must appear as a palette entry")
        }
    }

    @Test("CommandPaletteRegistrySeeder populates one palette entry per sub-agent slug")
    func testCommandPaletteRegistrySeeder_populates5SubAgents() async {
        await CommandPaletteRegistrySeeder.seed()
        let all = await CommandPaletteRegistry.shared.allItems()
        let agentIds = all.filter { $0.id.hasPrefix("palette.agent.") }
        #expect(agentIds.count == SubAgentIdentity.Name.allCases.count,
                "seeder must register one palette entry per sub-agent (got \(agentIds.count), expected \(SubAgentIdentity.Name.allCases.count))")
        for name in SubAgentIdentity.Name.allCases {
            #expect(agentIds.contains { $0.id == "palette.agent.\(name.rawValue)" },
                    "sub-agent '\(name.rawValue)' must appear in the palette")
        }
    }

    @Test("CommandPaletteRegistrySeeder populates one palette entry per zone toggle")
    func testCommandPaletteRegistrySeeder_populatesZoneToggles() async {
        await CommandPaletteRegistrySeeder.seed()
        let all = await CommandPaletteRegistry.shared.allItems()
        let zoneIds = all.filter { $0.id.hasPrefix("palette.zone.") }
        #expect(zoneIds.count == 5, "seeder must register 5 zone-toggle entries (got \(zoneIds.count))")
        for id in ["palette.zone.library", "palette.zone.preview", "palette.zone.tools", "palette.zone.chat", "palette.zone.dynamic"] {
            #expect(zoneIds.contains { $0.id == id }, "expected zone palette entry '\(id)'")
        }
    }

    @Test("CommandPaletteRegistrySeeder populates one palette entry per Settings section")
    func testCommandPaletteRegistrySeeder_populatesSettingsSections() async {
        await CommandPaletteRegistrySeeder.seed()
        let all = await CommandPaletteRegistry.shared.allItems()
        let settingsIds = all.filter { $0.id.hasPrefix("palette.settings.") }
        #expect(settingsIds.count == 3, "seeder must register 3 Settings entries (got \(settingsIds.count))")
        for id in ["palette.settings.providers", "palette.settings.memory", "palette.settings.skills"] {
            #expect(settingsIds.contains { $0.id == id }, "expected settings palette entry '\(id)'")
        }
    }

    @Test("SkillKeywordRegistryBootstrap registers the 35 hub commands as keyword targets")
    func testSkillKeywordBootstrap_registersKeywordsFromHubCommands() async {
        await SkillKeywordRegistryBootstrap.seed()
        for cmd in SkillAdapter.hubCommands {
            let match = await SkillKeywordMatcher.shared.match(input: "/\(cmd.name)")
            #expect(match != nil, "keyword matcher must resolve '/\(cmd.name)' to a SkillKeyword (= M1 fix)")
            if let m = match {
                #expect(m.skillName == cmd.name, "match for '/\(cmd.name)' must map to the right skill name")
            }
        }
    }

    @Test("SkillKeywordRegistryBootstrap enables natural-language match for hub-command aliases")
    func testSkillKeywordBootstrap_naturalLanguageAliasMatch() async {
        await SkillKeywordRegistryBootstrap.seed()
        let match = await SkillKeywordMatcher.shared.match(input: "please review the chapter for style consistency")
        #expect(match != nil, "natural-language 'review the chapter for style' must match a hub command")
        #expect(match?.skillName == "review", "natural-language 'review' must resolve to /review skill")
    }

    @Test("production WenshuConductor builds tools from ToolRegistry.shared (not an empty dict)")
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
        _ = ParagraphAITool._registryBootstrap
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
        let reachableDefaults = WenshuConductor.defaultToolNames.filter { name in
            tools[name] != nil
        }
        #expect(!reachableDefaults.isEmpty,
                "buildTools must surface at least one default-name handler when the shared registry has it (reachable: \(reachableDefaults))")
    }

    @Test("WenshuAppDelegate.activeLLMConnector returns a usable connector for any slug (= ConversationLoop.runTurn reachable)")
    func testActiveLLMConnector_fallsBackToAnthropicForUnknownSlug() async {
        let priorValue = UserDefaults.standard.string(forKey: "wenshu.llm.activeConnector")
        defer {
            if let prior = priorValue {
                UserDefaults.standard.set(prior, forKey: "wenshu.llm.activeConnector")
            } else {
                UserDefaults.standard.removeObject(forKey: "wenshu.llm.activeConnector")
            }
        }

        UserDefaults.standard.set("anthropic", forKey: "wenshu.llm.activeConnector")
        let connector1 = WenshuAppDelegate.activeLLMConnector()
        #expect(connector1.connectorID == "anthropic",
                "anthropic slug must resolve to AnthropicConnector (= M14 fix)")

        UserDefaults.standard.set("unknown-slug-xyz", forKey: "wenshu.llm.activeConnector")
        let connector2 = WenshuAppDelegate.activeLLMConnector()
        #expect(connector2.connectorID == "anthropic",
                "unknown slug must fall back to AnthropicConnector (= never nil)")

        UserDefaults.standard.removeObject(forKey: "wenshu.llm.activeConnector")
        let connector3 = WenshuAppDelegate.activeLLMConnector()
        #expect(connector3.connectorID == "anthropic",
                "missing slug must fall back to AnthropicConnector (= never nil)")
    }

    @Test("CommandPaletteRegistrySeeder dynamic-zone entry dispatches .navigateTo('kanban')")
    func testPaletteNavigateSurface_mapsKanbanDestination() async {
        await CommandPaletteRegistrySeeder.seed()
        let all = await CommandPaletteRegistry.shared.allItems()
        guard let kanbanEntry = all.first(where: { $0.id == "palette.zone.dynamic" }) else {
            Issue.record("palette entry 'palette.zone.dynamic' must exist (= seeder must register it)")
            return
        }
        if case let .navigateTo(destination) = kanbanEntry.action {
            #expect(destination == "kanban",
                    "dynamic zone palette entry must dispatch navigateTo('kanban')")
        } else {
            Issue.record("palette.zone.dynamic must have action .navigateTo")
        }
    }
}
