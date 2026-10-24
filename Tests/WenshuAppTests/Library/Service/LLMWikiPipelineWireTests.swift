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
//  Only (1) is live. The auto-call hook (ed03f21bcd) was removed by
//  the SwiftData migration (2a08897eba) and is not restored: the
//  layers it wrote (layerAbstracts / layerIndexes) are filtered out
//  of the agent's read surface, so a save-time derivation would
//  write two layers nothing reads. The UI trigger has no caller
//  either. Per the boss's business goal (= documents become the
//  constraints for later writing) the summary belongs on
//  Reference.summary, which the agent already reads.
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
//    3. testReferenceStoreDoesNotAutoCallLLMWikiOpsOnCreate —
//       FileSystemReferenceStore does NOT auto-derive (= the
//       derived layers have no reader, so the auto-call stays off).
//
//  Per Q34 5.2 + Q173 ponytail + Q186 + Q57 + Q112: source-level
//  tests following the v1.44 specialized-tools P1 hermes-port
//  batch precedent.

import Foundation
import Testing
import WenshuAgent
@testable import WenshuApp

@Suite("LLM Wiki pipeline wire-up (v2.8d — boss 2026-09-28 OOB B10)")
struct LLMWikiPipelineWireTests {

    private var wenshuConductorPath: String {
        var url = SourceLocator.repoRoot
        url.appendPathComponent("Sources/WenshuApp/Features/Agent/Store/WenshuConductorAppExtensions.swift")
        return url.path
    }

    private var llmWikiOpsPath: String {
        var url = SourceLocator.repoRoot
        url.appendPathComponent("Sources/WenshuApp/Features/Agent/Service/LLMWikiOps.swift")
        return url.path
    }

    private var llmWikiToolPath: String {
        var url = SourceLocator.repoRoot
        url.appendPathComponent("Sources/WenshuApp/Features/Agent/Service/LLMWikiTool.swift")
        return url.path
    }

    private var fileSystemReferenceStorePath: String {
        var url = SourceLocator.repoRoot
        url.appendPathComponent("Sources/WenshuApp/Features/Library/Service/FileSystemReferenceStore.swift")
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
        // The conductor's tool list delegates to ToolCatalogue (= the flat name
        // list moved there when each tool grew a category), so the file that
        // actually holds the name is the one to read.
        // The catalogue lives in the app (= the tool roster is app state).
        var catalogueURL = SourceLocator.repoRoot
        catalogueURL.appendPathComponent("Sources/WenshuApp/Features/Agent/Service/ToolCatalogue.swift")
        let cataloguePath = catalogueURL.standardizedFileURL
        let catalogue = try String(contentsOf: cataloguePath, encoding: .utf8)
        #expect(catalogue.contains("\"llm_wiki\""),
                "WenshuConductor.defaultToolNames must contain \"llm_wiki\"")
    }

    @Test("LLMWikiTool exists + the reference store does NOT auto-derive (= the derived layers have no reader)")
    func testReferenceStoreDoesNotAutoCallLLMWikiOpsOnCreate() throws {
        // LLMWikiTool exists (= manual-call surface for LLM).
        let toolSource = try? String(contentsOfFile: llmWikiToolPath, encoding: .utf8)
        #expect(toolSource != nil,
                "LLMWikiTool.swift must exist (= the manual-call surface)")
        // The auto-call hook stays OFF. It was added by ed03f21bcd and
        // removed by 2a08897eba (the SwiftData migration) without a
        // stated reason; it was dead weight, not a live feature:
        // the derived layers (layerAbstracts / layerIndexes) are
        // filtered out of the agent's read surface
        // (ReferenceLibraryTool.parseLayerIfUserFacing accepts only
        // `raw` + `entities`), so a save-time derivation would write
        // two layers nothing reads. The manual surface (the agent
        // calls llm_wiki -> LLMWikiOps.runAll / runDerivation) is the
        // path that exists.
        let storeSource = try String(contentsOfFile: fileSystemReferenceStorePath, encoding: .utf8)
        #expect(!storeSource.contains("LLMWikiOps"),
                "FileSystemReferenceStore must not auto-call LLMWikiOps (= the derived layers have no reader, so a save-time derivation writes layers nothing reads)")
    }
}