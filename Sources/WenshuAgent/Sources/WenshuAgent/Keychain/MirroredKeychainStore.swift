// MirroredKeychainStore.swift · Wenshu
//
// Mirrored dual-store backend for `ProviderKeychain`. Companion to
// `AppleKeychainStore` (= Apple Keychain) and `FileProviderKeyStore` (=
// `~/Library/Application Support/com.wenshu.app/provider-keys.json`).
//
// Per boss 2026-10-16 OOB "在用户配 key 的时候, 就两头存.
// 无论用户怎么开关, 只是切换读 key 的位置": every key write goes
// to BOTH stores; every key read consults BOTH stores; the
// user-facing toggle (`wenshu.useKeychainForProviderKeys`) only
// decides which store is the PRIMARY for reads (the secondary
// is consulted as a fallback when the primary returns nil).
//
// The previous behavior (= the `2a132f25c` toggle commit) had
// the read path select ONE store based on the toggle, and the
// write path write to ONE store based on the toggle. Boss
// identified a real bug: if the user configured a key with the
// toggle ON (= key landed in Apple Keychain), then flipped the
// toggle OFF, the read path consulted the file store, got nil,
// and the chat empty-state showed up (= "key 没配"). The
// same bug applied in reverse (configured with toggle OFF, then
// flipped ON).
//
// Fix: this backend always writes BOTH stores. The toggle
// continues to control which is the read PRIMARY (= matches
// the user's current intent), but the read SECONDARY acts as
// automatic recovery: when the user flips the toggle, the next
// read falls back to the other store. Once the key is read
// successfully from the secondary, it is RE-WRITTEN to the
// primary (so the next read doesn't need the fallback). The
// user never has to re-enter the key.
//
// Security notes (= preserves all hard rules from `2a132f25c`):
// 1. File path stays at
//    `~/Library/Application Support/com.wenshu.app/provider-keys.json`
//    (= NOT inside the `.ws` library; = the wenshu AI agent's
//    filesystem scope is `libraryRoot`; = the file is outside
//    that scope and unreadable by the in-wenshu AI).
// 2. File mode is 0600 (= owner-only read/write; = set by
//    `FileProviderKeyStore.writeLocked`).
// 3. The file is plaintext JSON (= not encrypted at rest; = the
//    user accepts this trade-off by enabling the toggle; = the
//    file write happens regardless of the toggle to keep the
//    dual-store invariant).
//
// Thread-safety: holds one lock per inner store and serializes
// through the FileProviderKeyStore's internal NSLock. Reads from
// the Apple Keychain are synchronous and thread-safe per Apple
// Security framework docs.

import Foundation

/// Wraps two `ProviderKeychainStoring` backends and mirrors writes
/// across both. Reads consult the primary first (= the one
/// matching the current `wenshu.useKeychainForProviderKeys` toggle;
/// = `AppleKeychainStore` when ON, `FileProviderKeyStore` when OFF);
/// the secondary is consulted only when the primary returns nil.
///
/// `init` has two flavors: the production init takes a
/// `keychainPrimary: Bool` and builds the two concrete stores
/// (AppleKeychainStore + FileProviderKeyStore). The test init
/// takes arbitrary stores (= `ProviderKeychainStoring` instances;
/// = the test suite uses InMemoryKeychainStore on both sides for
/// hermetic introspection).
public final class MirroredKeychainStore: ProviderKeychainStoring, @unchecked Sendable {
    /// The two underlying stores. Both are thread-safe; = the
    /// per-store `NSLock` (File) + Apple Security framework
    /// (Keychain) cover the cross-thread cases.
    public let keychainStore: any ProviderKeychainStoring
    public let fileStore: any ProviderKeychainStoring

    /// Whether this store may reach the keychain.
    ///
    /// `nil` = decide from the build's signature. A test injects `false` to
    /// exercise the unsigned-build path without touching process-wide state,
    /// which matters because the package tests run in parallel.
    private let keychainAllowedOverride: Bool?

    /// The effective answer, resolved once per store.
    private let keychainAllowed: Bool

    /// Which store is PRIMARY for reads. Decided by
    /// `wenshu.useKeychainForProviderKeys`:
    /// - toggle ON (= default) = keychainPrimary = true
    /// - toggle OFF = keychainPrimary = false (= file is primary)
    ///
    /// Set by the caller (= the backend resolver
    /// `ProviderKeychain.resolveBackend` passes the right value
    /// here based on the toggle). Reads can flip `keychainPrimary`
    /// at any time (= the toggle change re-runs `resolveBackend`).
    public var keychainPrimary: Bool

    /// Production initializer. Builds Apple Keychain + file
    /// backends (= the canonical wenshu dual-store path).
    public init(keychainPrimary: Bool) {
        self.keychainStore = AppleKeychainStore()
        self.fileStore = FileProviderKeyStore()
        self.keychainPrimary = keychainPrimary
        self.keychainAllowedOverride = nil
        self.keychainAllowed = Self.isStableSigned
    }

    /// Test initializer. Accepts any two `ProviderKeychainStoring`
    /// backends. Used by `MirroredKeychainStoreTests` to inject
    /// two `InMemoryKeychainStore` instances for hermetic
    /// assertions on each side.
    public init(
        keychainStore: any ProviderKeychainStoring,
        fileStore: any ProviderKeychainStoring,
        keychainPrimary: Bool,
        keychainAllowed: Bool? = nil
    ) {
        self.keychainStore = keychainStore
        self.fileStore = fileStore
        self.keychainPrimary = keychainPrimary
        self.keychainAllowedOverride = keychainAllowed
        // An injected pair holds no real keychain, so the build's signature
        // says nothing about it: the injected value decides, and the default
        // (= nil) means "no restriction", which keeps the mirrored-store
        // tests asserting what they always asserted.
        self.keychainAllowed = keychainAllowed ?? true
    }

    /// Whether this store will touch the keychain.
    ///
    /// False for an unsigned build, which is what keeps the macOS permission
    /// dialog off the user's screen during development.
    public var mayUseKeychain: Bool { keychainAllowed }

    /// Whether this build has a code-signing identity macOS will remember.
    ///
    /// macOS keys the keychain's "which app asked for this" record on the
    /// code signature. An ad-hoc-signed binary (= every local development
    /// build) counts as a new app on every launch and gets prompted every
    /// launch. A signed build keeps one identity, is prompted once, and is
    /// then on the item's ACL.
    ///
    /// The test seam is `WENSHU_STABLE_SIGNING=1`: a test process is
    /// unsigned too, and without the seam every mirrored-store test would
    /// skip the mirror write those tests exist to assert.
    /// Resolved once per process: the signature cannot change while the app
    /// runs, and spawning codesign on every key write would be absurd.
    private static let stableSignedOnce: Bool = resolveStableSigning()

    /// The override the test seam sets.
    ///
    /// A process-wide override rather than an environment variable: the
    /// package tests run in parallel, and an environment variable is shared
    /// across them, so one test flipping it changes what the others see.
    nonisolated(unsafe) static var stableSigningOverride: Bool?

    /// The env seam is read on every call rather than folded into the cached
    /// value, so a test can flip it after the process has already resolved
    /// the signature once.
    static var isStableSigned: Bool {
        if let override = stableSigningOverride { return override }
        if ProcessInfo.processInfo.environment["WENSHU_STABLE_SIGNING"] == "1" {
            return true
        }
        return stableSignedOnce
    }

    private static func resolveStableSigning() -> Bool {
        guard let binary = runningBinaryURL else { return false }
        return !SigningIdentity.isAdhoc(binaryAt: binary)
    }

    /// The executable this process runs from.
    ///
    /// The bundle's own executable, not `Bundle.main.executableURL`: under
    /// XCTest the main bundle is the Apple-signed `xctest` runner, so asking
    /// it would report a stable identity for a process that is not the app.
    private static var runningBinaryURL: URL? {
        if let executable = Bundle.main.executableURL,
           !isToolchainHelper(executable.path),
           FileManager.default.fileExists(atPath: executable.path) {
            return executable
        }
        for index in 0..<_dyld_image_count() {
            guard let raw = _dyld_get_image_name(index) else { continue }
            let path = String(validatingCString: raw) ?? ""
            if path.hasSuffix("/WenshuApp"), FileManager.default.fileExists(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }
        return nil
    }

    /// Whether the path belongs to a Swift toolchain helper rather than to
    /// the app.
    ///
    /// Under `swift test` the running process is the toolchain's testing
    /// helper, which carries Apple's signature. Judging the signature of
    /// that helper would report a stable identity for a process that is
    /// emphatically not the app, so the check has to name the app's own
    /// binary instead of whatever happens to be running.
    private static func isToolchainHelper(_ path: String) -> Bool {
        path.hasSuffix("/xctest")
            || path.hasSuffix("/swiftpm-testing-helper")
            || path.contains("/Xcode.app/")
            || path.contains("/.xctest/")
    }

    /// Reads the code signature to classify the build.
    enum SigningIdentity {
        /// True when the binary carries an ad-hoc signature (= no stable
        /// identity) or no signature at all.
        ///
        /// `codesign -dv --verbose=4` prints `Signature=adhoc` for an ad-hoc
        /// binary, and an `Authority=` chain for a properly signed one. The
        /// authority chain is the discriminator, not the presence of a
        /// signature: an ad-hoc binary has a signature and no authority, and
        /// `codesign -s -` on an already-signed binary fails outright, so
        /// "does it have any signature" is the wrong question.
        static func isAdhoc(binaryAt url: URL) -> Bool {
            guard let output = codesignDescription(of: url) else { return true }
            if output.contains("Signature=adhoc") { return true }
            return !output.contains("Authority=")
        }

        /// The `codesign -dv` output, or nil when the tool is unavailable.
        ///
        /// `codesign -dv` writes the signature description to stderr, not
        /// stdout; reading only stdout yields an empty string, which would
        /// make every binary look unsigned.
        static func codesignDescription(of url: URL) -> String? {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
            process.arguments = ["-dv", "--verbose=4", url.path]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            do {
                try process.run()
            } catch {
                return nil
            }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            let output = String(decoding: data, as: UTF8.self)
            return output.isEmpty ? nil : output
        }
    }

    /// The executable this process runs from, or nil when it is not a file.
    private static var adHocSignedBinaryURL: URL? {
        var path: String?
        if let executable = Bundle.main.executableURL {
            path = executable.path
        } else {
            for index in 0..<_dyld_image_count() {
                let raw = _dyld_get_image_name(index)
                if let raw, let cString = String(validatingCString: raw) {
                    if cString.hasSuffix("/WenshuApp") {
                        path = cString
                        break
                    }
                }
            }
        }
        guard let path, FileManager.default.fileExists(atPath: path) else { return nil }
        return URL(fileURLWithPath: path)
    }

    /// True when the on-disk binary carries an ad-hoc signature rather than a
    /// Developer ID.
    ///
    /// Read from the code signature rather than inferred from the bundle
    /// identifier: a locally built .app carries a perfectly normal bundle id
    /// and is still ad-hoc signed, which is exactly the case that needs to be
    /// detected.
    static func hasDeveloperID(binaryAt url: URL) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        process.arguments = ["-dv", url.path]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        guard (try? process.run()) != nil else { return false }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let output = String(decoding: data, as: UTF8.self)
        return output.contains("Authority=Developer ID") || output.contains("Authority=Apple Development")
    }

    private var primary: any ProviderKeychainStoring {
        keychainPrimary ? keychainStore : fileStore
    }
    private var secondary: any ProviderKeychainStoring {
        keychainPrimary ? fileStore : keychainStore
    }

    // MARK: - ProviderKeychainStoring

    /// Write the key to BOTH stores. Tolerant of secondary failures
    /// (= the primary write succeeding is the contract; = the
    /// secondary failing is logged but does not throw). The
    /// canonical case for secondary failure: Apple Keychain access
    /// denied (= `errSecMissingEntitlement` on ad-hoc-signed
    /// wenshu.app) — the file write still lands, so the next
    /// read with the file-primary toggle succeeds.
    public func saveKeySync(_ key: String, for provider: Provider) throws {
        // Primary: must succeed (= caller expects a stable
        // contract: save = durably stored somewhere). Throws
        // on failure (= the Settings Save button surfaces the
        // error to the user).
        try primary.saveKeySync(key, for: provider)

        // Secondary: best-effort. Logged on failure, NOT
        // thrown. = the dual-store invariant is "the
        // secondary write is fire-and-forget; = the user
        // does not need to know it failed as long as the
        // primary succeeded". = this is the only sane
        // trade-off because the keychain access denied
        // case (= ad-hoc signed) is normal for development;
        // = throwing here would block the user from
        // configuring a key at all when only the secondary
        // (= keychain) is denied.
        // Never touch the keychain on an unsigned build. macOS decides whether
        // to prompt from the code signature, so an ad-hoc-signed binary counts
        // as a different app on every launch and the keychain asks for
        // permission each time — and it asks before returning any OSStatus, so
        // the catch below is too late to matter: the dialog has already been
        // shown by the time it runs. The check belongs before the call.
        //
        // A Developer ID build has a stable identity, the prompt does not
        // reappear, and the mirror fills in normally (= the path a released app
        // takes, and the one this toggle was written for).
        guard keychainAllowed else {
            NSLog("WSKeychain: this build may not use the keychain; skipping the mirror write")
            return
        }
        do {
            try secondary.saveKeySync(key, for: provider)
        } catch {
            NSLog("WSKeychain: secondary write to \(keychainPrimary ? "file" : "keychain") failed for \(provider.slug): \(error.localizedDescription). Primary write succeeded; the key is still retrievable from the primary.")
        }
    }

    /// Read the key. Primary first; if nil, secondary. When the
    /// secondary hit happens, re-write the key to the primary so
    /// the next read doesn't need the fallback (= self-healing;
    /// = matches the boss's "切换开关时 key 还在" requirement).
    public func loadKeySync(for provider: Provider) -> String? {
        // An unsigned build must not read the keychain either: the read
        // prompts exactly like the write does, and it does so on every
        // launch. The file store is the whole answer for such a build.
        guard keychainAllowed || !keychainParticipates else {
            return fileStore.loadKeySync(for: provider)
        }
        if let primaryValue = primary.loadKeySync(for: provider) {
            return primaryValue
        }
        // Primary returned nil (= key not in primary, OR
        // primary read was denied and the silent-fail returned
        // nil). Fall back to secondary. The
        // self-heal write to the primary is best-effort: it
        // can fail (e.g., keychain still denied) but the read
        // succeeded so the caller gets the value.
        guard let secondaryValue = secondary.loadKeySync(for: provider) else {
            return nil
        }
        // Self-heal: write the recovered value to the
        // primary so the next read is fast. The write is
        // fire-and-forget; = if it fails the user still
        // gets the value right now.
        try? primary.saveKeySync(secondaryValue, for: provider)
        return secondaryValue
    }

    /// Delete from BOTH stores. Both must succeed (= deleting
    /// from one and not the other leaves a stale key that
    /// could surprise the user later). If either fails, the
    /// error is thrown (= the Settings Delete button surfaces
    /// it to the user).
    public func deleteKeySync(for provider: Provider) throws {
        // Both stores: attempt both, throw the first error
        // (= the second deletion is still attempted so a
        // transient failure in one doesn't leave the other
        // with a stale key).
        var firstError: Error?
        do { try primary.deleteKeySync(for: provider) }
        catch { firstError = error }
        do { try secondary.deleteKeySync(for: provider) }
        catch {
            if firstError == nil { firstError = error }
        }
        if let firstError { throw firstError }
    }

    /// Union of providers-with-keys from both stores (=
    /// deduplicated, sorted). The Settings pane uses this to
    /// render the green "有配置" badge for each provider; =
    /// the union ensures a key written to only one store
    /// (= e.g., user just toggled, write to secondary
    /// succeeded but primary write failed transiently) still
    /// shows the green badge.
    public func listProvidersWithKeys() -> [String] {
        var set = Set<String>()
        // Same unsigned-build rule as the read: the keychain list prompts too.
        // This runs on every launch (= it backs the chat empty-state), so it
        // is the most visible source of the dialog.
        if keychainAllowed {
            set.formUnion(primary.listProvidersWithKeys())
            set.formUnion(secondary.listProvidersWithKeys())
        } else {
            set.formUnion(fileStore.listProvidersWithKeys())
        }
        return Array(set).sorted()
    }

    /// Whether this store pair can reach the real keychain.
    ///
    /// False for the injected test pair, which is what keeps the
    /// unsigned-build guard from short-circuiting the mirror writes the
    /// mirrored-store tests assert.
    public var keychainParticipates: Bool {
        keychainStore is AppleKeychainStore || fileStore is AppleKeychainStore
    }

    // MARK: - Toggle-time migration

    /// One-shot migration helper called when the user flips the
    /// `wenshu.useKeychainForProviderKeys` toggle. Reads every
    /// key from the side the user is moving AWAY from (= the
    /// current secondary) and writes it to the side the user
    /// is moving TOWARD (= the current primary), so the next
    /// read consults the new primary directly and finds the
    /// key without needing the self-heal path.
    ///
    /// Per boss 2026-10-16 OOB "如果用户在配好 key 后关闭钥
    /// 匙串功能, 应该立刻把 key 放在不走钥匙串的路径中".
    /// The `2f9b1e5ca` self-heal already covers this case
    /// (= the next `loadKeySync` falls back to the
    /// secondary AND re-writes to the primary), but the
    /// user wanted the migration to be visible at the
    /// moment the toggle flips (= the chat empty-state
    /// should not flash). Calling `migrateToCurrentPrimary`
    /// from the toggle's onChange handler pre-populates the
    /// new primary so the empty-state flash goes away.
    ///
    /// Errors are swallowed (= per-store errors are
    /// logged via `NSLog`; = the migration is best-effort;
    /// = the user's `saveKeySync` path stays the contract
    /// for the "key was just configured" case).
    public func migrateToCurrentPrimary() {
        let secondarySlugs = secondary.listProvidersWithKeys()
        for slug in secondarySlugs {
            guard let provider = Provider.by(slug: slug) else { continue }
            guard let key = secondary.loadKeySync(for: provider) else { continue }
            // Write to primary; = use the same try? pattern
            // (= the self-heal path uses `try?` for the
            // same reason: the user already has a working
            // read via the secondary, so a primary write
            // failure is not fatal; = the next read
            // self-heals).
            do {
                try primary.saveKeySync(key, for: provider)
            } catch {
                NSLog("WSKeychain: migrateToCurrentPrimary failed to write \(slug) to primary: \(error.localizedDescription)")
            }
        }
    }
}
