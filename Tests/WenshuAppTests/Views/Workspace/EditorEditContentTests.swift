// EditorEditContentTests.swift · Wenshu · v0.87 ticket 002
//
// Source-level structural tests for EditorEditContent (= the SwiftUI
// live-edit surface for the editor pane; = wraps
// WenshuMarkdownEditor = NSViewRepresentable around
// nodes-app/swift-markdown-engine).
//
// Per boss 2026-09-14 OOB '按优先级推' + 'A': extend item 10
// (= WorkspaceView test coverage expansion). v0.82-83 covered 3
// subcomponents; v0.87 ticket 001 covered PreviewTabBackground;
// this ticket covers EditorEditContent.
//
// EditorEditContent uses @Binding + 7 let callbacks + 1 optional
// callback + MarkdownEditorConfiguration (= a struct from the
// MarkdownEngine SPM dependency). ViewInspector v0.10.3 cannot
// reliably construct such a view without setting up an NSView host
// and pre-building the configuration (= requires access to
// MarkdownEngine internals).
//
// Per v0.82 Q-lesson: ViewInspector v0.10.3 cannot deep-inspect
// opaque _ShapeView containers or propagate @State-owned @Binding
// writeback. We use STRUCTURAL assertions only (= file imports,
// @Binding declared, struct conforms to View, body references
// WenshuMarkdownEditor, etc.).

import SwiftUI
import Testing
@testable import WenshuApp

@Suite("EditorEditContent (v0.87 — SwiftUI live-edit surface)")
struct EditorEditContentTests {

    @Test("source imports SwiftUI + MarkdownEngine")
    func sourceImports() throws {
        let sourcePath = "/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Views/Workspace/EditorEditContent.swift"
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        #expect(source.contains("import SwiftUI"),
                "must import SwiftUI for View protocol")
        #expect(source.contains("import MarkdownEngine"),
                "must import MarkdownEngine (= the SPM product providing MarkdownEditorConfiguration)")
    }

    @Test("source declares @Binding var draft (= required for live editing)")
    func declaresDraftBinding() throws {
        let sourcePath = "/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Views/Workspace/EditorEditContent.swift"
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        // Strip line comments (= the header text mentions "@Binding"
        // as a description of what the struct has; = keep structural
        // assertion only on actual declarations).
        let codeLines = source.components(separatedBy: "\n").filter {
            !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//")
        }
        let codeRegion = codeLines.joined(separator: "\n")

        #expect(codeRegion.contains("@Binding var draft: String"),
                "must declare @Binding var draft: String (= per the v0.34 spec)")
        #expect(codeRegion.contains("let originalBody: String"),
                "must declare let originalBody: String (= saved-state baseline)")
        #expect(codeRegion.contains("let onSave: () -> Void"),
                "must declare let onSave callback")
        #expect(codeRegion.contains("let onWordCountChange: (Int) -> Void"),
                "must declare word count callback (= v0.34 B-18)")
        #expect(codeRegion.contains("let onDirtyChange: (Bool) -> Void"),
                "must declare dirty-state callback (= v0.34 B-22)")
        #expect(codeRegion.contains("let configuration: MarkdownEditorConfiguration"),
                "must declare MarkdownEditorConfiguration (= v0.39 ticket 001)")
        #expect(codeRegion.contains("let draftId: String"),
                "must declare draftId (= per-tab scoping)")
    }

    @Test("body uses WenshuMarkdownEditor (= the NSViewRepresentable wrapper)")
    func bodyUsesMarkdownEditor() throws {
        let sourcePath = "/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Views/Workspace/EditorEditContent.swift"
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        #expect(source.contains("WenshuMarkdownEditor("),
                "body must instantiate WenshuMarkdownEditor (= the engine bridge)")
    }

    @Test("body wires onChange for draft (= char count callback) + isDirty (= auto-save routing)")
    func bodyWiresOnChange() throws {
        let sourcePath = "/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Views/Workspace/EditorEditContent.swift"
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        #expect(source.contains(".onChange(of: draft)"),
                "body must wire onChange(of: draft) (= per-keystroke word count)")
        #expect(source.contains(".onChange(of: isDirty)"),
                "body must wire onChange(of: isDirty) (= v0.34 B-22 auto-save routing)")
    }

    @Test("isDirty is computed (= draft != originalBody, no stored state)")
    func isDirtyIsComputed() throws {
        let sourcePath = "/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Views/Workspace/EditorEditContent.swift"
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        // Strip line comments to avoid false positives (= the header
        // text mentions "draft != originalBody" as description).
        let codeLines = source.components(separatedBy: "\n").filter {
            !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//")
        }
        let codeRegion = codeLines.joined(separator: "\n")

        #expect(codeRegion.contains("private var isDirty: Bool"),
                "isDirty must be a computed property (private var, no stored state)")
        #expect(codeRegion.contains("draft != originalBody"),
                "isDirty must be `draft != originalBody` (= canonical dirty definition)")
    }

    @Test("struct conforms to View")
    func conformsToView() throws {
        let sourcePath = "/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Views/Workspace/EditorEditContent.swift"
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        #expect(source.contains("struct EditorEditContent: View"),
                "struct must conform to View protocol")
    }

    @Test("struct does not declare @State (= pure rendering surface)")
    func noStateDeclarations() throws {
        // Per the header comment: "No @State / @Environment /
        // @Observable = pure rendering surface". Verify @State is
        // not used (= the header text mentions "@State" as a
        // description of what is NOT in the struct; = strip comments
        // first).
        let sourcePath = "/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Views/Workspace/EditorEditContent.swift"
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        let codeLines = source.components(separatedBy: "\n").filter {
            !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//")
        }
        let codeRegion = codeLines.joined(separator: "\n")

        #expect(!codeRegion.contains("@State"),
                "code region must not declare @State (= per the pure-rendering-surface claim)")
    }
}