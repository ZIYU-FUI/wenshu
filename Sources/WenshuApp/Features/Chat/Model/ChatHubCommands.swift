//  ChatHubCommands.swift
//
//  Canonical registry for chat slash commands (= the 35 hub
//  commands). Owned by the Chat layer (= not by Skill), because the
//  user-facing trigger is `/<name>` in the chat composer. The
//  underlying execution path (= the prompt template the LLM sees
//  when the user picks `/review`) is wenshu-side; = this file is
//  purely the static catalog of available commands.
//
//  Future UX ticket: transform `/` autocomplete into a button +
//  popover menu (= Apple HIG canonical); = this catalog stays the
//  source of truth for both presentations.
//
//  Per AGENTS.md §11.14 product philosophy: the user cannot define
//  new hub commands. The list below is wenshu-managed only.

import Foundation

/// One chat slash command (= a user-facing category of AI action).
///
/// `name` = the canonical identifier (= e.g. `review`).
/// `description` = a one-line summary rendered in the autocomplete
/// popup and Command Palette.
/// `category` = a free-form bucket for grouping in the UI
/// (= `writing` / `story` / `prose` / `mechanics` / `code` /
/// `research` / `discovery` / `ops`).
struct HubCommand: Sendable, Equatable, Identifiable, Hashable {
    let name: String
    let description: String
    let category: String
    var id: String { name }

    init(name: String, description: String, category: String) {
        self.name = name
        self.description = description
        self.category = category
    }
}

/// The static catalog of wenshu chat slash commands. Order matches
/// the canonical writing → story → prose → mechanics → code →
/// research → discovery → ops order (= the categories are
/// presentation buckets; = no semantic priority).
enum ChatHubCommands {

    static let all: [HubCommand] = [
        HubCommand(name: "help", description: "Show available slash commands", category: "writing"),
        HubCommand(name: "review", description: "Review chapter", category: "writing"),
        HubCommand(name: "rewrite", description: "Rewrite passage", category: "writing"),
        HubCommand(name: "summarize", description: "Summarize chapter", category: "writing"),
        HubCommand(name: "translate", description: "Translate text", category: "writing"),
        HubCommand(name: "continue", description: "Continue chapter", category: "writing"),
        HubCommand(name: "suggest", description: "Suggest plot point", category: "writing"),

        HubCommand(name: "outline", description: "Generate outline", category: "story"),
        HubCommand(name: "outliner", description: "Refine outline", category: "story"),
        HubCommand(name: "character", description: "Character sheet", category: "story"),
        HubCommand(name: "plot", description: "Plot arc", category: "story"),
        HubCommand(name: "world", description: "Worldbuilding entry", category: "story"),
        HubCommand(name: "chapter", description: "Draft chapter", category: "story"),
        HubCommand(name: "scene", description: "Draft scene", category: "story"),
        HubCommand(name: "dialog", description: "Dialog snippet", category: "story"),

        HubCommand(name: "grammar", description: "Grammar check", category: "prose"),
        HubCommand(name: "prose", description: "Prose-quality check", category: "prose"),
        HubCommand(name: "style", description: "Style check", category: "prose"),
        HubCommand(name: "voice", description: "Voice check", category: "prose"),
        HubCommand(name: "pacing", description: "Pacing analysis", category: "prose"),
        HubCommand(name: "tension", description: "Tension analysis", category: "prose"),

        HubCommand(name: "motivation", description: "Character motivations", category: "mechanics"),
        HubCommand(name: "conflict", description: "Conflict + obstacles", category: "mechanics"),

        HubCommand(name: "debug", description: "Debug snippet", category: "code"),
        HubCommand(name: "test", description: "Generate tests", category: "code"),
        HubCommand(name: "lint", description: "Lint file", category: "code"),
        HubCommand(name: "format", description: "Format file", category: "code"),

        HubCommand(name: "research", description: "Research topic", category: "research"),
        HubCommand(name: "citation", description: "Add citations", category: "research"),
        HubCommand(name: "cite", description: "Inline citation", category: "research"),
        HubCommand(name: "bibliography", description: "Bibliography entry", category: "research"),
        HubCommand(name: "docs", description: "Generate documentation", category: "research"),

        HubCommand(name: "search", description: "Search library", category: "discovery"),
        HubCommand(name: "index", description: "Index library", category: "discovery"),

        HubCommand(name: "cron", description: "Manage scheduled cron jobs", category: "ops")
    ]

    static func commands(in category: String) -> [HubCommand] {
        all.filter { $0.category == category }
    }

    static func command(named name: String) -> HubCommand? {
        all.first(where: { $0.name == name })
    }
}
