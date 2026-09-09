// BookEditorSheet.swift · Wenshu (Wenshu) · v0.02.1 (book module) + v52 (wizard)
//
// The 'New Book' / 'Rename Book' modal.
//
// v52 (= 8/15 17:32 ',,, ') adds the
// New Book Creation Wizard. Three fields:
// - (title) required, TextField, autofocus
// - (length) Picker (.segmented), default .medium
// - （）(idea) optional, TextField (.axis = .vertical)
//
// All three fields live in a single modal (= owner '
// '). Not a multi-step NavigationStack wizard (= overkill for three
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
// - Form.footer the "" hint (= Apple HIG: use a footer
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
                TextField(WenshuI18n.t("auto2.bookeditorsheet.l99.h94921264"), text: $title)
                    .onSubmit(commit)
                TextField(WenshuI18n.t("auto2.bookeditorsheet.l101.h15789783"), text: $author)
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
                    Text(WenshuI18n.t("book_editor.length"))
                } footer: {
                    Text(WenshuI18n.t("auto.bookeditorsheet.l124.h18390452"))
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
                    Text(WenshuI18n.t("book_editor.premise_label"))
                } footer: {
                    Text(WenshuI18n.t("book_editor.premise_caption"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 420)
        // POLISH-LIQUIDGLASS-004: New Book / Rename Book modal sheet
        // root uses Apple .glassEffect(.regular) (= macOS 27 Tahoe
        // Liquid Glass; same shape as POLISH-LIQUIDGLASS-001/002/003
        // that glassed TopBar + Sidebar + Editor chrome + StatusBar).
        // Color.clear provides the glass layer size; the modifier
        // applies the canonical Apple Liquid Glass material. No
        // custom border or shadow (= boss 2026-09-02 hard rule
        // 'every color comes from an Apple API'; .glassEffect already
        // includes the canonical hairline + depth shadow per Apple
        // HIG). Applied AFTER .formStyle(.grouped) + .frame so the
        // glass layer sizes to the sheet's minWidth: 420 outer rect.
        .background { Color.clear.glassEffect(.regular) }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(WenshuI18n.t("auto2.bookeditorsheet.l160.h80176953")) { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(WenshuI18n.t("auto2.bookeditorsheet.l163.h48925685"), action: commit)
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