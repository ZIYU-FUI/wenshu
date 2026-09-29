// BackgroundReviewTool.swift · WenshuApp · v2.8c
//
// LLM-facing tool that lets the agent submit background-review
// proposals (= the auto-call surface per the auto+manual
// consolidation stance).
//
// Per the consolidation: manual + auto callers go through
// `BackgroundReviewOps` (= the unified facade). This tool is the
// auto-call surface; manual callers (= the operator in the
// inspector tab) call `BackgroundReviewOps` directly.
//
// Why this exists:
//   - `BackgroundReview` actor (= declared in v0.36) had zero
//     callers (= dead actor per §11 baseline).
//   - The inspector's BackgroundReview tab was unused.
//   - The agent's auto-call hook was missing.
//   - ONE unified surface was the chosen design (= this tool +
//     the manual tab + the agent's `ConversationLoop` auto-call
//     hook all go through `BackgroundReviewOps`).
//
// Wire format (= the LLM tool-use input):
//   {
//     "action": "submit" (= the only action for the MVP;
//     "list" / "approve" / "reject" are follow-up tickets),
//     "kind": "<ProposalKind rawValue>",
//     "summary": "<one-line proposal summary>",
//     "details": "<optional free-text details>"
//   }
//
// Result (= the tool-use output):
//   {
//     "ok": true,
//     "action": "submit",
//     "proposal_id": "<UUID>"
//   }
//
// Scope: this commit adds the tool + registers it. It does NOT
// add the inspector tab UI (= follow-up ticket). It does NOT add
// the agent's auto-call hook into `ConversationLoop` (= separate
// ticket that wires `ConversationLoop` ->
// `BackgroundReviewOps.submit`; the current surface only adds
// the LLM-call entry point so the agent can explicitly invoke
// the tool).

import Foundation

final class BackgroundReviewTool: Tool, @unchecked Sendable {

    static let shared = BackgroundReviewTool()

    init() {}

    func execute(input: String) async throws -> String {
        guard let data = input.data(using: .utf8) else {
            return "{\"ok\":false,\"error\":\"BackgroundReviewTool: input is not UTF-8\"}"
        }
        guard let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return "{\"ok\":false,\"error\":\"BackgroundReviewTool: input is not a JSON object\"}"
        }
        let action = parsed["action"] as? String ?? ""
        switch action {
        case "submit":
            let kindRaw = parsed["kind"] as? String ?? ProposalKind.other.rawValue
            let summary = parsed["summary"] as? String ?? ""
            let details = parsed["details"] as? String
            let kind = ProposalKind(rawValue: kindRaw) ?? .other
            let proposal = BackgroundProposal(
                kind: kind,
                title: summary,
                description: details ?? "",
                proposedChanges: []
            )
            await BackgroundReviewOps.submit(proposal)
            let response: [String: Any] = [
                "ok": true,
                "action": "submit",
                "proposal_id": proposal.id.uuidString
            ]
            guard let outData = try? JSONSerialization.data(withJSONObject: response),
                  let s = String(data: outData, encoding: .utf8) else {
                return "{\"ok\":false,\"error\":\"BackgroundReviewTool: JSON encode failed\"}"
            }
            return s
        case "list":
            let pending = await BackgroundReviewOps.listPending()
            let response: [String: Any] = [
                "ok": true,
                "action": "list",
                "pending": pending.map { proposal in
                    [
                        "id": proposal.id.uuidString,
                        "kind": proposal.kind.rawValue,
                        "title": proposal.title,
                        "submitted_at": ISO8601DateFormatter().string(from: proposal.submittedAt)
                    ]
                }
            ]
            guard let outData = try? JSONSerialization.data(withJSONObject: response),
                  let s = String(data: outData, encoding: .utf8) else {
                return "{\"ok\":false,\"error\":\"BackgroundReviewTool: JSON encode failed\"}"
            }
            return s
        default:
            return "{\"ok\":false,\"error\":\"BackgroundReviewTool: unsupported action '\(action)'\"}"
        }
    }
}

// MARK: - Tool registry bootstrap

extension BackgroundReviewTool {

    /// Module-load registration (= same pattern as
    /// DelegateResearchTool, WebSearchTool, KanbanStoreTool,
    /// ReferenceLibraryTool, etc.). Idempotent.
    static let _registryBootstrap: Void = {
        Task {
            await ToolRegistry.shared.registerTool(
                name: "background_review",
                toolset: "agent",
                schema: ToolRegistrySchema(
                    name: "background_review",
                    description: """
                    Submit or list background-review proposals (= the
                    boss-pinned v2.8c consolidation per 2026-09-28
                    OOB B8: manual + auto callers both go through
                    BackgroundReviewOps). The agent uses this tool
                    to submit proposals (= auto surface); the
                    operator uses the inspector tab to approve /
                    reject (= manual surface).
                    """,
                    inputSchema: [
                        "action": ToolRegistrySchemaProperty(
                            type: "string",
                            description: "The operation to perform.",
                            enumValues: ["submit", "list"]
                        ),
                        "kind": ToolRegistrySchemaProperty(
                            type: "string",
                            description: "The proposal kind (= ProposalKind rawValue; required for action='submit')."
                        ),
                        "summary": ToolRegistrySchemaProperty(
                            type: "string",
                            description: "One-line proposal summary (= required for action='submit')."
                        ),
                        "details": ToolRegistrySchemaProperty(
                            type: "string",
                            description: "Optional free-text proposal details."
                        )
                    ],
                    required: ["action"]
                ),
                handler: BackgroundReviewTool.shared,
                description: """
                Background review consolidation surface (= manual + auto).
                """,
                emoji: "📋"
            )
        }
    }()
}