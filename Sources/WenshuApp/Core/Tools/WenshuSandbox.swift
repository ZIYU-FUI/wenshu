//
//  WenshuSandbox.swift · Wenshu · wt/sandbox-tighten-2026-09-25
//
//  Path-scoped sandbox for wenshu built-in tools.
//
//  Policy: every path the agent feeds to a wenshu built-in tool
//  must resolve inside the user's selected `.ws` library root (= the
//  path stored at UserDefaults `wenshu.libraryPath` per AGENTS.md
//  §11 baseline). Paths outside the library root are rejected with
//  a typed error.
//
//  This is an allow-list (= not a deny-list). A deny-list can miss
//  user-private paths (`~/.ssh/`, `/private/tmp/`, etc.); an
//  allow-list scoped to one root cannot.
//
//  Attachment uploads (ChatSessionViewModel.attachImageIntoLibrary)
//  write to `<libraryPath>/cache/chat-uploads/` (= inside .ws), so
//  they pass the sandbox naturally without an exemption.
//
//  Symlink resolution: paths are resolved against the real path
//  (`URL.resolvingSymlinksInPath()` + `URL.standardized`) before
//  comparison, so an attacker cannot use a symlink to escape the
//  library root.
//
//  Inputs the helper accepts:
//    - absolute path string ("/Users/foo/.../library.ws/file.txt")
//    - path relative to the library root ("file.txt" or
//      "shelves/abc/books/xyz/chapter.md")
//    - file URL with file scheme
//
//  If the library root is not configured (= UserDefaults has no
//  wenshu.libraryPath), every path check rejects (= no implicit
//  fallback to home / tmp).
//

import Foundation

enum WenshuSandbox {

    /// Canonical UserDefaults key for the library root path (= mirrors
    /// `RuntimeCWD.libraryPathKey`; = the AGENTS.md §11 baseline).
    static let libraryPathKey = "wenshu.libraryPath"

    // MARK: - Errors

    /// Thrown when a path attempt leaves the library root (= outside
    /// `.ws`) or the library root itself is not configured.
    enum SandboxError: Error, LocalizedError, Sendable {
        case libraryRootUnconfigured
        case pathOutsideLibrary(resolvedPath: String, libraryRoot: String)
        case invalidPath(reason: String)

        var errorDescription: String? {
            switch self {
            case .libraryRootUnconfigured:
                return "Wenshu sandbox: library root is not configured. Set wenshu.libraryPath in UserDefaults (= complete onboarding first)."
            case .pathOutsideLibrary(let resolved, let root):
                return "Wenshu sandbox: path '\(resolved)' is outside the library root '\(root)'. Only paths inside the .ws library bundle are allowed."
            case .invalidPath(let reason):
                return "Wenshu sandbox: invalid path (\(reason))."
            }
        }
    }

    // MARK: - Library root resolution

    /// Resolve the library root URL from UserDefaults. Returns nil when
    /// the key is unset or empty (= pre-onboarding state).
    static func resolveLibraryRoot() -> URL? {
        let raw = UserDefaultsStore.shared.string(forKey: .libraryPath)
        guard !raw.isEmpty else { return nil }
        return URL(fileURLWithPath: raw, isDirectory: true)
    }

    /// Resolve the library root as a canonical absolute path string.
    /// Symlinks collapsed so path comparison is stable.
    static func resolveLibraryRootPath() -> String? {
        resolveLibraryRoot()?.resolvingSymlinksInPath().path
    }

    // MARK: - Path assertion (= the validator entry points)

    /// Assert `path` resolves inside the library root.
    /// - Parameter path: absolute or library-relative path string.
    /// - Throws: `SandboxError.pathOutsideLibrary` or `.libraryRootUnconfigured`.
    static func assertInsideLibrary(path: String) throws {
        let root = resolveLibraryRootPath()
        guard let root else {
            throw SandboxError.libraryRootUnconfigured
        }
        let resolved = try resolveAgainstRoot(path: path, root: root)
        guard isInside(resolved: resolved, root: root) else {
            throw SandboxError.pathOutsideLibrary(resolvedPath: resolved, libraryRoot: root)
        }
    }

    /// Assert `url` (file URL) resolves inside the library root.
    static func assertInsideLibrary(url: URL) throws {
        try assertInsideLibrary(path: url.path)
    }

    /// Boolean variant of `assertInsideLibrary(path:)`. Useful in
    /// `if`/`guard` where the caller wants to render a tool-specific
    /// error message rather than the sandbox error.
    static func isInsideLibrary(path: String) -> Bool {
        do {
            try assertInsideLibrary(path: path)
            return true
        } catch {
            return false
        }
    }

    static func isInsideLibrary(url: URL) -> Bool {
        isInsideLibrary(path: url.path)
    }

    // MARK: - Pre-dispatch validator

    /// Default validator closure for `ToolExecutor.preDispatchValidator`.
    /// Inspects the input dictionary for known path keys
    /// (`path`, `file`, `cwd`, `from`, `to`, `rootDir`) and rejects any
    /// value that resolves outside the library root.
    ///
    /// Path keys that DO NOT contain a filesystem path (= e.g. URLs
    /// for web tools, regex strings for search) are ignored here;
    /// = the per-tool pre-dispatch hook chain handles URL/regex
    /// validation separately.
    ///
    /// When the library root is not configured, this validator
    /// throws (no implicit allow). Callers wanting to test the
    /// sandbox without onboarding can pre-set `wenshu.libraryPath`
    /// in UserDefaults.
    static func preDispatchValidator(
        toolName: String,
        input: [String: String]
    ) throws -> [String: String] {
        let pathKeys = ["path", "file", "cwd", "from", "to", "rootDir"]
        for key in pathKeys {
            guard let value = input[key], !value.isEmpty else { continue }
            do {
                try assertInsideLibrary(path: value)
            } catch let error as SandboxError {
                throw ToolExecutorError.sandboxViolation(
                    toolName: toolName,
                    key: key,
                    underlying: error
                )
            } catch {
                throw error
            }
        }
        return input
    }

    // MARK: - Internal helpers

    /// Resolve `path` (= absolute or library-relative) against the
    /// library root, then canonicalize symlinks + `.`/`..`.
    static func resolveAgainstRoot(path: String, root: String) throws -> String {
        if path.isEmpty {
            throw SandboxError.invalidPath(reason: "empty string")
        }
        let url: URL
        if path.hasPrefix("/") {
            url = URL(fileURLWithPath: path)
        } else {
            // Relative: anchor to library root. Use string concat so
            // `url.path` contains the resolved root segment (= matches
            // the runtime CWD resolver pattern in RuntimeCWD.swift).
            let rootClean = root.hasSuffix("/") ? String(root.dropLast()) : root
            url = URL(fileURLWithPath: "\(rootClean)/\(path)")
        }
        // resolvingSymlinksInPath collapses `..`, `.`, and symlink
        // hops. standardized then collapses trailing slashes etc.
        let resolvedURL = url.resolvingSymlinksInPath().standardized
        return resolvedURL.path
    }

    /// Is `resolved` inside the directory tree rooted at `root`?
    /// Compares canonical path strings with a trailing-slash anchor
    /// so `/path/to/ws` is considered inside `/path/to/ws` but
    /// `/path/to/wsfoo` is not (= prefix-match trap).
    static func isInside(resolved: String, root: String) -> Bool {
        let rootSlash = root.hasSuffix("/") ? root : root + "/"
        let rootExact = root.hasSuffix("/") ? String(root.dropLast()) : root
        return resolved == rootExact || resolved.hasPrefix(rootSlash)
    }
}