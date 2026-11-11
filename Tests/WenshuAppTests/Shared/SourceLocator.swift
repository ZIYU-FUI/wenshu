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

    /// Reads every production source file whose name starts with
    /// `prefix` (= `ChatView` reads `ChatView.swift` AND
    /// `ChatView+KeyboardShortcuts.swift`), = = joined with a newline.
    ///
    /// WHY: a source-content test asserts about a VIEW, = = not about a
    /// FILE. = = When the view was one file, = = the file WAS the view's
    /// source; = = after the view was split into several files, = = the
    /// file is only a SLICE of it, = = and an assertion about the view
    /// (does it bind this shortcut? = = does it use this padding?)
    /// would read one slice and answer about the wrong thing. = = So the
    /// reader takes the whole group, = = and a token is counted the same
    /// way it was counted when the view was one file.
    ///
    /// ORDER: the group's files are read in sorted order, = = so the
    /// joined text is stable = = (a test that pins a line number or a
    /// block's neighbours reads the same text every run).
    ///
    /// FAILURE MODE: throws `fileReadUnknown` when the group is EMPTY,
    /// because a reader that silently returned "" would let an assertion
    /// about the view pass for the wrong reason.
    static func readGroup(prefixed prefix: String) throws -> String {
        let group = try filesUnderSources(inGroupOf: prefix)
        guard !group.isEmpty else { throw CocoaError(.fileReadUnknown) }
        return try group
            .map { try read($0) }
            .joined(separator: "\n")
    }

    /// A path's file name without its `.swift` extension.
    static func pathWithoutExtension(of path: String) -> String {
        var name = path
        if let slash = name.lastIndex(of: "/") {
            name = String(name[name.index(after: slash)...])
        }
        if name.hasSuffix(".swift") {
            name = String(name.dropLast(".swift".count))
        }
        return name
    }

    /// Reads a production source file as UTF-8.
    /// FAILURE MODE: throws `fileNotFound` when the relative path no
    /// longer points at a file (= the source moved during a directory
    /// reorganization); callers get a real error rather than a
    /// silently-empty string.
    static func read(_ relativePath: String) throws -> String {
        let fileURL = url(relativePath)
        guard let text = try String(data: Data(contentsOf: fileURL), encoding: .utf8) else {
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
    /// Every `.swift` path under Sources/ that belongs to `stem`'s
    /// GROUP, = = repo-root relative. = = A group is the file named
    /// `stem.swift` PLUS the `stem+<Cluster>.swift` files that sit
    /// BESIDE it.
    ///
    /// WHY THE GROUP AND NOT A PREFIX: = = a prefix would also match a
    /// DIFFERENT type whose name starts with the same letters (= =
    /// `ChatViewModelLongRunningGoal.swift` starts with `ChatView`), = =
    /// and a reader that pulled that in would answer about a file the
    /// assertion was never about. = = The `+` separator is the tree's
    /// own convention for a file split OUT of another, = = and a split
    /// file sits beside the file it was split out of, = = so the group is
    /// exactly "the stem and the pieces split out of it".
    static func filesUnderSources(inGroupOf stem: String) throws -> [String] {
        let sourcesRoot = url("Sources")
        guard let walker = FileManager.default.enumerator(
            at: sourcesRoot,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            throw CocoaError(.fileReadUnknown)
        }
        var all: [String] = []
        for case let entry as URL in walker
            where entry.pathExtension == "swift"
        {
            let relative = entry.path
                .replacingOccurrences(of: repoRoot.path + "/", with: "")
            // A previous build's intermediates can shadow the real
            // source; they are never the file under test.
            if !relative.contains("/.build/") {
                all.append(relative)
            }
        }
        guard let stemPath = all.first(where: { pathWithoutExtension(of: $0) == stem }) else {
            return []
        }
        let directory = (stemPath as NSString).deletingLastPathComponent
        return all.filter { path in
            let name = pathWithoutExtension(of: path)
            guard name.hasPrefix(stem) else { return false }
            guard (path as NSString).deletingLastPathComponent == directory else { return false }
            // The stem itself, or a piece split out of it.
            return name == stem || name.hasPrefix(stem + "+")
        }.sorted()
    }

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
            where entry.lastPathComponent == fileName && entry.pathExtension == "swift"
        {
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

    /// Every `.swift` path under Sources/, repo-root relative.
    ///
    /// WHY: a gate whose claim is about a TYPE (= "no production file
    /// reaches this member") cannot name its candidates in advance, = =
    /// the candidates are every file that mentions the type, = = and
    /// that set is a property of the tree, = = not of the reader. = ⇒
    /// So the reader takes the tree.
    ///
    /// ORDER: sorted, = = so a reader that pins a line number or a
    /// block's neighbours reads the same text every run.
    static func swiftFilesUnderSources() throws -> [String] {
        let sourcesRoot = url("Sources")
        guard let walker = FileManager.default.enumerator(
            at: sourcesRoot,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            throw CocoaError(.fileReadUnknown)
        }
        var all: [String] = []
        for case let entry as URL in walker where entry.pathExtension == "swift" {
            let relative = entry.path
                .replacingOccurrences(of: repoRoot.path + "/", with: "")
            // A previous build's intermediates can shadow the real
            // source; they are never the file under test.
            if !relative.contains("/.build/") {
                all.append(relative)
            }
        }
        return all.sorted()
    }
}
