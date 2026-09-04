// ReferenceEditorSheet.swift · Wenshu (文枢) · v0.26 (FCP library replica)
//
// Editor sheet for a single reference. Library-public (= cross-book
// shared; boss 8/26 OOB). The user can import a source (= a book
// title, a web URL, a research note) and it becomes a Reference
// available across all books in the library.
//
// v0.26 FCP library replica spec at
// `.scratch/2026-08-26-fcp-library-replica/spec.md` ticket 013.

import SwiftUI

struct ReferenceEditorSheet: View {
    let existingReference: Reference?
    let onSave: (Reference) -> Void
    let onCancel: () -> Void

    @State private var title: String
    @State private var source: String
    @State private var url: String
    @State private var layer: ReferenceLayer
    @State private var summary: String

    init(
        existingReference: Reference? = nil,
        defaultLayer: ReferenceLayer = .layerRaw,
        onSave: @escaping (Reference) -> Void,
        onCancel: @escaping () -> Void = {}
    ) {
        self.existingReference = existingReference
        self.onSave = onSave
        self.onCancel = onCancel
        _title = State(initialValue: existingReference?.title ?? "")
        _source = State(initialValue: existingReference?.source ?? "")
        _url = State(initialValue: existingReference?.url ?? "")
        _layer = State(initialValue: existingReference?.layer ?? defaultLayer)
        _summary = State(initialValue: existingReference?.summary ?? "")
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(existingReference == nil ? "新建资料" : "编辑资料")
                    .font(.headline)
                Spacer()
            }
            .padding()
            Divider()
            Form {
                Section("基本信息") {
                    TextField("标题", text: $title)
                        .textFieldStyle(.roundedBorder)
                    TextField("来源 (可选, 例如 书籍名 / 作者 / 出版年)", text: $source)
                        .textFieldStyle(.roundedBorder)
                    TextField("URL (可选)", text: $url)
                        .textFieldStyle(.roundedBorder)
                }
                Section("分层") {
                    Picker("所在层", selection: $layer) {
                        ForEach(ReferenceLayer.allCases, id: \.self) { l in
                            if l.isUserFacing {
                                Label(l.displayName, systemImage: l.icon)
                                    .tag(l)
                            }
                        }
                    }
                    .pickerStyle(.menu)
                    Text(layer == .layerRaw
                         ? "原始资料 = 用户手动导入的来源 (v0.26 唯一可选层)。"
                         : "实体 = LLM 自动整理的实体 (v0.27+ 启用)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Section("摘要 (一行的中心思想)") {
                    TextField("摘要", text: $summary, axis: .vertical)
                        .lineLimit(2...4)
                        .textFieldStyle(.roundedBorder)
                }
            }
            .formStyle(.grouped)
            Divider()
            HStack {
                Button("取消", role: .cancel) { onCancel() }
                Spacer()
                Button("保存") { save() }
                    .buttonStyle(.borderedProminent)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(minWidth: 460, idealWidth: 560, minHeight: 480, idealHeight: 560)
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        let now = Date.now
        let reference: Reference
        if let existing = existingReference {
            reference = Reference(
                id: existing.id,
                title: trimmedTitle,
                source: source.isEmpty ? nil : source,
                url: url.isEmpty ? nil : url,
                layer: layer,
                summary: summary,
                characterRefIds: existing.characterRefIds,
                worldRefIds: existing.worldRefIds,
                bookRefIds: existing.bookRefIds,
                createdAt: existing.createdAt,
                updatedAt: now
            )
        } else {
            reference = Reference(
                title: trimmedTitle,
                source: source.isEmpty ? nil : source,
                url: url.isEmpty ? nil : url,
                layer: layer,
                summary: summary
            )
        }
        onSave(reference)
    }
}