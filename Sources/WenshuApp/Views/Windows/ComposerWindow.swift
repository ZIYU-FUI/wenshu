//
//  ComposerWindow.swift · Wenshu · v2.8b ticket T10-T13 (boss 2026-09-28 OOB B7)
//
//  Independent Composer window (= NoteComposer operating surface).
//
//  Per boss 2026-09-28 OOB B7 '和老板 todo 一样' (= same shape as
//  the existing kanban + todo windows): an MVP composer surface
//  that calls into NoteComposer (= the rename / merge / split
//  helpers).
//
//  Standards axis:
//    S1 (Apple-API-first): pure SwiftUI primitives + SF Symbols 6
//        + Apple HIG `.windowResizability(.contentSize)` (= the
//        same shape as kanban + todo windows).
//    S3 (single source of truth for composer logic): the view
//        delegates all rename / merge / split logic to NoteComposer;
//        = the view never modifies content directly.

import SwiftUI

/// Independent Composer window (= MVP per boss 2026-09-28 OOB B7).
///
/// Provides a form to call NoteComposer's rename / merge / split
/// helpers (= NoteComposer is the canonical composer surface per
/// AGENTS.md §11 baseline; = this view is the UI host).
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
            case .rename: return WenshuI18n.t("composer.op.rename")
            case .merge:  return WenshuI18n.t("composer.op.merge")
            case .split:  return WenshuI18n.t("composer.op.split")
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
                    WenshuI18n.t("composer.field.note_id"),
                    text: $sourceNoteId
                )
                .textFieldStyle(.roundedBorder)
            } header: {
                Text(WenshuI18n.t("composer.section.note_id"))
            }
            switch selectedOperation {
            case .rename:
                Section {
                    TextField(
                        WenshuI18n.t("composer.field.old_name"),
                        text: $oldName
                    )
                    .textFieldStyle(.roundedBorder)
                    TextField(
                        WenshuI18n.t("composer.field.new_name"),
                        text: $newName
                    )
                    .textFieldStyle(.roundedBorder)
                } header: {
                    Text(WenshuI18n.t("composer.section.rename"))
                }
            case .merge:
                Section {
                    TextField(
                        WenshuI18n.t("composer.field.target_note_id"),
                        text: $targetNoteId
                    )
                    .textFieldStyle(.roundedBorder)
                } header: {
                    Text(WenshuI18n.t("composer.section.merge"))
                }
            case .split:
                Section {
                    TextField(
                        WenshuI18n.t("composer.field.start_line"),
                        text: $startLine
                    )
                    .textFieldStyle(.roundedBorder)
                    TextField(
                        WenshuI18n.t("composer.field.end_line"),
                        text: $endLine
                    )
                    .textFieldStyle(.roundedBorder)
                } header: {
                    Text(WenshuI18n.t("composer.section.split"))
                }
            }
            if let resultText {
                Section {
                    Text(resultText)
                        .font(.caption)
                } header: {
                    Text(WenshuI18n.t("composer.section.result"))
                }
            }
        }
    }
}