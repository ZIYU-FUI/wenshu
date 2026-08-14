// BookEditorSheet.swift · Wenshu (Wenshu) · v0.02.1 (book module)
//
// The 'New Book' / 'Rename Book' modal. Mirrors BookshelfEditorSheet
// (v41) with one extra field (author). Apple HIG-standard modal form.

import SwiftUI

struct BookEditorSheet: View {
    enum Mode {
        case create
        case rename(title: String, author: String)
    }

    let mode: Mode
    let onCommit: (String, String) throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String = ""
    @State private var author: String = ""
    @State private var error: String?

    init(mode: Mode, onCommit: @escaping (String, String) throws -> Void) {
        self.mode = mode
        self.onCommit = onCommit
        switch mode {
        case .create:
            _title = State(initialValue: "")
            _author = State(initialValue: "")
        case .rename(let initialTitle, let initialAuthor):
            _title = State(initialValue: initialTitle)
            _author = State(initialValue: initialAuthor)
        }
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canCommit: Bool {
        !trimmedTitle.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(titleText)
                .font(.headline)
            TextField("书名", text: $title)
                .textFieldStyle(.roundedBorder)
                .onSubmit(commit)
            TextField("作者（可选）", text: $author)
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

    private var titleText: String {
        switch mode {
        case .create: return "新建书"
        case .rename: return "重命名书"
        }
    }

    private func commit() {
        let n = trimmedTitle
        guard !n.isEmpty else { return }
        do {
            try onCommit(n, author.trimmingCharacters(in: .whitespacesAndNewlines))
            dismiss()
        } catch {
            self.error = "\(error)"
        }
    }
}