// ToolExposureTests.swift
//
// Visibility and admission are separate decisions, and the tests keep them
// separate: the list shown to the model is a hint, the check at dispatch is
// what holds.

import Foundation
import Testing
@testable import WenshuAgent

@Suite("Tool exposure")
struct ToolExposureTests {

    private let registry: [ExposedTool] = [
        ExposedTool(name: "paragraph_ai", category: .writing, mutates: true),
        ExposedTool(name: "outline", category: .writing),
        ExposedTool(name: "search_book", category: .navigation),
        ExposedTool(name: "web_search", category: .research),
        ExposedTool(name: "web_fetch", category: .research),
        ExposedTool(name: "read_file", category: .system),
        ExposedTool(name: "run_command", category: .system),
        ExposedTool(name: "illustration", category: .media)
    ]

    @Test("an empty selection shows everything")
    func emptySelectionShowsEverything() {
        let exposure = ToolExposure(registry: registry)
        #expect(exposure.visible.count == registry.count)
        #expect(exposure.isVisible("run_command"))
    }

    @Test("a selection narrows the list")
    func selectionNarrows() {
        let exposure = ToolExposure(registry: registry, selected: ["paragraph_ai", "web_search"])
        #expect(Set(exposure.visible.map(\.name)) == ["paragraph_ai", "web_search"])
        #expect(!exposure.isVisible("run_command"))
    }

    @Test("admission follows visibility, not the caller's belief")
    func admissionFollowsVisibility() {
        let exposure = ToolExposure(registry: registry, selected: ["paragraph_ai"])
        #expect(exposure.admits("paragraph_ai"))
        #expect(!exposure.admits("run_command"),
                "a tool the model was not shown must still be refused at dispatch")
    }

    @Test("a name not in the registry is never visible")
    func unknownNameIsNotVisible() {
        let exposure = ToolExposure(registry: registry, selected: ["paragraph_ai", "not_a_tool"])
        #expect(exposure.visible.map(\.name) == ["paragraph_ai"],
                "selecting a name that no longer exists must not surface a phantom")
    }

    @Test("every preset keeps the writing tools")
    func presetsAlwaysIncludeWriting() {
        let presets = ToolExposure.standardPresets(registry: registry)
        for preset in presets {
            #expect(preset.tools.contains("paragraph_ai"),
                    "\(preset.id) must leave the user able to write")
        }
    }

    @Test("the system preset is the only one that reaches shell tools")
    func systemPresetHoldsTheSharpTools() {
        let presets = ToolExposure.standardPresets(registry: registry)
        for preset in presets where preset.id != "system" {
            #expect(!preset.tools.contains("run_command"), "\(preset.id) must not expose shell access")
            #expect(!preset.tools.contains("read_file"), "\(preset.id) must not expose raw file access")
        }
        let system = presets.first { $0.id == "system" }
        #expect(system?.tools.contains("run_command") == true)
    }

    @Test("presets grow rather than replace each other")
    func researchPresetIncludesWritingAndResearch() {
        let presets = ToolExposure.standardPresets(registry: registry)
        guard let research = presets.first(where: { $0.id == "research" }) else {
            Issue.record("the research preset must exist")
            return
        }
        #expect(research.tools.contains("paragraph_ai"))
        #expect(research.tools.contains("web_search"))
        #expect(!research.tools.contains("run_command"))
    }

    @Test("resolving from preset ids produces the union")
    func resolveUnionsPresets() {
        let presets = ToolExposure.standardPresets(registry: registry)
        let exposure = ToolExposure.resolve(registry: registry, presets: presets, enabledPresetIDs: ["writing", "research"])
        #expect(exposure.visible.contains { $0.name == "paragraph_ai" })
        #expect(exposure.visible.contains { $0.name == "web_search" })
        #expect(!exposure.visible.contains { $0.name == "run_command" })
        #expect(Set(exposure.enabledPresets) == ["writing", "research"])
    }

    @Test("an unknown preset id is ignored rather than emptying the toolset")
    func unknownPresetIdIsIgnored() {
        let presets = ToolExposure.standardPresets(registry: registry)
        let exposure = ToolExposure.resolve(
            registry: registry,
            presets: presets,
            enabledPresetIDs: ["writing", "renamed_in_a_later_version"]
        )
        #expect(exposure.visible.contains { $0.name == "paragraph_ai" },
                "a renamed preset must not take the writing tools with it")
    }

    @Test("applying presets replaces the previous selection")
    func applyReplacesSelection() {
        var exposure = ToolExposure(registry: registry)
        let presets = ToolExposure.standardPresets(registry: registry)
        exposure.apply(presets: presets.filter { $0.id == "writing" })
        #expect(!exposure.isVisible("web_search"))
        exposure.apply(presets: presets.filter { $0.id == "research" })
        #expect(exposure.isVisible("web_search"))
        #expect(exposure.enabledPresets == ["research"])
    }

    @Test("categories group the registry for a settings screen")
    func categoriesGroupTools() {
        let exposure = ToolExposure(registry: registry)
        #expect(Set(exposure.names(.research)) == ["web_search", "web_fetch"])
        #expect(exposure.names(.system).contains("run_command"))
        #expect(exposure.names(.media) == ["illustration"])
    }

    @Test("presets are ordered simplest first")
    func presetsOrderedByComplexity() {
        let presets = ToolExposure.standardPresets(registry: registry)
        #expect(presets.map(\.id) == ["writing", "research", "media", "system"])
        for preset in presets {
            #expect(!preset.summary.isEmpty, "\(preset.id) needs a line a user can act on")
        }
    }

    @Test("the settings types carry the selection")
    func settingsCarrySelection() {
        // The visible set lives on PromptSettings because it decides what the
        // prompt advertises; ToolSettings carries the dispatch-side knobs.
        var prompt = PromptSettings()
        prompt.visibleTools = ["paragraph_ai"]
        #expect(!prompt.visibleTools.contains("run_command"))
        var tools = ToolSettings()
        tools.autoApprove = true
        #expect(tools.autoApprove)
    }
}