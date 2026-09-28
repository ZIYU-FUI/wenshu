//
//  SecondaryWindowsTests.swift · Wenshu · v2.8b ticket T10-T13 (boss 2026-09-28 OOB)
//
//  Structural tests for the 4 v2.8b secondary windows (= boss
//  OOB B6 + B7 + B9 '在标题栏/工具栏中加一个按钮，和老板 todo 一样，打开一个独立 windows 先构建一个独立功能页面').
//
//  The 4 windows (= boss 2026-09-28 OOB scope):
//    1. Canvas (= JSONCanvasCodec codepath).
//    2. Composer (= NoteComposer codepath).
//    3. ForeshadowingGraph (= the graph view that was previously
//       declared but never wired).
//    4. Cron (= the cron schedule + prompt scanner that was
//       previously declared but never wired).
//
//  Acceptance (= boss 2026-09-28 OOB B6 + B7 + B9):
//    1. testWindowIDExposesFourCases — WindowID enum exposes
//       canvas + composer + foreshadowingGraph + cron cases.
//    2. testAppRootSceneDeclaresFourWindows — AppRootScene
//       declares 4 new Window(id:"wenshu-*") scene declarations.
//    3. testShellDetailColumnWiresFourButtons — ShellDetailColumn
//       toolbar .principal ToolbarItemGroup contains 4 new
//       buttons (= one per window) using openWindow(id:).
//
//  swift test --filter SecondaryWindowsTests
//
//  Per Q34 5.2 + Q173 ponytail + Q186 + Q57 + Q112: source-level
//  tests following the v1.44 specialized-tools P1 hermes-port
//  batch precedent.

import Testing
import Foundation
@testable import WenshuApp

@Suite("Secondary windows (v2.8b — boss 2026-09-28 OOB B6 + B7 + B9)")
struct SecondaryWindowsTests {

    private var navigationShellPath: String {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 { url.deleteLastPathComponent() }
        url.appendPathComponent("Sources/WenshuApp/UI/Layout/NavigationSplitShell.swift")
        return url.path
    }

    private var appRootScenePath: String {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 { url.deleteLastPathComponent() }
        url.appendPathComponent("Sources/WenshuApp/App/AppRootScene.swift")
        return url.path
    }

    private var shellDetailColumnPath: String {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 { url.deleteLastPathComponent() }
        url.appendPathComponent("Sources/WenshuApp/UI/Layout/ShellDetailColumn.swift")
        return url.path
    }

    @Test("WindowID exposes canvas + composer + foreshadowingGraph + cron cases (= v2.8b boss B6+B7+B9 surface)")
    func testWindowIDExposesFourCases() throws {
        let source = try String(contentsOfFile: navigationShellPath, encoding: .utf8)
        // (name, identifier) pairs; = windowID matches the
        // Swift enum case name; = identifier matches the
        // raw wenshu-stable identifier string (= the kebab
        // convention used by the existing kanban + todo IDs).
        for (windowID, identifier) in [
            ("canvas", "wenshu-canvas"),
            ("composer", "wenshu-composer"),
            ("foreshadowingGraph", "wenshu-foreshadowing-graph"),
            ("cron", "wenshu-cron"),
        ] {
            #expect(source.contains("static let \(windowID) = \"\(identifier)\""),
                    "WindowID.\(windowID) must be declared (= \(identifier) identifier)")
        }
    }

    @Test("AppRootScene declares 4 new Window(id:) scene declarations (= the v2.8b 4 windows)")
    func testAppRootSceneDeclaresFourWindows() throws {
        let source = try String(contentsOfFile: appRootScenePath, encoding: .utf8)
        for windowID in ["canvas", "composer", "foreshadowingGraph", "cron"] {
            #expect(source.contains("id: WindowID.\(windowID)"),
                    "AppRootScene must declare a Window with id=WindowID.\(windowID)")
        }
    }

    @Test("ShellDetailColumn toolbar wires 4 new openWindow buttons (= boss B6+B7+B9 click surface)")
    func testShellDetailColumnWiresFourButtons() throws {
        let source = try String(contentsOfFile: shellDetailColumnPath, encoding: .utf8)
        for windowID in ["canvas", "composer", "foreshadowingGraph", "cron"] {
            #expect(source.contains("openWindow(id: WindowID.\(windowID))"),
                    "ShellDetailColumn must wire an openWindow(id: WindowID.\(windowID)) button in the .principal ToolbarItemGroup")
        }
    }
}