// SubAgentIdentity.swift
//
// 5 sub-agents under `WenshuConductor`:
//   - Researcher: `web_search` + `reference_library`.
//   - Writer: `paragraph_ai`.
//   - Analyst: (= no wenshu tool counterpart yet; = tool list
//     empty).
//   - Archivist: (= storage via the per-book archive dir + filesystem
//     directly; = tool list empty).
// - Auditor: (read memory via WSMemoryProvider directly; = tool list empty)
//
// The vocabulary (= the slug every call site passes around) lives here;
// the FACTS of a role (= label, prompt, tool list, dispatch) live in
// one table: `SubAgentRoleRegistry`. This file reads that table.
//

/// 5 sub-agent identities, each a domain expert dispatched by WenshuConductor.
public enum SubAgentIdentity {
    /// Sub-agent name enum. String rawValue used for intent classify and dispatch.
    public enum Name: String, CaseIterable, Sendable {
        case researcher
        case writer
        case analyst
        case archivist
        case auditor
    }

    /// Per-sub-agent system prompt. Prepended to sub-agent LLM call (independent context).
    public static func systemPrompt(name: Name) -> String {
        SubAgentRoleRegistry.requiredRole(forSlug: name.rawValue).systemPrompt
    }

    /// Per-sub-agent tool list (= the wenshu-side tool names; = NOT
    /// the hermes port slug). Forwarded to `ToolRegistry.getDefinitions`
    /// (= the LLM-facing schema) and `ToolRegistry.getHandler` (= the
    /// dispatch path). Each tool name MUST match a real wenshu tool
    /// registered in `ToolRegistry.shared` (= hermes
    /// DELEGATE_BLOCKED_TOOLS parity; = tools not in this list are
    /// blocked by `delegate(...)`).
    ///
    /// The list and the reason each role has it live in the role table
    /// (= `SubAgentRoleRegistry`); this function reads that table.
    static func tools(name: Name) -> [String] {
        SubAgentRoleRegistry.requiredRole(forSlug: name.rawValue).toolNames
    }

    /// User-facing display name (Chinese for ChatView debug / future UI).
    static func displayName(name: Name) -> String {
        SubAgentRoleRegistry.requiredRole(forSlug: name.rawValue).displayLabel
    }
}
