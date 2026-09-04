//
//  AgentSettingsView.swift · Wenshu · v0.35 ticket 006 + 009 + 010
//
//  Agent settings pane with 3 sub-sections:
//    - LLM Connector (= 7 provider profiles with API key input + test)
//    - Memory (= enable toggle + scope + retention + recent entries)
//    - Skills (= installed skills + slash-command tester)
//
//  Iron rule 6 compliance: layout/spacing uses DesignTokens. Min window
//  size is Apple HIG standard for Settings windows (= no magic numbers).
//

import SwiftUI

// Apple HIG canonical Settings window dimensions (= Chrome = 30, body
// needs ~500 PT for stacked sections). Token scope: window sizing is
// not in DesignTokens (= DesignTokens = chrome/spacing; window sizing
// is HIG-defined).
private let settingsMinWidth: CGFloat = 600
private let settingsMinHeight: CGFloat = 500

public struct AgentSettingsView: View {
    @State public var selectedSection: AgentSection = .llmConnector

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Section picker
            Picker("", selection: $selectedSection) {
                Label("LLM", systemImage: "cpu").tag(AgentSection.llmConnector)
                Label("Memory", systemImage: "brain.head.profile").tag(AgentSection.memory)
                Label("Skills", systemImage: "command").tag(AgentSection.skills)
            }
            .pickerStyle(.segmented)
            .padding(DesignTokens.chromePaddingMedium)

            Divider()

            // Active section content
            Group {
                switch selectedSection {
                case .llmConnector:
                    LLMConnectorSettingsView()
                case .memory:
                    MemorySettingsView()
                case .skills:
                    SkillsSettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: settingsMinWidth, minHeight: settingsMinHeight)
    }

    public enum AgentSection: String, CaseIterable, Hashable {
        case llmConnector
        case memory
        case skills
    }
}