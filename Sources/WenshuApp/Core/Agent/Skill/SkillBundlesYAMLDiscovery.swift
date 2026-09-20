//
//  SkillBundlesYAMLDiscovery.swift · Wenshu · v0.75 ticket 001
//
//  Hermes-port continuation: discovers SkillBundle YAML files at the
//  canonical wenshu path (= `~/Library/Application Support/wenshu/skill-bundles/*.yaml`)
//  and registers each into `SkillBundles.shared` (= the actor from
//  v0.73 ticket 001).
//
//  Hermes counterpart: hermes-agent `agent/skill_bundles.py` `_scan_bundles`
//  (= scans `~/.hermes/skill-bundles/*.yaml`).
//
//  Per AGENTS.md §11.3 wenshu-side wins pattern: thin adapter that delegates
//  to `SkillBundles.shared.register(...)`. NO duplicate resolver logic.
//
//  YAML schema (= minimal; = only what SkillBundles actor consumes):
//    id: alpha
//    name: Alpha Bundle
//    skill_ids:
//      - code-review
//      - refactor
//    dependencies:
//      - core-libs
//
//  Per AGENTS.md §11.1: NO third-party YAML libraries. Use Foundation's
//  simple line-based parser (= bundles have flat top-level scalars + 2
//  arrays; = no nested objects; = matches the hermes YAML subset).
//
//  Discovery path convention (= per wenshu spec):
//    - `$WENSHU_BUNDLES_DIR` env var override (for tests + dev)
//    - `~/Library/Application Support/wenshu/skill-bundles/` (macOS app)
//    - `~/.wenshu/skill-bundles/` (fallback; = matches the AGENTS.md path note)
//
//  Public API:
//    - `SkillBundlesYAMLDiscovery.discover(into: SkillBundles, from: URL?) -> Int`
//    - `SkillBundlesYAMLDiscovery.defaultDirectory()` (= returns the resolved default URL)
//

import Foundation

// MARK: - YAML schema

/// Minimal in-memory representation of a SkillBundle YAML file.
/// (= matches the hermes YAML subset — flat scalars + 2 arrays only.)
public struct SkillBundleYAML: Sendable, Equatable {
    public let id: String
    public let name: String
    public let skillIDs: [String]
    public let dependencies: [String]
}

/// Errors thrown by `SkillBundlesYAMLDiscovery`.
public enum SkillBundlesYAMLDiscoveryError: Error, LocalizedError, Sendable {
    case directoryNotFound(URL)
    case missingField(String)
    case duplicateID(String)
    case malformedYAML(file: URL, reason: String)

    public var errorDescription: String? {
        switch self {
        case .directoryNotFound(let url):
            return "SkillBundles directory not found: \(url.path)"
        case .missingField(let field):
            return "SkillBundles YAML missing required field: \(field)"
        case .duplicateID(let id):
            return "Duplicate SkillBundle id: \(id)"
        case .malformedYAML(let file, let reason):
            return "Malformed SkillBundle YAML at \(file.lastPathComponent): \(reason)"
        }
    }
}

// MARK: - Discovery

/// Discovers SkillBundle YAML files at the canonical wenshu path
/// (= `~/Library/Application Support/wenshu/skill-bundles/*.yaml`)
/// and registers each into a `SkillBundles` actor.
///
/// This is the wenshu-side counterpart of hermes' `_scan_bundles` function
/// in `agent/skill_bundles.py`. The scan order:
/// 1. `$WENSHU_BUNDLES_DIR` env var override
/// 2. `~/Library/Application Support/wenshu/skill-bundles/`
/// 3. `~/.wenshu/skill-bundles/`
///
/// Usage:
/// ```
/// let count = await SkillBundlesYAMLDiscovery.discover(
///     into: SkillBundles.shared,
///     from: nil  // = use default directory
/// )
/// ```
public enum SkillBundlesYAMLDiscovery {

    /// Resolve the default SkillBundles directory.
    /// Order: env var override → Application Support → ~/.wenshu fallback.
    public static func defaultDirectory() -> URL {
        if let override = ProcessInfo.processInfo.environment["WENSHU_BUNDLES_DIR"],
           !override.isEmpty
        {
            return URL(fileURLWithPath: override, isDirectory: true)
        }

        // macOS canonical: ~/Library/Application Support/wenshu/skill-bundles/
        if let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first {
            return appSupport
                .appendingPathComponent("wenshu", isDirectory: true)
                .appendingPathComponent("skill-bundles", isDirectory: true)
        }

        // Fallback: ~/.wenshu/skill-bundles/ (= matches the AGENTS.md path note)
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home
            .appendingPathComponent(".wenshu", isDirectory: true)
            .appendingPathComponent("skill-bundles", isDirectory: true)
    }

    /// Discover YAML files at `from` (= nil = use `defaultDirectory()`)
    /// and register each into `bundles`. Returns the number registered.
    /// Returns 0 (= no-op) if directory doesn't exist (= first-launch UX).
    public static func discover(
        into bundles: SkillBundles,
        from directory: URL? = nil
    ) async -> Int {
        let dir = directory ?? defaultDirectory()
        let fm = FileManager.default

        // First-launch UX: missing directory = no bundles registered = silent success.
        guard fm.fileExists(atPath: dir.path) else {
            return 0
        }

        let yamlFiles: [URL]
        do {
            let contents = try fm.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )
            yamlFiles = contents.filter { $0.pathExtension == "yaml" || $0.pathExtension == "yml" }
        } catch {
            return 0
        }

        var registeredCount = 0
        for file in yamlFiles {
            do {
                let yaml = try parseYAML(at: file)
                let bundle = SkillBundle(
                    id: yaml.id,
                    name: yaml.name,
                    skillIDs: yaml.skillIDs,
                    dependencies: yaml.dependencies
                )
                await bundles.register(bundle)
                registeredCount += 1
            } catch {
                // Per Q34: log + continue (= don't crash on first malformed file)
                FileHandle.standardError.write(
                    Data("[wenshu] SkillBundles YAML discovery error at \(file.lastPathComponent): \(error)\n".utf8)
                )
                continue
            }
        }

        return registeredCount
    }

    // MARK: - YAML parser (= minimal subset; = no nested objects)

    /// Parse a SkillBundle YAML file. Supports ONLY:
    /// - Top-level scalars (id, name) with `key: value` syntax
    /// - Top-level arrays (skill_ids, dependencies) with `- item` syntax
    /// - Comments (# ...) and blank lines
    ///
    /// Does NOT support:
    /// - Nested mappings (= hermes doesn't use them in SkillBundles files)
    /// - Multi-line strings
    /// - Quoted strings with embedded colons
    ///
    /// This is intentional (= matches the hermes YAML subset; = avoids
    /// adding a YAML library per AGENTS.md §11.1).
    public static func parseYAML(at url: URL) throws -> SkillBundleYAML {
        let content: String
        do {
            content = try String(contentsOf: url, encoding: .utf8)
        } catch {
            throw SkillBundlesYAMLDiscoveryError.malformedYAML(
                file: url, reason: "unable to read file: \(error)"
            )
        }
        return try parseYAMLString(content, sourceFile: url)
    }

    /// Parse YAML content from a string (= lets tests skip filesystem).
    public static func parseYAMLString(
        _ content: String,
        sourceFile: URL? = nil
    ) throws -> SkillBundleYAML {
        var id: String?
        var name: String?
        var skillIDs: [String] = []
        var dependencies: [String] = []
        var currentArray: String? = nil

        for rawLine in content.components(separatedBy: .newlines) {
            // Strip comments + trim (= trim FIRST so leading whitespace is gone
            // before the # split; = prevents leading spaces leaking into the
            // array-item detection)
            let stripped = rawLine.trimmingCharacters(in: .whitespaces)
            let line = stripped
                .components(separatedBy: "#").first ?? stripped

            // Skip blank lines
            if line.isEmpty { continue }

            // Array item (= `  - value` or `- value`)
            // (= needs to check BEFORE the colon-split since array items
            // can contain colons in values)
            let trimmed = line
            if trimmed.hasPrefix("- ") {
                let value = String(trimmed.dropFirst(2))
                    .trimmingCharacters(in: .whitespaces)
                if let arr = currentArray {
                    switch arr {
                    case "skill_ids": skillIDs.append(value)
                    case "dependencies": dependencies.append(value)
                    default:
                        throw SkillBundlesYAMLDiscoveryError.malformedYAML(
                            file: sourceFile ?? URL(fileURLWithPath: "/unknown"),
                            reason: "unexpected array '\(arr)'"
                        )
                    }
                } else {
                    throw SkillBundlesYAMLDiscoveryError.malformedYAML(
                        file: sourceFile ?? URL(fileURLWithPath: "/unknown"),
                        reason: "array item outside of array context"
                    )
                }
                continue
            }

            // Top-level key:value (= `key: value`)
            guard let colonIndex = trimmed.firstIndex(of: ":") else {
                throw SkillBundlesYAMLDiscoveryError.malformedYAML(
                    file: sourceFile ?? URL(fileURLWithPath: "/unknown"),
                    reason: "line without colon: '\(trimmed)'"
                )
            }
            let key = String(line[..<colonIndex]).trimmingCharacters(in: .whitespaces)
            let rawValue = String(line[line.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)

            if rawValue.isEmpty {
                // Empty value = array follows on next lines (= `key:\n  - item`)
                currentArray = key
                switch key {
                case "skill_ids", "dependencies":
                    continue  // expected
                default:
                    throw SkillBundlesYAMLDiscoveryError.malformedYAML(
                        file: sourceFile ?? URL(fileURLWithPath: "/unknown"),
                        reason: "unexpected mapping key '\(key)'"
                    )
                }
            } else if rawValue == "[]" {
                // Inline empty array (= `key: []`); = accepted as a
                // no-op (= same as the empty-`rawValue` + multi-line
                // array path but for single-line brevity).
                currentArray = nil
                switch key {
                case "skill_ids", "dependencies":
                    continue
                default:
                    throw SkillBundlesYAMLDiscoveryError.malformedYAML(
                        file: sourceFile ?? URL(fileURLWithPath: "/unknown"),
                        reason: "unexpected mapping key '\(key)'"
                    )
                }
            } else {
                // Scalar value
                currentArray = nil
                switch key {
                case "id": id = rawValue
                case "name": name = rawValue
                default:
                    throw SkillBundlesYAMLDiscoveryError.malformedYAML(
                        file: sourceFile ?? URL(fileURLWithPath: "/unknown"),
                        reason: "unknown top-level key '\(key)'"
                    )
                }
            }
        }

        guard let resolvedID = id else {
            throw SkillBundlesYAMLDiscoveryError.missingField("id")
        }
        guard let resolvedName = name else {
            throw SkillBundlesYAMLDiscoveryError.missingField("name")
        }

        return SkillBundleYAML(
            id: resolvedID,
            name: resolvedName,
            skillIDs: skillIDs,
            dependencies: dependencies
        )
    }
}