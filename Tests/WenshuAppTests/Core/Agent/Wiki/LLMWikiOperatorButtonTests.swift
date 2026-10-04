//
//  LLMWikiOperatorButtonTests.swift · Wenshu · v2.9a ticket T24 (boss 2026-09-28 OOB A4)
//
//  Structural tests for the v2.9a LLM Wiki operator button
//  (= boss 2026-09-28 OOB inventory A4 = 'LLM Wiki operator 按钮
//  缺 = 手动 surface 缺一半').
//
//  Per boss 2026-09-28 OOB (= the post-v2.8 inventory surfaced
//  A4): the v2.8d LLM Wiki pipeline is wired (= LLM can call
//  'llm_wiki' tool; = FileSystemReferenceStore.saveReference
//  auto-triggers derivation on every raw save). But the
//  operator (= the boss) has no direct "Re-derive wiki now"
//  affordance. v2.9a fixes this by adding an operator button
//  in the detail column toolbar that calls
//  LLMWikiOps.runAllFromActiveLibrary.
//
//  Three source-level tests pin the canonical shape:
//
//    1. testLLMWikiOpsRunAllFromActiveLibrary —
//       LLMWikiOps.runAllFromActiveLibrary is a public static
//       helper (= the operator-button entry point resolves
//       the active library from UserDefaults).
//
//    2. testShellDetailColumnOperatorButton —
//       ShellDetailColumn.toolbar has the operator button
//       (= i18n key llm_wiki.operator.open is referenced).
//
//    3. testLLMWikiToolUsesSSOT —
//       LLMWikiTool's resolveActiveStore and
//       LLMWikiOps.runAllFromActiveLibrary share one resolution
//       path (= both read wenshu.libraryPath the same way; =
//       the LLM tool path + the operator-button path are
//       SSOT on UserDefaults).
//
//  Per Q34 5.2 + Q173 ponytail + Q186 + Q57 + Q112: source-level
//  tests following the v2.8d LLMWikiPipelineWireTests pattern.
//
//  Per boss 2026-09-28 OOB: '用户体验第一' = no placeholder/stub;
//  = the v2.9a LLM Wiki operator button must run the real
//  pipeline (= not a placeholder NSLog).

import Testing
import Foundation
@testable import WenshuApp

@Suite("LLM Wiki operator button (v2.9a — boss 2026-09-28 OOB A4)")
struct LLMWikiOperatorButtonTests {

    private func resolve(_ relative: String) -> String {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<6 { url.deleteLastPathComponent() }
        url.appendPathComponent(relative)
        return url.path
    }

    @Test("LLMWikiOps.runAllFromActiveLibrary exists (= the operator-button entry point)")
    func testLLMWikiOpsRunAllFromActiveLibrary() throws {
        let source = try String(contentsOfFile: resolve("Sources/WenshuApp/Core/Agent/Wiki/LLMWikiOps.swift"), encoding: .utf8)
        #expect(source.contains("runAllFromActiveLibrary"),
                "LLMWikiOps.runAllFromActiveLibrary must exist (= boss A4 = 'operator 按钮缺 = 手动 surface 缺一半')")
    }

    @Test("ShellDetailColumn operator button = i18n key llm_wiki.operator.open")
    func testShellDetailColumnOperatorButton() throws {
        let source = try String(contentsOfFile: resolve("Sources/WenshuApp/Views/Inspector/InspectorView.swift"), encoding: .utf8)
        #expect(source.contains("llm_wiki.operator.open"),
                "ShellDetailColumn.toolbar must include the LLM Wiki operator button (= boss A4 = 'operator 按钮')")
    }

    @Test("LLMWikiTool resolveActiveStore + LLMWikiOps.runAllFromActiveLibrary share the SSOT path (= wenshu.libraryPath)")
    func testLLMWikiToolUsesSSOT() throws {
        let opsSource = try String(contentsOfFile: resolve("Sources/WenshuApp/Core/Agent/Wiki/LLMWikiOps.swift"), encoding: .utf8)
        let toolSource = try String(contentsOfFile: resolve("Sources/WenshuApp/Core/Agent/Tool/LLMWikiTool.swift"), encoding: .utf8)
        // Both paths must read wenshu.libraryPath from UserDefaults
        // (= the canonical wenshu-pollution-defense active-library
        // resolution; = no divergence between operator button
        // and LLM tool entry).
        let opsHasLibraryPath = opsSource.contains("wenshu.libraryPath")
        let toolHasLibraryPath = toolSource.contains("wenshu.libraryPath")
        #expect(opsHasLibraryPath && toolHasLibraryPath,
                "LLMWikiOps.runAllFromActiveLibrary + LLMWikiTool.resolveActiveStore must share the wenshu.libraryPath SSOT")
    }
}