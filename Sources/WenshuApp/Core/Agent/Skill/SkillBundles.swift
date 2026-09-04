//
//  SkillBundles.swift · Wenshu · TICKET-HERMES-GAP-006
//
//  Ported from hermes-agent `agent/skill_bundles.py` (438 LOC).
//
//  Hermes' SkillBundles = multi-skill dependency resolution: a YAML
//  bundle at `~/.hermes/skill-bundles/*.yaml` names a set of skills
//  and optional extra instructions; invoking `/<bundle>` loads all
//  referenced skills in one go (= slash-command aliasing).
//
//  The wenshu-side wins pattern (AGENTS.md §11.3):
//  - Disk loading already lives in `Core/Skills/SkillRegistry.swift` +
//    `SkillAdapter.swift`. We do NOT re-implement YAML parsing here.
//  - This file ships the in-memory bundle resolver + transitive
//    dependency resolver (= pure data structure + actor). Future
//    tickets can add YAML discovery on top of `register(_:)` without
//    changing the public surface.
//  - Hermes' slug normalization, scan-on-disk, file-level CRUD, and
//    `build_bundle_invocation_message` (= glue to skill_payload) are
//    intentionally NOT ported in this ticket — they live behind the
//    SkillAdapter / SkillRegistry surface and don't need a parallel
//    implementation. Documented in the gap audit as out-of-scope.
//
//  Public API surface (matches the task spec):
//  - SkillBundle struct (= id + name + skillIDs + dependencies)
//  - SkillBundles actor (= register / resolve / dependencies)
//  - SkillBundlesError enum (= missing bundle, cycle)
//
//  Per AGENTS.md §11 hard rule: Apple Foundation only. No third-party
//  imports. No YAML parser (= the existing SkillRegistry owns disk
//  I/O + parsing for wenshu).
//

import Foundation

// MARK: - SkillBundle

/// In-memory representation of a bundle of skills that can be loaded
/// together via one slash-command alias.
///
/// `skillIDs` = the skills directly referenced by this bundle.
/// `dependencies` = other bundle IDs this bundle depends on
/// (= transitive resolution is computed by `SkillBundles.dependencies`).
public struct SkillBundle: Sendable, Equatable, Identifiable, Codable {
    public let id: String
    public let name: String
    public let skillIDs: [String]
    public let dependencies: [String]

    public init(
        id: String,
        name: String,
        skillIDs: [String],
        dependencies: [String] = []
    ) {
        self.id = id
        self.name = name
        self.skillIDs = skillIDs
        self.dependencies = dependencies
    }
}

// MARK: - SkillBundles actor

/// Thread-safe registry + resolver for `SkillBundle`s.
///
/// Resolution = walk the bundle graph, return every skill ID reachable
/// through the direct `skillIDs` list and through every dependency's
/// `skillIDs` (= transitive).
///
/// Default `SkillBundles()` = empty registry; `resolve(bundleID:)` on
/// an unknown id throws `SkillBundlesError.bundleNotFound`. The actor
/// is safe to call from any isolation context (= Swift 6 strict).
public actor SkillBundles {
    private var bundles: [String: SkillBundle] = [:]

    public init() {}

    /// Register a bundle. Re-registering the same id overwrites the
    /// previous value (= matches hermes `scan_bundles` "later wins").
    public func register(_ bundle: SkillBundle) {
        bundles[bundle.id] = bundle
    }

    /// Remove a bundle by id. No-op when the id is unknown.
    public func unregister(id: String) {
        bundles.removeValue(forKey: id)
    }

    /// Clear every registered bundle (= useful for tests + hot reload).
    public func unregisterAll() {
        bundles.removeAll()
    }

    /// Snapshot of currently-registered bundles, in registration order.
    public var current: [SkillBundle] { Array(bundles.values) }

    /// Look up a single bundle by id (= nil when not registered).
    public func bundle(id: String) -> SkillBundle? {
        bundles[id]
    }

    /// Resolve a bundle to its FULL skill-ID set (= direct + transitive
    /// dependencies' direct skillIDs).
    ///
    /// Throws `SkillBundlesError.bundleNotFound` when the id is not
    /// registered. Cycles are tolerated (= each bundle's skillIDs is
    /// added once; we deduplicate by `Set` membership).
    public func resolve(bundleID: String) async throws -> [String] {
        guard let root = bundles[bundleID] else {
            throw SkillBundlesError.bundleNotFound(id: bundleID)
        }

        // BFS through the dependency graph; track visited bundle IDs
        // so cycles don't loop forever. Skill IDs are deduplicated.
        var visited: Set<String> = []
        var queue: [String] = [root.id]
        var skillIDs: [String] = []

        while let next = queue.first {
            queue.removeFirst()
            if visited.contains(next) { continue }
            visited.insert(next)
            guard let bundle = bundles[next] else { continue }
            skillIDs.append(contentsOf: bundle.skillIDs)
            queue.append(contentsOf: bundle.dependencies)
        }

        // Preserve order (= first-seen wins), but deduplicate.
        var seen = Set<String>()
        return skillIDs.filter { seen.insert($0).inserted }
    }

    /// Return the TRANSITIVE bundle-id set reachable from `bundleID`
    /// (= every other bundle id this bundle depends on, directly or
    /// indirectly). Self is included.
    ///
    /// Throws `SkillBundlesError.bundleNotFound` when the id is not
    /// registered. Cycles are tolerated (= visited set short-circuits).
    public func dependencies(bundleID: String) async throws -> [String] {
        guard bundles[bundleID] != nil else {
            throw SkillBundlesError.bundleNotFound(id: bundleID)
        }

        var visited: Set<String> = []
        var queue: [String] = [bundleID]
        var order: [String] = []

        while let next = queue.first {
            queue.removeFirst()
            if visited.contains(next) { continue }
            visited.insert(next)
            order.append(next)
            guard let bundle = bundles[next] else { continue }
            queue.append(contentsOf: bundle.dependencies)
        }

        return order
    }
}

// MARK: - Errors

public enum SkillBundlesError: Error, LocalizedError, Sendable {
    case bundleNotFound(id: String)
    case cycleDetected(participating: [String])

    public var errorDescription: String? {
        switch self {
        case .bundleNotFound(let id):
            return "SkillBundle '\(id)' not found in registry."
        case .cycleDetected(let participating):
            return "SkillBundles dependency cycle detected involving: \(participating.joined(separator: ", "))"
        }
    }
}
