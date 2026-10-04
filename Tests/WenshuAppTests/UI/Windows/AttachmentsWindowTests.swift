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
@testable import WenshuApp

@Suite("AttachmentsWindow (boss 2026-10-03 OOB — WSAttachment entry window)")
struct AttachmentsWindowTests {

    private func resolve(_ relative: String) -> String {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 { url.deleteLastPathComponent() }
        url.appendPathComponent(relative)
        return url.path
    }

    @Test("AttachmentsWindow file exists (= independent window)")
    func testAttachmentsWindowExists() throws {
        let filePath = resolve("Sources/WenshuApp/Views/Windows/AttachmentsWindow.swift")
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
        let filePath = resolve("Sources/WenshuApp/Views/Windows/AttachmentsWindow.swift")
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
        let shellPath = resolve("Sources/WenshuApp/UI/Layout/NavigationSplitShell.swift")
        let shellSource = try String(contentsOfFile: shellPath, encoding: .utf8)
        #expect(shellSource.contains("static let attachments = \"wenshu-attachments\""),
                "WindowID.attachments must be declared in NavigationSplitShell")
        let scenePath = resolve("Sources/WenshuApp/App/AppRootScene.swift")
        let sceneSource = try String(contentsOfFile: scenePath, encoding: .utf8)
        #expect(sceneSource.contains("id: WindowID.attachments"),
                "Window must be registered in AppRootScene with WindowID.attachments")
        #expect(sceneSource.contains("AttachmentsWindow()"),
                "Window content must be AttachmentsWindow()")
    }

    @Test("ShellDetailColumn has toolbar button opening attachments window")
    func testToolbarButtonForAttachments() throws {
        let toolbarPath = resolve("Sources/WenshuApp/Views/Inspector/InspectorView.swift")
        let source = try String(contentsOfFile: toolbarPath, encoding: .utf8)
        #expect(source.contains("openWindow(id: WindowID.attachments)"),
                "Toolbar must wire openWindow(id: WindowID.attachments)")
        #expect(source.contains("wenshu.window] click: openWindow id=\\(WindowID.attachments)"),
                "Toolbar must log the canonical openWindow NSLog marker")
    }

    @Test("i18n keys for attachments window present in en + zh-Hans")
    func testI18nKeysForAttachments() throws {
        let enPath = resolve("Sources/WenshuApp/Resources/en.lproj/Localizable.strings")
        let zhPath = resolve("Sources/WenshuApp/Resources/zh-Hans.lproj/Localizable.strings")
        for path in [enPath, zhPath] {
            // plutil -p prints key=value pairs from a binary plist
            let output = try shellOut("plutil -p \"\(path)\"")
            #expect(output.contains("\"window.attachments.title\""),
                    "\(path) must contain window.attachments.title")
            #expect(output.contains("\"window.attachments.empty\""),
                    "\(path) must contain window.attachments.empty")
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