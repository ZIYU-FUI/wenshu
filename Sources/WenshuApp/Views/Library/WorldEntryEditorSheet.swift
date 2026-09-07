// WorldEntryEditorSheet.swift · Wenshu (文枢) · v0.26 (FCP library replica)
//
// Editor sheet for a single world-building entry. Per boss 2026-08-26
// OOB '按文件夹分开管理' = each world entry is a discrete .md file
// with a structured metadata header.
//
// v0.26 FCP library replica spec at
// `.scratch/2026-08-26-fcp-library-replica/spec.md` ticket 009.

import SwiftUI

struct WorldEntryEditorSheet: View {
    /// Parent book id (= the world.json index under
    /// books/<book-id>/world/ + the .md body under books/<book-id>/world/<uuid>.md).
    let bookId: UUID

    /// Optional existing entry (= edit mode). Nil = create mode.
    let existingEntry: WorldEntry?

    /// Save callback (= parent decides whether to use store.saveEntry
    /// vs store.replaceEntry).
    let onSave: (WorldEntry) -> Void

    /// Cancel callback (= dismiss sheet).
    let onCancel: () -> Void

    @State private var name: String
    @State private var type: WorldEntryType
    @State private var summary: String
    @State private var newTypeRaw: String
    @State private var newTypeDisplayName: String

    init(
        bookId: UUID,
        existingEntry: WorldEntry? = nil,
        onSave: @escaping (WorldEntry) -> Void,
        onCancel: @escaping () -> Void = {}
    ) {
        self.bookId = bookId
        self.existingEntry = existingEntry
        self.onSave = onSave
        self.onCancel = onCancel
        _name = State(initialValue: existingEntry?.name ?? "")
        _type = State(initialValue: existingEntry?.type ?? .other)
        _summary = State(initialValue: existingEntry?.summary ?? "")
        _newTypeRaw = State(initialValue: "")
        _newTypeDisplayName = State(initialValue: "")
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(existingEntry == nil ? "新建世界观条目" : "编辑世界观条目")
                    .font(.headline)
                Spacer()
            }
            .padding()
            Divider()
            Form {
                Section(WenshuI18n.t("auto2.worldentryeditorsheet.l60.h68295865")) {
                    TextField(WenshuI18n.t("auto2.worldentryeditorsheet.l61.h51100240"), text: $name)
                        .textFieldStyle(.roundedBorder)
                    Picker("类型", selection: $type) {
                        ForEach(WorldEntryType.allCases, id: \.self) { kind in
                            Label(kind.displayName, systemImage: kind.icon)
                                .tag(kind)
                        }
                    }
                    .pickerStyle(.menu)
                    if type == .other {
                        HStack {
                            TextField(WenshuI18n.t("auto2.worldentryeditorsheet.l72.h25860463"), text: $newTypeRaw)
                                .textFieldStyle(.roundedBorder)
                            TextField(WenshuI18n.t("auto2.worldentryeditorsheet.l74.h3499700"), text: $newTypeDisplayName)
                                .textFieldStyle(.roundedBorder)
                        }
                        .help(WenshuI18n.t("auto2.worldentryeditorsheet.l77.h96228527"))
                    }
                }
                Section(WenshuI18n.t("auto2.worldentryeditorsheet.l80.h15189232")) {
                    TextField(WenshuI18n.t("world_editor.summary_field"), text: $summary, axis: .vertical)
                        .lineLimit(2...4)
                        .textFieldStyle(.roundedBorder)
                }
            }
            .formStyle(.grouped)
            Divider()
            HStack {
                Button(WenshuI18n.t("auto2.worldentryeditorsheet.l89.h29496358"), role: .cancel) { onCancel() }
                Spacer()
                Button(WenshuI18n.t("auto2.worldentryeditorsheet.l91.h21300719")) { save() }
                    .buttonStyle(.borderedProminent)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(minWidth: 420, idealWidth: 520, minHeight: 360, idealHeight: 420)
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        let now = Date.now
        let entry: WorldEntry
        if let existing = existingEntry {
            entry = WorldEntry(
                id: existing.id,
                bookId: existing.bookId,
                type: type,
                name: trimmedName,
                summary: summary,
                characterRefIds: existing.characterRefIds,
                createdAt: existing.createdAt,
                updatedAt: now
            )
        } else {
            entry = WorldEntry(
                bookId: bookId,
                type: type,
                name: trimmedName,
                summary: summary
            )
        }
        onSave(entry)
    }
}