// ToolCatalogueTests.swift
//
// The catalogue replaces a flat list of twenty names, so the properties that
// matter are that nothing was lost in the rename and that a preset actually
// narrows the list.

import Foundation
import Testing
@testable import WenshuApp
import WenshuAgent

@Suite("Tool catalogue")
struct ToolCatalogueTests {

    /// The names that were in the flat list before the catalogue existed.
    private static let previousNames: Set<String> = [
        "ParagraphAI", "ReadFile", "WriteFile", "av", "background_review",
        "book_chapter", "book_edit_chapter", "book_entity", "book_manager",
        "book_outline", "file", "delegate_research", "kanban", "llm_wiki",
        "process", "reference_library", "todo", "todo_hermes", "vision",
        "web", "web_search"
    ]

    @Test("no tool was lost in the move from the flat list")
    func catalogueCoversTheOldList() {
        let names = Set(ToolCatalogue.names)
        #expect(names == Self.previousNames,
                "missing: \\(Self.previousNames.subtracting(names)) added: \\(names.subtracting(Self.previousNames))")
    }

    @Test("every tool declares a category")
    func everyToolHasACategory() {
        #expect(!ToolCatalogue.all.isEmpty)
        #expect(ToolCatalogue.exposureRegistry.count == ToolCatalogue.all.count)
    }

    @Test("names are unique")
    func namesAreUnique() {
        #expect(Set(ToolCatalogue.names).count == ToolCatalogue.names.count)
    }

    @Test("an unset selection exposes everything")
    func emptySelectionExposesEverything() {
        let names = ToolCatalogue.exposedNames(settings: PromptSettings())
        #expect(Set(names) == Set(Self.previousNames),
                "an existing installation must keep every tool until someone chooses")
    }

    @Test("a narrowed selection drops the rest")
    func narrowedSelectionDropsTheRest() {
        var settings = PromptSettings()
        settings.visibleTools = ["book_chapter", "ParagraphAI"]
        #expect(Set(ToolCatalogue.exposedNames(settings: settings)) == ["book_chapter", "ParagraphAI"])
    }

    @Test("catalogue order is preserved under filtering, so the tool list stays cache-stable")
    func orderIsPreservedUnderFiltering() {
        let all = ToolCatalogue.names
        var settings = PromptSettings()
        settings.visibleTools = ["web_search", "ParagraphAI", "book_chapter"]
        let filtered = ToolCatalogue.exposedNames(settings: settings)
        // Catalogue order puts the library first, because that is what a novel
        // needs most; the selection order the user clicked in is irrelevant.
        #expect(filtered == ["book_chapter", "ParagraphAI", "web_search"],
                "the model sees the list in catalogue order regardless of selection order")
        #expect(filtered == all.filter { filtered.contains($0) })
    }

    @Test("the writing preset drops shell access")
    func writingPresetDropsShellAccess() {
        var settings = PromptSettings()
        let presets = ToolExposure.standardPresets(registry: ToolCatalogue.exposureRegistry)
        guard let writing = presets.first(where: { $0.id == "writing" }) else {
            Issue.record("the writing preset must exist")
            return
        }
        settings.visibleTools = Set(writing.tools)
        let names = ToolCatalogue.exposedNames(settings: settings)
        #expect(!names.contains("process"))
        #expect(!names.contains("WriteFile"))
        #expect(names.contains("ParagraphAI"))
        #expect(names.contains("book_chapter"))
    }

    @Test("the system preset keeps everything")
    func systemPresetKeepsEverything() {
        let presets = ToolExposure.standardPresets(registry: ToolCatalogue.exposureRegistry)
        guard let system = presets.first(where: { $0.id == "system" }) else {
            Issue.record("the system preset must exist")
            return
        }
        #expect(Set(system.tools) == Set(Self.previousNames))
    }

    @Test("every preset leaves the user able to write the book")
    func presetsKeepTheLibraryTools() {
        let presets = ToolExposure.standardPresets(registry: ToolCatalogue.exposureRegistry)
        for preset in presets {
            #expect(preset.tools.contains("book_chapter"), "\(preset.id) must reach the chapters")
            #expect(preset.tools.contains("ParagraphAI"), "\(preset.id) must reach the writing aid")
        }
    }

    @Test("selecting by preset id resolves to a tool selection")
    func presetSelectionResolves() {
        let exposure = ToolCatalogue.exposure(enabledPresetIDs: ["writing"])
        #expect(!exposure.visible.contains { $0.name == "process" })
        #expect(exposure.visible.contains { $0.name == "ParagraphAI" })
    }

    @Test("mutating tools are flagged, so a surface can distinguish them")
    func mutatingToolsAreFlagged() {
        let mutations = Set(ToolCatalogue.all.filter(\.mutates).map(\.name))
        #expect(mutations.contains("book_edit_chapter"))
        #expect(!mutations.contains("web_search"), "searching does not change the library")
        #expect(!mutations.contains("llm_wiki"))
    }
}