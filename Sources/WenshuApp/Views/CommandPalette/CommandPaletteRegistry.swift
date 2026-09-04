//
//  CommandPaletteRegistry.swift · Wenshu · CHATBOX-002 (2026-09-04)
//
//  Searchable registry of all ⌘K palette actions (= commands, skills,
//  navigation). Mirrors hermes slash_registry.py + commands.py.
//
//  CHATBOX-002 (2026-09-04, boss OOB 'B'): single search box that lists
//  every available command / skill / action in the app. The palette is
//  the canonical entry point for everything that was previously hidden
//  behind slash commands, menu bar items, or NotificationCenter posts.
//
//  Design:
//    - actor (Swift 6 strict concurrency = Sendable types only).
//    - register / unregister / allItems / itemsMatching (= hermes
//      slash_registry.search() parity).
//    - Filtering happens INSIDE the actor (= single source of truth,
//      no race between register and search).
//    - Pure data layer — UI lives in CommandPaletteView.swift.
//
//  No new third-party dependency (= Apple stack exclusive per AGENTS.md
//  §11.1). Public surface is additive (= does NOT remove or rename any
//  existing public type).
//

import Foundation

/// Single ⌘K palette entry (= one row in the dropdown).
///
/// The action field is an enum so the palette stays type-safe across
/// command / skill / navigate / send-chat / custom (= hermes
/// slash_registry.py action kinds).
public struct CommandPaletteItem: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String?
    public let category: String      // "command" / "skill" / "navigate" / "chat" / "custom"
    public let shortcutHint: String? // "⌘N" / "/skill_name" / "⌘K"

    /// Sendable action kind. Closures would be nicer ergonomically but
    /// can't carry Swift 6 strict concurrency; the enum dispatches
    /// through the SwiftUI side via the standard command / navigation
    /// paths (= .openSettings, .navigate, NotificationCenter post, etc.).
    public let action: CommandPaletteAction

    public init(
        id: String,
        title: String,
        subtitle: String? = nil,
        category: String,
        shortcutHint: String? = nil,
        action: CommandPaletteAction
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.category = category
        self.shortcutHint = shortcutHint
        self.action = action
    }
}

/// Palette action kinds (= hermes command / skill / navigate dispatch).
///
/// Each case is a tagged payload — the palette view switches on `.action`
/// and either invokes the skill / posts a notification / opens a
/// Settings tab / sends a chat message / calls a custom hook. Closures
/// were rejected (Swift 6 Sendable), and a stringly-typed action would
/// lose type safety. This enum is the middle ground.
public enum CommandPaletteAction: Sendable, Equatable, Hashable {
    /// Invoke a skill (= same path as SkillAdapter.parseAndInvoke in CHATBOX-001).
    /// args = the keyword args to pass (mostly empty in v1; future
    /// skill args land here).
    case invokeSkill(skillName: String, args: [String: String])
    /// Open the Settings window at a specific tab (= "general" /
    /// "providers" / "skills" / etc.). The Settings scene reads the
    /// env value to pick the tab.
    case openSettings(tab: String)
    /// Navigate to a zone / view (= "kanban" / "todo" / "editor" /
    /// "library"). Posts a NotificationCenter event that WorkspaceView
    /// listens for.
    case navigateTo(destination: String)
    /// Send a chat message (= same shape as the chat TextField's
    /// submit path; the chat view listens for the notification and
    /// appends to its draftText).
    case sendChatMessage(String)
    /// Custom hook (= escape hatch for future wenshu features).
    /// The name is a string tag the SwiftUI layer can dispatch on.
    case custom(name: String)

    public static func == (lhs: CommandPaletteAction, rhs: CommandPaletteAction) -> Bool {
        switch (lhs, rhs) {
        case let (.invokeSkill(a1, a2), .invokeSkill(b1, b2)):
            return a1 == b1 && a2 == b2
        case let (.openSettings(a), .openSettings(b)): return a == b
        case let (.navigateTo(a), .navigateTo(b)): return a == b
        case let (.sendChatMessage(a), .sendChatMessage(b)): return a == b
        case let (.custom(a), .custom(b)): return a == b
        default: return false
        }
    }

    public func hash(into hasher: inout Hasher) {
        // Discriminator + payload. Stable across cases (= same payload
        // hashes the same regardless of case order). Required for
        // SwiftUI Identifiable / Hashable usage in the palette list.
        switch self {
        case let .invokeSkill(skillName, args):
            hasher.combine(0)
            hasher.combine(skillName)
            hasher.combine(args)
        case let .openSettings(tab):
            hasher.combine(1)
            hasher.combine(tab)
        case let .navigateTo(destination):
            hasher.combine(2)
            hasher.combine(destination)
        case let .sendChatMessage(message):
            hasher.combine(3)
            hasher.combine(message)
        case let .custom(name):
            hasher.combine(4)
            hasher.combine(name)
        }
    }
}

/// Searchable ⌘K palette registry. Pure data layer — UI lives in
/// CommandPaletteView.swift.
///
/// CHATBOX-002 design (= hermes slash_registry.py parity):
///   - register / unregister for dynamic items (= commands a plugin /
///     third-party skill registers at runtime)
///   - allItems() returns the full list (for the empty-query state)
///   - itemsMatching(_:) returns the filtered list (case-insensitive
///     substring match on title + subtitle + skill name + shortcut hint)
///   - filter happens inside the actor = single source of truth = no
///     race between register and search
///
/// Swift 6 strict concurrency: actor isolation enforces Sendable on
/// every parameter and return type (= CommandPaletteItem is Sendable,
/// its action enum is Sendable). Closures-as-action would require
/// `@Sendable` + main-actor hop + lose the type-safety enum gives.
public actor CommandPaletteRegistry {
    /// Process-wide singleton (= same pattern as SkillKeywordMatcher.shared;
    /// the App.swift ⌘K menu posts to this; ChatView / Settings views
    /// observe it via SwiftUI .sheet binding).
    public static let shared = CommandPaletteRegistry()

    private var items: [String: CommandPaletteItem] = [:]

    public init() {}

    /// Register an item. If the id is already taken, the new item wins
    /// (= same precedence as hermes slash_registry.register: latest
    /// registration wins).
    public func register(_ item: CommandPaletteItem) {
        items[item.id] = item
    }

    /// Register many items in one call (= convenience for the
    /// "seed default palette" code path).
    public func registerMany(_ newItems: [CommandPaletteItem]) {
        for item in newItems {
            items[item.id] = item
        }
    }

    /// Unregister by id. No-op if the id was never registered.
    public func unregister(id: String) {
        items.removeValue(forKey: id)
    }

    /// Snapshot of every registered item. Returned as an array (= not
    /// the actor's internal dictionary) so callers can sort / filter
    /// outside the actor without violating isolation.
    public func allItems() -> [CommandPaletteItem] {
        return Array(items.values)
    }

    /// Filtered subset of registered items. Match = case-insensitive
    /// substring match against title / subtitle / category / shortcutHint.
    /// Empty query returns all items.
    ///
    /// Why inside the actor: filter happens on the actor's storage so
    /// there is no race with concurrent register/unregister calls. The
    /// caller can iterate the result outside the actor (= it's already
    /// a snapshot value, not a live view).
    public func itemsMatching(_ query: String) -> [CommandPaletteItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return Array(items.values) }
        let needle = trimmed.lowercased()
        return items.values.filter { item in
            if item.title.lowercased().contains(needle) { return true }
            if let subtitle = item.subtitle, subtitle.lowercased().contains(needle) { return true }
            if item.category.lowercased().contains(needle) { return true }
            if let hint = item.shortcutHint, hint.lowercased().contains(needle) { return true }
            // Also match against the skill name in the action payload
            // (= /skill-name search works as expected).
            if case let .invokeSkill(skillName, _) = item.action,
               skillName.lowercased().contains(needle) {
                return true
            }
            return false
        }
    }

    /// Total count (= for the palette footer "N items").
    public func count() -> Int {
        return items.count
    }
}
