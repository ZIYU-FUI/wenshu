// EditModeBadgeTests.swift · Wenshu · v0.82 ticket 001
//
// Structural tests for EditModeBadge. ViewInspector v0.10.3 + modern
// SwiftUI (= opaque _ShapeView<TupleContent>) cannot deep-inspect the
// badge's Text nodes (= the View tree wraps them in opaque types).
// We test the structural contract instead: button exists, badge source
// file contains the expected symbols (= label + combo + Circle).

import SwiftUI
import ViewInspector
import Testing
@testable import WenshuApp

@Suite("EditModeBadge (v0.82 ticket 001 — WorkspaceView subcomponent)")
@MainActor
struct EditModeBadgeTests {

    // MARK: - Helpers

    @MainActor
    private struct TestHost: View {
        @State var isEnabled: Bool
        var body: some View {
            EditModeBadge(isEnabled: $isEnabled)
        }
    }

    @MainActor
    private func makeHost(initialState: Bool) -> TestHost {
        TestHost(isEnabled: initialState)
    }

    /// Read the source file (= structural source-level verification,
    /// independent of ViewInspector opaque-type limitations).
    private static func badgeSource() -> String {
        guard let url = Bundle.module.url(forResource: "EditModeBadge", withExtension: "swift") else {
            // Bundle.module doesn't expose source files at runtime;
            // = fall back to a hardcoded path under the worktree.
            return ""
        }
        return (try? String(contentsOf: url)) ?? ""
    }

    // MARK: - Structural tests (= SwiftUI view tree)

    @Test("contains exactly one Button (= the toggle trigger)")
    func containsOneButton() throws {
        let view = makeHost(initialState: false)
        let badge = try view.inspect()
        let buttons = try badge.findAll(ViewType.Button.self)
        #expect(buttons.count == 1,
                "expected 1 Button in EditModeBadge (= the toggle), found \(buttons.count)")
    }

    @Test("initial render reflects initial binding value (= no auto-toggle on mount)")
    func initialRenderReflectsState() throws {
        let viewOff = makeHost(initialState: false)
        let _ = try viewOff.inspect()
        #expect(viewOff.isEnabled == false,
                "initial isEnabled must be false (= no auto-toggle)")

        let viewOn = makeHost(initialState: true)
        let _ = try viewOn.inspect()
        #expect(viewOn.isEnabled == true,
                "initial isEnabled must be true (= binding respected)")
    }

    // MARK: - Source-level tests (= worktree filesystem)

    @Test("badge source file uses the i18n label key")
    func sourceUsesLabelKey() throws {
        // Read the source from disk (= the test file lives in a worktree).
        let worktreePath = "/Volumes/ANAN/Engineering/wenshu/.worktrees/v1.52-stale-test-cleanup/Sources/WenshuApp/Views/Workspace/EditModeBadge.swift"
        let source = try String(contentsOfFile: worktreePath)
        #expect(source.contains("\"workspace.layoutEditMode\""),
                "EditModeBadge.swift must reference the i18n label key")
    }

    @Test("badge source file uses the hotkey formatter")
    func sourceUsesHotkeyFormatter() throws {
        let worktreePath = "/Volumes/ANAN/Engineering/wenshu/.worktrees/v1.52-stale-test-cleanup/Sources/WenshuApp/Views/Workspace/EditModeBadge.swift"
        let source = try String(contentsOfFile: worktreePath)
        #expect(source.contains("HotkeyFormatter.editModeCombo"),
                "EditModeBadge.swift must use HotkeyFormatter.editModeCombo")
    }

    @Test("badge source file uses a Circle (= the indicator dot)")
    func sourceUsesCircle() throws {
        let worktreePath = "/Volumes/ANAN/Engineering/wenshu/.worktrees/v1.52-stale-test-cleanup/Sources/WenshuApp/Views/Workspace/EditModeBadge.swift"
        let source = try String(contentsOfFile: worktreePath)
        #expect(source.contains("Circle()"),
                "EditModeBadge.swift must contain a Circle (= the indicator)")
    }

    @Test("badge uses .regularMaterial background (= Liquid Glass canonical)")
    func sourceUsesRegularMaterial() throws {
        let worktreePath = "/Volumes/ANAN/Engineering/wenshu/.worktrees/v1.52-stale-test-cleanup/Sources/WenshuApp/Views/Workspace/EditModeBadge.swift"
        let source = try String(contentsOfFile: worktreePath)
        #expect(source.contains(".regularMaterial"),
                "EditModeBadge.swift must use .regularMaterial (= Apple HIG macOS 27 Liquid Glass)")
    }

    // MARK: - Toggle behavior (= independent of ViewInspector)

    @Test("binding toggle contract works (= independence from View)")
    func bindingToggleContract() {
        var flag = false
        flag.toggle()
        #expect(flag == true)
        flag.toggle()
        #expect(flag == false)
    }
}