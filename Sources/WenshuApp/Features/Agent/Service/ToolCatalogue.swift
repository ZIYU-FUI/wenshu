// ToolCatalogue.swift
//
// What the app registers, with a category per tool (= replaces the flat
// defaultToolNames list in WenshuConductor).
//
// The category is the whole point. A flat list of twenty names is a list
// nobody can act on: a settings screen showing it teaches the user nothing
// about what they are turning on, and the assistant cannot say "this one
// reaches outside your library" because the list does not know. Assigning a
// category at registration makes the presets in ToolExposure derivable
// instead of hand-maintained, so a new tool joins a preset by declaring what
// it is rather than by being added to four lists.
//
// Naming is inherited from the registry rather than corrected here. The
// registry keys on these strings, tests assert them, and a rename that is not
// a rename breaks tool calls mid-conversation.

import Foundation
import WenshuAgent

/// One tool the app ships, and where it belongs.
public struct CataloguedTool: Sendable {
    public let name: String
    public let category: ToolCategory
    /// Whether the tool changes something on disk.
    public let mutates: Bool

    public init(name: String, category: ToolCategory, mutates: Bool) {
        self.name = name
        self.category = category
        self.mutates = mutates
    }

    var exposed: ExposedTool {
        ExposedTool(name: name, category: category, mutates: mutates)
    }
}

/// The registry the app builds from.
public enum ToolCatalogue {
    /// Every tool the app registers, in the order the conductor asks for them.
    ///
    /// The order is the order a user meets them in: library work first,
    /// because that is what a novel needs, then writing aids, then the things
    /// that reach outside the machine.
    public static let all: [CataloguedTool] = [
        // Library (= the novel itself).
        CataloguedTool(name: "book_manager", category: .navigation, mutates: true),
        CataloguedTool(name: "book_chapter", category: .navigation, mutates: true),
        CataloguedTool(name: "book_outline", category: .navigation, mutates: true),
        CataloguedTool(name: "book_entity", category: .navigation, mutates: true),
        CataloguedTool(name: "book_edit_chapter", category: .navigation, mutates: true),
        CataloguedTool(name: "reference_library", category: .navigation, mutates: false),
        CataloguedTool(name: "llm_wiki", category: .navigation, mutates: false),

        // Writing aids.
        CataloguedTool(name: "ParagraphAI", category: .writing, mutates: false),
        CataloguedTool(name: "todo", category: .writing, mutates: true),
        CataloguedTool(name: "todo_hermes", category: .writing, mutates: true),
        CataloguedTool(name: "kanban", category: .writing, mutates: true),
        CataloguedTool(name: "background_review", category: .writing, mutates: true),

        // Research (= leaves the library, does not leave the machine's control
        // of the text).
        CataloguedTool(name: "web_search", category: .research, mutates: false),
        CataloguedTool(name: "delegate_research", category: .research, mutates: false),
        CataloguedTool(name: "web", category: .research, mutates: false),

        // Media.
        CataloguedTool(name: "av", category: .media, mutates: true),
        CataloguedTool(name: "vision", category: .media, mutates: false),

        // System (= reaches the filesystem and the shell).
        CataloguedTool(name: "file", category: .system, mutates: true),
        CataloguedTool(name: "ReadFile", category: .system, mutates: false),
        CataloguedTool(name: "WriteFile", category: .system, mutates: true),
        CataloguedTool(name: "process", category: .system, mutates: true)
    ]

    /// The names, in catalogue order (= what the conductor asks for).
    public static var names: [String] { all.map(\.name) }

    /// The catalogue as the exposure layer sees it.
    public static var exposureRegistry: [ExposedTool] { all.map(\.exposed) }

    /// Build the exposure a user has configured.
    ///
    /// An empty preset list means everything, which is the default and the
    /// state every existing installation is in (= nothing is turned off until
    /// someone opens settings and chooses).
    public static func exposure(settings: PromptSettings) -> ToolExposure {
        let presets = ToolExposure.standardPresets(registry: exposureRegistry)
        if settings.visibleTools.isEmpty {
            return ToolExposure(registry: exposureRegistry)
        }
        return ToolExposure(
            registry: exposureRegistry,
            selected: settings.visibleTools
        )
    }

    /// Build the exposure from preset ids, for a settings screen.
    public static func exposure(enabledPresetIDs: [String]) -> ToolExposure {
        let presets = ToolExposure.standardPresets(registry: exposureRegistry)
        return ToolExposure.resolve(
            registry: exposureRegistry,
            presets: presets,
            enabledPresetIDs: enabledPresetIDs
        )
    }

    /// Names the conductor should ask the registry for.
    public static func exposedNames(settings: PromptSettings) -> [String] {
        let exposure = exposure(settings: settings)
        let visible = Set(exposure.visible.map(\.name))
        // Catalogue order is preserved so the tool list the model sees stays
        // stable across turns: a list that reshuffles costs cache.
        return names.filter { visible.contains($0) }
    }
}