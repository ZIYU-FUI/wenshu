// EditorContentPlaceholderTests.swift · Wenshu · v0.83 ticket 002
//
// Source-level tests for EditorContentPlaceholder. We check the code
// region (= between `import SwiftUI` and closing `}`) for @Binding/@State/
// @Environment so doc-comment matches (= the source itself declares
// "No params, no @Binding, no @State, no @Environment") don't trigger
// false positives.

import SwiftUI
import ViewInspector
import Testing
@testable import WenshuApp

@Suite("EditorContentPlaceholder (v0.83 ticket 002 — WorkspaceView subcomponent)")
@MainActor
struct EditorContentPlaceholderTests {

    // MARK: - Structural tests

    @Test("renders exactly one Color.clear (= the empty placeholder)")
    func rendersOneColorClear() throws {
        let placeholder = try EditorContentPlaceholder().inspect()
        let colors = try placeholder.findAll(ViewType.Color.self)
        #expect(colors.count == 1, "expected 1 Color in EditorContentPlaceholder, found \(colors.count)")
    }

    @Test("has no buttons (= pure stateless presentation)")
    func hasNoButtons() throws {
        let placeholder = try EditorContentPlaceholder().inspect()
        let buttons = try placeholder.findAll(ViewType.Button.self)
        #expect(buttons.isEmpty, "EditorContentPlaceholder should have 0 buttons")
    }

    @Test("has no Text views (= pure stateless presentation)")
    func hasNoText() throws {
        let placeholder = try EditorContentPlaceholder().inspect()
        let texts = try placeholder.findAll(ViewType.Text.self)
        #expect(texts.isEmpty, "EditorContentPlaceholder should have 0 Text views")
    }

    // MARK: - Source-level tests (= code region only)

    @Test("source uses Color.clear (= the placeholder content)")
    func sourceUsesColorClear() throws {
        let source = try Self.codeRegion()
        #expect(source.contains("Color.clear"), "EditorContentPlaceholder.swift must declare Color.clear")
    }

    @Test("code region has no @Binding (= pure stateless)")
    func codeRegionHasNoBinding() throws {
        let source = try Self.codeRegion()
        #expect(!source.contains("@Binding"), "EditorContentPlaceholder code region should have no @Binding")
    }

    @Test("code region has no @State (= pure stateless)")
    func codeRegionHasNoState() throws {
        let source = try Self.codeRegion()
        #expect(!source.contains("@State"), "EditorContentPlaceholder code region should have no @State")
    }

    @Test("code region has no @Environment (= pure stateless)")
    func codeRegionHasNoEnvironment() throws {
        let source = try Self.codeRegion()
        #expect(!source.contains("@Environment"), "EditorContentPlaceholder code region should have no @Environment")
    }

    @Test("source mentions v0.28 (= the removal of the white overlay)")
    func sourceHasV028Context() throws {
        let path = "/Volumes/ANAN/Engineering/wenshu/.worktrees/v0.83-workspaceview-subcomponents/Sources/WenshuApp/Views/Workspace/EditorContentPlaceholder.swift"
        let source = try String(contentsOfFile: path)
        #expect(source.contains("v0.28"), "EditorContentPlaceholder.swift should document v0.28 context")
    }

    // MARK: - Helpers

    /// Read the code region (= between `import SwiftUI` and the end of the
    /// `struct` closing brace). Strips doc comments that would otherwise
    /// false-positive the @Binding/@State/@Environment checks (= the file's
    /// doc says "No params, no @State, no @Binding, no @Environment").
    private static func codeRegion() throws -> String {
        let path = "/Volumes/ANAN/Engineering/wenshu/.worktrees/v0.83-workspaceview-subcomponents/Sources/WenshuApp/Views/Workspace/EditorContentPlaceholder.swift"
        let source = try String(contentsOfFile: path)

        // Strip // line comments (= doc comments contain the @Binding substring)
        let lines = source.components(separatedBy: .newlines).filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return !trimmed.hasPrefix("//")
        }

        // Strip /* ... */ block comments
        var joined = lines.joined(separator: "\n")
        if let blockRange = joined.range(of: #"/\*[\s\S]*?\*/"#, options: .regularExpression) {
            joined.replaceSubrange(blockRange, with: "")
        }

        // Keep only the code after `import SwiftUI` (= skip doc headers)
        guard let importRange = joined.range(of: "import SwiftUI") else {
            return joined
        }
        return String(joined[importRange.upperBound...])
    }
}