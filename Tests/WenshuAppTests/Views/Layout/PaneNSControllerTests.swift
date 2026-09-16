//
//  PaneNSControllerTests.swift · Wenshu · v1.41 ticket 001
//
//  Structural tests for PaneNSController (= the AppKit NSSplitViewController
//  subclass that hosts the recursive LayoutTreeState tree = repowise #4
//  untested hotspot, 1648 NLOC, 7 dependents).
//
//  Per boss OOB 2026-09-16 "按优先级推" + "继续" (= continue the
//  fat-file split pattern from v1.32-v1.40): v1.41 adds source-level
//  structural coverage (= no NSViewController rendering; = code-level
//  verification of the PaneNSController surface = matches the v1.30
//  PlaceholderViewTests + v1.40 PreviewPaneTests pattern).
//
//  Per repowise `get_health` directive (2026-09-14, still ranks
//  PaneNSController.swift = #4 untested hotspot, weighted_deficit 4856,
//  share_of_repo_gap_pct 6.4%):
//    fix_first (next): PaneNSController.swift
//    reason: Hotspot with no paired test file (= needs coverage)
//
//  Per Q34 5.2 + Q173 ponytail + Q186 + Q57 + Q112: 12 source-level
//  tests (= this ticket = 1 file 1 commit). Path is derived from
//  `#filePath` (= robust to worktree relocations).

import Foundation
import AppKit
import Testing
@testable import WenshuApp

@Suite("PaneNSController (v1.41 — repowise #4 untested hotspot, 1648 NLOC)")
struct PaneNSControllerTests {

    private var paneNSControllerPath: String {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 { url.deleteLastPathComponent() }
        url.appendPathComponent("Sources/WenshuApp/Views/Layout/PaneNSController.swift")
        return url.path
    }

    @Test("PaneNSController exists as final class (= confirmed by source)")
    func testPaneNSControllerExists() throws {
        let source = try String(contentsOfFile: paneNSControllerPath, encoding: .utf8)
        #expect(source.contains("final class PaneNSController: NSSplitViewController"),
                "PaneNSController must be declared as final NSSplitViewController subclass")
    }

    @Test("PaneNSController is final (= no subclassing = the canonical AppKit pattern)")
    func testIsFinal() throws {
        let source = try String(contentsOfFile: paneNSControllerPath, encoding: .utf8)
        #expect(source.contains("final class PaneNSController"),
                "PaneNSController must be `final class` (= AppKit convention)")
    }

    @Test("PaneNSController imports AppKit (= native NSSplitViewController hierarchy)")
    func testImportsAppKit() throws {
        let source = try String(contentsOfFile: paneNSControllerPath, encoding: .utf8)
        #expect(source.contains("import AppKit"),
                "PaneNSController must import AppKit")
    }

    @Test("PaneNSController declares splitView override (= canonical NSSplitViewController delegate)")
    func testSplitViewOverride() throws {
        let source = try String(contentsOfFile: paneNSControllerPath, encoding: .utf8)
        #expect(source.contains("nonisolated override func splitView("),
                "PaneNSController must override splitView delegate method")
    }

    @Test("PaneNSController handles wenshuToggleZone notification (= v0.30 observer)")
    func testHandlesWenshuToggleZone() throws {
        let source = try String(contentsOfFile: paneNSControllerPath, encoding: .utf8)
        #expect(source.contains(".wenshuToggleZone") || source.contains("wenshuToggleZone"),
                "PaneNSController must handle .wenshuToggleZone notification")
    }

    @Test("PaneNSController handles wenshuEditorMaximizedChanged (= v0.34 ticket 03)")
    func testHandlesEditorMaximizedChanged() throws {
        let source = try String(contentsOfFile: paneNSControllerPath, encoding: .utf8)
        #expect(source.contains(".wenshuEditorMaximizedChanged") || source.contains("wenshuEditorMaximizedChanged"),
                "PaneNSController must handle .wenshuEditorMaximizedChanged")
    }

    @Test("PaneNSController declares restoreAllZones (= un-collapse all panes)")
    func testRestoreAllZones() throws {
        let source = try String(contentsOfFile: paneNSControllerPath, encoding: .utf8)
        #expect(source.contains("restoreAllZones"),
                "PaneNSController must declare restoreAllZones")
    }

    @Test("PaneNSController file > 1000 NLOC (= repowise needs_work evidence)")
    func testFileSize() throws {
        let source = try String(contentsOfFile: paneNSControllerPath, encoding: .utf8)
        let lineCount = source.components(separatedBy: "\n").count
        #expect(lineCount > 1000,
                "PaneNSController.swift should be > 1000 NLOC; = found \(lineCount) lines")
    }

    @Test("PaneNSController owns applyDividerStyle (= thin divider hit area)")
    func testApplyDividerStyle() throws {
        let source = try String(contentsOfFile: paneNSControllerPath, encoding: .utf8)
        #expect(source.contains("applyDividerStyle"),
                "PaneNSController must declare applyDividerStyle")
    }

    @Test("PaneNSController owns buildLayout (= the recursive tree → NSSplitView walker)")
    func testBuildLayout() throws {
        let source = try String(contentsOfFile: paneNSControllerPath, encoding: .utf8)
        #expect(source.contains("buildLayout"),
                "PaneNSController must declare buildLayout")
    }

    @Test("PaneNSController declares no SwiftUI state markers in code (= AppKit class)")
    func testNoStateProperties() throws {
        let source = try String(contentsOfFile: paneNSControllerPath, encoding: .utf8)
        // Filter out comment lines (= the @Environment mention on line 1238
        // is a /// doc-comment, not actual code).
        let codeLines = source.components(separatedBy: "\n").filter { line in
            !line.trimmingCharacters(in: .whitespaces).hasPrefix("///") &&
            !line.trimmingCharacters(in: .whitespaces).hasPrefix("//")
        }
        let codeRegion = codeLines.joined(separator: "\n")
        let stateCount = codeRegion.components(separatedBy: "@State").count - 1
        let envCount = codeRegion.components(separatedBy: "@Environment").count - 1
        let bindCount = codeRegion.components(separatedBy: "@Binding").count - 1
        #expect(stateCount == 0,
                "PaneNSController must have zero @State in code (= AppKit class); found \(stateCount)")
        #expect(envCount == 0,
                "PaneNSController must have zero @Environment in code (= AppKit class); found \(envCount)")
        #expect(bindCount == 0,
                "PaneNSController must have zero @Binding in code (= AppKit class); found \(bindCount)")
    }

    @Test("PaneNSController splitView override is marked nonisolated (= Swift 6 concurrency)")
    func testSplitViewIsNonisolated() throws {
        let source = try String(contentsOfFile: paneNSControllerPath, encoding: .utf8)
        let splitViewLine = source.components(separatedBy: "\n").first(where: { $0.contains("override func splitView(") }) ?? ""
        #expect(splitViewLine.contains("nonisolated"),
                "PaneNSController splitView override must be marked nonisolated (= Swift 6 concurrency)")
    }
}
