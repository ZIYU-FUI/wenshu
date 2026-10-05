// LLMWikiOps.swift
//
// LLM Wiki pipeline unified ops (= the manual + auto facade per
// the core-capability directive: research-to-document pipeline =
// wenshu's central capability, must be complete end to end).
//
// Per the pipeline-must-be-complete directive: the LLM Wiki
// pipeline (= `LLMWikiLayerDeriver` + `LLMWikiLinter`) was dead
// code per §11 baseline (= zero callers). Wiring covers:
//   1. Manual tool-call (= LLM invokes the `llm_wiki` tool).
//   2. Auto-call (= the agent's `ConversationLoop` / a new
//      raw-reference auto-derive hook runs the derivation).
//   3. UI trigger (= the reference-library inspector's
//      'Re-derive wiki' button for the operator).
//
// All three surfaces go through these 4 entry points (= the
// unified manual + auto facade per the §11.3 wenshu-side wins
// principle: the pipeline must complete end to end).
//
// Standards axis (= S1 + S3 + S4 + S5):
//   S1 (Apple-API-first): the `LLMWikiLayerDeriver` +
//       `LLMWikiLinter` (= pure-data deterministic derivation; =
//       no LLM call) are the source of truth; `LLMWikiOps` is a
//       thin `@MainActor` facade that delegates to them.
//   S3 (single source of truth): one set of 4 entry points
//       serves manual + auto callers.
//   S4 (typed errors): `DerivationStats` + `LintReport` capture
//       the result (= callers can render the library-health
//       surface without re-running the derivation).
//   S5 (no public surface): zero new public keywords.

import Foundation

/// LLM Wiki pipeline unified facade (= manual + auto go through
/// these 4 entry points per the pipeline-must-be-complete
/// directive).
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
    /// 'Re-derive wiki' workflow per the (see OOB.md) B10).
    static func runAll(store: ReferenceStoring) async throws -> LLMWikiOpsResult {
        let stats = try await runDerivation(store: store)
        let findings = try await runLint(store: store)
        return LLMWikiOpsResult(
            ranAt: Date(),
            stats: stats,
            lintFindings: findings
        )
    }

    /// v2.9a: operator one-click entry point that resolves the
    /// active library from `ActiveLibrary` (= the security-scoped
    /// bookmark; = canonical single source of truth for the .ws
    /// bundle URL) and runs the full derivation + lint pipeline.
    /// Returns nil if no library is bound (= the user-facing 'no
    /// library' state). Mirrors the `resolveActiveStore` helper
    /// previously duplicated in `LLMWikiTool` (= SSOT lifted to
    /// `LLMWikiOps` so the toolbar button + the LLM tool path share
    /// one source).
    static func runAllFromActiveLibrary() async throws -> LLMWikiOpsResult? {
        guard let path = ActiveLibrary.path,
              !path.isEmpty else { return nil }
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        // Per boss 2026-10-05 OOB ' 8': the FileSystemReferenceStore
        // struct is @MainActor-isolated (= SwiftData's ModelContext
        // contract); = actor-based callers can't instantiate it
        // directly. Hop to the main actor to grab a SwiftData-backed
        // instance (= the production path); = falls back to the
        // FileSystem path if no ModelContainer is wired (dev tools
        // + tests).
        let store: any ReferenceStoring = await MainActor.run {
            FileSystemReferenceStore(
                referenceLibraryRoot: url,
                modelContainer: WSPersistenceContainer.shared
            )
        }
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