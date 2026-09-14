//
//  SkillBundlesTool.swift · Wenshu · v0.73 ticket 001-wire-skillbundles
//
//  LLM-facing wrapper for `Sources/WenshuApp/Core/Agent/Skill/SkillBundles.swift`
//  (= the 1:1 hermes port of `agent/skill_bundles.py` shipped in
//  TICKET-HERMES-GAP-006). The actor was orphaned from the LLM tool
//  surface (= no Tool wrapper); this ticket wires it in.
//
//  Per AGENTS.md §11.3 wenshu-side wins pattern: this Tool is a thin
//  adapter that delegates to `SkillBundles.shared`. We do NOT re-implement
//  bundle resolution; the actor owns the in-memory registry + BFS.
//
//  Actions (= matches the spec):
//  - list                       — enumerate registered bundles
//  - show <bundle_id>           — fetch a single bundle
//  - resolve <bundle_id>        — transitive skill-ID resolution
//  - register <bundle>          — add or overwrite a bundle
//  - unregister <bundle_id>     — remove a bundle
//
//  Per Q42: reuse `SkillBundles.shared` actor. NO duplicate resolver logic.
//  Per AGENTS.md §11.1: Apple Foundation only. NO third-party deps.
//  Per Q187-Q190: doc-only header preserved verbatim (English only).
//
//  Tool name: "skill_bundles"  · toolset: "agent" (= matches KanbanStoreTool)
//
//

import Foundation

// MARK: - Tool

/// LLM-facing wrapper around the canonical `SkillBundles` actor.
///
/// Round-trips JSON envelopes (= hermes tool surface convention):
/// the LLM sends `{"action": "list"}` and receives a JSON envelope
/// `{"ok": true, "bundles": [...]}`. Errors come back as
/// `{"ok": false, "error": "..."}` (= matches `KanbanStoreTool`).
public final class SkillBundlesTool: Tool, @unchecked Sendable {

    /// Module-singleton (= matches `KanbanStoreTool.shared` pattern).
    /// The actor is its own singleton; `SkillBundles.shared` is the
    /// hermes-port surface from TICKET-HERMES-GAP-006.
    public static let shared = SkillBundlesTool()

    private let registry: SkillBundles

    /// Designated init (= allows tests to inject a private `SkillBundles`).
    public init(registry: SkillBundles = SkillBundles.shared) {
        self.registry = registry
    }

    public func execute(input: String) async throws -> String {
        let payload = parseJSON(input)
        let action = (payload["action"] as? String ?? "").lowercased()

        switch action {
        case "list":
            return await handleList()
        case "show":
            return await handleShow(payload: payload)
        case "resolve":
            return await handleResolve(payload: payload)
        case "register":
            return await handleRegister(payload: payload)
        case "unregister":
            return await handleUnregister(payload: payload)
        case "":
            return jsonError(action: nil, message: "missing required field: action")
        default:
            return jsonError(action: action, message: "unknown action '\(action)'; expected one of: list, show, resolve, register, unregister")
        }
    }

    // MARK: - Actions

    private func handleList() async -> String {
        let bundles = await registry.current
        let items = bundles.map { bundle -> [String: Any] in
            [
                "id": bundle.id,
                "name": bundle.name,
                "skill_ids": bundle.skillIDs,
                "dependencies": bundle.dependencies
            ]
        }
        return jsonOK(payload: ["bundles": items, "count": items.count])
    }

    private func handleShow(payload: [String: Any]) async -> String {
        guard let id = payload["bundle_id"] as? String, !id.isEmpty else {
            return jsonError(action: "show", message: "missing required field: bundle_id")
        }
        guard let bundle = await registry.bundle(id: id) else {
            return jsonError(action: "show", message: "bundle '\(id)' not found")
        }
        return jsonOK(payload: [
            "bundle": [
                "id": bundle.id,
                "name": bundle.name,
                "skill_ids": bundle.skillIDs,
                "dependencies": bundle.dependencies
            ]
        ])
    }

    private func handleResolve(payload: [String: Any]) async -> String {
        guard let id = payload["bundle_id"] as? String, !id.isEmpty else {
            return jsonError(action: "resolve", message: "missing required field: bundle_id")
        }
        do {
            let skillIDs = try await registry.resolve(bundleID: id)
            return jsonOK(payload: [
                "bundle_id": id,
                "skill_ids": skillIDs,
                "count": skillIDs.count
            ])
        } catch let error as SkillBundlesError {
            return jsonError(action: "resolve", message: error.errorDescription ?? "resolution failed")
        } catch {
            return jsonError(action: "resolve", message: "unexpected error: \(error)")
        }
    }

    private func handleRegister(payload: [String: Any]) async -> String {
        guard let bundleDict = payload["bundle"] as? [String: Any] else {
            return jsonError(action: "register", message: "missing required field: bundle (object)")
        }
        guard let id = bundleDict["id"] as? String, !id.isEmpty else {
            return jsonError(action: "register", message: "bundle.id (non-empty string) required")
        }
        guard let name = bundleDict["name"] as? String, !name.isEmpty else {
            return jsonError(action: "register", message: "bundle.name (non-empty string) required")
        }
        guard let skillIDs = bundleDict["skill_ids"] as? [String] else {
            return jsonError(action: "register", message: "bundle.skill_ids (array of strings) required")
        }
        let dependencies = (bundleDict["dependencies"] as? [String]) ?? []

        let bundle = SkillBundle(
            id: id,
            name: name,
            skillIDs: skillIDs,
            dependencies: dependencies
        )
        await registry.register(bundle)
        return jsonOK(payload: [
            "registered": [
                "id": bundle.id,
                "name": bundle.name,
                "skill_ids": bundle.skillIDs,
                "dependencies": bundle.dependencies
            ]
        ])
    }

    private func handleUnregister(payload: [String: Any]) async -> String {
        guard let id = payload["bundle_id"] as? String, !id.isEmpty else {
            return jsonError(action: "unregister", message: "missing required field: bundle_id")
        }
        await registry.unregister(id: id)
        return jsonOK(payload: ["bundle_id": id, "removed": true])
    }

    // MARK: - JSON envelope (= matches KanbanStoreTool convention)

    private func parseJSON(_ input: String) -> [String: Any] {
        guard let data = input.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return [:]
        }
        return obj
    }

    private func jsonOK(payload: [String: Any]) -> String {
        var envelope = payload
        envelope["ok"] = true
        return jsonString(envelope)
    }

    private func jsonError(action: String?, message: String) -> String {
        var envelope: [String: Any] = ["ok": false, "error": message]
        if let a = action { envelope["action"] = a }
        return jsonString(envelope)
    }

    private func jsonString(_ payload: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(
            withJSONObject: payload,
            options: [.sortedKeys]
        ) else {
            return "{\"ok\":false,\"error\":\"internal: failed to encode envelope\"}"
        }
        return String(data: data, encoding: .utf8) ?? "{\"ok\":false,\"error\":\"internal: non-utf8 envelope\"}"
    }
}

// MARK: - ToolRegistry bootstrap (= matches KanbanStoreTool pattern)

extension SkillBundlesTool {

    /// Module-load registration with `ToolRegistry.shared` (= hermes
    /// `tools/registry.py` `register()` 1:1). Fires once at first
    /// type access; the underlying `Task` schedules the async
    /// `register(...)` call off the init thread.
    ///
    /// Idempotent: same-toolset re-registration silently replaces;
    /// cross-toolset shadowing is blocked unless `override=true`.
    public static let _registryBootstrap: Void = {
        Task {
            await ToolRegistry.shared.register(
                name: "skill_bundles",
                toolset: "agent",
                schema: ToolRegistrySchema(
                    name: "skill_bundles",
                    description: """
                    Manage SkillBundles (= hermes-port `/bundle` slash-command aliasing \
                    per TICKET-HERMES-GAP-006). Actions: list / show / resolve / register / \
                    unregister. A bundle names a set of skill IDs and optional other bundle \
                    dependencies; `resolve` returns the transitive skill-ID set reachable \
                    through the dependency graph (= cycles tolerated). Use list to enumerate, \
                    show to inspect one, resolve to get the full skill set, register to add \
                    or overwrite, unregister to remove.
                    """,
                    inputSchema: [
                        "action": ToolRegistrySchemaProperty(
                            type: "string",
                            description: "The skill_bundles operation to perform.",
                            enumValues: ["list", "show", "resolve", "register", "unregister"]
                        ),
                        "bundle_id": ToolRegistrySchemaProperty(
                            type: "string",
                            description: "Bundle identifier (= required for show / resolve / unregister)."
                        ),
                        "bundle": ToolRegistrySchemaProperty(
                            type: "object",
                            description: "Bundle payload (= required for register). Object shape: { id, name, skill_ids[], dependencies[] }."
                        )
                    ],
                    required: []
                ),
                handler: SkillBundlesTool.shared,
                description: """
                Manage SkillBundles (= hermes-port `/bundle` slash-command aliasing). \
                Actions: list / show / resolve / register / unregister.
                """,
                emoji: "🧺"
            )
        }
    }()
}

// NOTE: Swift 6 forbids top-level expressions, so the static let
// `_registryBootstrap` initializer runs lazily on first type access
// (= Swift equivalent of Python module-load statement = hermes
// `registry.register(...)` at import time). Production code paths
// that touch this type (= e.g. ChatView constructing
// `ParagraphAITool.shared`, WenshuConductor constructing
// `SkillBundlesTool.shared`) automatically trigger the bootstrap.