//
//  EditorExpandShrinkTrailingButton.swift · Wenshu · v0.40 apple-001 Q2 slice 6
//
//  Extracted from WorkspaceView.swift (formerly inline private
//  struct at line 908). Q2 boss拍 split WorkspaceView. Slice 6
//  = the trailing button on the editor pane's top-right that
//  toggles "Expand Fullscreen" <-> "Restore Layout".
//
//  Apple HIG = one view per file. EditorExpandShrinkTrailingButton
//  has 2 @AppStorage (= persistence for editorMaximized Bool + the
//  snapshot JSON that PaneNSController.handleEditorMaximizedChanged
//  writes before collapsing the 5 zones). No @Binding / @State /
//  @Observable = pure presentation.
//
//  This slice ALSO bundles an AGENTS.md English-only sweep:
//  the original tooltip strings were CJK literals:
//    - "恢复布局" (= "Restore Layout")
//    - "展开全屏" (= "Expand Fullscreen")
//  Replaced with WenshuI18n.t() lookups. Both en + zh-Hans
//  Localizable.strings receive the 2 new keys in this same commit
//  (= I18n parity invariant maintained).
//
//  Only call site = WorkspaceView's editor pane top-right; invoked
//  as `EditorExpandShrinkTrailingButton()`.
//  Extracting it does not change any caller signature.
//

import SwiftUI

struct EditorExpandShrinkTrailingButton: View {
    // v0.34 ticket 01: replaced @State with @AppStorage (= Rule 11 + Apple
    // HIG standard storage; the bug ticket 03 fixes = no real persistence,
    // but @AppStorage makes persistence easy to add later if needed). The
    // snapshot key is written by PaneNSController.handleEditorMaximizedChanged
    // BEFORE the 5 zone-hide animator calls (= Q38 boss "full-state snapshot"
    // decision; restore-on-shrink must read this JSON).
    //
    // v0.40 apple-001 HIG absent batch: migrated wenshu.editorMaximized
    // from @AppStorage to @SceneStorage (= Apple HIG macOS 14+ standard for
    // per-window state restoration). Each window can have a different
    // editor maximize state (= when the user opens two windows and shrinks
    // the editor in only one, the other window should keep the unshrunk
    // state). @SceneStorage is scoped to the Scene (= the window) and
    // restores on relaunch (= matches Apple HIG "per-window state
    // restoration" requirement).
    //
    // wenshu.editorExpand.snapshot stays on @AppStorage (= the snapshot
    // JSON is the LAST-SHRUNK layout, = intended to apply across all
    // windows when the user re-opens one after closing all).
    @SceneStorage("wenshu.editorMaximized") private var editorMaximized: Bool = false
    @AppStorage("wenshu.editorExpand.snapshot") private var editorExpandSnapshotJSON: String = "{}"

    var body: some View {
        // v0.34 boss 2026-09-02 OOB 'the ICON on the right of the editor, the size did not follow the component':
        // the editor expand/shrink trailing button was using raw `Lucide(...)`
        // (= no size parameter = Lucide default size, not Apple HIG standard
        // 18 PT tab icon). Migrated to the SAME icon-rendering pattern as
        // PaneIconTab: Color.clear as 28 PT hot area base + icon as centered
        // .overlay with explicit DesignTokens.tabIconSize (= 18 PT). Now
        // visually identical to the leading tab icons in the same row
        // (= the 6 zones' tab bar visual contract is uniform).
        //
        // Hover plumbing also migrated to .hoverWash() (= previous commit's
        // single source of truth for hover wash; removed the per-site
        // .onHover + .background tint + @State isHover + .clipShape plumbing).
        //
        // v0.34 boss 2026-09-02 OOB (multi-layer audit): the trailing-button
        // shape (Color.clear.frame(28,28).overlay(LucideIcon) + .hoverWash +
        // .plain + .help) was duplicated between WorkspaceView.swift
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
            // v0.34 ticket 03 (= Q33 boss fix): the action was previously a
            // dead `editorMaximized.toggle()` (= View-local @State only,
            // no layout effect). Now it writes @AppStorage AND posts the
            // .wenshuEditorMaximizedChanged notification, which
            // PaneNSController.handleEditorMaximizedChanged listens for
            // (= ticket 02 implementation). Notification.object carries
            // the new Bool payload so the listener can branch on
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
