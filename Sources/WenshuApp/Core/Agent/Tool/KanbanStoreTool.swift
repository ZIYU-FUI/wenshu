//
//  KanbanStoreTool.swift · Wenshu · P0 #5 (WIRE-AGENT-005, 2026-09-04)
//
//  Thin adapter exposing the kanban LLM surface (= KanbanTools actor,
//  ported from hermes kanban_tools.py) through the canonical Tool
//  protocol so the WenshuConductor.tool registry can dispatch
//  tool_use blocks to it. Lets the LLM agent create / list / show /
//  transition / block / unblock / complete kanban tickets directly
//  from the chat surface (= one Tool entry-point registered with
//  WenshuConductor.tools in ChatView).
//
//  Why an adapter (instead of using KanbanTools directly)?
//
//    KanbanTools is an `actor` (= serialized mutation surface) with a
//    `kanban(action:params:)` method that accepts a typed
//    `KanbanParams` struct. The Tool protocol mandates
//    `execute(input: String) async throws -> String` (= the chat
//    surface contract; matches the LLM tool_use block shape). This
//    adapter bridges the two:
//
//      LLM tool_use JSON  ->  ToolInputParser (S3 single source of truth)
//                          ->  KanbanTools.kanban(action:params:)
//                          ->  KanbanStore (= wenshu-side canonical, written
//                             by KanbanTools itself; per the existing
//                             HERMES-PARTIAL-011 architecture the
//                             wenshu-side KanbanStore IS the canonical
//                             task store; KanbanTools is the action
//                             dispatcher that mutates it)
//
//    Per boss wenshu-side-wins pattern (= KanbanTools.swift header
//    line 9-10), KanbanTools already routes every action through
//    the canonical wenshu-side KanbanStore. This adapter is the
//    Tool-protocol-facing entry point (= JSON in, JSON out) that
//    lets the LLM hit that surface without a code change to
//    KanbanTools itself.
//
//  Action surface (= single input field `action`):
//
//    kanban_create    {action:"create", title, body?, priority?}
//    kanban_list      {action:"list", status?, limit?}
//    kanban_show      {action:"show", task_id}
//    kanban_complete  {action:"complete", task_id}
//    kanban_block     {action:"block", task_id, reason?}
//    kanban_unblock   {action:"unblock", task_id}
//    kanban_transition{action:"transition", task_id, new_status}
//
//  Empty / unknown action = `kanban_list` (mirrors HermesTodoTool /
//  TodoStoreTool's "empty input == read" convention).
//
//  Output: JSON `{ ok: true, action, data, summary }` (= LLM can
//  see what was written). On error: JSON `{ ok: false, action,
//  error }` (= does not throw; per ToolExecutorError policy the
//  LLM gets a string it can react to, not a thrown exception).
//
//  Standards-axis S3 (= single source of truth for tool input JSON):
//  tool input parsing goes through ToolInputParser (same as
//  HermesTodoTool / TodoStoreTool / ReadFileTool / WriteFileTool /
//  ParagraphAITool).
//
//  Standards-axis S4 (= no new third-party deps): pure Foundation +
//  the existing WenshuApp module surface (KanbanTools actor +
//  ToolInputParser + KanbanStore). No SQLite import here.
//
//

import Foundation

public struct KanbanStoreTool: Tool, Sendable {

    /// Tool name. ToolExecutor routes one tool_use block to one Tool
    /// by name (= matches the convention other wenshu tools use:
    /// "ParagraphAI", "todo", "ReadFile", "WriteFile"; for kanban
    /// we use the bare noun "kanban" because that's the verb the LLM
    /// writes in its `kanban_create` / `kanban_list` calls and
    /// matches the wenshu-kanban user-facing surface name).
    public let name = "kanban"

    /// Human-readable description (baked into the tool schema at
    /// prompt-build time so the LLM sees it cached as static context).
    public let description = """
    Manage Kanban tickets in the current book. Actions: create / \
    list / show / complete / block / unblock / transition. Each \
    action mirrors the canonical wenshu-side KanbanStore (= SQLite, \
    user-facing in the OpenBox zone). Use list to read; create to \
    add; show to fetch one; complete to mark done; block / unblock \
    to toggle blocked status; transition to move between explicit \
    states (new / triage / ready / running / blocked / review / done \
    / failed).
    """

    private let kanbanTools: KanbanTools

    public init(kanbanTools: KanbanTools) {
        self.kanbanTools = kanbanTools
    }

    // MARK: - Tool conformance

    public func execute(input: String) async throws -> String {
        // Step 1: parse input via the single-source-of-truth parser
        // (= S3 parity with TodoStoreTool / ReadFileTool / etc.).
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let parsed: [String: Any]
        if trimmed.isEmpty {
            parsed = [:]
        } else {
            do {
                parsed = try ToolInputParser.parseDictionary(input: input)
            } catch {
                return Self.jsonError(action: nil, message: "invalid input: \(error)")
            }
        }

        // Step 2: extract action (default = list = matches the empty-
        // input-read convention TodoStoreTool uses).
        let action = (parsed["action"] as? String ?? "list").lowercased()

        // Step 3: dispatch to the LLM-facing KanbanTools actor.
        let params = Self.buildParams(parsed: parsed)
        let result = await kanbanTools.kanban(action: action, params: params)

        // Step 4: surface the result as a JSON envelope the LLM can
        // react to. KanbanTools.kanban returns its own shape
        // (= KanbanToolResult with `success`, `output`, `data`); we
        // forward to the wenshu envelope convention used by
        // TodoStoreTool for consistency.
        if result.success {
            return Self.jsonOk(action: action, summary: result.output, data: result.data)
        } else {
            return Self.jsonError(action: action, message: result.output)
        }
    }

    // MARK: - Param mapping (parsed dict -> KanbanParams)

    /// Translate the LLM-supplied JSON dictionary into a typed
    /// `KanbanParams`. Field names follow the wenshu-kanban
    /// convention (= task_id, new_status) and also accept the bare
    /// hermes aliases (= id, status) so prompts written for the
    /// hermes-python tool work unchanged.
    private static func buildParams(parsed: [String: Any]) -> KanbanTools.KanbanParams {
        // task_id / id (hermes uses bare `id`; wenshu uses `task_id`).
        let taskId: String? = (parsed["task_id"] as? String) ?? (parsed["id"] as? String)

        // title (only create)
        let title = parsed["title"] as? String
        // body (create + comment share this in hermes; for our
        // create we pass it through but the wenshu KanbanStore does
        // not store body -- it preserves forward compatibility with
        // a future body column).
        let body = parsed["body"] as? String
        // status (list filter) -- accepts "running" / "ready" / etc.
        let status = parsed["status"] as? String
        // assignee
        let assignee = parsed["assignee"] as? String
        // priority (Int? from JSON number or numeric string)
        let priority = Self.parseInt(parsed["priority"])
        // model override (hermes parity; not stored in wenshu yet)
        let modelOverride = parsed["model_override"] as? String
        // comment body (for action=comment; not exposed in the
        // LLM-facing action set here, but accepted for forward
        // compatibility).
        let comment = parsed["comment"] as? String
        // reason (for action=block; descriptive text stored in the
        // tool output, not the SQLite row).
        let reason = parsed["reason"] as? String
        // limit (list cap)
        let limit = Self.parseInt(parsed["limit"])
        // include_archived (list filter; accepted but wenshu does
        // not have an archive surface yet, so the field is reserved).
        let includeArchived: Bool? = {
            if let b = parsed["include_archived"] as? Bool { return b }
            if let s = parsed["include_archived"] as? String { return (s as NSString).boolValue }
            return nil
        }()
        // parent_id / child_id (link; not in the LLM-facing set
        // here but accepted for forward compatibility).
        let parentId = parsed["parent_id"] as? String
        let childId = parsed["child_id"] as? String
        // new_status (transition target). Accept both "new_status"
        // and bare "status" when the action is transition (action
        // routing in the caller is already done).
        let newStatus: String? = {
            if let s = parsed["new_status"] as? String { return s }
            // Only fall back to "status" when the LLM is explicitly
            // invoking a status-mutating action (= complete / block
            // / unblock / transition have their own status slots in
            // KanbanParams; we forward the user's status to whichever
            // slot the dispatcher expects). For now, just forward
            // the parsed value -- the KanbanTools dispatcher uses
            // taskId alone for complete / block / unblock and
            // newStatus for transition, so a bare "status" without
            // a new_status alias falls through safely.
            return parsed["status"] as? String
        }()
        // tenant (multi-profile isolation; hermes-only field,
        // accepted for forward compat).
        let tenant = parsed["tenant"] as? String

        return KanbanTools.KanbanParams(
            taskId: taskId,
            title: title,
            body: body,
            status: status,
            assignee: assignee,
            tenant: tenant,
            priority: priority,
            modelOverride: modelOverride,
            comment: comment,
            reason: reason,
            limit: limit,
            includeArchived: includeArchived,
            parentId: parentId,
            childId: childId,
            newStatus: newStatus
        )
    }

    private static func parseInt(_ raw: Any?) -> Int? {
        if let i = raw as? Int { return i }
        if let d = raw as? Double { return Int(d) }
        if let s = raw as? String, let i = Int(s) { return i }
        return nil
    }

    // MARK: - JSON envelope helpers

    private static func jsonOk(action: String, summary: String, data: [String: String]) -> String {
        // Surface the KanbanTools result data in the wenshu envelope
        // (= the LLM sees `summary` for human reading + `data` for
        // programmatic follow-up, e.g. picking up a created
        // task_id to reference in a follow-up tool call).
        var payload: [String: Any] = [
            "ok": true,
            "action": action,
            "summary": summary
        ]
        if !data.isEmpty {
            payload["data"] = data
        }
        return jsonString(payload)
    }

    private static func jsonError(action: String?, message: String) -> String {
        var payload: [String: Any] = ["ok": false, "error": message]
        if let a = action { payload["action"] = a }
        return jsonString(payload)
    }

    private static func jsonString(_ payload: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(
            withJSONObject: payload,
            options: [.sortedKeys]
        ) else {
            return "{\"ok\":false,\"error\":\"internal: failed to encode envelope\"}"
        }
        return String(data: data, encoding: .utf8) ?? "{\"ok\":false,\"error\":\"internal: non-utf8 envelope\"}"
    }
}
