// Sources/WenshuApp/Views/Workspace/EditorContentPlaceholder.swift
//
// The empty `Color.clear` placeholder for the editor pane.
// Pane background uniformity is applied by the surrounding
// pane chrome (= the editor placeholder is just empty since
// the `Color.white.opacity(0.55)` overlay was removed).
//
// One view per file (Apple HIG). `EditorContentPlaceholder` is
// the smallest extractable view left (= 11 LOC, pure stateless).
// No params, no `@State`, no `@Binding`, no `@Environment`.

import SwiftUI

struct EditorContentPlaceholder: View {
    var body: some View {
        // REMOVED the Color.white.opacity(0.55) overlay (= was
        // making the editor pane appear LIGHTER than the other
        // panes). The pane background is now uniform across
        // the workspace.
        Color.clear
    }
}
