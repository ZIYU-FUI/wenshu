// BookEditorSheet.swift · Wenshu (Wenshu) · v0.02.1 (book module) + v52 (wizard)
//
// The 'New Book' / 'Rename Book' modal.
//
// v52 (= boss 8/15 17:32 '书名, 篇幅选择, 创意点, 然后新建') adds the
// New Book Creation Wizard. Three fields:
//   - 书名 (title)            required, TextField, autofocus
//   - 篇幅 (length)           Picker (.segmented), default .medium
//   - 创意点（选填）(idea)     optional, TextField (.axis = .vertical)
//
// All three fields live in a single modal (= owner拍 '先实现最简新建书
// 的逻辑'). Not a multi-step NavigationStack wizard (= overkill for three
// fields; the Apple HIG Picker for length gives a quick visual pick
// without leaving the modal).
//
// Apple HIG components used:
//   - .sheet(isPresented:)     modal container
//   - Form                     standardized layout
//   - Section                  grouping
//   - TextField                 title + idea (= single + multiline axis)
//   - Picker (.segmented)      length (= 3 options, segmented is the
//                               HIG-recommended style when there are
//                               < 5 options)
//   - Form.footer              the "选填" hint (= Apple HIG: use a footer
//                               rather than placeholder text for
//                               optional fields)
//
// Rename mode keeps the same form (= no length / idea changes there
// because rename is for re-labeling, not re-categorizing; v0.04+ will
// add a separate 'Edit Book' sheet if needed).

import SwiftUI

struct BookEditorSheet: View {
    enum Mode {
        case create
        case rename(title: String, author: String)
    }

    let mode: Mode
    /// On commit, the wizard emits the field values. The view does
    /// NO business logic (= the Library model owns the contract; the
    /// view is a thin shell over it).
    ///
    /// Parameters: (title, author, length, idea). The Library decides
    /// what to do with them (= in v52, addBook wraps these into a new
    /// Book + persists + auto-selects).
    let onCommit: (String, String, BookLength, String?) throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String = ""
    @State private var author: String = ""
    @State private var length: BookLength = .medium
    @State private var idea: String = ""
    @State private var error: String?

    init(mode: Mode, onCommit: @escaping (String, String, BookLength, String?) throws -> Void) {
        self.mode = mode
        self.onCommit = onCommit
        switch mode {
        case .create:
            _title = State(initialValue: "")
            _author = State(initialValue: "")
            _length = State(initialValue: .medium)
            _idea = State(initialValue: "")
        case .rename(let initialTitle, let initialAuthor):
            _title = State(initialValue: initialTitle)
            _author = State(initialValue: initialAuthor)
            // Rename keeps the book at its current length / idea (= no
            // re-categorization on rename).
            _length = State(initialValue: .medium)
            _idea = State(initialValue: "")
        }
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedIdea: String? {
        let t = idea.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    private var canCommit: Bool {
        !trimmedTitle.isEmpty
    }

    private var titleText: String {
        switch mode {
        case .create: return "新建书"
        case .rename: return "重命名书"
        }
    }

    var body: some View {
        Form {
            Section {
                TextField("书名", text: $title)
                    .onSubmit(commit)
                TextField("作者（可选）", text: $author)
                    .onSubmit(commit)
            } header: {
                Text(titleText)
            } footer: {
                if let error {
                    Text(error)
                        .foregroundStyle(.red)
                }
            }
            // Length + idea are only shown in .create mode (= rename
            // doesn't re-categorize the book).
            if case .create = mode {
                Section {
                    Picker("篇幅", selection: $length) {
                        ForEach(BookLength.allCases, id: \.self) { len in
                            Text(len.displayName).tag(len)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("篇幅")
                } footer: {
                    Text("选中后可在书内逐章调整。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section {
                    TextField(
                        "创意点（选填）",
                        text: $idea,
                        axis: .vertical
                    )
                    .lineLimit(2...6)
                } header: {
                    Text("创意点（选填）")
                } footer: {
                    Text("一句话写你的故事方向；以后会用作 AI 写作助手的上下文。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 420)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存", action: commit)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canCommit)
            }
        }
    }

    private func commit() {
        let n = trimmedTitle
        guard !n.isEmpty else { return }
        do {
            let trimmedAuthor = author.trimmingCharacters(in: .whitespacesAndNewlines)
            try onCommit(n, trimmedAuthor, length, trimmedIdea)
            dismiss()
        } catch {
            self.error = "\(error)"
        }
    }
}