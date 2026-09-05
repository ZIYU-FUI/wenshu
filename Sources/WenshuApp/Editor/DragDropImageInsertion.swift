// Sources/WenshuApp/Editor/DragDropImageInsertion.swift
//
// v0.39 ticket 001 out-of-scope followup STUB (boss 2026-09-05 OOB "推 2345678" item #2).
// Per .scratch/2026-09-04-editor-migration/spec.md §2.2: drag-drop image insertion UX
// is deferred to a future ticket (also listed as future ticket 004 per spec.md §4.2).
// The EmbeddedImageProvider contract (= ReferenceLibraryImageProvider) already
// resolves ![[name]] embeds; this stub holds the future drag-and-drop UI seam so
// the workspace can wire the affordance without re-opening the ticket.
//
// Behavior: TODO. Full impl requires boss拍 (= drop target registration +
// NSItemProvider payload parsing + insertion into the active chapter draft).
//
// Stub compiles cleanly (struct + valid body) per AGENTS.md §11 hard rules.

import SwiftUI

struct DragDropImageInsertion: View {
    var body: some View {
        // TODO: full impl requires boss拍 (drop target + payload parse + insert)
        Text("DragDropImageInsertion: TODO")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}
