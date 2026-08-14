// BookshelfEditorSheet.swift · Wenshu (Wenshu) · v0.02.0 (bookshelf module)
//
// The 'New Shelf' / 'Rename Shelf' modal. Apple HIG-standard modal form
// (= Notes / Reminders / Finder 'New Folder' dialog): a single text field
// for the name, Cancel + OK buttons, keyboard focus on the field at open.
//
// Owner 8/15 15:55: '架构需要先定好, 不能没事加个东西, 然后重构一堆
// 东西'. The modal is a pure view; the callback closes over a single
// mutation (= addShelf / renameShelf from WenshuLibrary). No direct
// store access.

import SwiftUI

struct BookshelfEditorSheet: View {
    enum Mode {
        case create
        case rename(String)  // initial name (= prefilled)
    }

    let mode: Mode
    let onCommit: (String) throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var error: String?

    init(mode: Mode, onCommit: @escaping (String) throws -> Void) {
        self.mode = mode
        self.onCommit = onCommit
        // Initial value for the field (= prefill in rename mode).
        switch mode {
        case .create: _name = State(initialValue: "")
        case .rename(let initial): _name = State(initialValue: initial)
        }
    }

    private var title: String {
        switch mode {
        case .create: return "新建书架"
        case .rename: return "重命名书架"
        }
    }

    private var trimmed: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canCommit: Bool {
        !trimmed.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            TextField("书架名称", text: $name)
                .textFieldStyle(.roundedBorder)
                .onSubmit(commit)
                .frame(minWidth: 280)
            if let error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            HStack {
                Spacer()
                Button("取消", role: .cancel) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                Button("保存") {
                    commit()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canCommit)
            }
        }
        .padding(20)
        .frame(minWidth: 320)
    }

    private func commit() {
        let n = trimmed
        guard !n.isEmpty else { return }
        do {
            try onCommit(n)
            dismiss()
        } catch {
            self.error = "\(error)"
        }
    }
}