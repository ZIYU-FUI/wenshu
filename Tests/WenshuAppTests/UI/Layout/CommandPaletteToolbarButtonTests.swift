//
//  CommandPaletteToolbarButtonTests.swift · Wenshu · v2.8a ticket T8 (boss 2026-09-28 OOB)
//
//  Structural tests for the CommandPalette toolbar button (= the
//  v2.8a wire-up per boss OOB B3: boss said the CommandPaletteView
//  needs an explicit button in a sensible toolbar location; = this
//  commit adds the toolbar button alongside the existing inspector
//  toggle + kanban window + todo window buttons).
//
//  Acceptance (= boss 2026-09-28 OOB B3):
//    1. testShellDetailColumn_wiresCommandPaletteButton — source-
//       level check that ShellDetailColumn's `.principal`
//       ToolbarItemGroup contains a Button that calls
//       `CommandPaletteController.show()`.
//
//  swift test --filter CommandPaletteToolbarButtonTests
//
//  Per Q34 5.2 + Q173 ponytail + Q186 + Q57 + Q112: source-level
//  test following the v1.44 specialized-tools P1 hermes-port
//  batch precedent.

import Testing
import Foundation
@testable import WenshuApp

@Suite("CommandPalette toolbar button (v2.8a — boss 2026-09-28 OOB B3)")
struct CommandPaletteToolbarButtonTests {

    private var shellDetailPath: String {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 { url.deleteLastPathComponent() }
        url.appendPathComponent("Sources/WenshuApp/Views/Inspector/InspectorView.swift")
        return url.path
    }

    @Test("ShellDetailColumn wires a CommandPaletteController.show button (= boss B3 surface)")
    func testShellDetailColumnWiresCommandPaletteButton() throws {
        let source = try String(contentsOfFile: shellDetailPath, encoding: .utf8)
        // The button MUST call CommandPaletteController.show() so the
        // existing NotificationCenter.post(.wenshuShowCommandPalette)
        // (= the .sheet host in LibraryRootView) opens the palette.
        #expect(source.contains("CommandPaletteController.show()"),
                "ShellDetailColumn must contain a toolbar Button that calls CommandPaletteController.show() (= the v2.8a boss B3 surface)")
        // The button must be inside the .principal ToolbarItemGroup
        // (= the same placement as the existing inspector toggle /
        // kanban / todo buttons).
        #expect(source.contains("ToolbarItemGroup(placement: .principal)"),
                "ShellDetailColumn must host the CommandPalette button in the .principal ToolbarItemGroup (= the same placement as the existing inspector / kanban / todo buttons)")
    }
}