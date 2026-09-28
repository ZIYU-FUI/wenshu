//
//  LLMWikiPipelineWireTests.swift · Wenshu · v2.8d ticket T17-T19 (boss 2026-09-28 OOB)
//
//  Structural tests for the LLM Wiki pipeline wire-up (= boss
//  OOB B10 '调研生成文档，辅助写作，协助用户创建合理的剧情' +
//  '如果 wiki 是解决方案，那就需要不完整').
//
//  LLMWikiLayerDeriver + LLMWikiLinter (= the canonical v0.28
//  pure-data derivation layer) was a dead actor (= zero callers
//  per §11 baseline). boss asked for it to be wired to:
//    1. Manual tool-call (= LLM invokes `llm_wiki` tool).
//    2. Auto-call (= the agent's ConversationLoop runs the
//       derivation when a new raw .md lands).
//    3. UI trigger (= the reference-library inspector's
//       'Re-derive wiki' button for the operator).
//
//  Three source-level tests pin the canonical shape:
//
//    1. testLLMWikiOpsExposesEntryPoints — LLMWikiOps exposes
//       4 entry points (runDerivation / runLint / runAll /
//       lastResult) (= the unified manual + auto façade).
//
//    2. testWenshuConductorRegistersLLMWikiTool —
//       WenshuConductor.defaultToolNames contains "llm_wiki"
//       (= the agent's tool-call entry).
//
//    3. testReferenceStoreAutoCallsLLMWikiOpsOnCreate —
//       FileSystemReferenceStore.create triggers
//       LLMWikiOps.runDerivation (= the agent's auto-call hook
//       per boss OOB '需要不完整').
//
//  Per Q34 5.2 + Q173 ponytail + Q186 + Q57 + Q112: source-level
//  tests following the v1.44 specialized-tools P1 hermes-port
//  batch precedent.

import Testing
import Foundation
@testable import WenshuApp

@Suite("LLM Wiki pipeline wire-up (v2.8d — boss 2026-09-28 OOB B10)")
struct LLMWikiPipelineWireTests {

    private var wenshuConductorPath: String {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<4 { url.deleteLastPathComponent() }
        url.appendPathComponent("Sources/WenshuApp/Core/Agent/Conversation/WenshuConductor.swift")
        return url.path
    }

    private var llmWikiOpsPath: String {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<4 { url.deleteLastPathComponent() }
        url.appendPathComponent("Sources/WenshuApp/Core/Agent/Wiki/LLMWikiOps.swift")
        return url.path
    }

    private var llmWikiToolPath: String {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<4 { url.deleteLastPathComponent() }
        url.appendPathComponent("Sources/WenshuApp/Core/Agent/Tool/LLMWikiTool.swift")
        return url.path
    }

    private var fileSystemReferenceStorePath: String {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<4 { url.deleteLastPathComponent() }
        url.appendPathComponent("Sources/WenshuApp/Storage/FileSystemReferenceStore.swift")
        return url.path
    }

    @Test("LLMWikiOps exposes 4 entry points (runDerivation / runLint / runAll / lastResult) (= unified manual + auto façade)")
    func testLLMWikiOpsExposesEntryPoints() throws {
        let source = try String(contentsOfFile: llmWikiOpsPath, encoding: .utf8)
        for entryPoint in ["runDerivation", "runLint", "runAll", "lastResult"] {
            #expect(source.contains("static func \(entryPoint)"),
                    "LLMWikiOps must expose static func \(entryPoint)(...) (= the unified manual + auto entry point)")
        }
    }

    @Test("WenshuConductor registers llm_wiki tool (= the agent's tool-call entry)")
    func testWenshuConductorRegistersLLMWikiTool() throws {
        let source = try String(contentsOfFile: wenshuConductorPath, encoding: .utf8)
        #expect(source.contains("\"llm_wiki\""),
                "WenshuConductor.defaultToolNames must contain \"llm_wiki\"")
    }

    @Test("LLMWikiTool exists + FileSystemReferenceStore.create auto-calls LLMWikiOps (= manual + auto surfaces wired)")
    func testReferenceStoreAutoCallsLLMWikiOpsOnCreate() throws {
        // LLMWikiTool exists (= manual-call surface for LLM).
        let toolSource = try? String(contentsOfFile: llmWikiToolPath, encoding: .utf8)
        #expect(toolSource != nil,
                "LLMWikiTool.swift must exist (= the manual-call surface)")
        // FileSystemReferenceStore auto-calls LLMWikiOps (= the
        // event-driven auto-call hook per boss OOB B10).
        let storeSource = try String(contentsOfFile: fileSystemReferenceStorePath, encoding: .utf8)
        #expect(storeSource.contains("LLMWikiOps"),
                "FileSystemReferenceStore must call LLMWikiOps.runDerivation on create (= the agent's auto-call hook)")
    }
}