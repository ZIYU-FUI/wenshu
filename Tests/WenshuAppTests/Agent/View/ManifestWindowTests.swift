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
import WenshuData
@testable import WenshuApp

@Suite("ManifestWindow (boss 2026-10-03 OOB — WSManifest entry window)")
struct ManifestWindowTests {

    private func resolve(_ relative: String) -> String {
        var url = SourceLocator.repoRoot
        url.appendPathComponent(relative)
        return url.path
    }

    @Test("ManifestWindow file exists (= independent window)")
    func testManifestWindowExists() throws {
        let filePath = resolve("Sources/WenshuApp/Features/Manifest/View/ManifestWindow.swift")
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
        let filePath = resolve("Sources/WenshuApp/Features/Manifest/View/ManifestWindow.swift")
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

    @Test("Manifest window is reachable from the canonical toolbar row")
    func testToolbarButtonFormanifest() throws {
        // The button row is data-driven: `WindowID.toolbarButtons` lists the
        // id and `WindowOpenButton` performs the openWindow call. Asserting a
        // literal `openWindow(id: WindowID.manifest)` in one view only held while
        // each button was hand-written; the row is the single source of truth now.
        let toolbar = try SourceLocator.read(
            "Sources/WenshuApp/Features/Chrome/View/ChromeMainToolbar.swift")
        let button = try SourceLocator.read(
            "Sources/WenshuApp/Features/Chrome/View/WindowOpenButton.swift")
        #expect(toolbar.contains("ToolbarButton(id: WindowID.manifest"),
                "toolbar row must list WindowID.manifest")
        #expect(toolbar.contains("ForEach(WindowID.toolbarButtons"),
                "toolbar row must render the data-driven button list")
        #expect(button.contains("openWindow(id: id)"),
                "WindowOpenButton must perform the openWindow call for every listed id")
    }

    @Test("i18n keys for manifest window present in en + zh-Hans")
    func testI18nKeysForManifest() throws {
        let enLanguage = "en"
        let zhLanguage = "zh-Hans"
        for language in [enLanguage, zhLanguage] {
            let output = StringCatalogReader.strings(language: language)
            #expect(output["window.manifest.title"] != nil,
                    "\(language) must contain window.manifest.title")
            #expect(output["window.manifest.workspace_uuid"] != nil,
                    "\(language) must contain window.manifest.workspace_uuid")
            #expect(output["window.manifest.schema_version"] != nil,
                    "\(language) must contain window.manifest.schema_version")
        }
    }

}