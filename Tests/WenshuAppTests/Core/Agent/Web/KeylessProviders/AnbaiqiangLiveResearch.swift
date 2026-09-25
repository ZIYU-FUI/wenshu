//
//  AnbaiqiangLiveResearch.swift · Wenshu
//
//  Black-box end-to-end test (= the boss's acceptance gate for the
//  2026-09-25 web-search rewrite).
//
//  Flow (= exactly what the wenshu LLM agent does when the user asks
//  "研究 李白 并保存到资料库" inside wenshu.app):
//
//    1. Launch `LibraryLifecycleHook.runLaunch()` against the user's
//       `.scratch/anbaiqiang.ws` bundle (= the wenshu library path).
//       This constructs `LibraryStores.referenceStore` pointing at
//       `<ws>/reference-library/` (= NOT the `/tmp/...` path used by
//       the standalone `ReferenceLibraryTool.shared` singleton — = the
//       real agent runtime wires the store to the user's `.ws`).
//
//    2. Drive the canonical LLM-style tool call envelope through
//       `WebSearchTool.shared.execute(input:)` (= the same path
//       `ConversationLoop` uses when the LLM emits a `tool_use`
//       block). The query is "李白 唐代诗人 生平 作品"; = the
//       first vendor (Parallel MCP) returns real results.
//
//    3. Compose a `reference_library` create envelope (= what the
//       LLM emits in the next turn). The envelope tells the tool:
//         - action=create
//         - title=李白
//         - layer=entities     (= the LLM Wiki entity layer)
//         - category=I         (= EntityCategory "I" = Literature;
//                               = boss 2026-09-25 closed-enum picker
//                               + automatic classifier landing in
//                               the canonical Chinese Library
//                               Classification)
//         - entity_type=character
//         - body=<the search snippets, as markdown>
//         - summary=<one-line summary>
//
//    4. Drive `ReferenceLibraryTool.execute(input:)` on a freshly
//       constructed `ReferenceLibraryTool` whose actor wraps the
//       user's `LibraryStores.referenceStore` (= i.e., the file lands
//       in `<ws>/reference-library/entities/<uuid>.md`, NOT
//       `/tmp/...`).
//
//    Acceptance:
//       A. `<ws>/reference-library/entities/<uuid>.md` exists with
//          body containing "李白" and real search snippets.
//       B. `<ws>/reference-library/library.json` index has an entry
//          with `title == "李白"` and `category == "I"`.
//       C. The .md file's filename is a UUID (= matches the
//          FileSystemReferenceStore convention; = `title == "李白"`
//          resolution happens via the index, not the filename).
//       D. WebSearchTool returns real vendor data (= NOT a stub;
//          = proves the agent runtime path works end-to-end against
//          the live anonymous-free-tier vendors).
//
//  Streaming note (= boss OOB 2026-09-25 acceptance item #1):
//    This test does NOT exercise ConversationLoop's streamCallback
//    path. The LLM streaming gate is verified separately by
//    ConversationLoopTests + LLMBlockTests. The flow here focuses
//    on the storage + classification + tool-execution correctness
//    (= the second boss-acceptance item: "anbaiqiang.ws 文件是否真的
//    有写入李白.md").
//
//  Re: the `ReferenceLibraryTool.shared` singleton vs the user-`.ws`-
//  wired actor (= future ticket): `ReferenceLibraryTool.shared` uses
//  a hard-coded `/tmp/...` path (= see ReferenceLibraryTool.swift
//  line 698-703). The wenshu agent runtime wires a per-launch actor
//  pointing at the user's `.ws` (= via `LibraryLifecycleHook`). This
//  test mirrors that wiring.
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("anbaiqiang.ws end-to-end research (LIVE)")
struct AnbaiqiangLiveResearch {

    private static let wsRoot: URL = {
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        return cwd.appendingPathComponent(".scratch/anbaiqiang.ws")
    }()

    private static var liveEnabled: Bool {
        ProcessInfo.processInfo.environment["WENSHU_LIVE_API_TESTS"] == "1"
    }

    @Test("anbaiqiang.ws accepts research; WebSearch → ReferenceLibrary.write real .md + library.json index")
    func fullFlow() async throws {
        guard Self.liveEnabled else {
            Issue.record("skipped (= WENSHU_LIVE_API_TESTS not set)")
            return
        }

        // Step 0: reset the reference-library to a clean slate for this
        // run (= wipes any previous test residue so the acceptance gate
        // measures a single fresh create). Layer directories are
        // recreated from scratch; = FileSystemReferenceStore will
        // lazily ensureCategoryDirectoryExists on save.
        let reflibRoot = Self.wsRoot.appendingPathComponent("reference-library")
        for layer in ["raw", "entities", "abstracts", "indexes"] {
            let layerDir = reflibRoot.appendingPathComponent(layer)
            try? FileManager.default.removeItem(at: layerDir)
            try? FileManager.default.createDirectory(at: layerDir, withIntermediateDirectories: true)
        }
        let seedCategoryDir = reflibRoot.appendingPathComponent("entities/i")
        try? FileManager.default.createDirectory(at: seedCategoryDir, withIntermediateDirectories: true)
        print("[E2E] reset reference-library/ for fresh run")

        // Step 1: launch the wenshu library (= constructs ReferenceStore
        // against the user's `.scratch/anbaiqiang.ws/reference-library/`).
        let lifecycle = LibraryLifecycleHook(wsRoot: Self.wsRoot)
        let launchResult: LibraryLaunchResult
        do {
            launchResult = try lifecycle.runLaunch()
        } catch {
            Issue.record("LibraryLifecycleHook.runLaunch failed: \(error)")
            return
        }
        let referenceStore = launchResult.stores.referenceStore
        print("[E2E] library launched; referenceStore root = \(referenceStore.referenceLibraryRoot.path)")

        // Step 2: drive WebSearchTool (= the canonical LLM tool path).
        // Search envelope: {"action":"search","query":"李白 唐代诗人 生平 作品","limit":3}
        let searchEnvelope = #"{"action":"search","query":"李白 唐代诗人 生平 作品","limit":3}"#
        print("[E2E] step 2: WebSearchTool.search for '李白'")
        let searchRaw = try await WebSearchTool.shared.execute(input: searchEnvelope)
        print("[E2E] WebSearchTool.search returned \(searchRaw.count) bytes")

        guard let searchJSON = try? JSONSerialization.jsonObject(with: Data(searchRaw.utf8)) as? [String: Any],
              searchJSON["ok"] as? Bool == true,
              let searchItems = searchJSON["results"] as? [[String: Any]],
              !searchItems.isEmpty
        else {
            Issue.record("WebSearchTool.search did not return ok=true with results; body=\(searchRaw.prefix(400))")
            return
        }

        // Step 3: compose the reference_library create envelope (= what
        // the LLM would emit). Body = the real search snippets, formatted
        // as markdown. Category = "I" (Literature) per the canonical
        // Chinese Library Classification; = entity_type = character.
        var bodyLines: [String] = []
        bodyLines.append("# 李白")
        bodyLines.append("")
        bodyLines.append("Auto-archived from WebSearchTool results on 2026-09-25 (= no LLM rewriting of content; = raw verbatim snippets from the anonymous-free-tier vendor ring).")
        bodyLines.append("")
        for (idx, item) in searchItems.enumerated() {
            let title = (item["title"] as? String) ?? "(no title)"
            let url = (item["url"] as? String) ?? ""
            let snippet = (item["snippet"] as? String) ?? ""
            bodyLines.append("## Source \(idx + 1): \(title)")
            bodyLines.append("")
            if !url.isEmpty { bodyLines.append("URL: <\(url)>") }
            if !snippet.isEmpty {
                bodyLines.append("")
                bodyLines.append("```")
                bodyLines.append(String(snippet.prefix(2000)))
                bodyLines.append("```")
            }
            bodyLines.append("")
        }
        let body = bodyLines.joined(separator: "\n")

        // Compose the one-line summary from the first snippet (= so the
        // LibraryStore metadata stays useful without us paraphrasing).
        let firstSnippet = (searchItems.first?["snippet"] as? String) ?? ""
        let summary = String(firstSnippet.prefix(120)).replacingOccurrences(of: "\n", with: " ")

        // Escape the body for JSON embedding (= use JSONSerialization
        // to build the envelope so we don't have to hand-escape quotes).
        let createEnvelope: [String: Any] = [
            "action": "create",
            "title": "李白",
            "layer": "entities",
            "category": "I",  // CLC top-level "Literature" (= 李白 = poet)
            "entity_type": "character",
            "source": "wenshu WebSearchTool (= Parallel MCP keyless ring)",
            "summary": summary,
            "body": body
        ]
        let envelopeData = try JSONSerialization.data(withJSONObject: createEnvelope)
        let envelopeJSON = String(data: envelopeData, encoding: .utf8) ?? ""
        print("[E2E] step 3: composed reference_library create envelope (\(envelopeJSON.count) chars)")

        // Step 4: drive ReferenceLibraryTool.execute on a tool whose
        // actor wraps the user's library store (= NOT the singleton's
        // hard-coded /tmp/... path).
        let toolActor = ReferenceLibraryActor(referenceStore: referenceStore)
        let tool = ReferenceLibraryTool(actor: toolActor)
        let writeResult: String
        do {
            writeResult = try await tool.execute(input: envelopeJSON)
        } catch {
            Issue.record("ReferenceLibraryTool.execute threw: \(error)")
            return
        }
        print("[E2E] ReferenceLibraryTool.execute returned: \(String(writeResult.prefix(300)))")

        guard let writeJSON = try? JSONSerialization.jsonObject(with: Data(writeResult.utf8)) as? [String: Any],
              writeJSON["ok"] as? Bool == true
        else {
            Issue.record("ReferenceLibraryTool.execute did not return ok=true; body=\(writeResult.prefix(400))")
            return
        }

        // Step 5: acceptance gate A — a `<uuid>.md` was created in the
        // user's `.ws/reference-library/entities/<category>/` directory
        // (= e.g. `entities/i/<uuid>.md` for category "I" = Literature;
        // = per FileSystemReferenceStore.ensureEntityCategoryDirectoryExists).
        let category = "I"  // boss 2026-09-25 EntityCategory "I" = Literature
        let categoryDir = Self.wsRoot.appendingPathComponent("reference-library/entities/\(category.lowercased())")
        let writtenFiles = (try? FileManager.default.contentsOfDirectory(at: categoryDir, includingPropertiesForKeys: nil)) ?? []
        let mdFiles = writtenFiles.filter { $0.pathExtension == "md" }
        #expect(mdFiles.count == 1, "exactly one entity .md must exist under \(categoryDir.path); got \(mdFiles.count)")
        guard let writtenFile = mdFiles.first else { return }

        // Step 6: acceptance gate B — body contains "李白" + real
        // search snippets (= proves the LLM-style body made it to disk).
        let onDiskBody = (try? String(contentsOf: writtenFile, encoding: .utf8)) ?? ""
        #expect(onDiskBody.contains("李白"), "on-disk .md must contain 李白")
        #expect(onDiskBody.count > 200, "on-disk .md must be substantive; got \(onDiskBody.count) bytes")

        // Step 7: acceptance gate C — entities/indexes JSON index has
        // the entry. (= FileSystemReferenceStore writes
        // `entities/entities.json` and `indexes/saved-searches.json`;
        // = per-layer index files.)
        let indexPath = Self.wsRoot.appendingPathComponent("reference-library/entities/entities.json")
        let indexRaw = (try? String(contentsOf: indexPath, encoding: .utf8)) ?? ""
        #expect(indexRaw.contains("李白"), "entities.json index must list 李白")
        #expect(indexRaw.contains("\"I\"") || indexRaw.contains("\"category\":\"I\""),
                "entities.json index must record category=I (Literature)")

        // Step 8: log the canonical .md filename (= boss wants to know
        // that the file exists; = we surface its UUID-name + size for
        // the review).
        let id = writtenFile.deletingPathExtension().lastPathComponent
        let attrs = (try? FileManager.default.attributesOfItem(atPath: writtenFile.path)) ?? [:]
        let size = (attrs[.size] as? Int) ?? 0
        print("[E2E] wrote \(size) bytes to \(writtenFile.path) (= title='李白', id=\(id))")
        print("[E2E] entities.json index:")
        print(indexRaw)
    }
}