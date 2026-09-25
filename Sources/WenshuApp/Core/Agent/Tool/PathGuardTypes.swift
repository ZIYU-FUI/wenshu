//
//  PathGuardTypes.swift · Wenshu · wt/path-guard-v2-2026-09-25
//
//  Typed path newtypes used by PathGuard (= the allow-list policy
//  that restricts wenshu built-in tool paths to the user's .ws
//  library root). Two types:
//
//    - LibraryPath: absolute path to the .ws library root (= the
//      value stored at UserDefaults "wenshu.libraryPath"). One per
//      user onboarding.
//
//    - RelativePath: a path string relative to a LibraryPath; = the
//      only kind of path string an LLM tool_use block can carry
//      without rejection (absolute paths in input are accepted if
//      they resolve inside the library root; = the type does not
//      reject absolute paths, it just provides a typed wrapper for
//      the relative case).
//
//  Both types wrap a `String` and provide no mutation. They are
//  Hashable / Codable / Sendable so they cross actor boundaries
//  safely (= ToolExecutor → PathGuard are in different files; =
//  the path values must travel between them).
//
//  These types do NOT change the wire format of ToolExecutor;
//  they wrap the existing `String` payload so callers can opt
//  into typed handling incrementally.
//
//  (= replaces the v1 raw `libraryRoot: String` and `path: String`
//  shape that violated design-check §9 Type Boundary + §7 Value
//  Object vs Entity.)
//

import Foundation

/// Absolute path to the user's .ws library root.
/// One per onboarding (= sourced from `WenshuDefaultsKey.libraryPath`).
struct LibraryPath: Hashable, Codable, Sendable, Comparable, CustomStringConvertible {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    /// Construct from a raw UserDefaults string. Empty / whitespace-only
    /// strings return nil (= guards against unconfigured onboarding).
    init?(rawValueOrNil raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        self.rawValue = trimmed
    }

    var url: URL {
        URL(fileURLWithPath: rawValue, isDirectory: true)
    }

    /// Canonical absolute path string with symlinks resolved.
    var canonicalPath: String {
        url.resolvingSymlinksInPath().standardizedFileURL.path
    }

    var description: String { rawValue }

    static func < (lhs: LibraryPath, rhs: LibraryPath) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Path relative to a `LibraryPath`. Carries no identity of its own
/// (= a value object). Construct from a raw string; validation that
/// the resolved path stays inside the library root happens at the
/// policy layer (PathGuard.assertInsideLibrary).
struct RelativePath: Hashable, Codable, Sendable, Comparable, CustomStringConvertible {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    var description: String { rawValue }

    static func < (lhs: RelativePath, rhs: RelativePath) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Typed wrapper for the input dictionary that arrives at a tool
/// execution. Replaces the v1 raw `[String: String]` shape (= the
/// implementer's vocabulary: callers had to know which keys were
/// paths vs strings vs bools). The wrapper exposes typed accessors
/// so PathGuard.preDispatchValidator can check each path-bearing
/// key with the correct type at the call site.
struct PathGuardInput: Sendable {
    private let raw: [String: String]

    init(raw: [String: String]) {
        self.raw = raw
    }

    /// Get the raw string value for `key`, if present.
    func string(forKey key: String) -> String? {
        raw[key]
    }

    /// Get the value for `key` as a `LibraryPath` (= if the raw
    /// string is empty, returns nil).
    func libraryPath(forKey key: String) -> LibraryPath? {
        guard let raw = raw[key], !raw.isEmpty else { return nil }
        return LibraryPath(rawValueOrNil: raw)
    }

    /// Get the value for `key` as a `RelativePath` (= if the raw
    /// string is empty, returns nil).
    func relativePath(forKey key: String) -> RelativePath? {
        guard let raw = raw[key], !raw.isEmpty else { return nil }
        return RelativePath(rawValue: raw)
    }

    /// All keys present in the input (= for diagnostics).
    var allKeys: [String] {
        Array(raw.keys).sorted()
    }
}