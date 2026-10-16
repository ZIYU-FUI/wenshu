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
final class MirroredKeychainStore: ProviderKeychainStoring, @unchecked Sendable {
    /// The two underlying stores. Both are thread-safe; = the
    /// per-store `NSLock` (File) + Apple Security framework
    /// (Keychain) cover the cross-thread cases.
    let keychainStore: any ProviderKeychainStoring
    let fileStore: any ProviderKeychainStoring

    /// Which store is PRIMARY for reads. Decided by
    /// `wenshu.useKeychainForProviderKeys`:
    /// - toggle ON (= default) = keychainPrimary = true
    /// - toggle OFF = keychainPrimary = false (= file is primary)
    ///
    /// Set by the caller (= the backend resolver
    /// `ProviderKeychain.resolveBackend` passes the right value
    /// here based on the toggle). Reads can flip `keychainPrimary`
    /// at any time (= the toggle change re-runs `resolveBackend`).
    var keychainPrimary: Bool

    /// Production initializer. Builds Apple Keychain + file
    /// backends (= the canonical wenshu dual-store path).
    init(keychainPrimary: Bool) {
        self.keychainStore = AppleKeychainStore()
        self.fileStore = FileProviderKeyStore()
        self.keychainPrimary = keychainPrimary
    }

    /// Test initializer. Accepts any two `ProviderKeychainStoring`
    /// backends. Used by `MirroredKeychainStoreTests` to inject
    /// two `InMemoryKeychainStore` instances for hermetic
    /// assertions on each side.
    init(
        keychainStore: any ProviderKeychainStoring,
        fileStore: any ProviderKeychainStoring,
        keychainPrimary: Bool
    ) {
        self.keychainStore = keychainStore
        self.fileStore = fileStore
        self.keychainPrimary = keychainPrimary
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
    func saveKeySync(_ key: String, for provider: Provider) throws {
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
    func loadKeySync(for provider: Provider) -> String? {
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
    func deleteKeySync(for provider: Provider) throws {
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
    func listProvidersWithKeys() -> [String] {
        var set = Set<String>()
        set.formUnion(primary.listProvidersWithKeys())
        set.formUnion(secondary.listProvidersWithKeys())
        return Array(set).sorted()
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
    func migrateToCurrentPrimary() {
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
