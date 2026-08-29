//
//  SubAgentProgressView.swift · Wenshu · v0.23 ticket 005 (sub-agent progress 明盒)
//
//  Boss 2026-08-23 拍: '看板放在聊天动态区, 虽然让用户知道工作进度的明盒'.
//  Reads from KanbanStore, renders running / done sub-agent tasks in aiDynamic zone.
//

import SwiftUI

/// Sub-agent progress view: 明盒 (transparent open box) showing all sub-agent tasks.
/// Reads KanbanStore (actor) and renders task list with status, title, duration.
/// Per boss 8/23 拍: '让用户知道工作进度的明盒'.
public struct SubAgentProgressView: View {
    @State private var store: KanbanStore?
    @State private var tasks: [KanbanTask] = []
    @State private var refreshTrigger: Int = 0

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("子代理进度")
                    .font(.headline)
                Spacer()
                Text("\(runningCount) 进行中 · \(doneCount) 已完成")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            Divider()

            if store == nil {
                Text("(loading KanbanStore...)")
                    .font(.system(size: 13))
                    .foregroundStyle(.tertiary)
            } else if tasks.isEmpty {
                Text("(暂无子代理任务 — 与文枢对话以触发)")
                    .font(.system(size: 13))
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
                Text("从 KanbanStore (actor) 实时更新 — 每 2 秒自动刷新 + 手动刷新按钮")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
                Button("刷新") {
                    refreshTrigger += 1
                }
                .buttonStyle(.bordered)
                .font(.caption)
            }
        }
        .padding()
        // v0.24 boss验收fix (2026-08-24): removed fixed minWidth/minHeight.
        // Tab content must follow zone size, not force zone to be 480x320.
        // Boss 8/24 feedback: 'tab 视图不改变区域大小, 自动适配区域大小'.
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
                    .font(.system(size: 13))
                Text(statusLabel)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            Spacer()
        }
        .padding(8)
        // v0.28 followup Boss UX round 24: .regularMaterial replaces
        // DesignColor.zoneSurface (= solid Color(nsColor: .controlBackgroundColor)
        // = NOT Liquid Glass). The sub-agent progress card now uses
        // the standard Liquid Glass card pattern (= matches macOS
        // notification cards / activity cards).
        .background(.regularMaterial)
        .cornerRadius(6)
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch task.status {
        case .running:
            Image(systemName: "circle.dashed")
                .foregroundStyle(.blue)
        case .done:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
        default:
            Image(systemName: "circle")
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