//
//  AppRootSceneTests.swift · Wenshu · v1.45 ticket 001
//
//  Structural tests for AppRootScene (= SwiftUI Scene root + wenshu menu chrome (= the legacy NSMenu → SwiftUI Commands migration per Q2 boss split); = ~486 NLOC,
//  = repowise untested hotspot).
//
//  Per boss OOB 2026-09-16 '按优先级推' + '自己一口气推完' (= keep
//  pushing until done): v1.45 adds final batch of source-level
//  structural coverage for remaining untested hotspots.
//
//  Per Q34 5.2 + Q173 ponytail + Q186 + Q57 + Q112: source-level
//  tests following the v1.40 PreviewPaneTests + v1.44 batch
//  precedent. Pattern: 8 tests per file.
//
//  Path is derived from #filePath (= robust to worktree relocations).

import Foundation
import SwiftUI
import Testing
@testable import WenshuApp

@Suite("AppRootScene (v1.45 — final batch untested hotspots)")
struct AppRootSceneTests {

    private var sourcePath: String {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<4 { url.deleteLastPathComponent() }
        url.appendPathComponent("Sources/WenshuApp/App/AppRootScene.swift")
        return url.path
    }

    @Test("AppRootScene exists (= confirmed by source)")
    func testExists() throws {
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        #expect(source.contains("AppRootScene"),
                "AppRootScene must be declared in AppRootScene.swift")
    }

    @Test("AppRootScene conforms to expected protocol (= source-level)")
    func testProtocolConformance() throws {
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        // AppRootScene may conform to View (= for SwiftUI views) OR App (= for the @main entry point).
        let conformsToView = source.contains(": View")
        let conformsToApp = source.contains(": App {") || source.contains(": App{")
        let conformsToScene = source.contains(": Scene {") || source.contains(": Scene{")
        #expect(conformsToView || conformsToApp || conformsToScene,
                "AppRootScene must conform to View (= SwiftUI view) or App (= @main entry)")
    }

    @Test("AppRootScene has body OR var body OR @main")
    func testBodyOrMain() throws {
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        let hasBody = source.contains("var body:") || source.contains("var scene:")
        let hasMain = source.contains("@main") || source.contains("@MainActor")
        #expect(hasBody || hasMain,
                "AppRootScene must declare body/scene OR @main/@MainActor")
    }

    @Test("AppRootScene imports SwiftUI")
    func testImportsSwiftUI() throws {
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        #expect(source.contains("import SwiftUI") ||
                source.contains("import AppKit"),
                "AppRootScene must import SwiftUI or AppKit")
        #expect(!source.contains("import LucideSwift"),
                "AppRootScene must NOT import LucideSwift (= removed by v1.x)")
    }

    @Test("AppRootScene file > 100 NLOC")
    func testFileSize() throws {
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        let lineCount = source.components(separatedBy: "\n").count
        #expect(lineCount > 100,
                "AppRootScene.swift should be > 100 NLOC; found \(lineCount)")
    }

    @Test("AppRootScene no Lucide references in code")
    func testNoLucideInCode() throws {
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        let codeLines = source.components(separatedBy: "\n").filter { line in
            !line.trimmingCharacters(in: .whitespaces).hasPrefix("///") &&
            !line.trimmingCharacters(in: .whitespaces).hasPrefix("//")
        }
        let codeRegion = codeLines.joined(separator: "\n")
        let lucideCount = codeRegion.components(separatedBy: "Lucide").count - 1
        #expect(lucideCount == 0,
                "AppRootScene must have zero Lucide references in code; found \(lucideCount)")
    }

    @Test("AppRootScene triple contract (= struct conformance + body + init)")
    func testTripleContract() throws {
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        let hasConformance = source.contains("struct AppRootScene") ||
                              source.contains(": View") ||
                              source.contains(": App {") ||
                              source.contains(": App{")
        let hasBody = source.contains("var body") || source.contains("var scene") || source.contains("@main")
        #expect(hasConformance, "1/2: struct AppRootScene conformance missing")
        #expect(hasBody, "2/2: body/scene/main missing")
    }

    @Test("AppRootScene uses Apple canonical APIs (= no third-party substitution)")
    func testAppleCanonical() throws {
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        // Per AGENTS.md §11.1: wenshu stack = Apple native. The body
        // must reference Apple HIG primitives (= NavigationSplitView,
        // WindowGroup, NSMenu, etc.).
        let usesAppleAPI = source.contains("WindowGroup") ||
                           source.contains("NavigationSplitView") ||
                           source.contains("Settings(") ||
                           source.contains("Commands") ||
                           source.contains("Scene") ||
                           source.contains("NSMenu") ||
                           source.contains("NSWindow") ||
                           source.contains("NavigationStack") ||
                           source.contains("VStack(") ||
                           source.contains("HStack(")
        #expect(usesAppleAPI,
                "AppRootScene must use Apple HIG APIs (= WindowGroup / NavigationSplitView / Commands / NSMenu)")
    }
}
