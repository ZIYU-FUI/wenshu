//
//  ActiveLibrary.swift · Wenshu
//
//  Single canonical accessor for the user's active .ws library URL.
//
//  Per the boss 2026-10-05 OOB: 'we have no users; before release we
//  don't need forward-compat'. One source of truth (=
//  LibraryBookmark's security-scoped bookmark Data; see
//  State/LibraryBookmark.swift). No legacy fallback path. The
//  previous 'wenshu.libraryPath' UserDefaults string is removed
//  (= see State/LibraryBookmark.swift where the UserDefaults key is
//  cleared on next launch).
//
//  Every Sources/WenshuApp consumer that needs the active library's
//  URL must go through `ActiveLibrary.path` (= canonical single
//  entry point). Reading 'wenshu.libraryPath' directly is removed.
//

import Foundation

/// Single source of truth for the user's active .ws library path string.
///
/// Apple HIG canonical pattern (= security-scoped bookmark).
/// Per boss 2026-10-05 OOB: 'no users, no forward compat'; = the
/// bookmark is the SOLE persistence. Consumers call `ActiveLibrary.path`
/// instead of `UserDefaults.standard.string(forKey: "wenshu.libraryPath")`.
enum ActiveLibrary {
    /// The active .ws library path string (= the bookmark-resolved
    /// path). Returns nil when no library has been picked yet (= the
    /// onboarding picker will be shown) or when the persisted
    /// bookmark cannot be decoded (= the folder moved/deleted; = the
    /// user has to pick again).
    ///
    /// Pure read; no I/O. Callers that need the security-scoped grant
    /// (= sandboxed builds only) must additionally call
    /// `url.startAccessingSecurityScopedResource()` around their
    /// file I/O. Today wenshu is non-sandboxed (= every existing
    /// consumer just reads via URL APIs; = no scope activation
    /// needed yet), but the seam is here so the Mac App Store
    /// distribution does not need a rewrite.
    ///
    /// `nonisolated` (= Swift 6 strict-concurrency safe; = the
    /// underlying `LibraryBookmark.resolve` is pure and Sendable).
    /// The `#if DEBUG` block reads the test override hook (= the
    /// only mutation surface; = production callers never see the
    /// `overrideForTesting` symbol).
    static nonisolated var path: String? {
        #if DEBUG
        if let testOverride = Self.overrideForTesting {
            return testOverride
        }
        #endif
        return LibraryBookmark.resolve()?.path
    }

    /// Test-only override hook. Visible only in DEBUG builds via
    /// the `#if DEBUG` block on `path`. Tests in
    /// `Tests/WenshuAppTests/` set this in their `init()` to mock the
    /// active library without touching the security-scoped bookmark
    /// persistence (= which is why the legacy 'wenshu.libraryPath'
    /// UserDefaults string was deleted; = tests can no longer reach
    /// into a UserDefaults key).
    ///
    /// `nonisolated(unsafe)` (= Swift 6 strict-concurrency = tests
    /// are .serialized on the main actor; = write/read is in practice
    /// single-threaded across the suite; = the compiler's concurrency
    /// checker is told to trust us). Always nil in production (= the
    /// `path` accessor only reads it under `#if DEBUG`).
    nonisolated(unsafe) static var overrideForTesting: String? = nil

    /// Call when the user picks a new .ws library (= from
    /// LibraryRootView's onboarding completion). Generates the
    /// security-scoped bookmark Data + replaces any previous
    /// bookmark (= no fallback, no coexistence).
    static func setActiveLibrary(at url: URL) throws {
        let data = try LibraryBookmark.make(for: url)
        LibraryBookmark.save(data)
    }

    /// Call when the user resets the library (= moves to a different
    /// .ws bundle). Drops the bookmark; next launch will show
    /// onboarding.
    static func clear() {
        LibraryBookmark.clear()
    }
}