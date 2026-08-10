// ProjectSettingsTab.swift · 文枢 (Wenshu) · v0.02.0 WO-LT-03 v2
//
// Tab 3 = 设定. 只读展示 v0.01.0 ProjectSnapshot 字段 (name / style /
// verbosity / tags / createdAt)。
//
// 拍板:
// - 用户没在项目 tab 选 project 时 (settingsProject == nil) 显示
//   "请先在项目 tab 选一个项目" 提示
// - 选中后字段全部只读, 不编辑 (v0.02.0 边界; v0.03.0 阶段门再接编辑)

import SwiftUI

struct ProjectSettingsTab: View {
    let project: ProjectSnapshot?

    var body: some View {
        Group {
            if let project = project {
                content(for: project)
            } else {
                emptyState
            }
        }
        .navigationTitle("设定")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: ProjectManagementTab.settings.symbolName)
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.secondary)
            Text("未选择项目")
                .font(.title3)
            Text("请先在项目 tab 选一个项目")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private func content(for project: ProjectSnapshot) -> some View {
        Form {
            Section("项目名") {
                LabeledContent("名称", value: project.name)
            }

            Section("文笔风格") {
                LabeledContent("风格", value: project.style)
                LabeledContent("注水量", value: "\(project.verbosity)")
            }

            Section("标签") {
                if project.tags.isEmpty {
                    Text("(无)")
                        .foregroundStyle(.secondary)
                } else {
                    Text(project.tags.joined(separator: " · "))
                }
            }

            Section("元数据") {
                LabeledContent("创建时间", value: formattedDate(project.createdAt))
                LabeledContent("项目 ID", value: project.id.uuidString)
                    .font(.caption.monospaced())
            }
        }
        .formStyle(.grouped)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
