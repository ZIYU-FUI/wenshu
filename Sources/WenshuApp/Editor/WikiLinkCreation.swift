// Sources/WenshuApp/Editor/WikiLinkCreation.swift
//
// v0.39 ticket 001 out-of-scope followup STUB (boss 2026-09-05 OOB "推 2345678" item #2).
// Per .scratch/2026-09-04-editor-migration/spec.md §2.2: wiki-link creation UX is
// deferred to a future ticket (also listed as future ticket 003 per spec.md §4.2,
// e.g. ⌘K palette). The WikiLinkResolver contract (= ReferenceLibraryWikiLinkResolver)
// already resolves existing [[name]] links; this stub holds the future creation
// UI seam (palette + autocomplete) so the workspace can wire the affordance
// without re-opening the ticket.
//
// Behavior: TODO. Full impl requires boss拍 (= ⌘K palette + reference-library
// entity autocomplete + cursor-position insertion of [[name]]).
//
// Stub compiles cleanly (struct + valid body) per AGENTS.md §11 hard rules.

import SwiftUI

struct WikiLinkCreation: View {
    var body: some View {
        // TODO: full impl requires boss拍 (palette + autocomplete + insert)
        Text("WikiLinkCreation: TODO")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}
