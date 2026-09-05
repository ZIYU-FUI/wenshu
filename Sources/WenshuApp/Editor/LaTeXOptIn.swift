// Sources/WenshuApp/Editor/LaTeXOptIn.swift
//
// v0.39 ticket 001 out-of-scope followup STUB (boss 2026-09-05 OOB "推 2345678" item #2).
// Per .scratch/2026-09-04-editor-migration/spec.md §2.2: LaTeX rendering via
// SwiftMath (= the MarkdownEngineLatex product) is opt-in and deferred to a
// future ticket (also listed as future ticket 002 per spec.md §4.2). WenshuEditorServicesFactory
// currently omits the `latex:` service parameter (= NoOpLatexRenderer default);
// this stub holds the future opt-in toggle + SwiftMath bridge seam so users can
// enable math rendering per-library without re-opening the ticket.
//
// Behavior: TODO. Full impl requires boss拍 (= MarkdownEngineLatex product adoption
// + per-library settings toggle + NoOpLatexRenderer replacement).
//
// Stub compiles cleanly (struct + valid body) per AGENTS.md §11 hard rules.

import SwiftUI

struct LaTeXOptIn: View {
    var body: some View {
        // TODO: full impl requires boss拍 (MarkdownEngineLatex + toggle + bridge)
        Text("LaTeXOptIn: TODO")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}
