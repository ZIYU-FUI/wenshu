//
//  SourceLocator.swift · WenshuAppTests
//
//  Single source of truth for "where is the repo root, and how do I
//  read a production source file from a test".
//
//  RATIONALE: source-content tests used to walk up to the repo root
//  by counting `deletingLastPathComponent()` calls. That count is
//  only correct for the test file's current directory depth, so any
//  commit that moves test files between directories silently breaks
//  every chain in the moved file — the tests still compile and the
//  code still reads correctly, but every read returns
//  `NSCocoaErrorDomain Code=260` (file not found). Probing for
//  `Package.swift` instead removes the depth coupling entirely: a
//  test file keeps working no matter where it sits in the tree, and
//  no future test-tree move can invalidate it.
//
//  Reading goes through `Data(contentsOf:)` rather than
//  `String(contentsOf:encoding:)` because the swiftpm-testing-helper
//  sandbox blocks the inline encoding-detect step and reports it as
//  Code=259 ("isn't in the correct format") on valid UTF-8 files.
//

import Foundation

enum SourceLocator {

    /// Repo root = the nearest ancestor directory holding a Package.swift.
    /// PERF: resolved once per process; the walk is 3-5 `exists` calls.
    static let repoRoot: URL = {
        var current = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while current.path != "/" {
            if FileManager.default.fileExists(
                atPath: current.appendingPathComponent("Package.swift").path
            ) {
                return current
            }
            current.deleteLastPathComponent()
        }
        fatalError("SourceLocator: no Package.swift above \(#filePath)")
    }()

    /// Absolute URL for a repo-root-relative path.
    static func url(_ relativePath: String) -> URL {
        repoRoot.appendingPathComponent(relativePath)
    }

    /// Absolute filesystem path for a repo-root-relative path.
    static func path(_ relativePath: String) -> String {
        url(relativePath).path
    }

    /// Reads a production source file as UTF-8.
    /// FAILURE MODE: throws `fileNotFound` when the relative path no
    /// longer points at a file (= the source moved during a directory
    /// reorganization); callers get a real error rather than a
    /// silently-empty string.
    static func read(_ relativePath: String) throws -> String {
        let fileURL = url(relativePath)
        guard let text = String(data: try Data(contentsOf: fileURL), encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return text
    }

    /// Reads the first production source file whose name matches
    /// `fileName` anywhere under Sources/. Use when a test asserts
    /// against a file whose directory is an implementation detail and
    /// moves between feature reorganizations — the assertion stays
    /// about the file, not about where the file happens to live.
    /// FAILURE MODE: throws when zero or more than one file matches,
    /// because an ambiguous match means the test would silently start
    /// asserting against the wrong file.
    static func readSource(named fileName: String) throws -> String {
        let matches = try filesUnderSources(named: fileName)
        guard let only = matches.first, matches.count == 1 else {
            throw CocoaError(.fileReadUnknown)
        }
        return try read(only)
    }

    /// Every `.swift` path under Sources/, repo-root relative.
    static func filesUnderSources(named fileName: String) throws -> [String] {
        let sourcesRoot = url("Sources")
        guard let walker = FileManager.default.enumerator(
            at: sourcesRoot,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            throw CocoaError(.fileReadUnknown)
        }
        var found: [String] = []
        for case let entry as URL in walker
        where entry.lastPathComponent == fileName && entry.pathExtension == "swift" {
            let relative = entry.path
                .replacingOccurrences(of: repoRoot.path + "/", with: "")
            // A previous build's intermediates can shadow the real
            // source; they are never the file under test.
            if !relative.contains("/.build/") {
                found.append(relative)
            }
        }
        return found.sorted()
    }
}
