//
//  SkillsSettingsView.swift · Wenshu · v0.35 ticket 010
//  + SETTINGS-PERSISTENCE-002 (2026-09-05).
//

import SwiftUI

private let smallChipCornerRadius: CGFloat = 3
private let subtleSurfaceAlpha: CGFloat = 0.05

public struct SkillsSettingsView: View {
    public let skills: [SkillAdapter.Skill]
    @State public var slashCommandBuffer: String = ""

    public init(skills: [SkillAdapter.Skill] = []) {
        self.skills = skills
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.chromePaddingMedium) {
            Text(WenshuI18n.t("settings.skills.title"))
                .font(.headline)
            Text(WenshuI18n.t("settings.skills.subtitle"))
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            HStack {
                Text(WenshuI18n.t("settings.skills.tryCommand"))
                    .font(.caption)
                TextField(WenshuI18n.t("settings.skills.tryCommand.placeholder"), text: $slashCommandBuffer)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
                if let parsed = SkillAdapter.parseSlashCommand(slashCommandBuffer) {
                    Text(WenshuI18n.ts("settings.skills.parsedHint", parsed.skillName))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            Text(WenshuI18n.tf("settings.skills.installed", skills.count))
                .font(.subheadline)

            if skills.isEmpty {
                Text(WenshuI18n.t("settings.skills.installed.empty"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, DesignTokens.chromePaddingSmall)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: DesignTokens.chromePaddingSmall) {
                        ForEach(skills) { skill in
                            SkillRow(skill: skill)
                        }
                    }
                }
                .frame(maxHeight: DesignTokens.settingsListMaxHeight)
            }
        }
        .padding(DesignTokens.chromePaddingMedium)
        // v0.40 boss 2026-09-08 OOB 'sweep for remaining background colors: removed the
        // chrome tier background tint (= .windowBackgroundColor
        // = boss wants gone per the 'go up another layer and remove the background' cleanup).
    }
}

public struct SkillRow: View {
    public let skill: SkillAdapter.Skill
    @State private var isEnabled: Bool

    public init(skill: SkillAdapter.Skill) {
        self.skill = skill
        self._isEnabled = State(initialValue: SkillAdapter().currentEnabled(name: skill.name))
    }

    public var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(WenshuI18n.t("b5.skillssettingsview.l80.h81170225"))
                    .font(.system(.caption, design: .monospaced))
                Text(skill.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: $isEnabled)
                .toggleStyle(.switch)
                .labelsHidden()
                .onChange(of: isEnabled) { _, newValue in
                    SkillAdapter.shared.setEnabled(name: skill.name, enabled: newValue)
                }
        }
        .padding(DesignTokens.chromePaddingSmall)
        .background(Color.secondary.opacity(subtleSurfaceAlpha), in: RoundedRectangle(cornerRadius: smallChipCornerRadius))
    }
}
