// ActiveLibrary.swift · Wenshu Single canonical accessor for the user's active .ws
// library URL. Per the boss 2026-10-05 (see OOB.md #2026-10-05) don't need forward-
// compat'. One source of truth (= LibraryBookmark's security-scoped bookmark Data; see
// State/LibraryBookmark.swift). No legacy fallback path. The previous
// 'wenshu.libraryPath' UserDefaults string is removed (= see
// State/LibraryBookmark.swift where the UserDefaults key is cleared on next launch).
// Every Sources/WenshuApp consumer that needs the active library's URL must go through
// `ActiveLibrary.path` (= canonical single entry point). Reading 'wenshu.libraryPath'
// directly is removed.

import Foundation
import WenshuAgent

/// Single source of truth for the user's active .ws library path string.
///
/// Apple HIG canonical pattern (= security-scoped bookmark).
/// Per boss 2026-10-05 (see OOB.md #2026-10-05)
/// bookmark is the SOLE persistence. Consumers call `ActiveLibrary.path`
/// instead of `UserDefaults.standard.string(forKey: "wenshu.libraryPath")`.
enum ActiveLibrary {
    /// The active .ws library path string (= the bookmark-resolved
    /// path). Returns nil when no library has been picked yet (= the
    /// onboarding picker will be shown) or when the persisted
    /// bookmark cannot be decoded (= the folder moved/deleted; = the
    /// user has to pick again).
    ///
    /// Pure read of what the app already holds; no file is opened. It
    /// is NOT free (= the bookmark decode is a UserDefaults read plus
    /// `URL(resolvingBookmarkData:)`), and it is now COUNTED, because a
    /// frame may not pay it per card (= CoverDiskCounting, counted by
    /// the cover suite that measures lookups per pass). Callers that
    /// need the security-scoped grant
    /// (= sandboxed builds only) must additionally call
    /// `url.startAccessingSecurityScopedResource()` around their
    /// file I/O. Today wenshu is non-sandboxed (= every existing
    /// consumer just reads via URL APIs; = no scope activation
    /// needed yet), but the seam is here so the Mac App Store
    /// distribution does not need a rewrite.
    ///
    /// `nonisolated` (= Swift 6 strict-concurrency safe; = the
    /// underlying `LibraryBookmark.resolve` is pure and Sendable).
    /// The `#if DEBUG` block reads the test override hook
    /// (= `PathGuard.libraryRootOverride`; = the only mutation
    /// surface; = production callers never see the override symbol).
    ///
    /// The override is a `@TaskLocal` that lives in the runtime
    /// package (= `PathGuard`), next to the path guard that reads it:
    /// a task local's storage is per-module, so the package cannot
    /// read one the app declares. Tests scope it with
    /// `PathGuard.$libraryRootOverride.withValue(root) { ... }`.
    nonisolated static var path: String? {
        // The visit is counted BEFORE either branch answers it, and that
        // placement is the whole point: under DEBUG the override returns
        // first and `LibraryBookmark.resolve()` is never reached, so a
        // counter sitting behind this line would prove nothing in the
        // test binary about a cost production pays on every card
        // (= CoverDiskCounting).
        CoverDiskCounting.noteLibraryLookup()
        #if DEBUG
            if let testOverride = PathGuard.libraryRootOverride {
                return testOverride
            }
        #endif
        return LibraryBookmark.resolve()?.path
    }

    /// Call when the user picks a new .ws library (= from
    /// LibraryRootView's onboarding completion). Generates the
    /// security-scoped bookmark Data + replaces any previous
    /// bookmark (= no fallback, no coexistence).
    static func setActiveLibrary(at url: URL) throws {
        let data = try LibraryBookmark.make(for: url)
        LibraryBookmark.save(data)
        // No cover cache is dropped here. A cover answer is kept under
        // the library it was read from (= CoverEntryCache), so the new
        // library cannot be answered from the old one's folders, and
        // dropping the old answers would only mean reading them again
        // if the user switches back.
    }

    /// Call when the user resets the library (= moves to a different
    /// .ws bundle). Drops the bookmark; next launch will show
    /// onboarding.
    static func clear() {
        // The library being left may have had covers deleted while the
        // app was not looking, so its answers are the ones that are
        // dropped; every other library's answers are still its own.
        CoverEntryCache.shared.removeAll(forRoot: CardCoverService.coversRoot)
        LibraryBookmark.clear()
    }
}
