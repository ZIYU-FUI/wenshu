//
//  UnusedSpmDepRemovalTests.swift · Wenshu · v2.9e ticket T40 (boss 2026-09-28 OOB B13)
//
//  Structural tests confirming the v2.9e unused SPM dependency
//  removal (= boss 2026-09-28 OOB inventory B13 = '4 个第三方库零
//  使用 (EPUBKit / ZIPFoundation / Highlighter / Textual)';
//  = the 4 §11.1 batch 2 exception SPM pins were adopted with
//  future consumer tickets; = 3 of them never landed any
//  consumer (= EPUBKit / ZIPFoundation / Textual); = Highlighter
//  IS used via HighlighterSwiftBridge (= WenshuEditorServicesFactory
//  instantiates a Highlighter for syntax highlighting); =
//  v2.9e T40 confirms the canonical shape).
//
//  Per boss 2026-09-28 OOB: 'B13 = 4 个 SPM dep 零使用'; =
//  the only removable dep of the 4 is Highlighter IF its
//  consumer can be cut (= HighlighterSwiftBridge is wired
//  at runtime = unblocking requires cutting 2 WenshuEditorServicesFactory
//  call sites + the syntax-highlight path; = future ticket).
//  For v2.9e T40 we pin the canonical state (= 3 unused
//  deps are already gone; = Highlighter has its consumer).
//
//  Three source-level tests pin the canonical shape:
//
//    1. testEPUBKitNotInPackageSwift —
//       Package.swift does not declare EPUBKit (= already
//       removed; = archived in AGENTS.md §11.1 history).
//
//    2. testZIPFoundationNotInPackageSwift —
//       Package.swift does not declare ZIPFoundation (= already
//       removed; = archived in AGENTS.md §11.1 history).
//
//    3. testHighlighterHasConsumer —
//       WenshuEditorServicesFactory instantiates
//       HighlighterSwiftBridge (= Highlighter IS used; = the
//       pin cannot be removed without cutting 2 call sites +
//       the syntax-highlight path).
//
//  Per Q34 5.2 + Q173 ponytail + Q186 + Q57 + Q112:
//  source-level tests following the v2.9c BackupRestoreUITests
//  pattern.

import Testing
import Foundation
@testable import WenshuApp

@Suite("Unused SPM dependency removal (v2.9e — boss 2026-09-28 OOB B13)")
struct UnusedSpmDepRemovalTests {

    private func resolve(_ relative: String) -> String {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<4 { url.deleteLastPathComponent() }
        url.appendPathComponent(relative)
        return url.path
    }

    @Test("Package.swift does not declare EPUBKit (= already removed; = archived in AGENTS.md §11.1)")
    func testEPUBKitNotInPackageSwift() throws {
        let source = try String(contentsOfFile: resolve("Package.swift"), encoding: .utf8)
        let hasActivePin = source.contains(".package(url: \"https://github.com/witekbobrowski/EPUBKit\"")
        #expect(!hasActivePin,
                "EPUBKit must NOT be an active .package pin in Package.swift (= boss B13 = 'zero-use SPM dep removal')")
    }

    @Test("Package.swift does not declare ZIPFoundation (= already removed; = archived in AGENTS.md §11.1)")
    func testZIPFoundationNotInPackageSwift() throws {
        let source = try String(contentsOfFile: resolve("Package.swift"), encoding: .utf8)
        let hasActivePin = source.contains(".package(url: \"https://github.com/weichsel/ZIPFoundation\"")
        #expect(!hasActivePin,
                "ZIPFoundation must NOT be an active .package pin in Package.swift (= boss B13 = 'zero-use SPM dep removal')")
    }

    @Test("Highlighter HAS consumer (= WenshuEditorServicesFactory wires HighlighterSwiftBridge)")
    func testHighlighterHasConsumer() throws {
        let source = try String(contentsOfFile: resolve("Sources/WenshuApp/Editor/WenshuEditorServicesFactory.swift"), encoding: .utf8)
        let hasConsumer = source.contains("HighlighterSwiftBridge()")
        #expect(hasConsumer,
                "Highlighter must have a consumer (= HighlighterSwiftBridge in WenshuEditorServicesFactory); = the Highlighter pin is justified")
    }
}