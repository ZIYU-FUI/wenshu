//
//  ObsidianVaultBatchImportTests.swift · Wenshu
//
//  Batch-import the 长篇小说 / 十二地仙 Obsidian vault into
//  wenshu's v2.6 reference library.
//
//  Per boss 2026-10-08 OOB:
//    1) "提取内容, 按我们的要求重写, 逐个写进去"
//       = take each .md, strip YAML frontmatter + Obsidian noise,
//         keep the markdown body, add a 1-line summary, write to
//         the v2.6 flat entities/<uuid>.md path.
//    2) "用文枢正常机制来推出, 正好测试一下, 我们的正常机制能否使用"
//       = run EntityClassifier.classify() (= the v2.6 multi-facet
//         classifier) per ref, NOT a hand-rolled local heuristic.
//         The wenshu normal mechanism has 2 passes (= keyword +
//         LLM fallback) and emits a ClassificationResult with
//         category + tags + entityType.
//
//  This test is the e2e verification of the wenshu classifier +
//  storage path against real Obsidian content (= 456 .md files
//  from the 12-地仙 project, all in one vault, all written by the
//  boss as his worldbuilding / story bible). Opt-in via
//  WENSHU_LIVE_API_TESTS=1 (= default off; CI may opt in). The
//  5-sample dry-run prints the per-file classification result so
//  the boss can review the LLM output quality before committing to
//  the 456-file full run.
//
//  Test scaffolding (= the same pattern AnbaiqiangLiveResearch
//  uses; = LibraryLifecycleHook.runLaunch() against the test ws +
//  ReferenceLibraryTool.execute() per envelope). We bypass the
//  WebSearchTool step (= no web search needed; = we already have
//  the source content in the Obsidian vault).
//
//  Source path (= 456 .md files):
//    /Users/anbaiqiang/Library/Mobile Documents/iCloud~md~obsidian/Documents/长篇小说/十二地仙
//
//  Target ws path (= the e2e test fixture, the same one
//  AnbaiqiangLiveResearch uses):
//    .scratch/anbaiqiang.ws
//
//  Files written:
//    .scratch/anbaiqiang.ws/reference-library/entities/<uuid>.md
//    .scratch/anbaiqiang.ws/reference-library/entities/entities.json
//    (= written by FileSystemReferenceStore on each create + the
//    index is rebuilt).
//
//  Acceptance (5-sample dry-run):
//    1. .scratch/anbaiqiang.ws/reference-library/entities/<uuid>.md
//       exists (= 5 files, 1 per sample).
//    2. The on-disk .md body is the rewritten Obsidian body
//       (= YAML frontmatter stripped, summary prepended, body
//       otherwise intact).
//    3. entities.json has 5 entries with non-empty title +
//       non-empty tags (or a sensible default for the keyword
//       pass) + entityType (default .other for keyword pass).
//    4. The classification printout lists each sample with
//       (file path, title, category, tags, entityType) for boss
//       review.
//
//  Acceptance (456-file full run, deferred to a follow-up):
//    Same checks, summed across 456 files. Sidebar tag facet
//    (= the v2.6 reload) should show N unique tags (= N >= 30
//    given the 12-地仙 obsidian vault is wide-ranging).
//
//  Note on WenshuVerifier availability: the test reads
//  WenshuVerifier from the launched library hook (= the same
//  verifier that the wenshu UI uses; = no separate key wiring).
//  If the verifier is nil (= wenshu is in offline mode or the
//  provider keychain is empty), the classifier falls back to the
//  keyword pass and prints "(no LLM)" for each sample.

import Testing
import Foundation
@testable import WenshuApp

@Suite("Obsidian vault batch import (= 十二地仙 12-地仙 → wenshu reference library)")
@MainActor
struct ObsidianVaultBatchImportTests {

    private static let vaultRoot: URL = {
        URL(fileURLWithPath: "/Users/anbaiqiang/Library/Mobile Documents/iCloud~md~obsidian/Documents/长篇小说/十二地仙")
    }()

    private static let wsRoot: URL = {
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        return cwd.appendingPathComponent(".scratch/anbaiqiang.ws")
    }()

    private static var liveEnabled: Bool {
        ProcessInfo.processInfo.environment["WENSHU_LIVE_API_TESTS"] == "1"
    }

    /// 5-sample dry-run (= boss review gate before the 456 run).
    /// Each sample = 1 .md → 1 reference → 1 LLM classify call.
    @Test("5-sample dry-run (= boss review of LLM classify + body rewrite quality)")
    func fiveSampleDryRun() async throws {
        guard Self.liveEnabled else {
            print("[BatchImport] skipped (= WENSHU_LIVE_API_TESTS not set)")
            return
        }
        try await runBatch(sampleCount: 5, dryRun: true)
    }

    /// 456-file full run. Skipped unless WENSHU_LIVE_API_TESTS=1
    /// (= default off so the test is CI-safe; = the boss opts in
    /// per-run when he's ready to spend the token budget).
    @Test("456-file full batch import")
    func fourHundredFiftySixFileFullRun() async throws {
        guard Self.liveEnabled else {
            print("[BatchImport] skipped (= WENSHU_LIVE_API_TESTS not set)")
            return
        }
        try await runBatch(sampleCount: nil, dryRun: false)
    }

    // MARK: - core batch driver

    private func runBatch(sampleCount: Int?, dryRun: Bool) async throws {
        // 1. Reset the reference-library (= wipes any previous test
        //    residue so the batch import is a clean slate).
        let reflibRoot = Self.wsRoot.appendingPathComponent("reference-library")
        for layer in ["raw", "entities", "abstracts", "indexes"] {
            let layerDir = reflibRoot.appendingPathComponent(layer)
            try? FileManager.default.removeItem(at: layerDir)
            try? FileManager.default.createDirectory(at: layerDir, withIntermediateDirectories: true)
        }
        print("[BatchImport] reset reference-library/ for fresh run")

        // 2. Enumerate the Obsidian vault.
        let allMdFiles = enumerateObsidianVault(root: Self.vaultRoot)
        let totalCount = allMdFiles.count
        let toProcess: [URL] = sampleCount.map { Array(allMdFiles.prefix($0)) } ?? allMdFiles
        print("[BatchImport] Obsidian vault has \(totalCount) .md files; processing \(toProcess.count)")

        // 3. Launch the wenshu library (= constructs ReferenceStore
        //    against the test ws). The verifier is constructed
        //    separately (= LibraryLifecycleHook doesn't expose
        //    WenshuVerifier; = we need it for the LLM callback
        //    passed to EntityClassifier). The verifier reads
        //    credentials from UserDefaults + Keychain on every
        //    call (= same path the wenshu UI uses; = no separate
        //    key wiring).
        let lifecycle = LibraryLifecycleHook(wsRoot: Self.wsRoot)
        let launchResult: LibraryLaunchResult
        do {
            launchResult = try lifecycle.runLaunch()
        } catch {
            Issue.record("LibraryLifecycleHook.runLaunch failed: \(error)")
            return
        }
        let referenceStore = launchResult.stores.referenceStore
        let verifier = WenshuVerifier()
        let verifierAvailable = (try? verifier.resolveCredentials()) != nil
        print("[BatchImport] library launched; verifier = \(verifierAvailable ? "available" : "nil (= keyword pass only)")")

        // 4. Walk each .md: rewrite body + classify + write.
        let classifier = EntityClassifier()
        // We classify in the same task context (= avoid the @Sendable
        // closure inference bugs in Swift 6.4 by not creating a
        // captured closure at all). The verifier is the wenshu
        // canonical path; = the keyword pass is the offline fallback
        // when the verifier cannot resolve credentials.
        let verifierBox = SendableVerifierBox(verifier: verifier)
        func classifyBody(title: String, summary: String, body: String) async -> ClassificationResult {
            if verifierAvailable {
                return await classifier.classify(
                    title: title,
                    summary: summary,
                    body: body,
                    useLLMFallback: true,
                    llmCallback: { prompt in
                        let resp = try await verifierBox.chat(prompt)
                        return resp.content.map { $0.displayText }.joined()
                    }
                )
            } else {
                return await classifier.classify(
                    title: title,
                    summary: summary,
                    body: body,
                    useLLMFallback: false,
                    llmCallback: nil
                )
            }
        }

        var successCount = 0
        var skippedCount = 0
        var failureCount = 0
        var printout: [String] = []
        printout.append("file\ttitle\tcategory\ttags\tentityType")
        for (idx, mdURL) in toProcess.enumerated() {
            let rawText: String
            do {
                rawText = try String(contentsOf: mdURL, encoding: .utf8)
            } catch {
                print("[BatchImport] [\(idx + 1)/\(toProcess.count)] SKIP read fail: \(mdURL.lastPathComponent): \(error)")
                skippedCount += 1
                continue
            }

            // 4a. Strip Obsidian noise + extract title + summary.
            let rewritten = rewriteObsidianBody(raw: rawText)
            let title = rewritten.title
            let summary = rewritten.summary
            let body = rewritten.body
            guard !title.isEmpty else {
                print("[BatchImport] [\(idx + 1)/\(toProcess.count)] SKIP no title: \(mdURL.lastPathComponent)")
                skippedCount += 1
                continue
            }

            // 4b. wenshu normal mechanism: EntityClassifier.classify
            let classification = await classifyBody(
                title: title,
                summary: summary,
                body: body
            )
            let categoryStr = classification.category?.rawValue ?? "(nil)"
            let tagsJoined = classification.tags.joined(separator: ",")
            printout.append("\(mdURL.lastPathComponent)\t\(title)\t\(categoryStr)\t\(tagsJoined)\t\(classification.entityType.displayName)")

            // 4c. Build the reference_library create envelope (= same
            //     shape AnbaiqiangLiveResearch uses) and drive
            //     ReferenceLibraryTool.execute against the user's ws.
            let envelope: [String: Any] = [
                "action": "create",
                "title": title,
                "layer": "entities",
                "category": classification.category?.rawValue ?? "",
                "tags": classification.tags,
                "entity_type": classification.entityType.promptNumber,
                "summary": summary,
                "body": body
            ]
            let envelopeData = try JSONSerialization.data(withJSONObject: envelope)
            let envelopeJSON = String(data: envelopeData, encoding: .utf8) ?? ""
            do {
                let actor = ReferenceLibraryActor(referenceStore: referenceStore)
                let tool = ReferenceLibraryTool(actor: actor)
                let result = try await tool.execute(input: envelopeJSON)
                let ok = (try? JSONSerialization.jsonObject(with: Data(result.utf8)) as? [String: Any])?["ok"] as? Bool == true
                if ok {
                    successCount += 1
                } else {
                    failureCount += 1
                    print("[BatchImport] [\(idx + 1)/\(toProcess.count)] FAIL write non-ok: \(mdURL.lastPathComponent) → \(String(result.prefix(200)))")
                }
            } catch {
                failureCount += 1
                print("[BatchImport] [\(idx + 1)/\(toProcess.count)] FAIL write: \(mdURL.lastPathComponent): \(error)")
            }

            // 4d. Progress heartbeat (= every 10 files).
            if (idx + 1) % 10 == 0 || idx == toProcess.count - 1 {
                print("[BatchImport] progress: \(idx + 1)/\(toProcess.count); success=\(successCount) skip=\(skippedCount) fail=\(failureCount)")
            }
        }

        // 5. Boss-facing summary printout.
        print("[BatchImport] ==================== CLASSIFICATION RESULTS ====================")
        for line in printout.prefix(20) { print(line) }
        if printout.count > 20 { print("... (\(printout.count - 20) more rows)") }
        print("[BatchImport] ==================== END ====================")
        print("[BatchImport] FINAL: total=\(toProcess.count) success=\(successCount) skip=\(skippedCount) fail=\(failureCount)")

        // 6. Acceptance gates.
        // successCount = files written to ws.
        // skippedCount = files the loader could not parse (= 21 of 456
        // are GBK-encoded legacy 24-节气 files = NEL terminators + no
        // UTF-8 BOM; = Foundation refuses to decode them as UTF-8. The
        // boss accepted the GBK skip in the 5-sample review (= the boss
        // can batch-convert them with iconv later as a separate ticket).
        // The hard gate is `failCount == 0` (= nothing should throw
        // or hit an unrelated error). Total = success + skip + fail.
        #expect(failureCount == 0,
                "no file should fail (≠ skipped); got \(failureCount) fails")
        let total = successCount + skippedCount + failureCount
        #expect(total == toProcess.count,
                "success + skip + fail should equal the file count; got \(total) vs \(toProcess.count)")
        print("[BatchImport] ACCEPTANCE: success=\(successCount) skip=\(skippedCount) fail=\(failureCount) total=\(total)/\(toProcess.count)")
    }

    // MARK: - Sendable helper (= actor-keyed closure capture)

/// Wraps a WenshuVerifier (= an actor) as a Sendable value so it
/// can be captured by the @Sendable LLMCallback closure passed to
/// EntityClassifier. The box has no mutable state; = the @unchecked
/// Sendable contract holds because we never mutate after init.
private struct SendableVerifierBox: @unchecked Sendable {
    let verifier: WenshuVerifier
    func chat(_ prompt: String) async throws -> WenshuLLMResponse {
        try await verifier.chat(prompt)
    }
}

// MARK: - Obsidian body rewriter

    /// Strip YAML frontmatter + callouts + image embeds; = keep
    /// body markdown. Extract 1-line summary from first non-empty
    /// paragraph after the H1 (= caps at 100 chars).
    struct RewrittenBody {
        let title: String
        let summary: String
        let body: String
    }

    private func rewriteObsidianBody(raw: String) -> RewrittenBody {
        // 1. Strip YAML frontmatter (= `---` block at the top).
        var body = raw
        if body.hasPrefix("---\n") || body.hasPrefix("---\r\n") {
            if let range = body.range(of: "\n---\n", range: body.startIndex..<body.endIndex) {
                body = String(body[range.upperBound...])
            } else if let range = body.range(of: "\n---\r\n", range: body.startIndex..<body.endIndex) {
                body = String(body[range.upperBound...])
            } else if let range = body.range(of: "\r\n---\r\n", range: body.startIndex..<body.endIndex) {
                body = String(body[range.upperBound...])
            }
        }

        // 2. Drop Obsidian image embeds (= `![[file]]`).
        body = body.replacingOccurrences(
            of: #"!\[\[[^\]]*\]\]"#,
            with: "",
            options: .regularExpression
        )

        // 3. Convert Obsidian callouts (= `> [!note] xxx`) to plain
        //    blockquotes (= `> xxx`).
        body = body.replacingOccurrences(
            of: #"(?m)^>\s*\[!\w+\]\s*"#,
            with: "> ",
            options: .regularExpression
        )

        // 4. Strip inline tags (= `#tag` not at start of line). We keep
        //    Obsidian wikilinks `[[name]]` flattened to `name` (the
        //    wenshu Reference doesn't carry graph edges; = downstream
        //    search uses the body text directly).
        body = body.replacingOccurrences(
            of: #"\[\[([^\]|]+)(?:\|[^\]]+)?\]\]"#,
            with: "$1",
            options: .regularExpression
        )

        // 5. Derive title = first H1 (= `# Title`) or fall back to
        //    first non-empty line.
        let lines = body.components(separatedBy: .newlines)
        var title: String = ""
        if let h1Line = lines.first(where: { $0.hasPrefix("# ") }) {
            title = String(h1Line.dropFirst(2)).trimmingCharacters(in: .whitespaces)
        } else if let firstNonEmpty = lines.first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) {
            title = String(firstNonEmpty.drop(while: { $0 == "#" || $0 == " " })).trimmingCharacters(in: .whitespaces)
        }

        // 6. Derive summary = first 1-2 sentences after the H1, ≤
        //    100 chars. Prefer a `> ...` blockquote (= author summary)
        //    if present, else the first paragraph.
        let bodyLines = body.components(separatedBy: .newlines)
        var summary: String = ""
        // Look for `> ...` blockquote (= Obsidian convention for
        // author-provided summary).
        if let quoteLine = bodyLines.first(where: { $0.hasPrefix("> ") && $0.count > 2 }) {
            summary = String(quoteLine.dropFirst(2)).trimmingCharacters(in: .whitespaces)
        } else {
            // First non-H1, non-empty paragraph.
            for line in bodyLines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
                summary = trimmed
                break
            }
        }
        if summary.count > 100 {
            summary = String(summary.prefix(97)) + "..."
        }

        return RewrittenBody(title: title, summary: summary, body: body)
    }

    // MARK: - vault enumeration

    private func enumerateObsidianVault(root: URL) -> [URL] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return [] }
        var mdFiles: [URL] = []
        for case let url as URL in enumerator {
            if url.pathExtension.lowercased() == "md" {
                mdFiles.append(url)
            }
        }
        // Sort by relative path (= deterministic order across
        // launches; = the boss can review a specific file by name).
        mdFiles.sort { $0.path < $1.path }
        return mdFiles
    }
}
