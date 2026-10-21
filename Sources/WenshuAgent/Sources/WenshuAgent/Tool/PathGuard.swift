//
//  PathGuard.swift
//
//  Allow-list path policy for wenshu built-in tools. Lives in
//  Core/Agent/Tool/ (= agent-runtime concern, = same layer as
//  ToolExecutor that consumes it; = no infra-layer dependency
//  from Core/Tools/ upward; = fixes v1's design-check §2
//  Module Boundary FAIL where the file was placed in
//  Core/Tools/ but called by Core/Agent/).
//
//  Policy: every path an LLM feeds to a wenshu built-in tool
//  must resolve inside the user's selected .ws library root
//  (= LibraryPath). Paths outside the library root are rejected
//  with a typed error. This is an allow-list (= not a deny-
//  list); = a deny-list can miss user-private paths
//  (~/.ssh/, /private/tmp/, etc.) while an allow-list scoped
//  to one root cannot.
//
//  Attachment uploads (ChatSessionViewModel.attachImageIntoLibrary)
//  write to <libraryPath>/cache/chat-uploads/ (= inside .ws),
//  so they pass the guard naturally without an exemption.
//
//  Symlink resolution: paths are resolved against the real
//  path (URL.resolvingSymlinksInPath + standardizedFileURL)
//  before comparison, so a symlink whose target is outside
//  the library root cannot be used to escape the guard.
//
//  If the library root is not configured (= UserDefaults has
//  no wenshu.libraryPath), every path check rejects (= no
//  implicit fallback to home / tmp / etc.).
//
//  Replaces v1's WenshuSandbox enum (= same semantics, =
//  typed inputs via PathGuardInput / LibraryPath / RelativePath,
//  = renamed to PathGuard per design-check §7 Naming:
//  "Wenshu" prefix is redundant (= module = WenshuApp) and
//  "Sandbox" implies Apple's kernel-level process sandbox
//  (= a different concept from this allow-list policy).
//

import Foundation
import os.log

public enum PathGuard {

    private static let logger = Logger(
        subsystem: "ai.wenshu.app",
        category: "PathGuard"
    )

    // MARK: - Errors

    public enum GuardError: Error, LocalizedError, Sendable, Equatable {
        case libraryRootUnconfigured
        case pathOutsideLibrary(resolved: LibraryPath, root: LibraryPath)
        case invalidPath(reason: String)

        public var errorDescription: String? {
            switch self {
            case .libraryRootUnconfigured:
                return "PathGuard: library root is not configured."
            case .pathOutsideLibrary(let resolved, let root):
                // Surface only the basename to avoid leaking
                // absolute paths to the chat UI. The full resolved
                // path is logged at debug level for diagnostics.
                logger.debug("PathGuard rejected path: resolved=\(resolved.rawValue, privacy: .private) root=\(root.rawValue, privacy: .private)")
                let basename = (resolved.rawValue as NSString).lastPathComponent
                return "PathGuard: '\(basename)' is outside the library root."
            case .invalidPath(let reason):
                return "PathGuard: invalid path (\(reason))."
            }
        }

        public static func == (lhs: GuardError, rhs: GuardError) -> Bool {
            switch (lhs, rhs) {
            case (.libraryRootUnconfigured, .libraryRootUnconfigured):
                return true
            case (.pathOutsideLibrary(let a1, let a2), .pathOutsideLibrary(let b1, let b2)):
                return a1 == b1 && a2 == b2
            case (.invalidPath(let a), .invalidPath(let b)):
                return a == b
            default:
                return false
            }
        }
    }

    // MARK: - Library root resolution

    /// The app's library-root accessor, installed by the app.
    ///
    /// The runtime cannot reach the app's storage layer, so the app
    /// supplies the path it resolves. The closure is read at the moment
    /// a path is checked, not captured at install time, so a library
    /// picked after launch is still guarded correctly.
    nonisolated(unsafe) public static var libraryRootProvider: (@Sendable () -> String?)?

    /// Test-only override for the library root.
    ///
    /// Apple HIG canonical pattern for test seams: `@TaskLocal` = the
    /// value lives in the current Swift task's context only; = tests
    /// wrap their body in
    /// `PathGuard.$libraryRootOverride.withValue(value) { ... }`
    /// = the override is automatically scoped to that block; = no
    /// cross-suite pollution; = no per-suite init() reset needed; =
    /// Swift 6 strict-concurrency safe (no `nonisolated(unsafe)`).
    ///
    /// The seam lives here, next to its only consumer, so a test can
    /// set the root the guard reads without the app's launch path
    /// running.
    @TaskLocal
    public static var libraryRootOverride: String?

    /// Resolve the library root (= the canonical single source of
    /// truth; = the security-scoped bookmark).
    ///
    /// The test override wins, so a test can pin the root without the
    /// app's provider being installed. Otherwise the app's provider
    /// answers. Returns nil when no library is bound (= pre-onboarding
    /// state, or the bookmark can't be resolved).
    public static func resolveLibraryRoot() -> LibraryPath? {
        if let override = libraryRootOverride { return LibraryPath(rawValueOrNil: override) }
        guard let raw = libraryRootProvider?() else { return nil }
        return LibraryPath(rawValueOrNil: raw)
    }

    /// Canonical library root path (= symlinks collapsed).
    public static func resolveLibraryRootCanonical() -> LibraryPath? {
        guard let root = resolveLibraryRoot() else { return nil }
        return LibraryPath(rawValue: root.canonicalPath)
    }

    // MARK: - Path assertion

    /// Assert `path` (absolute or library-relative) resolves inside
    /// the library root. Throws `GuardError` on failure.
    public static func assertInsideLibrary(path: String) throws {
        let root = try requireRoot()
        let resolved = try resolveAgainstRoot(path: path, root: root)
        let resolvedLibPath = LibraryPath(rawValue: resolved)
        guard isInside(resolved: resolvedLibPath, root: root) else {
            throw GuardError.pathOutsideLibrary(resolved: resolvedLibPath, root: root)
        }
    }

    /// Assert a `LibraryPath` (absolute path already typed) is inside
    /// the library root. Useful for tool bodies that have already
    /// constructed a `LibraryPath` from a UUID (= e.g. BookChapterTool).
    public static func assertInsideLibrary(path: LibraryPath) throws {
        let root = try requireRoot()
        let resolved = LibraryPath(rawValue: path.canonicalPath)
        guard isInside(resolved: resolved, root: root) else {
            throw GuardError.pathOutsideLibrary(resolved: resolved, root: root)
        }
    }

    /// Boolean variant. Useful in `if` / `guard` where the caller
    /// wants to render a tool-specific error rather than the guard
    /// error.
    public static func isInsideLibrary(path: String) -> Bool {
        do {
            try assertInsideLibrary(path: path)
            return true
        } catch {
            return false
        }
    }

    public static func isInsideLibrary(path: LibraryPath) -> Bool {
        do {
            try assertInsideLibrary(path: path)
            return true
        } catch {
            return false
        }
    }

    // MARK: - Pre-dispatch validator

    /// Path-bearing keys inspected by the default validator.
    /// Extensible (= future tools add keys here without changing
    /// the validator signature).
    public static let pathKeys: [String] = [
        "path", "file", "cwd", "from", "to", "rootDir"
    ]

    /// Default validator closure for `ToolExecutor.preDispatchValidator`.
    /// Inspects the typed input for known path keys and rejects any
    /// value that resolves outside the library root.
    ///
    /// Returns the input unchanged on success (= the validator is a
    /// pure pass-through; = per-key transformation lives in the
    /// per-tool pre-dispatch hook chain, not here).
    ///
    /// When the library root is not configured, this validator throws
    /// (no implicit allow).
    public nonisolated static func preDispatchValidator(
        toolName: String,
        input: PathGuardInput
    ) throws -> PathGuardInput {
        for key in pathKeys {
            guard let value = input.string(forKey: key) else { continue }
            do {
                try assertInsideLibrary(path: value)
            } catch let error as GuardError {
                throw ToolExecutorError.pathGuardViolation(
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

    private static func requireRoot() throws -> LibraryPath {
        guard let root = resolveLibraryRootCanonical() else {
            throw GuardError.libraryRootUnconfigured
        }
        return root
    }

    /// Resolve `path` (= absolute or library-relative) against the
    /// library root, then canonicalize symlinks + `.` / `..`.
    private static func resolveAgainstRoot(
        path: String,
        root: LibraryPath
    ) throws -> String {
        if path.isEmpty {
            throw GuardError.invalidPath(reason: "empty string")
        }
        let url: URL
        if path.hasPrefix("/") {
            url = URL(fileURLWithPath: path)
        } else {
            // Relative: anchor to library root. Use string concat so
            // url.path contains the resolved root segment (= matches
            // the runtime CWD resolver pattern in RuntimeCWD.swift).
            let rootClean = root.canonicalPath
            url = URL(fileURLWithPath: "\(rootClean)/\(path)")
        }
        let resolvedURL = url.resolvingSymlinksInPath().standardizedFileURL
        return resolvedURL.path
    }

    /// Is `resolved` inside the directory tree rooted at `root`?
    /// Compares canonical path strings with a trailing-slash anchor
    /// so `/path/to/ws` is considered inside `/path/to/ws` but
    /// `/path/to/wsfoo` is not (= prefix-match trap).
    private static func isInside(
        resolved: LibraryPath,
        root: LibraryPath
    ) -> Bool {
        let resolvedRaw = resolved.canonicalPath
        let rootRaw = root.canonicalPath
        let rootSlash = rootRaw.hasSuffix("/") ? rootRaw : rootRaw + "/"
        let rootExact = rootRaw.hasSuffix("/") ? String(rootRaw.dropLast()) : rootRaw
        return resolvedRaw == rootExact || resolvedRaw.hasPrefix(rootSlash)
    }
}