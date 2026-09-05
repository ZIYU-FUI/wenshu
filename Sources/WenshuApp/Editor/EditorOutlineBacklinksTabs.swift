// Sources/WenshuApp/Editor/EditorOutlineBacklinksTabs.swift
//
// v0.39 ticket 001 out-of-scope followup STUB (boss 2026-09-05 OOB "推 2345678" item #2).
// Per .scratch/2026-09-04-editor-migration/spec.md §2.2: the editor placeholder
// showing 大纲 (outline) + 反链 (backlinks) tabs for non-edit tabs is deferred.
// WorkspaceView.swift L391-392 currently shows `EditorPlaceholder()` for non-edit
// tabs (= outline / backlinks / references); this stub holds the future tabbed
// placeholder seam so the workspace can wire the tabs without re-opening the
// ticket.
//
// Behavior: TODO. Full impl requires boss拍 (= 大纲 tree view + 反链 cross-reference
// list + tab switcher in EditorPlaceholder chrome).
//
// Stub compiles cleanly (struct + valid body) per AGENTS.md §11 hard rules.

import SwiftUI

struct EditorOutlineBacklinksTabs: View {
    var body: some View {
        // TODO: full impl requires boss拍 (大纲 tree + 反链 list + tab switcher)
        Text("EditorOutlineBacklinksTabs: TODO")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}
