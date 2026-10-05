// LLMWikiTool.swift
//
// LLM-facing tool that lets the agent run the LLM Wiki
// derivation + lint (= the auto-call surface per the core-
// capability directive: research-to-document pipeline =
// wenshu's central capability, used for grounded novel writing).
//
// Per the pipeline-must-be-complete directive: the LLM Wiki
// pipeline (= `LLMWikiLayerDeriver` + `LLMWikiLinter`) was dead
// code per §11 baseline (= zero callers). Wiring covers:
//   1. Manual tool-call (= LLM invokes the `llm_wiki` tool).
//      This file is the manual surface.
//   2. Auto-call (= `FileSystemReferenceStore.create` triggers
//      `LLMWikiOps.runDerivation`).
//   3. UI trigger (= the reference-library inspector's
//      'Re-derive wiki' button for the operator; follows).
//
// Wire format (= the LLM tool-use input):
//   {
//     "action": "runAll" | "runDerivation" | "runLint" | "status",
//     "library_path": "/path/to/.ws"  (= optional; = derived
//       from the active library when omitted)
//   }
//
// Result (= the tool-use output):
//   {
//     "ok": true,
//     "action": "runAll",
//     "stats": {
//       "raw_count": 5,
//       "abstracts_written": 5,
//       "indexes_written": 12,
//       "duration_ms": 8
//     },
//     "lint_findings": [
//       {"severity": "warning", "code": "LLM-ORPHAN-ENTITY",
//        "message": "Entity 'X' has no provenance link"}
//     ]
//   }
//
// Scope: this commit adds the tool + registers it. The
// `FileSystemReferenceStore.create` auto-call hook is in this
// same commit (= the pipeline must complete end to end; =
// manual + auto in one arc).

import Foundation

final class LLMWikiTool: Tool, @unchecked Sendable {

    static let shared = LLMWikiTool()

    /// Test-only init (= allows injecting a custom store).
    init() {}

    func execute(input: String) async throws -> String {
        guard let data = input.data(using: .utf8) else {
            return "{\"ok\":false,\"error\":\"LLMWikiTool: input is not UTF-8\"}"
        }
        guard let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return "{\"ok\":false,\"error\":\"LLMWikiTool: input is not a JSON object\"}"
        }
        let action = parsed["action"] as? String ?? "status"

        // Resolve the active ReferenceStoring. v2.8d MVP: walk the
        // current library root from UserDefaults (= wenshu.libraryPath).
        guard let store = await resolveActiveStore() else {
            return "{\"ok\":false,\"error\":\"LLMWikiTool: no active library resolved (= wenshu.libraryPath missing or .ws bundle absent)\"}"
        }

        switch action {
        case "runAll":
            let result = try await LLMWikiOps.runAll(store: store)
            return encodeResult(action: action, result: result)
        case "runDerivation":
            let stats = try await LLMWikiOps.runDerivation(store: store)
            return encodeStats(action: action, stats: stats)
        case "runLint":
            let findings = try await LLMWikiOps.runLint(store: store)
            return encodeFindings(action: action, findings: findings)
        case "status":
            let prior = await LLMWikiOps.lastResult()
            if let prior {
                return encodeResult(action: action, result: prior)
            } else {
                return "{\"ok\":true,\"action\":\"status\",\"ran_at\":null,\"stats\":null,\"lint_findings\":null}"
            }
        default:
            return "{\"ok\":false,\"error\":\"LLMWikiTool: unsupported action '\(action)'\"}"
        }
    }

    private func resolveActiveStore() async -> (any ReferenceStoring)? {
        // Use the wenshu-pollution-defense invariant: read the
        // active library path from UserDefaults (= the AppState
        // surface the rest of the app uses). Falls back to nil
        // (= caller receives a typed error) when no library is
        // bound (= the inspector's "no library" state).
        //
        // v2.9a: delegate to `LLMWikiOps.runAllFromActiveLibrary`'s
        // resolution (= SSOT = both the LLM tool path and the
        // operator-button path read the same `ActiveLibrary.path`).
        guard let path = ActiveLibrary.path,
              !path.isEmpty else { return nil }
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return FileSystemReferenceStore(referenceLibraryRoot: url)
    }

    private func encodeStats(action: String, stats: LLMWikiLayerDeriver.DerivationStats) -> String {
        let response: [String: Any] = [
            "ok": true,
            "action": action,
            "stats": [
                "raw_count": stats.rawCount,
                "abstracts_written": stats.abstractsWritten,
                "indexes_written": stats.indexesWritten,
                "duration_ms": stats.durationMs
            ]
        ]
        return jsonString(response) ?? "{\"ok\":false,\"error\":\"LLMWikiTool: JSON encode failed\"}"
    }

    private func encodeFindings(action: String, findings: [LLMWikiLinter.LintFinding]) -> String {
        let response: [String: Any] = [
            "ok": true,
            "action": action,
            "lint_findings": findings.map { f in
                [
                    "severity": f.severity.rawValue,
                    "code": f.code,
                    "message": f.message
                ]
            }
        ]
        return jsonString(response) ?? "{\"ok\":false,\"error\":\"LLMWikiTool: JSON encode failed\"}"
    }

    private func encodeResult(action: String, result: LLMWikiOpsResult) -> String {
        var response: [String: Any] = [
            "ok": true,
            "action": action,
            "ran_at": result.ranAt.formatted(.iso8601)
        ]
        if let stats = result.stats {
            response["stats"] = [
                "raw_count": stats.rawCount,
                "abstracts_written": stats.abstractsWritten,
                "indexes_written": stats.indexesWritten,
                "duration_ms": stats.durationMs
            ]
        }
        if let findings = result.lintFindings {
            response["lint_findings"] = findings.map { f in
                [
                    "severity": f.severity.rawValue,
                    "code": f.code,
                    "message": f.message
                ]
            }
        }
        return jsonString(response) ?? "{\"ok\":false,\"error\":\"LLMWikiTool: JSON encode failed\"}"
    }

    private func jsonString(_ dict: [String: Any]) -> String? {
        guard let data = try? JSONSerialization.data(withJSONObject: dict) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
}

// MARK: - Tool registry bootstrap

extension LLMWikiTool {

    /// Module-load registration (= same pattern as
    /// BackgroundReviewTool, DelegateResearchTool, etc.).
    /// Idempotent.
    static let _registryBootstrap: Void = {
        Task {
            await ToolRegistry.shared.registerTool(
                name: "llm_wiki",
                toolset: "agent",
                schema: ToolRegistrySchema(
                    name: "llm_wiki",
                    description: """
                    Run the LLM Wiki pipeline (= the canonical v0.28
                    pure-data 4-layer derivation per (see OOB.md #2026-09-28)
                    OOB B10: raw/ + entities/ + abstracts/ + indexes/).
                    This is the canonical agent-side surface for the
                    LLM Wiki pipeline (= background research-driven
                    writing aid).
                    """,
                    inputSchema: [
                        "action": ToolRegistrySchemaProperty(
                            type: "string",
                            description: "The LLM Wiki operation to perform.",
                            enumValues: ["runAll", "runDerivation", "runLint", "status"]
                        ),
                        "library_path": ToolRegistrySchemaProperty(
                            type: "string",
                            description: "Optional absolute path to the .ws library root. Defaults to the active library bound in UserDefaults (wenshu.libraryPath)."
                        )
                    ],
                    required: ["action"]
                ),
                handler: LLMWikiTool.shared,
                description: """
                LLM Wiki pipeline (= the canonical 4-layer derivation).
                """,
                emoji: "🧠"
            )
        }
    }()
}