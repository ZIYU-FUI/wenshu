//
// Sources/WenshuApp/Views/Windows/_FILE_.swift
//
//  Independent Composer window (= NoteComposer operating surface).
//
//  Per the existing kanban + todo window pattern: an MVP composer
//  surface that calls into `NoteComposer` (= the rename / merge /
//  split helpers).
//
//  Standards axis:
//    S1 (Apple-API-first): pure SwiftUI primitives + SF Symbols 6
//        + Apple HIG `.windowResizability(.contentSize)` (= the
//        same shape as kanban + todo windows).
//    S3 (single source of truth for composer logic): the view
//        delegates all rename / merge / split logic to NoteComposer;
//        = the view never modifies content directly.

import SwiftUI

/// Independent Composer window (= the multi-window MVP).
///
/// Provides a form to call `NoteComposer`'s rename / merge / split
/// helpers (= `NoteComposer` is the canonical composer surface;
/// = this view is the UI host).
@MainActor
struct ComposerWindow: View {

    @State private var selectedOperation: Operation = .rename
    @State private var sourceNoteId: String = ""
    @State private var oldName: String = ""
    @State private var newName: String = ""
    @State private var targetNoteId: String = ""
    @State private var startLine: String = ""
    @State private var endLine: String = ""
    @State private var resultText: String?

    enum Operation: String, CaseIterable, Identifiable {
        case rename
        case merge
        case split
        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .rename: return String(localized: "composer.op.rename")
            case .merge:  return String(localized: "composer.op.merge")
            case .split:  return String(localized: "composer.op.split")
            }
        }
    }

    init() {}

    var body: some View {
        NavigationStack {
            formBody
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Picker("Operation", selection: $selectedOperation) {
                            ForEach(Operation.allCases) { op in
                                Text(op.displayName).tag(op)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
        }
        .frame(minWidth: 540, minHeight: 400)
    }

    @ViewBuilder
    private var formBody: some View {
        Form {
            Section {
                TextField(
                    String(localized: "composer.field.note_id"),
                    text: $sourceNoteId
                )
                .textFieldStyle(.roundedBorder)
            } header: {
                Text(String(localized: "composer.section.note_id"))
            }
            switch selectedOperation {
            case .rename:
                Section {
                    TextField(
                        String(localized: "composer.field.old_name"),
                        text: $oldName
                    )
                    .textFieldStyle(.roundedBorder)
                    TextField(
                        String(localized: "composer.field.new_name"),
                        text: $newName
                    )
                    .textFieldStyle(.roundedBorder)
                } header: {
                    Text(String(localized: "composer.section.rename"))
                }
            case .merge:
                Section {
                    TextField(
                        String(localized: "composer.field.target_note_id"),
                        text: $targetNoteId
                    )
                    .textFieldStyle(.roundedBorder)
                } header: {
                    Text(String(localized: "composer.section.merge"))
                }
            case .split:
                Section {
                    TextField(
                        String(localized: "composer.field.start_line"),
                        text: $startLine
                    )
                    .textFieldStyle(.roundedBorder)
                    TextField(
                        String(localized: "composer.field.end_line"),
                        text: $endLine
                    )
                    .textFieldStyle(.roundedBorder)
                } header: {
                    Text(String(localized: "composer.section.split"))
                }
            }
            if let resultText {
                Section {
                    Text(resultText)
                        .font(.caption)
                } header: {
                    Text(String(localized: "composer.section.result"))
                }
            }

            // Run button = call `NoteComposer` per the selected
            // operation. `NoteComposer.rename` / `merge` / `split`
            // are the canonical composer surfaces (= this view is
            // the UI host).
            Section {
                Button(String(localized: "composer.run")) {
                    runOperation()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private func runOperation() {
        switch selectedOperation {
        case .rename:
            resultText = NoteComposer.rename(
                oldName: oldName,
                newName: newName,
                content: sourceNoteId
            )
        case .merge:
            // NoteComposer.merge takes a list of source
            // contents (= not just one body); = wrap the
            // current sourceNoteId as a single-item list.
            // Swift array literals cannot infer tuple element
            // labels from the parameter declaration; = use
            // an explicit (name:content:) tuple literal so
            // the call matches NoteComposer's signature.
            let pair: (name: String, content: String) = (name: sourceNoteId, content: sourceNoteId)
            resultText = NoteComposer.merge(
                targetName: targetNoteId,
                sourceContents: [pair]
            )
        case .split:
            let start = Int(startLine) ?? 0
            let end = Int(endLine) ?? 0
            // NoteComposer.split throws and returns a tuple
            // (= first: String = before-split body; = second:
            // String = after-split body); = the MVP path
            // shows the first part in the result panel
            // (= the second part is also available via the
            // = a future ticket can add a second text
            // field to render both).
            do {
                let split = try NoteComposer.split(
                    content: sourceNoteId,
                    startLine: start,
                    endLine: end
                )
                resultText = "first: \(split.first)\nsecond: \(split.second)"
            } catch {
                resultText = "split failed: \(error)"
            }
        }
    }
}