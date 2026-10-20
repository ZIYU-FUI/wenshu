// ToolExposure.swift
//
// Which tools the model is shown (= hermes turn_tool_validation, and the
// toolset surface that validation exists to serve).
//
// Two different decisions live here and are easy to confuse:
//
//  1. Visibility. Which tools appear in the tools[] array. A tool the model
//     cannot see cannot hallucinate a call to it, cannot waste a turn
//     discovering it is unavailable, and does not spend prompt tokens on a
//     description it will never use.
//  2. Admission. A call the model did make, checked again at dispatch. The
//     model can be told about a tool and still call something else, and the
//     list it was shown is not a security boundary on its own.
//
// Hermes keeps both. So does this.
//
// Visibility is also the cheapest way to serve users at different levels. A
// first-time writer gets the writing tools and nothing else; someone
// researching gets search and fetch; someone who wants shell access gets it
// explicitly. The cost of the advanced set is a longer tool list, so making
// it opt-in is what keeps the simple case simple.

import Foundation

/// What kind of thing a tool is, for the presets and for grouping in settings.
public enum ToolCategory: String, Sendable, CaseIterable, Equatable {
    /// Reading and writing the user's own text.
    case writing
    /// Navigating the library: search, outline, links.
    case navigation
    /// Looking things up outside the library.
    case research
    /// Filesystem, processes, network = the ones a writing tool rarely needs.
    case system
    /// Producing images or audio.
    case media
}

/// One tool as the exposure layer sees it.
public struct ExposedTool: Sendable, Equatable {
    public let name: String
    public let category: ToolCategory
    /// Whether the tool changes state on disk (= a writing tool).
    public let mutates: Bool

    public init(name: String, category: ToolCategory, mutates: Bool = false) {
        self.name = name
        self.category = category
        self.mutates = mutates
    }
}

/// A named bundle of tools a user can turn on as a unit.
public struct ToolPreset: Sendable, Equatable {
    public let id: String
    public let title: String
    /// One line, in product language (= "search the library" not "BM25 index").
    public let summary: String
    public let tools: [String]

    public init(id: String, title: String, summary: String, tools: [String]) {
        self.id = id
        self.title = title
        self.summary = summary
        self.tools = tools
    }
}

/// Resolves which tools are visible and which calls are admitted.
public struct ToolExposure: Sendable {
    /// Everything the app registered.
    public var registry: [ExposedTool]
    /// The user's selection, by tool name. Empty means every tool.
    public var selected: Set<String>
    /// Preset identifiers the user turned on, for display in settings.
    public var enabledPresets: [String]

    public init(
        registry: [ExposedTool] = [],
        selected: Set<String> = [],
        enabledPresets: [String] = []
    ) {
        self.registry = registry
        self.selected = selected
        self.enabledPresets = enabledPresets
    }

    /// The tools a model sees.
    ///
    /// An empty selection means everything. That default matters: a user who
    /// never opened settings should not find half their tools gone.
    public var visible: [ExposedTool] {
        guard !selected.isEmpty else { return registry }
        return registry.filter { selected.contains($0.name) }
    }

    public func isVisible(_ name: String) -> Bool {
        visible.contains { $0.name == name }
    }

    /// Whether a call the model made may run.
    ///
    /// Separate from visibility on purpose. The tool list is a hint; this is
    /// the check that holds when the model calls something it was not shown.
    public func admits(_ name: String) -> Bool {
        isVisible(name)
    }

    public func names(_ category: ToolCategory) -> [String] {
        visible.filter { $0.category == category }.map(\.name)
    }

    /// Replace the selection with the given presets.
    public mutating func apply(presets: [ToolPreset]) {
        var names: Set<String> = []
        for preset in presets {
            names.formUnion(preset.tools)
        }
        selected = names
        enabledPresets = presets.map(\.id)
    }

    /// Build an exposure from the registry plus a set of preset ids.
    ///
    /// Unknown preset ids are ignored rather than fatal: a preset renamed in a
    /// later version must not empty someone's toolset on upgrade.
    public static func resolve(
        registry: [ExposedTool],
        presets: [ToolPreset],
        enabledPresetIDs: [String]
    ) -> ToolExposure {
        var names: Set<String> = []
        var ids: [String] = []
        for id in enabledPresetIDs {
            guard let preset = presets.first(where: { $0.id == id }) else { continue }
            names.formUnion(preset.tools)
            ids.append(id)
        }
        return ToolExposure(registry: registry, selected: names, enabledPresets: ids)
    }

    /// The presets shipped with the app.
    ///
    /// Ordered simplest-first, because that is the order a settings screen
    /// should present them in. Every preset includes the writing tools: a
    /// user who turns on research still has to be able to write.
    public static func standardPresets(registry: [ExposedTool]) -> [ToolPreset] {
        func names(_ category: ToolCategory) -> [String] {
            registry.filter { $0.category == category }.map(\.name)
        }
        return [
            ToolPreset(
                id: "writing",
                title: "写作",
                summary: "人物、大纲、文笔、字数。默认打开。",
                tools: names(.writing) + names(.navigation)
            ),
            ToolPreset(
                id: "research",
                title: "查资料",
                summary: "联网搜索和抓取网页，用来核对资料里的真实现状。",
                tools: names(.writing) + names(.navigation) + names(.research)
            ),
            ToolPreset(
                id: "media",
                title: "配图与朗读",
                summary: "生成插图、把章节读出来。",
                tools: names(.writing) + names(.navigation) + names(.media)
            ),
            ToolPreset(
                id: "system",
                title: "文件和命令",
                summary: "读写任意文件、运行命令。只有需要时才开。",
                tools: registry.map(\.name)
            )
        ]
    }
}