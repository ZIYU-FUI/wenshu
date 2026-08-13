// ProjectSettingsView.swift · 文枢 (Wenshu) · v0.05.0 t_ce783c49
//
// 项目设置弹窗。 老板 8/13 01:25 OOB 参考 FCP 项目标题弹窗规范 —
// 横向紧凑布局 + chip 横排 + 紧凑间距。 规范真值见
// .hermes/kanban/reports/DESIGN-POPUP-FCP-2026-08-13.md。
//
// 布局全走 Popup 库 (PopupFrame / PopupFormRow / PopupChipGroup /
// PopupButtonBar), 本文件只管字段与回调, 不自定义尺寸/间距/配色。
//
// 边界 (沿 AGENTS.md §5.4):
// - 不新增单例, 不碰 WenshuStoreActor, 不碰 .ws schema
// - 落库由调用方接 onSave 决定 (本视图不直接写 store)

import SwiftUI

struct ProjectSettingsView: View {
    /// 被编辑的项目快照 (入参真值)。
    var project: ProjectSnapshot
    /// 点"保存"回调, 带编辑后的快照。
    var onSave: (ProjectSnapshot) -> Void
    /// 点"取消"回调。
    var onCancel: () -> Void

    @State private var name: String
    // ponytail: genre / startTime / 3 toggle 只活在本视图 @State —
    // ProjectSnapshot 缺 genre / startTime / video / audio / custom 字段,
    // 加字段 = 改 Models (本卡 7 文件外), 留 v0.06 扩 schema 时接上。
    // 现在 onSave 只回写 name, 其余字段原样保留, 不假装已落库。
    @State private var genre: String
    @State private var startTime: Date
    @State private var videoEnabled: Bool
    @State private var audioEnabled: Bool
    @State private var customEnabled: Bool

    @FocusState private var nameFocused: Bool

    /// 题材 5 选项 (chip 横排, 沿规范 §3)。
    private let genres: [String] = ["玄幻", "都市", "历史", "科幻", "言情"]

    init(
        project: ProjectSnapshot,
        onSave: @escaping (ProjectSnapshot) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.project = project
        self.onSave = onSave
        self.onCancel = onCancel
        // @State 初值从入参快照取一次 — 后续编辑不回头改 project,
        // 点"保存"才把改动交给调用方。
        _name = State(initialValue: project.name)
        _genre = State(initialValue: "玄幻")
        _startTime = State(initialValue: project.createdAt)
        _videoEnabled = State(initialValue: false)
        _audioEnabled = State(initialValue: false)
        _customEnabled = State(initialValue: false)
    }

    var body: some View {
        PopupFrame(title: "项目设置", width: PopupMetrics.width) {
            rows
        } footer: {
            PopupButtonBar(
                confirmTitle: "保存",
                confirmDisabled: trimmedName.isEmpty,
                onCancel: onCancel,
                onConfirm: save
            )
        }
        .onAppear {
            // 沿 WO-007: macOS sheet 抢 key window, 否则键盘事件路由回原 app。
            WindowActivation.forceKeyToWenshuSheet()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                nameFocused = true
            }
        }
    }

    // MARK: - 主操作区 (规范 §2 横向 grid)

    @ViewBuilder
    private var rows: some View {
        PopupFormRow(label: "项目名") {
            TextField("必填", text: $name)
                .textFieldStyle(.roundedBorder)
                .focused($nameFocused)
        }

        PopupFormRow(label: "题材") {
            PopupChipGroup(options: genres, selection: $genre)
        }

        PopupFormRow(label: "开始时间") {
            DatePicker(
                "",
                selection: $startTime,
                displayedComponents: [.date, .hourAndMinute]
            )
            .labelsHidden()
        }

        PopupFormRow(label: "视频") {
            Toggle("渲染视频预览", isOn: $videoEnabled)
        }

        PopupFormRow(label: "音频") {
            Toggle("渲染音频", isOn: $audioEnabled)
        }

        PopupFormRow(label: "自定义设置") {
            Toggle("启用自定义设置", isOn: $customEnabled)
        }
    }

    // MARK: - 数据

    /// 只回写 name — 其余字段沿入参快照原样带回 (见上方 ponytail 注)。
    private func save() {
        var updated = project
        updated.name = trimmedName
        onSave(updated)
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespaces)
    }
}
