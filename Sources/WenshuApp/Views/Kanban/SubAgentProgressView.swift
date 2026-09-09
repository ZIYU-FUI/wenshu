//
// SubAgentProgressView.swift · Wenshu · v0.23 ticket 005 (sub-agent progress)
//
// [CJK-TRANSLATE] 1 line(s) awaiting manual translation (see git blame for original CJK text)
// Boss 2026-08-23: 'kanbanchat, userworkprogress'.
//  Reads from KanbanStore, renders running / done sub-agent tasks in aiDynamic zone.
//

import SwiftUI

/// Sub-agent progress view: (transparent open box) showing all sub-agent tasks.
/// Reads KanbanStore (actor) and renders task list with status, title, duration.
/// Per boss 8/23: 'userworkprogress'.
public struct SubAgentProgressView: View {
    @State private var store: KanbanStore?
    @State private var tasks: [KanbanTask] = []
    @State private var refreshTrigger: Int = 0

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(WenshuI18n.t("subagent.progress_title"))
                    .font(.headline)
                Spacer()
                Text(WenshuI18n.t("auto2.subagentprogressview.l27.h17103990"))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Divider()

            if store == nil {
                Text(WenshuI18n.t("b5.subagentprogressview.l35.h27766576"))
                    .font(.body)
                    .foregroundStyle(.tertiary)
            } else if tasks.isEmpty {
                Text(WenshuI18n.t("subagent.empty_state"))
                    .font(.body)
                    .foregroundStyle(.tertiary)
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
                    .foregroundStyle(.tertiary)
                Spacer()
                Button(WenshuI18n.t("auto2.subagentprogressview.l59.h26216387")) {
                    refreshTrigger += 1
                }
                .buttonStyle(.bordered)
                .font(.caption)
            }
        }
        .padding()
        // v0.24 bossverificationfix (2026-08-24): removed fixed minWidth/minHeight.
        // Tab content must follow zone size, not force zone to be 480x320.
        // Boss 8/24 feedback: 'tab viewchangechangeregionsize, autoregionsize'.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task {
            if store == nil {
                store = try? KanbanStore()
            }
        }
        .task(id: refreshTrigger) {
            // Auto-refresh every 2s (Apple HIG live update pattern).
            // v0.23 audit #014 fix: check cancellation between refresh
            // + sleep (boss 8/23 risk-averse: don't leak refresh cycles
            // on view dismiss).
            while !Task.isCancelled {
                refreshTasks()
                do {
                    try await Task.sleep(nanoseconds: 2_000_000_000)
                } catch {
                    return  // cancelled mid-sleep
                }
            }
        }
    }

    private func refreshTasks() {
        guard let store = store else { return }
        tasks = (try? store.list()) ?? []
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
        HStack(spacing: 8) {
            statusIcon
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.body)
                Text(statusLabel)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
        }
        .padding(DesignTokens.chromePaddingVertical)
        // v0.28 followup Boss UX round 24: .regularMaterial replaces
        // v0.40 boss real-device test 2026-09-07: removed
        // .regularMaterial (= Liquid Glass sub-agent card);
        // now uses Color.clear (= no background).
        .background(Color.clear)
        .cornerRadius(DesignTokens.surfaceCornerRadiusProgressCard)
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch task.status {
        case .running:
            LucideIconSystemFallback("circle.dashed", size: 14)
                .foregroundStyle(.blue)
        case .done:
            LucideIconSystemFallback("checkmark.circle.fill", size: 14)
                .foregroundStyle(.green)
        case .failed:
            LucideIconSystemFallback("xmark.circle.fill", size: 14)
                .foregroundStyle(.red)
        default:
            LucideIconSystemFallback("circle", size: 14)
                .foregroundStyle(.tertiary)
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