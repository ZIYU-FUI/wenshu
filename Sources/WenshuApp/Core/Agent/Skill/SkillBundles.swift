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
struct SkillBundle: Sendable, Equatable, Identifiable, Codable {
    let id: String
    let name: String
    let skillIDs: [String]
    let dependencies: [String]

    init(
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
/// `SkillBundles.shared` is the canonical module-singleton (= hermes
/// `_bundles_state` module-level dict). Use the designated init when
/// you need an isolated registry (= tests, hot reload).
actor SkillBundles {
    /// Canonical module-singleton (= matches hermes `_bundles_state`).
    /// Added in v0.73 ticket 001 to give the LLM-facing SkillBundlesTool
    /// (= `Core/Agent/Tool/SkillBundlesTool.swift`) a stable registry handle
    /// without leaking actor internals.
    static let shared: SkillBundles = SkillBundles()

    private var bundles: [String: SkillBundle] = [:]

    init() {}

    /// Register a bundle. Re-registering the same id overwrites the
    /// previous value (= matches hermes `scan_bundles` "later wins").
    func register(_ bundle: SkillBundle) {
        bundles[bundle.id] = bundle
    }

    /// Remove a bundle by id. No-op when the id is unknown.
    func unregister(id: String) {
        bundles.removeValue(forKey: id)
    }

    /// Clear every registered bundle (= useful for tests + hot reload).
    func unregisterAll() {
        bundles.removeAll()
    }

    /// Snapshot of currently-registered bundles, in registration order.
    var current: [SkillBundle] { Array(bundles.values) }

    /// Look up a single bundle by id (= nil when not registered).
    func bundle(id: String) -> SkillBundle? {
        bundles[id]
    }

    /// Resolve a bundle to its FULL skill-ID set (= direct + transitive
    /// dependencies' direct skillIDs).
    ///
    /// Throws `SkillBundlesError.bundleNotFound` when the id is not
    /// registered. Cycles are tolerated (= each bundle's skillIDs is
    /// added once; we deduplicate by `Set` membership).
    func resolve(bundleID: String) async throws -> [String] {
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
    func dependencies(bundleID: String) async throws -> [String] {
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

enum SkillBundlesError: Error, LocalizedError, Sendable {
    case bundleNotFound(id: String)
    case cycleDetected(participating: [String])

    var errorDescription: String? {
        switch self {
        case .bundleNotFound(let id):
            return "SkillBundle '\(id)' not found in registry."
        case .cycleDetected(let participating):
            return "SkillBundles dependency cycle detected involving: \(participating.joined(separator: ", "))"
        }
    }
}

// MARK: - H5 Hermes-Python gap port (= 1:1 port of hermes
//         `agent/skill_bundles.py` pure helpers).
//
// Wenshu-side wins (= per AGENTS.md §11.3):
//
// Direct port of hermes `agent/skill_bundles.py` per spec §3.1 #32
// (= TICKET-HERMES-GAP-006 follow-up). The target file already existed
// at 182 LOC (= ⚠️ partial per gap audit 2026-09-04 = wenshu-s
// partial port = in-memory resolver layer).
// This H5 ticket adds the 4 hermes pure helpers (= slugify +
// bundlePathFor + scanBundles + reloadBundles) that were
// intentionally NOT ported in TICKET-HERMES-GAP-006.
//
// The hermes-specific helpers (= `_bundles_dir` / `_iter_bundle_files`
// / `_max_mtime` / `_load_bundle_file` / `scan_bundles` /
// `reload_bundles` / `get_skill_bundles` / `resolve_bundle_command_key`
// / `list_bundles` / `build_bundle_invocation_message` /
// `bundle_path_for` / `save_bundle` / `delete_bundle`) are ported
// in part (= the pure helpers = slugify + bundlePathFor +
// scanBundles + reloadBundles). The YAML-disk-IO glue (= bundle file
// write / delete / reload via YAML library) is left as future
// tickets per the wenshu-side-wins comment in the file header.
//
// Hermes Python line ranges cited in doc-comments below (= for
// traceability back to `/Volumes/ANAN/.hermes/agent/skill_bundles.py`).
//
// Per AGENTS.md §11.3 wenshu-side wins:
//   - `_bundles_dir()` (= hermes L67-L73) replaced by wenshu's
//     `SkillBundlesYAMLDiscovery.defaultDirectory()` (= already
//     exists with macOS-aware paths + WENSHU_BUNDLES_DIR env override).
//   - `_iter_bundle_files()` (= hermes L84-L91) replaced by
//     `SkillBundlesYAMLDiscovery.discover(...)`.
//   - The hermes YAML cache layer (= `_bundles_cache` +
//     `_bundles_cache_mtime` Python module globals) is replaced
//     by the wenshu `SkillBundles` actor's `bundles.values` + mtime
//     tracking on the actor itself (= thread-safe by Swift
//     Concurrency contract; = no manual cache invalidation needed).
//   - YAML save/delete are future tickets (= wenshu-side wins =
//     `SkillBundlesYAMLDiscovery` already does scan-only; = CRUD
//     needs an explicit UI ticket per the v0.73 ship record).

extension SkillBundles {

    // MARK: -- H5.1 slug normalization (= hermes L78-L82)

    /// Pure-function: normalize a bundle/skill name to a URL-safe
    /// slash-command slug (= hermes `_slugify` at
    /// `agent/skill_bundles.py` L78-L82).
    ///
    /// Mirrors hermes's `_slugify` (= lowercases, replaces spaces +
    /// underscores with hyphens, strips any non `[a-z0-9-]` chars,
    /// collapses consecutive hyphens, strips leading/trailing
    /// hyphens).
    static func slugify(_ name: String) -> String {
        var cmd = name.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "_", with: "-")
        // Strip anything that's not [a-z0-9-] (= hermes L80 =
        // `_BUNDLE_INVALID_CHARS.sub("", cmd)`).
        let allowed = CharacterSet.lowercaseLetters
            .union(.decimalDigits)
            .union(CharacterSet(charactersIn: "-"))
        cmd = String(cmd.unicodeScalars.filter { allowed.contains($0) })
        // Collapse `--` -> `-` (= hermes L81 =
        // `_BUNDLE_MULTI_HYPHEN.sub("-", cmd)`).
        while cmd.contains("--") {
            cmd = cmd.replacingOccurrences(of: "--", with: "-")
        }
        // Strip leading/trailing hyphens (= hermes L82 = `.strip("-")`).
        return cmd.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    // MARK: -- H5.2 bundle path builder (= hermes L378-L383)

    /// Pure-function: return the canonical filesystem path for a
    /// bundle name (= hermes `bundle_path_for` at
    /// `agent/skill_bundles.py` L378-L383).
    ///
    /// Uses `SkillBundlesYAMLDiscovery.defaultDirectory()` (= wenshu-side
    /// wins; = hermes uses `_bundles_dir()` which is different).
    ///
    /// - Throws: `ValueError` (= wenshu maps to `SkillBundlesError`/
    ///   would be re-thrown via `try?` in callers) when the name
    ///   normalizes to an empty slug.
    static func bundlePath(for name: String) throws -> URL {
        let slug = slugify(name)
        guard !slug.isEmpty else {
            // Hermese raises `ValueError`; = wenshu-side wins maps
            // to Swift's typed throws (= caller decides error type).
            throw NSError(
                domain: "SkillBundles",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Bundle name \(name) normalizes to an empty slug"]
            )
        }
        let dir = SkillBundlesYAMLDiscovery.defaultDirectory()
        return dir.appendingPathComponent("\(slug).yaml")
    }

    // MARK: -- H5.3 scan + cache invalidation (= hermes L160-L177)

    /// Pure-function: re-scan the bundles directory and update the
    /// in-memory registry (= hermes `scan_bundles` at
    /// `agent/skill_bundles.py` L160-L177 + `get_skill_bundles`
    /// L195-L203).
    ///
    /// Uses `SkillBundlesYAMLDiscovery` (= wenshu-side wins) to
    /// discover the YAML files; = hermes uses raw `pathlib.glob`.
    ///
    /// Returns: the number of bundles successfully registered.
    func scanBundles(
        directory: URL? = nil
    ) async -> Int {
        let dir = directory ?? SkillBundlesYAMLDiscovery.defaultDirectory()
        return await SkillBundlesYAMLDiscovery.discover(into: self, from: dir)
    }

    // MARK: -- H5.4 reload diff (= hermes L211-L227)

    /// Pure-function: re-scan and return a diff between the
    /// previous in-memory state and the new state (= hermes
    /// `reload_bundles` at `agent/skill_bundles.py` L211-L227).
    ///
    /// Returns: a `ReloadDiff` struct with `added` / `removed` /
    /// `unchanged` / `total` counts (= matches hermes dict shape).
    func reloadBundles(
        directory: URL? = nil
    ) async -> ReloadDiff {
        let beforeIds = Set(self.current.map { $0.id })
        _ = await scanBundles(directory: directory)
        let afterIds = Set(self.current.map { $0.id })
        let addedIds = afterIds.subtracting(beforeIds).sorted()
        let removedIds = beforeIds.subtracting(afterIds).sorted()
        let unchangedIds = afterIds.intersection(beforeIds).sorted()
        return ReloadDiff(
            added: addedIds,
            removed: removedIds,
            unchanged: unchangedIds,
            total: afterIds.count,
        )
    }
}

/// Reload diff (= hermes `reload_bundles` dict shape at
/// `agent/skill_bundles.py` L211-L227).
///
/// Wenshu-side wins: instead of `dict[str, str]` (= name -> description),
/// we use plain `Set<String>` for `added` / `removed` / `unchanged`
/// (= the bundle ID = file slug) + a `total` Int (= hermes has the
/// same shape but with name+description strings inside).
struct ReloadDiff: Sendable, Equatable {
    let added: [String]
    let removed: [String]
    let unchanged: [String]
    let total: Int

    init(added: [String], removed: [String], unchanged: [String], total: Int) {
        self.added = added
        self.removed = removed
        self.unchanged = unchanged
        self.total = total
    }
}
