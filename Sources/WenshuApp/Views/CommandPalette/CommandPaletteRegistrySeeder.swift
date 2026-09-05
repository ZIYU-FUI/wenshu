//
//  CommandPaletteRegistrySeeder.swift · Wenshu · HERMES-AGENT-SMC-READYNESS T-CommandPaletteSeed
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
//    - 5 zone toggles (synthesize from ZoneSlot cases that have a
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
public enum CommandPaletteRegistrySeeder {

    /// Populate the registry. Safe to call multiple times.
    public static func seed() async {
        var items: [CommandPaletteItem] = []
        items.append(contentsOf: hubCommandItems())
        items.append(contentsOf: subAgentItems())
        items.append(contentsOf: zoneToggleItems())
        items.append(contentsOf: settingsItems())
        items.append(contentsOf: shortcutItems())
        await CommandPaletteRegistry.shared.registerMany(items)
    }

    // MARK: - Hub commands (35)

    private static func hubCommandItems() -> [CommandPaletteItem] {
        return SkillAdapter.hubCommands.map { cmd in
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

    // MARK: - Zone toggles (5)

    private static func zoneToggleItems() -> [CommandPaletteItem] {
        return [
            CommandPaletteItem(
                id: "palette.zone.library",
                title: "Toggle Library Zone",
                subtitle: "Show or hide the project sidebar (⌘⇧1)",
                category: "navigate",
                shortcutHint: "⌘⇧1",
                action: .navigateTo(destination: "library")
            ),
            CommandPaletteItem(
                id: "palette.zone.preview",
                title: "Toggle Preview Zone",
                subtitle: "Show or hide the preview pane",
                category: "navigate",
                shortcutHint: nil,
                action: .navigateTo(destination: "preview")
            ),
            CommandPaletteItem(
                id: "palette.zone.tools",
                title: "Toggle Tools Zone",
                subtitle: "Show or hide the specialized tools zone (⌘⇧2)",
                category: "navigate",
                shortcutHint: "⌘⇧2",
                action: .navigateTo(destination: "tools")
            ),
            CommandPaletteItem(
                id: "palette.zone.chat",
                title: "Toggle Chat Zone",
                subtitle: "Show or hide the AI chat zone (⌘⇧3)",
                category: "navigate",
                shortcutHint: "⌘⇧3",
                action: .navigateTo(destination: "chat")
            ),
            CommandPaletteItem(
                id: "palette.zone.dynamic",
                title: "Toggle Dynamic Zone",
                subtitle: "Show or hide the dynamic zone (Kanban + Todo)",
                category: "navigate",
                shortcutHint: "⌘⇧4",
                action: .navigateTo(destination: "kanban")
            )
        ]
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
            ),
            CommandPaletteItem(
                id: "palette.settings.skills",
                title: "Open Settings — Skills",
                subtitle: "Browse installed skills + slash commands",
                category: "command",
                shortcutHint: nil,
                action: .openSettings(tab: "skills")
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
}
