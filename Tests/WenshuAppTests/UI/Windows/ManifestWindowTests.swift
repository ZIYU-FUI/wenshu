//
//  ManifestWindowTests.swift · Wenshu
//
//  Structural tests for the ManifestWindow entry surface
//  (= boss 2026-10-03 OOB: "新增入口, 工具栏加三个圆的单独的按钮,
//  打开独立的 windows 像看板一样"). Pins the canonical wire-up
//  shape for the second of 3 WS-model entry windows.
//
//  Per Q34 5.2 + Q173 ponytail + Q186 + Q57 + Q112: source-level
//  tests following the AttachmentsWindowTests precedent.
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ManifestWindow (boss 2026-10-03 OOB — WSManifest entry window)")
struct ManifestWindowTests {

    private func resolve(_ relative: String) -> String {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 { url.deleteLastPathComponent() }
        url.appendPathComponent(relative)
        return url.path
    }

    @Test("ManifestWindow file exists (= independent window)")
    func testManifestWindowExists() throws {
        let filePath = resolve("Sources/WenshuApp/Views/Windows/ManifestWindow.swift")
        #expect(FileManager.default.fileExists(atPath: filePath),
                "ManifestWindow.swift must exist as a standalone file")
        let source = try String(contentsOfFile: filePath, encoding: .utf8)
        #expect(source.contains("struct ManifestWindow: View"),
                "ManifestWindow must declare a View struct")
        #expect(source.contains("import SwiftUI"),
                "ManifestWindow must import SwiftUI")
        #expect(source.contains("import SwiftData"),
                "ManifestWindow must import SwiftData")
    }

    @Test("ManifestWindow fetches WSManifest (= real SwiftData read)")
    func testManifestWindowFetchesWSManifest() throws {
        let filePath = resolve("Sources/WenshuApp/Views/Windows/ManifestWindow.swift")
        let source = try String(contentsOfFile: filePath, encoding: .utf8)
        #expect(source.contains("FetchDescriptor<WSManifest>"),
                "Window must fetch WSManifest via FetchDescriptor")
        #expect(source.contains("WSPersistenceContainer.shared.mainContext"),
                "Window must use the canonical shared container's mainContext")
    }

    @Test("WindowID.manifest declared and Window registered in AppRootScene")
    func testManifestWindowIDRegistered() throws {
        let scenePath = resolve("Sources/WenshuApp/App/AppRootScene.swift")
        let sceneSource = try String(contentsOfFile: scenePath, encoding: .utf8)
        #expect(sceneSource.contains("static let manifest = \"wenshu-manifest\""),
                "WindowID.manifest must be declared in AppRootScene")
        #expect(sceneSource.contains("id: WindowID.manifest"),
                "Window must be registered in AppRootScene with WindowID.manifest")
        #expect(sceneSource.contains("ManifestWindow()"),
                "Window content must be ManifestWindow()")
    }

    @Test("ShellDetailColumn has toolbar button opening manifest window")
    func testToolbarButtonForManifest() throws {
        let toolbarPath = resolve("Sources/WenshuApp/Views/Inspector/InspectorView.swift")
        let source = try String(contentsOfFile: toolbarPath, encoding: .utf8)
        #expect(source.contains("openWindow(id: WindowID.manifest)"),
                "Toolbar must wire openWindow(id: WindowID.manifest)")
        #expect(source.contains("wenshu.window] click: openWindow id=\\(WindowID.manifest)"),
                "Toolbar must log the canonical openWindow NSLog marker")
    }

    @Test("i18n keys for manifest window present in en + zh-Hans")
    func testI18nKeysForManifest() throws {
        let enPath = resolve("Sources/WenshuApp/Resources/en.lproj/Localizable.strings")
        let zhPath = resolve("Sources/WenshuApp/Resources/zh-Hans.lproj/Localizable.strings")
        for path in [enPath, zhPath] {
            let output = try shellOut("plutil -p \"\(path)\"")
            #expect(output.contains("\"window.manifest.title\""),
                    "\(path) must contain window.manifest.title")
            #expect(output.contains("\"window.manifest.workspace_uuid\""),
                    "\(path) must contain window.manifest.workspace_uuid")
            #expect(output.contains("\"window.manifest.schema_version\""),
                    "\(path) must contain window.manifest.schema_version")
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