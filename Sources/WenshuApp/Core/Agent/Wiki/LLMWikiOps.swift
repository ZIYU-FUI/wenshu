//
//  LLMWikiOps.swift · Wenshu · v2.8d ticket T17-T19 (boss 2026-09-28 OOB B10)
//
//  LLM Wiki pipeline unified ops (= the manual + auto façade per
//  boss 2026-09-28 OOB '调研生成文档，辅助写作，协助用户创建合理
//  的剧情，这个是我们的核心能力，如果 wiki 是解决方案，那就需要
//  不完整').
//
//  Per boss 2026-09-28 OOB B10: the LLM Wiki pipeline
//  (= LLMWikiLayerDeriver + LLMWikiLinter) was dead code per §11
//  baseline (= zero callers). boss asked for it to be wired to:
//    1. Manual tool-call (= LLM invokes `llm_wiki` tool).
//    2. Auto-call (= the agent's ConversationLoop / a new
//       raw-reference auto-derive hook runs the derivation).
//    3. UI trigger (= the reference-library inspector's
//       'Re-derive wiki' button for the operator).
//
//  All three surfaces go through these 4 entry points (= the
//  unified manual + auto façade per the §11.3 wenshu-side wins
//  principle + boss OOB B10: '需要不完整' = the pipeline must
//  complete end to end).
//
//  Standards axis (= S1 + S3 + S4 + S5):
//    S1 (Apple-API-first): the LLMWikiLayerDeriver + LLMWikiLinter
//        (= pure-data deterministic derivation; = no LLM call)
//        are the source of truth; = LLMWikiOps is a thin MainActor
//        façade that delegates to them.
//    S3 (single source of truth): one set of 4 entry points
//        serves manual + auto callers.
//    S4 (typed errors): DerivationStats + LintReport capture the
//        result (= callers can render the library-health surface
//        without re-running the derivation).
//    S5 (no public surface): zero new public keywords.

import Foundation

/// LLM Wiki pipeline unified façade (= manual + auto go through
/// these 4 entry points per boss 2026-09-28 OOB B10).
@MainActor
enum LLMWikiOps {

    /// Cached last result (= callers can render the library-health
    /// dashboard without re-running the derivation).
    private static var lastResultValue: LLMWikiOpsResult?

    /// Run the LLM Wiki derivation (= pure-data; = walks raw/
    /// produces abstracts/ + indexes/ entries). Used by both
    /// manual LLM tool-call + auto-call hook.
    static func runDerivation(store: ReferenceStoring) async throws -> LLMWikiLayerDeriver.DerivationStats {
        let deriver = LLMWikiLayerDeriver(store: store)
        let stats = try deriver.runDerivation()
        let result = LLMWikiOpsResult(
            ranAt: Date(),
            stats: stats,
            lintFindings: nil
        )
        lastResultValue = result
        return stats
    }

    /// Run the LLM Wiki lint (= orphan / broken-wikilink /
    /// index-completeness checks per LLMWikiLinter.swift).
    static func runLint(store: ReferenceStoring) async throws -> [LLMWikiLinter.LintFinding] {
        let linter = LLMWikiLinter(store: store)
        let findings = try linter.lint()
        let prior = lastResultValue
        let combined = LLMWikiOpsResult(
            ranAt: Date(),
            stats: prior?.stats,
            lintFindings: findings
        )
        lastResultValue = combined
        return findings
    }

    /// Run both derivation + lint (= the operator's one-click
    /// 'Re-derive wiki' workflow per boss OOB B10).
    static func runAll(store: ReferenceStoring) async throws -> LLMWikiOpsResult {
        let stats = try await runDerivation(store: store)
        let findings = try await runLint(store: store)
        return LLMWikiOpsResult(
            ranAt: Date(),
            stats: stats,
            lintFindings: findings
        )
    }

    /// v2.9a (boss 2026-09-28 OOB A4): operator one-click
    /// entry point that resolves the active library from
    /// UserDefaults (= wenshu.libraryPath) and runs the full
    /// derivation + lint pipeline. Returns nil if no library
    /// is bound (= the user-facing 'no library' state). Mirrors
    /// the `resolveActiveStore` helper previously duplicated in
    /// LLMWikiTool (= SSOT lifted to LLMWikiOps so the toolbar
    /// button + the LLM tool path share one source).
    static func runAllFromActiveLibrary() async throws -> LLMWikiOpsResult? {
        guard let path = UserDefaults.standard.string(forKey: "wenshu.libraryPath"),
              !path.isEmpty else { return nil }
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let store = FileSystemReferenceStore(referenceLibraryRoot: url)
        return try await runAll(store: store)
    }

    /// Read the cached last result (= callers render the
    /// library-health dashboard without re-running the derivation).
    static func lastResult() -> LLMWikiOpsResult? {
        return lastResultValue
    }
}

/// LLM Wiki run result (= DerivationStats + optional LintFindings).
struct LLMWikiOpsResult: Sendable {
    let ranAt: Date
    let stats: LLMWikiLayerDeriver.DerivationStats?
    let lintFindings: [LLMWikiLinter.LintFinding]?
}