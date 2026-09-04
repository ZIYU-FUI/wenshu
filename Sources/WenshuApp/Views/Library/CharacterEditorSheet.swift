// CharacterEditorSheet.swift · Wenshu (文枢) · v0.26 (FCP library replica)
//
// Editor sheet for a single character. Per boss 2026-08-26 OOB
// '人物设定' = each character has name + role + narrative arc +
// summary. Color-coded by role (Apple HIG semantic color convention,
// mirrors FCP Role's color pattern).
//
// v0.26 FCP library replica spec at
// `.scratch/2026-08-26-fcp-library-replica/spec.md` ticket 011.

import SwiftUI

struct CharacterEditorSheet: View {
    let bookId: UUID
    let existingCharacter: Character?
    let onSave: (Character) -> Void
    let onCancel: () -> Void

    @State private var name: String
    @State private var ageText: String
    @State private var role: CharacterRole
    @State private var arc: String
    @State private var summary: String

    init(
        bookId: UUID,
        existingCharacter: Character? = nil,
        onSave: @escaping (Character) -> Void,
        onCancel: @escaping () -> Void = {}
    ) {
        self.bookId = bookId
        self.existingCharacter = existingCharacter
        self.onSave = onSave
        self.onCancel = onCancel
        _name = State(initialValue: existingCharacter?.name ?? "")
        _ageText = State(initialValue: existingCharacter?.age.map(String.init) ?? "")
        _role = State(initialValue: existingCharacter?.role ?? .other)
        _arc = State(initialValue: existingCharacter?.arc ?? "")
        _summary = State(initialValue: existingCharacter?.summary ?? "")
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(existingCharacter == nil ? "新建角色" : "编辑角色")
                    .font(.headline)
                Spacer()
            }
            .padding()
            Divider()
            Form {
                Section("基本信息") {
                    TextField("姓名", text: $name)
                        .textFieldStyle(.roundedBorder)
                    HStack {
                        TextField("年龄 (可选)", text: $ageText)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 120)
                        Picker("角色定位", selection: $role) {
                            ForEach(CharacterRole.allCases, id: \.self) { r in
                                Label(r.displayName, systemImage: r.icon)
                                    .tag(r)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
                Section("叙事弧 (主角从 a 状态经过 b 事件最终 c 状态)") {
                    TextField("叙事弧 (可选)", text: $arc, axis: .vertical)
                        .lineLimit(2...4)
                        .textFieldStyle(.roundedBorder)
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
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(minWidth: 460, idealWidth: 560, minHeight: 440, idealHeight: 520)
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        let age = Int(ageText.trimmingCharacters(in: .whitespacesAndNewlines))
        let now = Date.now
        let character: Character
        if let existing = existingCharacter {
            character = Character(
                id: existing.id,
                bookId: existing.bookId,
                name: trimmedName,
                age: age,
                role: role,
                arc: arc.isEmpty ? nil : arc,
                summary: summary,
                worldRefIds: existing.worldRefIds,
                characterRefIds: existing.characterRefIds,
                referenceRefIds: existing.referenceRefIds,
                createdAt: existing.createdAt,
                updatedAt: now
            )
        } else {
            character = Character(
                bookId: bookId,
                name: trimmedName,
                age: age,
                role: role,
                arc: arc.isEmpty ? nil : arc,
                summary: summary
            )
        }
        onSave(character)
    }
}