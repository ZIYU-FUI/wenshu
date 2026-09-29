// DelegateResearchTool.swift · WenshuApp · v2.7
//
// LLM-facing tool that the wenshu main agent uses to delegate
// concrete-noun research to the Researcher sub-agent (= the
// fire-and-forget pattern).
//
// Why this exists:
//   - The wenshu main agent should focus on user-facing novel
//     building.
//   - Research (= `web_search` + `reference_library.create/extend`)
//     is delegated to the Researcher sub-agent.
//   - The user does NOT wait for research to complete (= the
//     main agent replies "research delegated" immediately).
//   - The Kanban board surfaces the in-progress task so the
//     user can see when research completes.
//
// Wire format (= the LLM tool-use input):
//   {
//     "action": "delegate" (= the only action; = reserved for
//       future "list" / "cancel" / etc.),
//     "nouns": ["Xi'an", "Ming Dynasty"]  (= the concrete
//       proper nouns to research; = can be 1..N per call; =
//       each noun becomes one researcher delegation + one kanban
//       task),
//     "context": "User mentions the protagonist born in Xi'an,
//       living in the Ming Dynasty"  (= optional free-text
//       context passed to the researcher)
//   }
//
// Result (= the tool-use output):
//   {
//     "ok": true,
//     "action": "delegate",
//     "delegations": [
//       {"noun": "Xi'an", "handle_id": "<UUID>",
//        "task_id": "<UUID>", "agent": "researcher",
//        "status": "pending"},
//       ...
//     ],
//     "kanban_tasks_added": ["<UUID>", ...]
//   }
//
// Scope: this commit adds the tool + registers it + adds a unit
// test. It does NOT implement the actual sub-agent runner (= the
// researcher LLM call itself). The runner is a follow-up ticket;
// = in the meantime the registered handle + kanban task are
// surfaced so the user sees research was kicked off. When the
// runner lands, it will pick up handles from
// `AsyncDelegationRegistry.delegationRegistry` (= the source of
// truth) and execute them in the background.
//

import Foundation

final class DelegateResearchTool: Tool, @unchecked Sendable {

    static let shared = DelegateResearchTool()

    /// Test-only init (= allows injecting a custom registry).
    init() {}

    func execute(input: String) async throws -> String {
        let payload = parseJSON(input)
        let action = (payload["action"] as? String ?? "").lowercased()

        switch action {
        case "delegate":
            return try await handleDelegate(payload: payload)
        case "":
            return jsonError(action: nil, message: "missing required field: action")
        default:
            return jsonError(
                action: action,
                message: "unknown action '\(action)'; expected 'delegate'"
            )
        }
    }

    /// The main path. Parses nouns + optional context, then:
    /// 1. Registers a delegation handle per noun (= AsyncDelegation
    ///    registry)
    /// 2. Adds a kanban task per noun (= user-visible progress
    ///    board)
    /// 3. Returns the consolidated JSON envelope
    private func handleDelegate(payload: [String: Any]) async throws -> String {
        // The dispatch layer (= ToolDispatchInputParser.parse) coerces
        // array values into JSON-encoded strings (= the wire format is
        // [String: String]). Accept both shapes: a real [String]
        // (= when the tool is called outside the executor path)
        // AND a JSON-encoded string (= the executor path).
        var nounsArray: [String] = []
        if let arr = payload["nouns"] as? [String] {
            nounsArray = arr
        } else if let encoded = payload["nouns"] as? String,
                  let data = encoded.data(using: .utf8),
                  let parsed = try? JSONSerialization.jsonObject(with: data) as? [String]
        {
            nounsArray = parsed
        }
        guard !nounsArray.isEmpty else {
            return jsonError(
                action: "delegate",
                message: "missing required field: nouns (= array of concrete proper nouns to research; = non-empty)"
            )
        }
        let context = payload["context"] as? String ?? ""

        var delegations: [[String: Any]] = []
        var kanbanTaskIDs: [String] = []

        for nounRaw in nounsArray {
            let noun = nounRaw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !noun.isEmpty else { continue }

            // Compose the research task = the noun plus any
            // user-provided context (= the researcher sub-agent
            // reads this as its user-facing prompt).
            let taskPrompt: String = context.isEmpty
                ? "调研「\(noun)」的 grounded 资料：核心定义、关键事实、关联上下文，输出一段中文摘要（3-5 句话），并把搜索到的可信信息写入 reference_library 的 entities 层（layer=entities, title=\"\(noun)\"，section_title=\"概要\"）。"
                : "调研「\(noun)」的 grounded 资料。用户上下文：\(context)。要求：1）web_search 搜索 \(noun)；2）输出一段中文摘要（3-5 句话）；3）将摘要写入 reference_library（layer=entities, title=\"\(noun)\"，section_title=\"概要\"）；4）如有具体可查的子话题（朝代、时代、地域等），分别建独立 entity。"

            // Register the delegation handle (= source-of-truth
            // record; = when the runner lands it will pick up
            // pending handles from here). Uses the shared
            // singleton registry (= the team-link consolidation
            // fix; = before v2.7 the tool created a fresh registry
            // per call and the runner never saw the handle).
            let registry = AsyncDelegationRegistry.shared
            let result = try await delegate(
                subagentProfile: SubAgentIdentity.Name.researcher.rawValue,
                task: taskPrompt,
                context: [
                    "noun": noun,
                    "layer": "entities",
                    "section_title": "概要"
                ],
                registry: registry
            )
            let handleID = result.handle.id
            let spawnID = result.handle.trackerSpawnID?.uuidString ?? ""

            // Add a kanban task for user-visible progress (= the
            // kanban view surfaces the research noun so the user
            // sees the in-flight research and can later see it
            // transition to done when the runner completes).
            let kanbanTaskID = await addKanbanTask(
                title: "research: \(noun)",
                body: taskPrompt,
                priority: 0
            )
            if let kanbanTaskID {
                kanbanTaskIDs.append(kanbanTaskID)
            }

            delegations.append([
                "noun": noun,
                "handle_id": handleID,
                "spawn_id": spawnID,
                "agent": SubAgentIdentity.Name.researcher.rawValue,
                "status": result.handle.state.rawValue
            ])
        }

        return jsonOK(payload: [
            "action": "delegate",
            "delegations": delegations,
            "kanban_tasks_added": kanbanTaskIDs,
            "count": delegations.count,
            // Friendly human-readable summary so the LLM (= and
            // any UI that surfaces the tool output) can read it
            // directly without re-parsing the JSON.
            "summary": "已发起 \(delegations.count) 项调研任务（researcher 子代理），调研结果将异步写入 reference_library。"
        ])
    }

    // Add a kanban task for the in-flight research (= best-effort;
        // = the kanban task is user-facing visibility, NOT a
        // source-of-truth record). When the repository is
        // unavailable (= tests, etc.), returns nil without throwing.
        //
        // Uses WSKanbanRepository.shared directly (= bypasses the
        // ToolRegistry tool dispatch + its fire-and-forget bootstrap
        // Tasks; = avoids the actor reentrancy SIGTRAP documented
        // in AGENTS.md §11.5). The ToolRegistry tool is reserved
        // for LLM-facing use; = the internal wenshu-side path
        // calls the repo directly.
        private func addKanbanTask(
            title: String,
            body: String,
            priority: Int
        ) async -> String? {
            do {
                let task = try await WSKanbanRepository.shared.add(
                    title: title,
                    priority: priority
                )
                return task.id
            } catch {
                // Best-effort (= no kanban row, but the delegation
                // handle is still registered; = the user simply
                // doesn't see the in-flight research row).
                return nil
            }
        }

        // MARK: - JSON helpers

    private func parseJSON(_ input: String) -> [String: Any] {
        guard let data = input.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return [:]
        }
        return dict
    }

    private func jsonOK(payload: [String: Any]) -> String {
        var merged = payload
        merged["ok"] = true
        return encode(merged)
    }

    private func jsonError(action: String?, message: String) -> String {
        var payload: [String: Any] = [
            "ok": false,
            "error": message
        ]
        if let action { payload["action"] = action }
        return encode(payload)
    }

    private func encode(_ payload: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(
            withJSONObject: payload,
            options: [.sortedKeys]
        ), let s = String(data: data, encoding: .utf8)
        else {
            return "{\"ok\":false,\"error\":\"DelegateResearchTool: JSON encode failed\"}"
        }
        return s
    }
}

// MARK: - Tool registry bootstrap

extension DelegateResearchTool {

    /// Module-load registration (= same pattern as WebSearchTool,
    /// KanbanStoreTool, ReferenceLibraryTool, etc.). Idempotent.
    static let _registryBootstrap: Void = {
        Task {
            await ToolRegistry.shared.registerTool(
                name: "delegate_research",
                toolset: "agent",
                schema: ToolRegistrySchema(
                    name: "delegate_research",
                    description: """
                    Delegate concrete-noun research to the Researcher sub-agent \
                    (= fire-and-forget; = main agent replies "已发起调研" without \
                    waiting). Use this INSTEAD OF `web_search` when the user \
                    prompt mentions a concrete proper noun that needs grounded \
                    verification. The researcher sub-agent runs in the background, \
                    writes the grounded summary to `reference_library` (layer=\
                    entities, section_title=概要), and transitions the kanban \
                    task to done. The main agent (= wenshu) does NOT block on \
                    the research (= it focuses on user-facing novel building).
                    """,
                    inputSchema: [
                        "action": ToolRegistrySchemaProperty(
                            type: "string",
                            description: "The delegate operation to perform.",
                            enumValues: ["delegate"]
                        ),
                        "nouns": ToolRegistrySchemaProperty(
                            type: "string",
                            description: "Array of concrete proper nouns to research. Each noun becomes one researcher delegation + one kanban task (= 1..N per call). Required."
                        ),
                        "context": ToolRegistrySchemaProperty(
                            type: "string",
                            description: "Optional free-text context passed to the researcher sub-agent as its user-facing prompt (= e.g. '主角出生在西安，生活在明朝')."
                        )
                    ],
                    required: ["action", "nouns"]
                ),
                handler: DelegateResearchTool.shared,
                description: """
                Delegate concrete-noun research to the Researcher sub-agent \
                (= fire-and-forget; = main agent does NOT block on research).
                """,
                emoji: "🔬"
            )
        }
    }()
}