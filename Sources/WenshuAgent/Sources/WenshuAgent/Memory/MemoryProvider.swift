// MemoryProvider.swift · Wenshu
//
// MemoryProvider ABC surface: system prompt fragment / prefetch /
// sync / tool schemas / pre-compress checkpoint (= wenshu-side
// implementation of the hermes MemoryProvider concept).
//
// SwiftData-backed persistence uses WSMemoryRepository (@MainActor)
// wrapping the WSMemory @Model.
// (= ToolSchema.normalize +
// memoryProviderToolsEnabled), but DEFER the wenshu-irrelevant
// hermes-side surface (= queue_prefetch for background prefetching +
// recall_status for deterministic indicator rendering + is_available
// for unavailable-state gating + INDICATOR_GLYPH for brand-mark
// customization + RecallStatus dataclass). The deferred items land
// when wenshu adds the corresponding features.
//
// SwiftData-backed persistence uses WSMemoryRepository (@MainActor)
// wrapping the WSMemory @Model; the deleted sqlite3 MemoryStore
// actor was the previous implementation.

import Foundation
import WenshuData

// WSMemoryRepository = @MainActor SwiftData wrapper.
// Future ticket: migrate to WSMemoryProvider via MemoryManaging protocol.

// MARK: - ABC (= hermes MemoryProvider)

/// Plugin-extensible memory provider ABC (= hermes MemoryProvider).
/// Mirrors the hermes surface: get_system_prompt / prefetch /
/// sync / get_tool_schemas / pre_compress_hook.
public protocol MemoryProvider: Sendable {

    /// Plugin slug (= unique identifier for registration).
    var slug: String { get }

    /// Whether this provider should be exposed to the agent
    /// (= hermes memory_provider_tools_enabled gate).
    var isEnabled: Bool { get }

    /// Returns the system-prompt fragment this provider contributes
    /// to the merged system prompt (= hermes get_system_prompt).
    func getSystemPrompt() -> String

    /// Synchronously prefetch relevant context for the upcoming turn
    /// (= hermes prefetch). Returns the prefetched context string
    /// (= merged by MemoryManager before the LLM call).
    func prefetch(forUserMessage message: String) async -> String

    /// Synchronously persist the turn's user + assistant messages
    /// (= hermes sync).
    func sync(userMessage: String, assistantResponse: String) async

    /// Returns the tool schemas this provider exposes to the LLM
    /// (= hermes get_tool_schemas). Default: empty (= no tool surface).
    func getToolSchemas() -> [ToolSchema]

    /// Pre-compress hook: called before the conversation context
    /// gets compressed (= hermes pre_compress hook). Returns the
    /// checkpoint payload that survives the compression.
    /// Default: nil (= provider doesn't need pre-compress checkpointing).
    func preCompressCheckpoint() async -> String?
}

// MARK: - Tool schema (= hermes normalize_tool_schema surface)

/// A tool schema exposed by a memory provider.
/// Mirrors the OpenAI tool format (= {name, description, parameters}).
public struct ToolSchema: Sendable, Hashable {
    public let name: String
    public let description: String
    /// Parameters as JSON Schema (= stored as raw JSON for flexibility).
    public let parametersJSON: String

    public init(name: String, description: String, parametersJSON: String = "{}") {
        self.name = name
        self.description = description
        self.parametersJSON = parametersJSON
    }

    /// Normalize an arbitrary schema (= hermes normalize_tool_schema).
    /// Unwraps an already-wrapped OpenAI tool entry and returns nil
    /// for anything without a resolvable name.
    public static func normalize(_ schema: Any) -> ToolSchema? {
        // Convert to JSON dictionary (= works for both [String: Any]
        // and JSON-string forms).
        let dict: [String: Any]
        if let d = schema as? [String: Any] {
            dict = d
        } else if let s = schema as? String, let data = s.data(using: .utf8),
                  let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            dict = parsed
        } else {
            return nil
        }
        // Unwrap if already wrapped in OpenAI tool form.
        var inner = dict
        if inner["type"] as? String == "function",
           let functionDict = inner["function"] as? [String: Any] {
            inner = functionDict
        }
        // Extract name.
        guard let name = inner["name"] as? String, !name.isEmpty else { return nil }
        let description = inner["description"] as? String ?? ""
        // Serialize parameters back to JSON.
        let paramsDict = inner["parameters"] as? [String: Any] ?? [:]
        let paramsData = (try? JSONSerialization.data(withJSONObject: paramsDict)) ?? Data()
        let paramsJSON = String(data: paramsData, encoding: .utf8) ?? "{}"
        return ToolSchema(name: name, description: description, parametersJSON: paramsJSON)
    }
}
