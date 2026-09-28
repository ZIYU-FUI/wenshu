//
//  CanvasWindowActorWireTests.swift · Wenshu · v2.9b ticket T26 (boss 2026-09-28 OOB B6 follow-up)
//
//  Structural tests for the v2.9b CanvasWindow save-back
//  (= boss 2026-09-28 OOB inventory follow-up A5 = 'CanvasWindow
//  能 .fileImporter 读 .canvas 文件 = 能显示节点列表 = 不能 save-back';
//  = v2.9b closes this gap).
//
//  Per boss 2026-09-28 OOB: '重复的应该合并, 不同的功能每个独立的；
//  = 但缺失的应该补'; = v2.9b adds the save-back path so the
//  boss can edit nodes + persist to .canvas file (= the canvas
//  window becomes a round-trip renderer, not a one-way reader).
//
//  Three source-level tests pin the canonical shape:
//
//    1. testCanvasWindowHasSaveToolbarButton —
//       CanvasWindow.toolbar has a save button (= i18n key
//       canvas.save).
//
//    2. testCanvasWindowSavePathEncodesViaJSONCanvasCodec —
//       CanvasWindow.saveBack path calls
//       JSONCanvasCodec.encode / encodeToString (= the
//       view never touches Codable directly; = SSOT on
//       the codec).
//
//    3. testCanvasWindowSaveUsesFileExporter —
//       CanvasWindow uses Apple HIG .fileExporter (= the
//       canonical save-back surface; = no NSOpenPanel
//       hacks).
//
//  Per Q34 5.2 + Q173 ponytail + Q186 + Q57 + Q112: source-level
//  tests following the v2.8b SecondaryWindowsTests pattern.

import Testing
import Foundation
@testable import WenshuApp

@Suite("CanvasWindow actor wire-up (v2.9b — boss 2026-09-28 OOB B6 follow-up)")
struct CanvasWindowActorWireTests {

    private func resolve(_ relative: String) -> String {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 { url.deleteLastPathComponent() }
        url.appendPathComponent(relative)
        return url.path
    }

    @Test("CanvasWindow.toolbar has save button (= i18n key canvas.save)")
    func testCanvasWindowHasSaveToolbarButton() throws {
        let source = try String(contentsOfFile: resolve("Sources/WenshuApp/Views/Windows/CanvasWindow.swift"), encoding: .utf8)
        #expect(source.contains("canvas.save"),
                "CanvasWindow.toolbar must include a save action (= boss B6 follow-up = '能 save-back')")
    }

    @Test("CanvasWindow save-back encodes via JSONCanvasCodec (= SSOT on the codec)")
    func testCanvasWindowSavePathEncodesViaJSONCanvasCodec() throws {
        let source = try String(contentsOfFile: resolve("Sources/WenshuApp/Views/Windows/CanvasWindow.swift"), encoding: .utf8)
        let usesEncode = source.contains("JSONCanvasCodec.encode") || source.contains("JSONCanvasCodec.encodeToString")
        #expect(usesEncode,
                "CanvasWindow save-back must call JSONCanvasCodec.encode / encodeToString (= SSOT = the view never touches Codable directly)")
    }

    @Test("CanvasWindow uses Apple HIG .fileExporter (= the canonical save-back surface)")
    func testCanvasWindowSaveUsesFileExporter() throws {
        let source = try String(contentsOfFile: resolve("Sources/WenshuApp/Views/Windows/CanvasWindow.swift"), encoding: .utf8)
        #expect(source.contains(".fileExporter"),
                "CanvasWindow must use .fileExporter (= Apple HIG canonical save-back surface; = no NSOpenPanel hacks)")
    }
}