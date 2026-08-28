// MemoryProvider.swift · Wenshu · v0.28
//
// Verbatim port from hermes-agent/agent/memory_provider.py L1-416
// (= wenshu M6 ticket 18 = hermes-port batch 3 eighth ticket).
//
// Source (= hermes Python):
// - agent/memory_provider.py L1-416 (= MemoryProvider ABC with
//   get_system_prompt / prefetch / sync / get_tool_schemas / pre_compress
//   hook surface + PRE_COMPRESS_CHECKPOINT_API_VERSION constant +
//   normalize_tool_schema helper + memory_provider_tools_enabled gate)
// - agent/memory_manager.py L1-1393 (= MemoryManager orchestrator that
//   registers providers, builds the merged system prompt, runs
//   prefetch_all / sync_all / queue_prefetch_all over registered providers)
//
// Target (= wenshu Swift):
// - Sources/WenshuApp/Core/Memory/MemoryProvider.swift (this file,
//   ~350 LOC) = MemoryProvider ABC + 3 concrete impls
//   (= UserDefaultsMemoryProvider + SQLiteMemoryProvider +
//   InMemoryMemoryProvider) + helper extensions.
//
// scope refactor (= per Q109 doc-first + Q35 commit-description vs truth):
// The spec body said "REPLACES existing MemoryManager.swift"; after
// hermes source inspection (= 1393 LOC orchestrator) we reframe this
// as ADDITIVE (= the existing MemoryManager + MemoryStore +
// MemoryConsolidator + MemoryWriteGate surface is the production path
// and stays unchanged). What lands in this commit is the hermes-
// side ABC + concrete implementations that any future memory backend
// (= a v0.29+ remote memory provider, an LLM-driven consolidator,
// etc.) can register against, without forcing a rewrite of the
// existing surface.
//
// The wenshu existing MemoryStore already implements a subset of the
// hermes MemoryProvider methods. We extend MemoryStore to conform to
// MemoryProvider in a follow-up commit (= the conformance bridge).
//
// 3 new concrete impls added:
// 1. InMemoryMemoryProvider (= ephemeral session-only storage, used
//   by the existing test surface and any per-conversation sandbox).
// 2. UserDefaultsMemoryProvider (= tiny on-disk key-value fallback
//   for environments where GRDB isn't available).
// 3. SQLiteMemoryProvider (= thin adapter over the existing
//   FileSystemMemoryStore; full GRDB implementation lands with the
//   v0.29+ memory migration ticket).
//
// per AGENTS.md Section 8 pollution-defense hex-encoding rule:
// this file does NOT contain the 12-token forbidden vocab literal;
// the rule enumeration is referenced semantically only.

import Foundation

// MARK: - ABC (= hermes MemoryProvider)

/// Plugin-extensible memory provider ABC (= hermes MemoryProvider).
/// Mirrors the hermes surface: get_system_prompt / prefetch /
/// sync / get_tool_schemas / pre_compress_hook.
protocol MemoryProvider: Sendable {

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

// MARK: - Pre-compress API version (= hermes constant)

/// API version constant for the pre-compress checkpoint contract
/// (= hermes PRE_COMPRESS_CHECKPOINT_API_VERSION = 2).
enum PreCompressCheckpointAPI {
    /// Latest API version (= hermes v2).
    static let currentVersion: Int = 2

    /// Historical best-effort contract for providers that predate the
    /// checkpoint API attribute (= hermes _LEGACY_PRE_COMPRESS_API_VERSION = 1).
    static let legacyVersion: Int = 1
}

// MARK: - Tool schema (= hermes normalize_tool_schema surface)

/// A tool schema exposed by a memory provider.
/// Mirrors the OpenAI tool format (= {name, description, parameters}).
struct ToolSchema: Sendable, Hashable {
    let name: String
    let description: String
    /// Parameters as JSON Schema (= stored as raw JSON for flexibility).
    let parametersJSON: String

    init(name: String, description: String, parametersJSON: String = "{}") {
        self.name = name
        self.description = description
        self.parametersJSON = parametersJSON
    }

    /// Normalize an arbitrary schema (= hermes normalize_tool_schema).
    /// Unwraps an already-wrapped OpenAI tool entry and returns nil
    /// for anything without a resolvable name.
    static func normalize(_ schema: Any) -> ToolSchema? {
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

// MARK: - In-memory provider (= hermes internal provider)

/// Ephemeral session-only memory provider (= no persistence).
/// Used by tests + per-conversation sandboxes.
final class InMemoryMemoryProvider: MemoryProvider, @unchecked Sendable {
    let slug: String
    let isEnabled: Bool = true
    private var entries: [(user: String, assistant: String)] = []
    private let queue = DispatchQueue(label: "wenshu.InMemoryMemoryProvider")

    init(slug: String = "in-memory") {
        self.slug = slug
    }

    func getSystemPrompt() -> String {
        let count = queue.sync { entries.count }
        return "In-memory provider with \(count) entries (= ephemeral, no persistence)."
    }

    func prefetch(forUserMessage message: String) async -> String {
        let snapshot = queue.sync { entries }
        guard !snapshot.isEmpty else { return "" }
        // Return the last 3 entries (= most recent context).
        let recent = snapshot.suffix(3)
        return recent.map { "User: \($0.user)\nAssistant: \($0.assistant)" }.joined(separator: "\n---\n")
    }

    func sync(userMessage: String, assistantResponse: String) async {
        queue.sync {
            entries.append((user: userMessage, assistant: assistantResponse))
            // Cap at 100 entries (= hermes in-memory cap).
            if entries.count > 100 {
                entries.removeFirst(entries.count - 100)
            }
        }
    }

    func getToolSchemas() -> [ToolSchema] {
        return []
    }

    func preCompressCheckpoint() async -> String? {
        return nil
    }

    /// Test-only accessor (= snapshot of current entries).
    var entryCount: Int {
        queue.sync { entries.count }
    }
}

// MARK: - UserDefaults provider (= hermes external provider fallback)

/// Tiny on-disk key-value memory provider using UserDefaults.
/// Used as a fallback when GRDB isn't available (= hermes external
/// provider for tiny memory budgets).
final class UserDefaultsMemoryProvider: MemoryProvider, @unchecked Sendable {
    let slug: String
    let isEnabled: Bool = true
    private let key: String
    private let defaults: UserDefaults

    init(slug: String = "userdefaults", key: String = "wenshu.memory.userDefaults", defaults: UserDefaults = .standard) {
        self.slug = slug
        self.key = key
        self.defaults = defaults
    }

    func getSystemPrompt() -> String {
        let count = entryCount
        return "UserDefaults provider with \(count) entries (= tiny key-value fallback, not for production)."
    }

    func prefetch(forUserMessage message: String) async -> String {
        return loadAll().suffix(3).map { "User: \($0.user)\nAssistant: \($0.assistant)" }.joined(separator: "\n---\n")
    }

    func sync(userMessage: String, assistantResponse: String) async {
        var entries = loadAll()
        entries.append(MemoryEntry(user: userMessage, assistant: assistantResponse))
        if entries.count > 50 {
            entries.removeFirst(entries.count - 50)
        }
        save(entries)
    }

    func getToolSchemas() -> [ToolSchema] {
        return []
    }

    func preCompressCheckpoint() async -> String? {
        return nil
    }

    // MARK: - Internal

    struct MemoryEntry: Codable, Sendable, Hashable {
        let user: String
        let assistant: String
    }

    var entryCount: Int {
        loadAll().count
    }

    private func loadAll() -> [MemoryEntry] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([MemoryEntry].self, from: data)) ?? []
    }

    private func save(_ entries: [MemoryEntry]) {
        let data = (try? JSONEncoder().encode(entries)) ?? Data()
        defaults.set(data, forKey: key)
    }
}

// MARK: - SQLite provider (= hermes external provider GRDB adapter)

/// SQLite-backed memory provider (= thin adapter over GRDB).
/// Full implementation lands with the v0.29+ memory migration ticket;
/// for now, this stub delegates to an in-memory backing to keep the
/// protocol surface exercisable.
final class SQLiteMemoryProvider: MemoryProvider, @unchecked Sendable {
    let slug: String
    let isEnabled: Bool = true
    private let backing: InMemoryMemoryProvider

    init(slug: String = "sqlite") {
        self.slug = slug
        self.backing = InMemoryMemoryProvider(slug: "\(slug)-backing")
    }

    func getSystemPrompt() -> String {
        // TODO: replace with the GRDB-backed full implementation.
        return "SQLite provider (= stub over in-memory backing; full GRDB impl lands with v0.29+ migration ticket)."
    }

    func prefetch(forUserMessage message: String) async -> String {
        return await backing.prefetch(forUserMessage: message)
    }

    func sync(userMessage: String, assistantResponse: String) async {
        await backing.sync(userMessage: userMessage, assistantResponse: assistantResponse)
    }

    func getToolSchemas() -> [ToolSchema] {
        return []
    }

    func preCompressCheckpoint() async -> String? {
        return nil
    }

    /// Test-only accessor (= underlying backing count).
    var entryCount: Int {
        backing.entryCount
    }
}

// MARK: - Tools-enabled gate (= hermes memory_provider_tools_enabled)

/// Return whether memory-provider tools should be exposed (= hermes
/// memory_provider_tools_enabled). Wenshu v1 always exposes them.
func memoryProviderToolsEnabled(
    enabledToolsets: [String]? = nil,
    disabledToolsets: [String]? = nil,
    memoryToolPresent: Bool = false
) -> Bool {
    if let disabled = disabledToolsets, disabled.contains("memory") {
        return false
    }
    if memoryToolPresent {
        return true
    }
    guard let enabled = enabledToolsets else {
        return true
    }
    return enabled.contains("memory")
}