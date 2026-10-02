// Sources/WenshuApp/Views/Workspace/EditorExpandShrinkTrailingButton.swift
//
// The trailing button on the editor pane's top-right that toggles
// "Expand Fullscreen" <-> "Restore Layout". One view per file
// (Apple HIG). No `@Binding` / `@State` / `@Observable` = pure
// presentation.
//
// Only call site = WorkspaceView's editor pane top-right; invoked
// as `EditorExpandShrinkTrailingButton()`. Extracting it does not
// change any caller signature.

import SwiftUI

struct EditorExpandShrinkTrailingButton: View {
    // `wenshu.editorMaximized` is `@SceneStorage` (= Apple HIG
    // macOS 14+ standard for per-window state restoration). Each
    // window can have a different editor maximize state (= when
    // the user opens two windows and shrinks the editor in only
    // one, the other window should keep the unshrunk state).
    // `@SceneStorage` is scoped to the Scene (= the window) and
    // restores on relaunch (= matches Apple HIG "per-window state
    // restoration" requirement).
    //
    // `wenshu.editorExpand.snapshot` stays on `@AppStorage` (= the
    // snapshot JSON is the LAST-SHRUNK layout, intended to apply
    // across all windows when the user re-opens one after closing
    // all).
    @SceneStorage("wenshu.editorMaximized") private var editorMaximized: Bool = false
    @AppStorage("wenshu.editorExpand.snapshot") private var editorExpandSnapshotJSON: String = "{}"

    var body: some View {
        //
        // the editor expand/shrink trailing button was using raw `Lucide(...)`
        // (= no size parameter = Lucide default size, not Apple HIG standard
        // 18 PT tab icon). Migrated to the SAME icon-rendering pattern as
        // PaneIconTab: Color.clear as 28 PT hot area base + icon as centered
        // .overlay at 18 PT (= Apple HIG small-control standard). Now
        // visually identical to the leading tab icons in the same row
        // (= the 6 zones' tab bar visual contract is uniform).
        //
        // Hover plumbing also migrated to .hoverWash() (= previous commit's
        // single source of truth for hover wash; removed the per-site
        // .onHover + .background tint + @State isHover + .clipShape plumbing).
        //
        // the trailing-button
        // shape (Color.clear.frame(28,28).overlay(Image(systemName:))
        // + .hoverWash + .plain + .help) was duplicated between WorkspaceView.swift
        // EditorExpandShrinkTrailingButton and TabContentDispatcher.swift
        // (chat-zone archive button). Replaced both with the shared
        // PaneTrailingIconButton helper. EditorExpandShrinkTrailingButton
        // now retains only the icon-toggle state (= editorMaximized) and
        // the tooltip string (= editorMaximized ? "Restore Layout" : "Expand Fullscreen").
        PaneTrailingIconButton(
            icon: editorMaximized
                ? "arrow.down.right.and.arrow.up.left"
                : "arrow.up.left.and.arrow.down.right",
            tooltip: editorMaximized
                ? WenshuI18n.t("workspace.editor.restore_layout")
                : WenshuI18n.t("workspace.editor.expand_fullscreen"),
            // The action writes `@SceneStorage` AND posts
            // `.wenshuEditorMaximizedChanged`, which
            // `PaneNSController.handleEditorMaximizedChanged`
            // listens for. `Notification.object` carries the new
            // `Bool` payload so the listener can branch on
            // snapshot-and-collapse vs restore.
            action: {
                editorMaximized.toggle()
                NotificationCenter.default.post(
                    name: .wenshuEditorMaximizedChanged,
                    object: editorMaximized
                )
            }
        )
    }
}
