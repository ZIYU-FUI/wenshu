// CharacterWorldView.swift · 文枢 (Wenshu) · v0.01.0 WO-004
//
// Final view of the WO-004 flow. Displays the AI-generated character cards
// and world rules in a read-only scroll view. The "返回项目" button pops
// all the way back to the ProjectListView and resets the ChatViewModel.
//
// Per WO-004 spec: nothing is persisted. The view is just a renderer for
// the view-layer snapshots (`CharacterSnapshot`, `WorldRuleSnapshot`).

import SwiftUI

struct CharacterWorldView: View {
    @ObservedObject var vm: ChatViewModel
    @Binding var navPath: NavigationPath

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                charactersSection
                worldRulesSection
                Spacer(minLength: 0)
            }
            .padding()
        }
        .navigationTitle("人物与世界")
        .navigationSubtitle("AI 生成的骨架 (mock · WO-005 接真生成)")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("返回项目") {
                    vm.reset()
                    navPath.removeLast(navPath.count)
                }
            }
        }
    }

    // MARK: - Sections

    private var charactersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(symbol: "person.2.fill", title: "人物")
            if vm.characters.isEmpty {
                Text("(暂无)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(vm.characters) { character in
                    characterCard(character)
                }
            }
        }
    }

    private func characterCard(_ character: CharacterSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(character.name)
                    .font(.headline)
                Text(character.role)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.15))
                    .clipShape(Capsule())
            }
            Text(character.backstory)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var worldRulesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(symbol: "globe.asia.australia.fill", title: "世界规则")
            if vm.worldRules.isEmpty {
                Text("(暂无)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(vm.worldRules) { rule in
                    ruleRow(rule)
                }
            }
        }
    }

    private func ruleRow(_ rule: WorldRuleSnapshot) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(rule.rule)
                    .font(.body)
                Text(rule.category)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func sectionHeader(symbol: String, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .foregroundStyle(.tint)
            Text(title)
                .font(.title2)
                .bold()
            Spacer()
        }
    }
}
