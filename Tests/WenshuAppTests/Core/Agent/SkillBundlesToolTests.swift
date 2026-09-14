// SkillBundlesToolTests.swift · Wenshu · v0.73 ticket 001-wire-skillbundles
//
// Hermes-port validation tests for SkillBundlesTool.swift
// (= LLM-facing wrapper over SkillBundles.swift shipped in
// TICKET-HERMES-GAP-006).
//
// Tests cover:
// - list action returns empty envelope on empty registry
// - register + list = 1 bundle
// - show returns the registered bundle
// - show returns bundle_not_found error for unknown id
// - resolve returns transitive skill IDs (deduplicated, cycles tolerated)
// - register payload validation (= missing bundle.id rejected)
// - unregister removes the bundle
// - unknown action returns typed error

import Foundation
import Testing
@testable import WenshuApp

@Suite("SkillBundlesTool (v0.73 ticket 001 — wire SkillBundles into ToolRegistry)")
struct SkillBundlesToolTests {

    // MARK: - Helpers

    /// Build a fresh tool + registry for every test (= each test owns its
    /// own `SkillBundles` instance to avoid actor-state cross-pollution).
    private static func makeTool() -> SkillBundlesTool {
        let registry = SkillBundles()
        return SkillBundlesTool(registry: registry)
    }

    private static func decodeEnvelope(_ json: String) throws -> [String: Any] {
        let data = Data(json.utf8)
        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }

    // MARK: - list

    @Test("list returns empty envelope on empty registry")
    func listEmptyRegistry() async throws {
        let tool = Self.makeTool()
        let result = await tool.execute(input: #"{"action":"list"}"#)
        let env = try Self.decodeEnvelope(result)
        #expect(env["ok"] as? Bool == true)
        #expect(env["count"] as? Int == 0)
        let bundles = env["bundles"] as? [[String: Any]] ?? []
        #expect(bundles.isEmpty == true)
    }

    @Test("register + list returns the registered bundle")
    func registerThenList() async throws {
        let tool = Self.makeTool()
        let registerInput = #"""
        {"action":"register","bundle":{"id":"alpha","name":"Alpha","skill_ids":["a","b"],"dependencies":[]}}
        """#
        let registerResult = await tool.execute(input: registerInput)
        let registerEnv = try Self.decodeEnvelope(registerResult)
        #expect(registerEnv["ok"] as? Bool == true)

        let listResult = await tool.execute(input: #"{"action":"list"}"#)
        let listEnv = try Self.decodeEnvelope(listResult)
        #expect(listEnv["ok"] as? Bool == true)
        #expect(listEnv["count"] as? Int == 1)
        let bundles = listEnv["bundles"] as? [[String: Any]] ?? []
        #expect(bundles.first?["id"] as? String == "alpha")
        #expect(bundles.first?["skill_ids"] as? [String] == ["a", "b"])
    }

    // MARK: - show

    @Test("show returns the registered bundle by id")
    func showByID() async throws {
        let tool = Self.makeTool()
        _ = await tool.execute(input: #"{"action":"register","bundle":{"id":"beta","name":"Beta","skill_ids":["x"]}}"#)
        let result = await tool.execute(input: #"{"action":"show","bundle_id":"beta"}"#)
        let env = try Self.decodeEnvelope(result)
        #expect(env["ok"] as? Bool == true)
        let bundle = env["bundle"] as? [String: Any]
        #expect(bundle?["id"] as? String == "beta")
        #expect(bundle?["name"] as? String == "Beta")
        #expect(bundle?["skill_ids"] as? [String] == ["x"])
    }

    @Test("show returns bundle_not_found error for unknown id")
    func showUnknownBundle() async throws {
        let tool = Self.makeTool()
        let result = await tool.execute(input: #"{"action":"show","bundle_id":"nope"}"#)
        let env = try Self.decodeEnvelope(result)
        #expect(env["ok"] as? Bool == false)
        let error = env["error"] as? String ?? ""
        #expect(error.contains("not found"))
    }

    @Test("show returns missing-bundle_id error when field absent")
    func showMissingField() async throws {
        let tool = Self.makeTool()
        let result = await tool.execute(input: #"{"action":"show"}"#)
        let env = try Self.decodeEnvelope(result)
        #expect(env["ok"] as? Bool == false)
        let error = env["error"] as? String ?? ""
        #expect(error.contains("bundle_id"))
    }

    // MARK: - resolve

    @Test("resolve returns transitive skill IDs")
    func resolveTransitive() async throws {
        let tool = Self.makeTool()
        _ = await tool.execute(input: #"{"action":"register","bundle":{"id":"root","name":"Root","skill_ids":["r1","r2"],"dependencies":["child"]}}"#)
        _ = await tool.execute(input: #"{"action":"register","bundle":{"id":"child","name":"Child","skill_ids":["c1"],"dependencies":[]}}"#)
        let result = await tool.execute(input: #"{"action":"resolve","bundle_id":"root"}"#)
        let env = try Self.decodeEnvelope(result)
        #expect(env["ok"] as? Bool == true)
        let skillIDs = env["skill_ids"] as? [String] ?? []
        // Root's direct skillIDs first (preserved order), then child's.
        #expect(skillIDs.contains("r1"))
        #expect(skillIDs.contains("r2"))
        #expect(skillIDs.contains("c1"))
        #expect(env["count"] as? Int == 3)
    }

    @Test("resolve dedupes overlapping skill IDs across dependency levels")
    func resolveDedupes() async throws {
        let tool = Self.makeTool()
        _ = await tool.execute(input: #"{"action":"register","bundle":{"id":"a","name":"A","skill_ids":["shared","a-only"],"dependencies":["b"]}}"#)
        _ = await tool.execute(input: #"{"action":"register","bundle":{"id":"b","name":"B","skill_ids":["shared","b-only"],"dependencies":[]}}"#)
        let result = await tool.execute(input: #"{"action":"resolve","bundle_id":"a"}"#)
        let env = try Self.decodeEnvelope(result)
        let skillIDs = env["skill_ids"] as? [String] ?? []
        // "shared" appears once even though both bundles include it.
        let sharedCount = skillIDs.filter { $0 == "shared" }.count
        #expect(sharedCount == 1)
        #expect(env["count"] as? Int == 3)  // shared, a-only, b-only
    }

    // MARK: - register payload validation

    @Test("register rejects payload without bundle field")
    func registerMissingBundle() async throws {
        let tool = Self.makeTool()
        let result = await tool.execute(input: #"{"action":"register"}"#)
        let env = try Self.decodeEnvelope(result)
        #expect(env["ok"] as? Bool == false)
        let error = env["error"] as? String ?? ""
        #expect(error.contains("bundle"))
    }

    @Test("register rejects bundle without skill_ids")
    func registerMissingSkillIDs() async throws {
        let tool = Self.makeTool()
        let result = await tool.execute(input: #"{"action":"register","bundle":{"id":"x","name":"X"}}"#)
        let env = try Self.decodeEnvelope(result)
        #expect(env["ok"] as? Bool == false)
        let error = env["error"] as? String ?? ""
        #expect(error.contains("skill_ids"))
    }

    // MARK: - unregister

    @Test("unregister removes a registered bundle")
    func unregisterRemoves() async throws {
        let tool = Self.makeTool()
        _ = await tool.execute(input: #"{"action":"register","bundle":{"id":"temp","name":"Temp","skill_ids":["t"]}}"#)
        let unregisterResult = await tool.execute(input: #"{"action":"unregister","bundle_id":"temp"}"#)
        let unregisterEnv = try Self.decodeEnvelope(unregisterResult)
        #expect(unregisterEnv["ok"] as? Bool == true)

        let listResult = await tool.execute(input: #"{"action":"list"}"#)
        let listEnv = try Self.decodeEnvelope(listResult)
        #expect(listEnv["count"] as? Int == 0)
    }

    // MARK: - error envelopes

    @Test("unknown action returns typed error")
    func unknownAction() async throws {
        let tool = Self.makeTool()
        let result = await tool.execute(input: #"{"action":"frobnicate"}"#)
        let env = try Self.decodeEnvelope(result)
        #expect(env["ok"] as? Bool == false)
        let error = env["error"] as? String ?? ""
        #expect(error.contains("unknown action"))
        #expect(env["action"] as? String == "frobnicate")
    }

    @Test("empty action returns missing-action error")
    func missingAction() async throws {
        let tool = Self.makeTool()
        let result = await tool.execute(input: #"{}"#)
        let env = try Self.decodeEnvelope(result)
        #expect(env["ok"] as? Bool == false)
        let error = env["error"] as? String ?? ""
        #expect(error.contains("action"))
    }
}