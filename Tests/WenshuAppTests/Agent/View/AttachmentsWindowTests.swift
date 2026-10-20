//
//  AttachmentsWindowTests.swift · Wenshu
//
//  Structural tests for the AttachmentsWindow entry surface
//  (= boss 2026-10-03 OOB: "新增入口, 工具栏加三个圆的单独的按钮,
//  打开独立的 windows 像看板一样"). Pins the canonical wire-up
//  shape for the first of 3 WS-model entry windows.
//
//  Three source-level tests pin the canonical shape:
//
//    1. testAttachmentsWindowExists — AttachmentsWindow.swift
//       exists as a real SwiftUI View (= not a placeholder).
//
//    2. testAttachmentsWindowFetchesWSAttachment — Window body
//       reads WSAttachment via FetchDescriptor (= the canonical
//       WSPersistenceContainer.shared.mainContext path).
//
//    3. testAttachmentsWindowIDRegistered — WindowID.attachments
//       is declared in NavigationSplitShell and the Window is
//       registered in AppRootScene.
//

import Testing
import Foundation
import WenshuData
@testable import WenshuApp

@Suite("AttachmentsWindow (boss 2026-10-03 OOB — WSAttachment entry window)")
struct AttachmentsWindowTests {

    private func resolve(_ relative: String) -> String {
        var url = SourceLocator.repoRoot
        url.appendPathComponent(relative)
        return url.path
    }

    @Test("AttachmentsWindow file exists (= independent window)")
    func testAttachmentsWindowExists() throws {
        let filePath = resolve("Sources/WenshuApp/Features/Attachments/View/AttachmentsWindow.swift")
        #expect(FileManager.default.fileExists(atPath: filePath),
                "AttachmentsWindow.swift must exist as a standalone file")
        let source = try String(contentsOfFile: filePath, encoding: .utf8)
        #expect(source.contains("struct AttachmentsWindow: View"),
                "AttachmentsWindow must declare a View struct")
        #expect(source.contains("import SwiftUI"),
                "AttachmentsWindow must import SwiftUI")
        #expect(source.contains("import SwiftData"),
                "AttachmentsWindow must import SwiftData (= @Model fetch)")
    }

    @Test("AttachmentsWindow fetches WSAttachment (= real SwiftData read)")
    func testAttachmentsWindowFetchesWSAttachment() throws {
        let filePath = resolve("Sources/WenshuApp/Features/Attachments/View/AttachmentsWindow.swift")
        let source = try String(contentsOfFile: filePath, encoding: .utf8)
        #expect(source.contains("FetchDescriptor<WSAttachment>"),
                "Window must fetch WSAttachment via FetchDescriptor")
        #expect(source.contains("WSPersistenceContainer.shared.mainContext"),
                "Window must use the canonical shared container's mainContext")
        #expect(source.contains("sortBy:"),
                "Window must sort attachments (= canonical ordering)")
    }

    @Test("WindowID.attachments declared and Window registered in AppRootScene")
    func testAttachmentsWindowIDRegistered() throws {
        // WindowID enum moved to AppRootScene.swift during the 2026-10-03
        // overabstraction cleanup (= NavigationSplitShell.swift deleted in
        // the same pass when the v2.8b 整窗重写 consolidated layout into
        // LibraryRootView + WorkspaceUIState). Pin the canonical home now.
        let scenePath = resolve("Sources/WenshuApp/App/AppRootScene.swift")
        let sceneSource = try String(contentsOfFile: scenePath, encoding: .utf8)
        #expect(sceneSource.contains("static let attachments = \"wenshu-attachments\""),
                "WindowID.attachments must be declared in AppRootScene")
        #expect(sceneSource.contains("id: WindowID.attachments"),
                "Window must be registered in AppRootScene with WindowID.attachments")
        #expect(sceneSource.contains("AttachmentsWindow()"),
                "Window content must be AttachmentsWindow()")
    }

    @Test("Attachments window is reachable from the canonical toolbar row")
    func testToolbarButtonForattachments() throws {
        // The button row is data-driven: `WindowID.toolbarButtons` lists the
        // id and `WindowOpenButton` performs the openWindow call. Asserting a
        // literal `openWindow(id: WindowID.attachments)` in one view only held while
        // each button was hand-written; the row is the single source of truth now.
        let toolbar = try SourceLocator.read(
            "Sources/WenshuApp/Features/Chrome/View/ChromeMainToolbar.swift")
        let button = try SourceLocator.read(
            "Sources/WenshuApp/Features/Chrome/View/WindowOpenButton.swift")
        #expect(toolbar.contains("ToolbarButton(id: WindowID.attachments"),
                "toolbar row must list WindowID.attachments")
        #expect(toolbar.contains("ForEach(WindowID.toolbarButtons"),
                "toolbar row must render the data-driven button list")
        #expect(button.contains("openWindow(id: id)"),
                "WindowOpenButton must perform the openWindow call for every listed id")
    }

    @Test("i18n keys for attachments window present in en + zh-Hans")
    func testI18nKeysForAttachments() throws {
        let enLanguage = "en"
        let zhLanguage = "zh-Hans"
        for language in [enLanguage, zhLanguage] {
            // plutil -p prints key=value pairs from a binary plist
            let output = StringCatalogReader.strings(language: language)
            #expect(output["window.attachments.title"] != nil,
                    "\(language) must contain window.attachments.title")
            #expect(output["window.attachments.empty"] != nil,
                    "\(language) must contain window.attachments.empty")
        }
    }

}