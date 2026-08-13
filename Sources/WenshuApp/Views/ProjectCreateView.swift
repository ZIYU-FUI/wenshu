// ProjectCreateView.swift · 文枢 (Wenshu) · v0.01.0 WO-004 → WO-007 →
// v0.03.0 V0-fix-1 (Fix D) → v0.05.0 t_ce783c49 (FCP 弹窗规范迁移)
//
// v0.05.0 t_ce783c49 (老板 8/13 01:25 OOB 参考 FCP 项目标题弹窗规范):
// Form + Section (iOS list 竖排观感) 整段迁 PopupFrame + PopupFormRow +
// PopupChipGroup + PopupButtonBar 横向紧凑布局。 规范真值见
// .hermes/kanban/reports/DESIGN-POPUP-FCP-2026-08-13.md。
// 文笔风格由 `.pickerStyle(.segmented)` 改 5 chip 横排 (规范 §3)。
//
// V0-fix-1 Fix D (装机 user 8/10 拍板): modal 尺寸 540×480 硬固定
// (用户拖不动)。 原 `.frame(minWidth: 520, minHeight: 480)` 软下限在
// split view 里跟主 window 一起变形, 比例失调; 锁死后视觉稳定, 跟
// macOS HIG 标准 modal (≈ Pages 新建文档) 对齐。 本文件自己挂
// `.frame(width: 540, height: 480)`, 不交给 PopupFrame — 尺寸是本弹窗
// 的拍板真值, 且 V0Fix1LayoutTests / V0Fix6LayoutTests 按源码字面量断言。
//
// Sheet 不挡主窗口 (FCP inspector sheet 风格) = SwiftUI 默认行为。
//
// WO-006 fix (保留): @FocusState + 自动 focus, 让 TextField 视觉激活
// 同时真正拿到 first responder。
//
// WO-007 fix (Spec 方案 A, 保留): macOS sheet 在 parent app 不是
// foreground 时抢不到 key window → .onAppear 调
// `WindowActivation.forceKeyToWenshuSheet()`, 0.3s 后强制 makeKey,
// 再叠加 WO-006 的 @FocusState auto-focus。

import SwiftUI

struct ProjectCreateView: View {
    /// Called when the user clicks "创建" with a valid form.
    var onCreate: (ProjectSnapshot) -> Void
    /// Called when the user cancels or closes the sheet.
    var onCancel: () -> Void

    @State private var name: String = ""
    @State private var style: String = "严肃"
    @State private var verbosity: Double = 5
    @State private var tagsText: String = ""

    // WO-006 fix: macOS sheet TextField 键盘路由断了 → 加 @FocusState +
    // 自动 focus, 延迟 0.3s 避开 sheet 动画焦点冲突。装机 user 8/7 反馈。
    @FocusState private var nameFocused: Bool
    @FocusState private var tagsFocused: Bool

    private let styles: [String] = ["严肃", "轻松", "诗意", "幽默", "口语"]

    var body: some View {
        PopupFrame(title: "新建项目") {
            rows
        } footer: {
            PopupButtonBar(
                confirmTitle: "创建",
                confirmDisabled: trimmedName.isEmpty,
                onCancel: onCancel,
                onConfirm: create
            )
        }
        // V0-fix-1 Fix D: 540x480 硬固定 (原 520x480 软下限被装机 user
        // 拍板撤换 — 软下限在 split view 里视觉跟主窗口变形)。
        .frame(width: 540, height: 480)
        .onAppear {
            // WO-007 fix (Solution A) — 强制 sheet NSWindow makeKey,
            // 抢回 key window 状态, key event 才路由到 sheet 而非原 key app。
            WindowActivation.forceKeyToWenshuSheet()

            // WO-006 fix: 延迟 0.3s 等 sheet 弹出动画走完再抢焦点,
            // 动画期间 SwiftUI 焦点路由会丢, 输入路由才真通。
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

        PopupFormRow(label: "文笔风格") {
            PopupChipGroup(options: styles, selection: $style)
        }

        PopupFormRow(label: "注水量") {
            HStack(spacing: PopupMetrics.inner) {
                Text("1").font(.caption).foregroundStyle(.secondary)
                Slider(value: $verbosity, in: 1...9, step: 1)
                Text("9").font(.caption).foregroundStyle(.secondary)
                Text("\(Int(verbosity))")
                    .font(.headline)
                    .frame(width: 24, alignment: .trailing)
            }
        }

        PopupFormRow(label: "标签") {
            TextField("用逗号分隔,如：玄幻, 少年, 复仇", text: $tagsText)
                .textFieldStyle(.roundedBorder)
                .focused($tagsFocused)
                .help("多个标签用逗号分隔")
        }

        PopupFormRow(label: "预览") {
            previewRow
        }
    }

    private var previewRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(trimmedName.isEmpty ? "(未命名)" : trimmedName)
                .font(.headline)
            HStack(spacing: 8) {
                Text(style).font(.caption).foregroundStyle(.secondary)
                Text("注水 \(Int(verbosity))").font(.caption).foregroundStyle(.secondary)
                if !parsedTags.isEmpty {
                    Text(parsedTags.joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    // MARK: - 数据

    private func create() {
        onCreate(
            ProjectSnapshot(
                name: trimmedName,
                style: style,
                verbosity: Int(verbosity),
                tags: parsedTags
            )
        )
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespaces)
    }

    private var parsedTags: [String] {
        tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}
