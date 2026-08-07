// ProjectCreateView.swift · 文枢 (Wenshu) · v0.01.0 WO-004
//
// Modal sheet for creating a new project. Captures:
// - 项目名 (required)
// - 文笔风格 (5-option segmented picker)
// - 注水量 (1-9 slider)
// - 标签 (comma-separated TextField)
//
// On "创建" it emits a `ProjectSnapshot` via the `onCreate` closure.
// On "取消" it emits nothing and lets the parent dismiss the sheet.

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

    // WO-006 fix: macOS Form sheet TextField 键盘路由断了 → 加 @FocusState +
    // 自动 focus,延迟 0.3s 避开 sheet 动画焦点冲突。装机 user 8/7 反馈。
    @FocusState private var nameFocused: Bool
    @FocusState private var tagsFocused: Bool

    private let styles: [String] = ["严肃", "轻松", "诗意", "幽默", "口语"]

    var body: some View {
        VStack(spacing: 0) {
            form
            Divider()
            actionBar
        }
        .frame(minWidth: 520, minHeight: 480)
        .onAppear {
            // 延迟 0.3s:Form sheet 弹出动画期间 SwiftUI 焦点路由会丢,
            // 等动画完再抢焦点,输入路由才真通。
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                nameFocused = true
            }
        }
    }

    private var form: some View {
        Form {
            Section("基本信息") {
                TextField("项目名(必填)", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .focused($nameFocused)
            }

            Section("文笔风格") {
                Picker("风格", selection: $style) {
                    ForEach(styles, id: \.self) { s in
                        Text(s).tag(s)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("注水量") {
                HStack(spacing: 12) {
                    Text("1")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                    Slider(value: $verbosity, in: 1...9, step: 1)
                    Text("9")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                    Text("\(Int(verbosity))")
                        .font(.headline)
                        .frame(width: 24, alignment: .trailing)
                }
            }

            Section("标签") {
                TextField("用逗号分隔,如：玄幻, 少年, 复仇", text: $tagsText)
                    .textFieldStyle(.roundedBorder)
                    .focused($tagsFocused)
                    .help("多个标签用逗号分隔")
            }

            Section("预览") {
                previewRow
            }
        }
        .formStyle(.grouped)
        .padding(.horizontal)
        .padding(.top)
    }

    private var previewRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(name.isEmpty ? "(未命名)" : name)
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

    private var actionBar: some View {
        HStack {
            Spacer()
            Button("取消", role: .cancel) {
                onCancel()
            }
            .keyboardShortcut(.cancelAction)

            Button("创建") {
                let project = ProjectSnapshot(
                    name: name.trimmingCharacters(in: .whitespaces),
                    style: style,
                    verbosity: Int(verbosity),
                    tags: parsedTags
                )
                onCreate(project)
            }
            .keyboardShortcut(.defaultAction)
            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding()
    }

    private var parsedTags: [String] {
        tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}
