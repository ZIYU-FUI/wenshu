//
// SubAgentProgressView.swift · Wenshu · v0.23 ticket 005 (sub-agent progress)
//
// 'kanbanchat, userworkprogress'.
//  Reads from WSKanbanRepository.shared (= @MainActor SwiftData wrapper; =  deleted KanbanStore actor), renders running / done sub-agent tasks in aiDynamic zone.
//

import SwiftUI

/// Sub-agent progress view: (transparent open box) showing all sub-agent tasks.
/// Reads WSKanbanRepository (= @MainActor SwiftData wrapper for WSKanbanTask @Model) and renders task list with status, title, duration.
/// 
struct SubAgentProgressView: View {
    @State private var tasks: [KanbanTask] = []
    @State private var refreshTrigger: Int = 0
    @Environment(WSRepositoryContainer.self) private var repositories: WSRepositoryContainer

    init() {}

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(WenshuI18n.t("subagent.progress_title"))
                    .font(.headline)
                Spacer()
                Text(WenshuI18n.t("auto2.subagentprogressview.l27.h17103990"))
                    .font(.caption)
                    .foregroundStyle(DesignTokens.statusForeground)
            }

            Divider()

            if tasks.isEmpty {
                Text(WenshuI18n.t("subagent.empty_state"))
                    .font(.body)
                    .foregroundStyle(DesignTokens.statusForeground)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(tasks, id: \.id) { task in
                            TaskRowView(task: task)
                        }
                    }
                }
            }

            Spacer()

            HStack {
                Text(WenshuI18n.t("subagent.live_update_hint"))
                    .font(.caption2)
                    .foregroundStyle(DesignTokens.statusForeground)
                Spacer()
                Button(WenshuI18n.t("auto2.subagentprogressview.l59.h26216387")) {
                    refreshTrigger += 1
                }
                .buttonStyle(.bordered)
                .font(.caption)
            }
        }
        .padding()
        // bossverificationfix (2026-08-24): removed fixed minWidth/minHeight.
        // Tab content must follow zone size, not force zone to be 480x320.
        // Boss 8/24 feedback: 'tab viewchangechangeregionsize, autoregionsize'.
        .task(id: refreshTrigger) {
            // Live update via EventBus (= AsyncStream; v0.71 cleanup batch 2 apple-miss fix).
            // SubAgentProgressView subscribes to kanban events; refresh on each event.
            // Manual Button trigger still works (= increments refreshTrigger = re-runs this .task).
            for await _ in EventBus.shared.events(categories: ["kanban"]) {
                refreshTasks()
            }
        }
    }

    private func refreshTasks() {
        tasks = (try? repositories.kanban.list()) ?? []
    }

    private var runningCount: Int {
        tasks.filter { $0.status == .running }.count
    }

    private var doneCount: Int {
        tasks.filter { $0.status == .done }.count
    }
}

private struct TaskRowView: View {
    let task: KanbanTask

    var body: some View {
        HStack(spacing: DesignTokens.spacingStandard) {
            statusIcon
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.body)
                Text(statusLabel)
                    .font(.caption)
                    .foregroundStyle(DesignTokens.statusForeground)
            }
            Spacer()
        }
        .padding(DesignTokens.spacingStandard)
        // followup Boss UX round 24: .regularMaterial replaces
        // boss real-device test 2026-09-07: removed
        // .regularMaterial (= Liquid Glass sub-agent card);
        // now uses Color.clear (= no background).
        .background(Color.clear)
        .cornerRadius(DesignTokens.surfaceCornerRadiusProgressCard)
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch task.status {
        case .running:
            SFIcon("circle.dashed", style: .inlineSmall, color: IconColor.blue)
        case .done:
            SFIcon("checkmark.circle", style: .inlineSmall, color: IconColor.green)
        case .failed:
            SFIcon("xmark.circle", style: .inlineSmall, color: IconColor.red)
        default:
            SFIcon("circle", style: .inlineSmall, color: IconColor.tertiary)
        }
    }

    private var statusLabel: String {
        switch task.status {
        case .new: return "pending"
        case .triage: return "triage"
        case .ready: return "ready"
        case .running: return "running..."
        case .blocked: return "blocked"
        case .review: return "review"
        case .done: return "done"
        case .failed: return "failed"
        }
    }
}
