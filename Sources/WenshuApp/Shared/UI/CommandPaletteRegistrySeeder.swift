//
//  CommandPaletteRegistrySeeder.swift
//
//  One-shot seeder for CommandPaletteRegistry.shared. Populates the
//  registry at app launch (= App.swift applicationDidFinishLaunching
//  spawns a detached task calling `seed()`). Before this commit the
//  registry was empty (= zero register callers); ⌘K opened a sheet
//  with "0 items" per the audit at .scratch/hermes-agent-smc-readiness-
//  evidence/triggers.md M2.
//
//  Seeding inventory (= per the audit fix path recommendation):
//    - 35 hub commands (loop over SkillAdapter.hubCommands)
//    - 5 sub-agents (loop over SubAgentIdentity.Name.allCases)
//    - 5 zone toggles (synthesize from TabKind cases that have a
//      menu binding)
//    - 3 Settings sections (openSettings(tab:) to providers/memory/skills)
//    - 1 Reset Layout custom action (uses existing wenshuResetLayout)
//    - 1 Send Chat message shortcut (pre-fills input with /help)
//
//  Each entry uses CommandPaletteItem's existing sendable payload
//  (= no closures; all dispatch goes through NotificationCenter). The
//  SwiftUI side already handles 5 distinct notification names; this
//  seeder just populates the registry that backs the ⌘K list.
//
//  Idempotent: `seed()` registerMany replaces by id (= latest
//  registration wins), so re-running seed() after a Settings-driven
//  skill install replaces the prior list without leaving stale rows.
//
//  Apple stack exclusive per AGENTS.md §11.1 (= no third-party deps).
//

import Foundation

/// Seeds CommandPaletteRegistry.shared with the real existing wenshu
/// actions (= per the audit recommendation).
enum CommandPaletteRegistrySeeder {

    /// Populate the registry. Safe to call multiple times.
    static func seed() async {
        var items: [CommandPaletteItem] = []
        items.append(contentsOf: hubCommandItems())
        items.append(contentsOf: subAgentItems())
        items.append(contentsOf: settingsItems())
        items.append(contentsOf: zoneToggleItems())
        items.append(contentsOf: shortcutItems())
        await CommandPaletteRegistry.shared.registerMany(items)
    }

    // MARK: - Hub commands (35)

    private static func hubCommandItems() -> [CommandPaletteItem] {
        return ChatHubCommands.all.map { cmd in
            CommandPaletteItem(
                id: "palette.hub.\(cmd.name)",
                title: "/\(cmd.name)",
                subtitle: cmd.description,
                category: "skill",
                shortcutHint: "/\(cmd.name)",
                action: .invokeSkill(skillName: cmd.name, args: [:])
            )
        }
    }

    // MARK: - Sub-agents (5)

    private static func subAgentItems() -> [CommandPaletteItem] {
        return SubAgentIdentity.Name.allCases.map { name in
            CommandPaletteItem(
                id: "palette.agent.\(name.rawValue)",
                title: "@\(name.rawValue)",
                subtitle: SubAgentIdentity.displayName(name: name),
                category: "command",
                shortcutHint: "@\(name.rawValue)",
                action: .custom(name: "subagent.\(name.rawValue)")
            )
        }
    }

    // MARK: - Settings sections (3)

    private static func settingsItems() -> [CommandPaletteItem] {
        return [
            CommandPaletteItem(
                id: "palette.settings.providers",
                title: "Open Settings — LLM Connector",
                subtitle: "Pick provider, supply credentials, test",
                category: "command",
                shortcutHint: "⌘,",
                action: .openSettings(tab: "providers")
            ),
            CommandPaletteItem(
                id: "palette.settings.memory",
                title: "Open Settings — Memory",
                subtitle: "Configure memory provider, scope, retention",
                category: "command",
                shortcutHint: nil,
                action: .openSettings(tab: "memory")
            )
        ]
    }

    // MARK: - Misc shortcuts

    private static func shortcutItems() -> [CommandPaletteItem] {
        return [
            CommandPaletteItem(
                id: "palette.shortcut.resetLayout",
                title: "Reset Layout",
                subtitle: "Restore the default 6-zone layout (⌘⇧R)",
                category: "command",
                shortcutHint: "⌘⇧R",
                action: .custom(name: "reset-layout")
            ),
            CommandPaletteItem(
                id: "palette.shortcut.sendChat",
                title: "Send Chat Message…",
                subtitle: "Open the chat zone with a pre-filled draft",
                category: "chat",
                shortcutHint: nil,
                action: .sendChatMessage("/help")
            )
        ]
    }

    // MARK: - Zone toggles (5 — synthesized from TabKind cases that have a menu binding)

    /// One palette entry per TabKind case that maps to a visible zone
    /// (= projectSidebar, projectPreview, specializedTools, aiChat,
    /// aiDynamic). editor is omitted (= the editor is always present;
    /// = no toggle exists for it).
    private static func zoneToggleItems() -> [CommandPaletteItem] {
        let zones: [(id: String, title: String, subtitle: String, action: CommandPaletteAction)] = [
            ("palette.zone.library", "Toggle Library", "Show or hide the project sidebar (= ⌘, the Settings shortcut is separate)", .custom(name: "toggle.library")),
            ("palette.zone.preview", "Toggle Preview", "Show or hide the reference preview zone", .custom(name: "toggle.preview")),
            ("palette.zone.tools", "Toggle Tools", "Show or hide the specialized tools zone", .custom(name: "toggle.tools")),
            ("palette.zone.chat", "Toggle Chat", "Show or hide the chat zone", .custom(name: "toggle.chat")),
            ("palette.zone.dynamic", "Toggle Dynamic Zone", "Navigate to the Kanban / SubAgent progress view (= ⌥K)", .navigateTo(destination: "kanban"))
        ]
        return zones.map { zone in
            CommandPaletteItem(
                id: zone.id,
                title: zone.title,
                subtitle: zone.subtitle,
                category: "command",
                shortcutHint: nil,
                action: zone.action
            )
        }
    }

}
