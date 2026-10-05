//
//  LibraryBookmark.swift · Wenshu
//
//  Apple HIG canonical single-library persistence (macOS 10.27+).
//
//  Why this exists (= the v0.x '' bug):
//  LibraryRootView previously stored the user's picked .ws library
//  root as a bare path string (@AppStorage "wenshu.libraryPath").
//  That works when wenshu runs without the App Sandbox (= today).
//  Under the App Sandbox (= the Mac App Store distribution path),
//  a bare path does NOT carry the user's grant; the app loses
//  access on every relaunch and falls back to the onboarding
//  picker. Apple's canonical answer is the security-scoped bookmark:
//  developer.apple.com/documentation/foundation/nsurl#bookmarkdata
//
//  What this file does:
//  1. LibraryBookmark.make(for:) turns the URL the user just picked
//     into a `Data` blob that encodes both the path and the sandbox
//     grant. Persisted to UserDefaults as 'wenshu.libraryBookmark'.
//  2. LibraryBookmark.resolve() turns that Data back into a URL on
//     the next launch, refreshes it if stale, and returns nil if
//     the path no longer exists. The caller MUST then call
//     url.startAccessingSecurityScopedResource() /
//     url.stopAccessingSecurityScopedResource() around the I/O.
//  3. The 'wenshu.libraryPath' string remains the source of truth for
//     every existing consumer (= 10+ call sites under Sources/WenshuApp/
//     Core/Chat, Core/Agent, App/WenshuAppDelegate, etc.). We do not
//     touch that surface in this commit. The bookmark is an additive
//     second source of truth whose only consumer is the sandbox-aware
//     I/O path; non-sandboxed runs keep working unchanged because the
//     string path still resolves and exists on disk.
//
//  Failure modes (= acceptable per Apple HIG for the no-bookmark case):
//  - User picked a bundle in the App Sandbox but the bookmark Data was
//     wiped / corrupted -> resolve() returns nil. LibraryRootView falls
//     back to the existing path-based onboarding trigger.
//  - User moved/renamed the .ws folder -> URL.resolvingBookmarkData
//     sets isStale = true; we re-bookmark if the URL still resolves.
//  - User deleted the .ws folder entirely -> resolve() returns nil
//     because bookmarkData can't be decoded to a valid URL.
//

import Foundation

/// Security-scoped bookmark persistence for the user's single .ws library.
///
/// Apple HIG macOS App Sandbox canonical pattern (= developer.apple.com/
/// documentation/foundation/url#bookmarkdata(options:includingresourcevaluesforkeys:relativeto:)).
/// Without this, the user has to re-pick the library after every relaunch
/// when the App Sandbox is enabled (= Mac App Store distribution).
enum LibraryBookmark {
    /// UserDefaults key for the persisted security-scoped bookmark Data.
    /// Kept distinct from 'wenshu.libraryPath' (= the legacy storage key)
    /// so non-sandboxed builds keep working without the bookmark.
    static let defaultsKey = "wenshu.libraryBookmark"

    /// Generate a security-scoped bookmark from a URL the user just
    /// selected through `.fileImporter` / `NSOpenPanel` / `NSSavePanel`.
    /// The returned `Data` encodes the path + the sandbox grant;
    /// persisting it preserves both across relaunches.
    static func make(for url: URL) throws -> Data {
        try url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }

    /// Persist the bookmark Data to UserDefaults.
    static func save(_ data: Data) {
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }

    /// Resolve the persisted bookmark to a URL.
    /// Returns nil if no bookmark exists (= first launch + not sandboxed
    /// is fine), or if the bookmark cannot be decoded (= corrupted /
    /// path deleted). Refreshes the stored bookmark when `isStale`
    /// reports that the path moved (= Apple canonical handling).
    ///
    /// Per Apple docs the caller MUST pair this with
    /// `url.startAccessingSecurityScopedResource()` before I/O and
    /// `url.stopAccessingSecurityScopedResource()` when finished.
    /// LibraryRootView wires that pair in its `.task` lifecycle.
    static func resolve() -> URL? {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else {
            return nil
        }
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: .withSecurityScope,
            bookmarkDataIsStale: &isStale
        ) else {
            // Bookmark can't be decoded. Clear so we don't keep
            // attempting on every launch (= silent failure mode
            // described in Apple's QA1941).
            UserDefaults.standard.removeObject(forKey: defaultsKey)
            return nil
        }
        if isStale {
            // Path moved but URL still resolves. Refresh so future
            // launches don't accumulate staleness (= mq-dir deep dive).
            if let fresh = try? url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            ) {
                UserDefaults.standard.set(fresh, forKey: defaultsKey)
            }
        }
        return url
    }

    /// Remove the persisted bookmark (= called when the user picks a
    /// different .ws library or resets the storage).
    static func clear() {
        UserDefaults.standard.removeObject(forKey: defaultsKey)
    }
}