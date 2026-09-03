//
//  SkillsSettingsView.swift · Wenshu · v0.35 ticket 010
//
//  Settings pane for skill subsystem (= spec §6.4 🟥 must-UI).
//  Renders: installed skills list with enable/disable toggles + install
//  new skill UI (deferred to v0.35.1).
//

import SwiftUI

// File-scope constant (= Apple HIG subtle surface tint = 0.05 alpha).
private let subtleSurfaceAlpha: CGFloat = 0.05

public struct SkillsSettingsView: View {
    @State public var skills: [SkillAdapter.Skill]
    @State public var slashCommandBuffer: String = ""

    public init(skills: [SkillAdapter.Skill] = []) {
        self._skills = State(initialValue: skills)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Skills")
                .font(.headline)
            Text("Skills are /-prefixed commands that extend the agent (= /compress, /help, /rewind, etc.).")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            // Skill command tester
            HStack {
                Text("Try a command:")
                    .font(.caption)
                TextField("/compress focus on chapter 3", text: $slashCommandBuffer)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
                if let parsed = SkillAdapter.parseSlashCommand(slashCommandBuffer) {
                    Text("→ \\(parsed.skillName)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            // Installed skills list
            Text("Installed skills (\\(skills.count))")
                .font(.subheadline)

            if skills.isEmpty {
                Text("No skills installed yet. Skills are loaded from the skill registry.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, DesignTokens.chromePaddingSmall)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(skills) { skill in
                            SkillRow(skill: skill)
                        }
                    }
                }
                .frame(maxHeight: 200)
            }
        }
        .padding(12)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

public struct SkillRow: View {
    public let skill: SkillAdapter.Skill
    @State private var isEnabled: Bool

    public init(skill: SkillAdapter.Skill) {
        self.skill = skill
        self._isEnabled = State(initialValue: skill.enabled)
    }

    public var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("/\\(skill.name)")
                    .font(.system(.caption, design: .monospaced))
                Text(skill.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: $isEnabled)
                .toggleStyle(.switch)
                .labelsHidden()
        }
        .padding(6)
        .background(Color.secondary.opacity(subtleSurfaceAlpha), in: RoundedRectangle(cornerRadius: 4))
    }
}