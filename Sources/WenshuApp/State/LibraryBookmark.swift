// Sources/WenshuApp/State/LibraryBookmark.swift
//
// Persists the user's active .ws library URL across launches
// using the Apple canonical security-scoped bookmark API
// (developer.apple.com/documentation/foundation/url#bookmarkdata).
//
import Foundation
// Why this exists (= the prior path-string bug):
// LibraryRootView used to store the user's picked .ws library
// root as a bare path string (@AppStorage "wenshu.libraryPath").
// That works when wenshu runs without the App Sandbox (= the
// build configuration today). Under the App Sandbox (= the
// Mac App Store distribution path), a bare path does NOT carry
// the user's grant; the app loses access on every relaunch and
// falls back to the onboarding picker.
//
// Why the implementation branches on sandbox:
//   .withSecurityScope is the Apple HIG canonical option for sandboxed
//   builds (developer.apple.com/documentation/foundation/url/bookmarkdataoptions/
//   securityscope). When the build is sandboxed, the bookmark data
//   carries an opaque sandbox signature that ONLY resolves in the
//   same sandboxed process. When the build is non-sandboxed
//   (= wenshu's current ad-hoc-codesigned distribution), passing
//   .withSecurityScope causes CoreFoundation to reject the bookmark
//   at resolve time with NSCocoaErrorDomain Code 259 ("isn't in
//   the correct format"). The fix = use .withSecurityScope only when
//   the process is sandboxed; otherwise use an empty options set
//   (= the bookmark is still a URL handle, but without the
//   sandbox-side grant because no grant is needed in a non-sandbox
//   process). The two persistence formats are mutually compatible
//   for reading within their own process class; the producer side
//   just picks the format that matches the producer's sandbox class.
//
// What this file does:
//   1. LibraryBookmark.make(for:) turns the URL the user just picked
//     into a `Data` blob that encodes both the path and (in sandboxed
//     builds) the sandbox grant. Persisted to UserDefaults as
//     'wenshu.libraryBookmark'.
//   2. LibraryBookmark.resolve() turns that Data back into a URL on
//     the next launch, refreshes it if stale, and returns nil if
//     the path no longer exists. The caller MUST then call
//     url.startAccessingSecurityScopedResource() /
//     url.stopAccessingSecurityScopedResource() around the I/O (no-op
//     when the bookmark has no security scope).
//   3. The 'wenshu.libraryPath' string was retired by a one-shot
//     migration in WenshuAppDelegate (= the migration runs on
//     launch and deletes the key; = the bookmark is the sole
//     persistence from then on).
//
// Failure modes (= Apple HIG canonical for each path):
//   - User picked a bundle in the App Sandbox but the bookmark
//     Data was wiped / corrupted -> resolve() returns nil.
//     LibraryRootView falls back to the existing onboarding trigger.
//   - User moved/renamed the .ws folder -> URL.resolvingBookmarkData
//     sets isStale = true; we re-bookmark if the URL still resolves.
//   - User deleted the .ws folder entirely -> resolve() returns nil
//     because bookmarkData can't be decoded to a valid URL.
//   - The build's sandbox class differs from when the bookmark
//     was originally created (= the producer and reader are in
//     different sandbox states) -> resolve() returns Code 259
//     and we clear the stale bookmark so the user re-enters
//     onboarding next launch (= a one-time migration pain, not
//     recurring).

/// Security-scoped bookmark persistence for the user's single
/// .ws library.
///
/// Apple HIG macOS App Sandbox canonical pattern
/// (developer.apple.com/documentation/foundation/url#bookmarkdata(options:includingresourcevaluesforkeys:relativeto:)).
/// Without the bookmark, the user has to re-pick the library
/// after every relaunch when the App Sandbox is enabled (= Mac
/// App Store distribution).
enum LibraryBookmark {
    /// UserDefaults key for the persisted security-scoped
    /// bookmark Data. Kept distinct from the retired
    /// 'wenshu.libraryPath' string (= one-shot migration in
    /// WenshuAppDelegate).
    static let defaultsKey = "wenshu.libraryBookmark"

    /// Returns true when the current process is sandboxed
    /// (= the Mac App Store distribution path). Non-sandboxed
    /// builds (= the current ad-hoc-codesigned distribution)
    /// return false here, and LibraryBookmark.make/writer skips
    /// the security-scope option (= see the file header for the
    /// rationale).
    static var isSandboxedProcess: Bool {
        // RATIONALE: the canonical sandbox probe on macOS is the
        // APP_SANDBOX_CONTAINER_ID environment variable (= set by
        // the kernel when the App Sandbox profile is active; = the
        // only Apple-blessed runtime indicator that works for both
        // Apple-signed and ad-hoc-codesigned processes). The check
        // is cheap (= the env table is in-process) and stable for the
        // lifetime of the process. Per the macOS App Sandbox design
        // guide (developer.apple.com/documentation/security/app_sandbox),
        // "the existence of the APP_SANDBOX_CONTAINER_ID env
        // variable indicates that your app is sandboxed." Returning
        // false in non-sandboxed builds avoids writing a sandbox
        // signature into the bookmark Data that the same
        // non-sandboxed process could not subsequently decode
        // (= NSCocoaErrorDomain Code 259; = see file header for the
        // failure mode).
        ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil
    }

    /// Generate a security-scoped bookmark from a URL the user
    /// just selected through `.fileImporter` / `NSOpenPanel` /
    /// `NSSavePanel`. The returned `Data` encodes the path and
    /// (in sandboxed builds) the sandbox grant; persisting it
    /// preserves both across relaunches.
    static func make(for url: URL) throws -> Data {
        // RATIONALE: the options set matches the build's
        // sandbox class. .withSecurityScope is the Apple HIG
        // canonical option for sandboxed builds; omitting it is
        // the canonical choice for non-sandboxed builds (the
        // security-scope signature would otherwise be a
        // round-trip failure = NSCocoaErrorDomain Code 259 at
        // resolve time). See file header for the full context.
        try url.bookmarkData(
            options: isSandboxedProcess ? .withSecurityScope : [],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }

    /// Persist the bookmark Data to UserDefaults.
    static func save(_ data: Data) {
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }

    /// Resolve the persisted bookmark to a URL.
    /// Returns nil if no bookmark exists (= first launch + not
    /// sandboxed is fine), or if the bookmark cannot be decoded
    /// (= corrupted / path deleted / sandbox-class mismatch
    /// between producer and reader). Refreshes the stored
    /// bookmark when `isStale` reports that the path moved
    /// (= Apple canonical handling).
    ///
    /// Per Apple docs the caller MUST pair this with
    /// `url.startAccessingSecurityScopedResource()` before I/O
    /// and `url.stopAccessingSecurityScopedResource()` when
    /// finished. Both calls are no-ops when the bookmark has
    /// no security scope (= the non-sandboxed case).
    /// LibraryRootView wires that pair in its `.task` lifecycle.
    static func resolve() -> URL? {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else {
            return nil
        }
        // RATIONALE: the options set must match the producer's
        // sandbox class. .withSecurityScope is required to decode
        // a sandboxed bookmark; omitting it succeeds for a
        // non-sandboxed bookmark. If the producer and reader
        // sandbox classes disagree (= the build's sandbox state
        // differs from the state under which the bookmark was
        // originally created), CoreFoundation returns Code 259
        // and we drop the stale bookmark so the user re-enters
        // onboarding next launch; = see file header for the
        // failure mode.
        let resolveOptions: URL.BookmarkResolutionOptions =
            isSandboxedProcess ? .withSecurityScope : []
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: resolveOptions,
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
                options: isSandboxedProcess ? .withSecurityScope : [],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            ) {
                UserDefaults.standard.set(fresh, forKey: defaultsKey)
            }
        }
        return url
    }

    /// Remove the persisted bookmark (= called when the user
    /// picks a different .ws library or resets the storage).
    static func clear() {
        UserDefaults.standard.removeObject(forKey: defaultsKey)
    }
}