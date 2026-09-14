// EditorExpandShrinkTrailingButtonTests.swift · Wenshu · v0.87 ticket 003
//
// Source-level structural tests for EditorExpandShrinkTrailingButton
// (= the trailing button on the editor pane's top-right that toggles
// "Expand Fullscreen" <-> "Restore Layout").
//
// Per boss 2026-09-14 OOB '按优先级推' + 'A': extend item 10
// (= WorkspaceView test coverage expansion). v0.82-83 covered 3
// subcomponents; v0.87 ticket 001 covered PreviewTabBackground;
// ticket 002 covered EditorEditContent; this ticket covers
// EditorExpandShrinkTrailingButton.
//
// Note: this view uses @SceneStorage (= Apple HIG macOS 14+ standard
// for per-window state restoration) and @AppStorage (= shared snapshot
// JSON). Behavior testing these in a unit-test context requires the
// Scene + a real NotificationCenter listener; = we use source-level
// structural assertions.

import SwiftUI
import Testing
@testable import WenshuApp

@Suite("EditorExpandShrinkTrailingButton (v0.87 — editor expand/shrink trailing button)")
struct EditorExpandShrinkTrailingButtonTests {

    @Test("source imports SwiftUI")
    func importsSwiftUI() throws {
        let sourcePath = "/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Views/Workspace/EditorExpandShrinkTrailingButton.swift"
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        #expect(source.contains("import SwiftUI"),
                "must import SwiftUI for View + @SceneStorage + @AppStorage")
    }

    @Test("struct conforms to View")
    func conformsToView() throws {
        let sourcePath = "/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Views/Workspace/EditorExpandShrinkTrailingButton.swift"
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        #expect(source.contains("struct EditorExpandShrinkTrailingButton: View"),
                "struct must conform to View")
    }

    @Test("uses @SceneStorage for editorMaximized (= Apple HIG macOS 14+ per-window state)")
    func usesSceneStorageForEditorMaximized() throws {
        let sourcePath = "/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Views/Workspace/EditorExpandShrinkTrailingButton.swift"
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        #expect(source.contains("@SceneStorage(\"wenshu.editorMaximized\")"),
                "must use @SceneStorage for wenshu.editorMaximized (= per Apple HIG v0.40 migration)")
    }

    @Test("uses @AppStorage for editorExpandSnapshotJSON (= cross-window snapshot)")
    func usesAppStorageForSnapshot() throws {
        let sourcePath = "/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Views/Workspace/EditorExpandShrinkTrailingButton.swift"
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        #expect(source.contains("@AppStorage(\"wenshu.editorExpand.snapshot\")"),
                "must use @AppStorage for the cross-window snapshot JSON")
    }

    @Test("body uses PaneTrailingIconButton (= shared helper from v0.34 multi-layer audit)")
    func usesPaneTrailingIconButton() throws {
        let sourcePath = "/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Views/Workspace/EditorExpandShrinkTrailingButton.swift"
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        #expect(source.contains("PaneTrailingIconButton("),
                "body must instantiate PaneTrailingIconButton (= the shared helper from v0.34)")
    }

    @Test("toggle action posts .wenshuEditorMaximizedChanged notification")
    func toggleActionPostsNotification() throws {
        let sourcePath = "/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Views/Workspace/EditorExpandShrinkTrailingButton.swift"
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        #expect(source.contains("NotificationCenter.default.post"),
                "toggle action must post NotificationCenter notification (= Q33 fix)")
        #expect(source.contains(".wenshuEditorMaximizedChanged"),
                "notification name must be .wenshuEditorMaximizedChanged (= canonical name)")
    }

    @Test("tooltip uses WenshuI18n (= AGENTS.md §11 English-only invariant + i18n parity)")
    func tooltipUsesI18n() throws {
        // Per header comment: original tooltips were CJK literals
        // (= "restorelayout" = "Restore Layout"; = "full screen" =
        // "Expand Fullscreen"). Replaced with WenshuI18n.t() lookups.
        // Verify no hardcoded CJK tooltip strings remain.
        let sourcePath = "/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Views/Workspace/EditorExpandShrinkTrailingButton.swift"
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        #expect(source.contains("WenshuI18n.t(\"workspace.editor.restore_layout\")"),
                "must look up Restore Layout tooltip via WenshuI18n (= I18n parity)")
        #expect(source.contains("WenshuI18n.t(\"workspace.editor.expand_fullscreen\")"),
                "must look up Expand Fullscreen tooltip via WenshuI18n (= I18n parity)")
    }

    @Test("icon toggles between two Lucide names (= the canonical icon pair)")
    func iconToggles() throws {
        let sourcePath = "/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Views/Workspace/EditorExpandShrinkTrailingButton.swift"
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        #expect(source.contains("arrow.down.right.and.arrow.up.left"),
                "shrunk-state icon must be the shrink arrow (= Lucide canonical)")
        #expect(source.contains("arrow.up.left.and.arrow.down.right"),
                "expanded-state icon must be the expand arrow (= Lucide canonical)")
    }
}