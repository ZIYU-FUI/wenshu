//
//  SummariesWindowTests.swift · Wenshu
//
//  Structural tests for the SummariesWindow entry surface
//  (= boss 2026-10-03 OOB: "新增入口, 工具栏加三个圆的单独的按钮,
//  打开独立的 windows 像看板一样"). Pins the canonical wire-up
//  shape for the third of 3 WS-model entry windows.
//
//  Per Q34 5.2 + Q173 ponytail + Q186 + Q57 + Q112: source-level
//  tests following the AttachmentsWindowTests + ManifestWindowTests
//  precedent.
//

import Testing
import Foundation
import WenshuData
@testable import WenshuApp

@Suite("SummariesWindow (boss 2026-10-03 OOB — WSSummary entry window)")
struct SummariesWindowTests {

    private func resolve(_ relative: String) -> String {
        var url = SourceLocator.repoRoot
        url.appendPathComponent(relative)
        return url.path
    }

    @Test("SummariesWindow file exists (= independent window)")
    func testSummariesWindowExists() throws {
        let filePath = resolve("Sources/WenshuApp/Features/Summaries/View/SummariesWindow.swift")
        #expect(FileManager.default.fileExists(atPath: filePath),
                "SummariesWindow.swift must exist as a standalone file")
        let source = try String(contentsOfFile: filePath, encoding: .utf8)
        #expect(source.contains("struct SummariesWindow: View"),
                "SummariesWindow must declare a View struct")
        #expect(source.contains("import SwiftUI"),
                "SummariesWindow must import SwiftUI")
        #expect(source.contains("import SwiftData"),
                "SummariesWindow must import SwiftData")
    }

    @Test("SummariesWindow fetches WSSummary (= real SwiftData read)")
    func testSummariesWindowFetchesWSSummary() throws {
        let filePath = resolve("Sources/WenshuApp/Features/Summaries/View/SummariesWindow.swift")
        let source = try String(contentsOfFile: filePath, encoding: .utf8)
        #expect(source.contains("FetchDescriptor<WSSummary>"),
                "Window must fetch WSSummary via FetchDescriptor")
        #expect(source.contains("WSPersistenceContainer.shared.mainContext"),
                "Window must use the canonical shared container's mainContext")
        #expect(source.contains("sortBy:"),
                "Window must sort summaries (= canonical ordering)")
    }

    @Test("WindowID.summaries declared and Window registered in AppRootScene")
    func testSummariesWindowIDRegistered() throws {
        let scenePath = resolve("Sources/WenshuApp/App/AppRootScene.swift")
        let sceneSource = try String(contentsOfFile: scenePath, encoding: .utf8)
        #expect(sceneSource.contains("static let summaries = \"wenshu-summaries\""),
                "WindowID.summaries must be declared in AppRootScene")
        #expect(sceneSource.contains("id: WindowID.summaries"),
                "Window must be registered in AppRootScene with WindowID.summaries")
        #expect(sceneSource.contains("SummariesWindow()"),
                "Window content must be SummariesWindow()")
    }

    @Test("Summaries window is reachable from the canonical toolbar row")
    func testToolbarButtonForsummaries() throws {
        // The button row is data-driven: `WindowID.toolbarButtons` lists the
        // id and `WindowOpenButton` performs the openWindow call. Asserting a
        // literal `openWindow(id: WindowID.summaries)` in one view only held while
        // each button was hand-written; the row is the single source of truth now.
        let toolbar = try SourceLocator.read(
            "Sources/WenshuApp/Features/Chrome/View/ChromeMainToolbar.swift")
        let button = try SourceLocator.read(
            "Sources/WenshuApp/Features/Chrome/View/WindowOpenButton.swift")
        #expect(toolbar.contains("ToolbarButton(id: WindowID.summaries"),
                "toolbar row must list WindowID.summaries")
        #expect(toolbar.contains("ForEach(WindowID.toolbarButtons"),
                "toolbar row must render the data-driven button list")
        #expect(button.contains("openWindow(id: id)"),
                "WindowOpenButton must perform the openWindow call for every listed id")
    }

    @Test("i18n keys for summaries window present in en + zh-Hans")
    func testI18nKeysForSummaries() throws {
        let enPath = resolve("Sources/WenshuApp/Resources/en.lproj/Localizable.strings")
        let zhPath = resolve("Sources/WenshuApp/Resources/zh-Hans.lproj/Localizable.strings")
        for path in [enPath, zhPath] {
            let output = try shellOut("plutil -p \"\(path)\"")
            #expect(output.contains("\"window.summaries.title\""),
                    "\(path) must contain window.summaries.title")
            #expect(output.contains("\"window.summaries.empty\""),
                    "\(path) must contain window.summaries.empty")
        }
    }

    private func shellOut(_ cmd: String) throws -> String {
        let process = Process()
        process.launchPath = "/bin/bash"
        process.arguments = ["-c", cmd]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
}