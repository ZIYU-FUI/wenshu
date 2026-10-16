// FileProviderKeyStore.swift · Wenshu
//
// File-based backend for `ProviderKeychain` (= the provider API
// key store). Companion to `AppleKeychainStore` (= which writes
// to the user's macOS Login Keychain via the Apple Security
// framework; = the canonical wenshu path per AGENTS.md §11).
//
// Activated by the `wenshu.useKeychainForProviderKeys` UserDefaults
// toggle (= the SettingView "使用系统钥匙串保存 key" switch in
// the Providers pane). When the toggle is OFF (= this backend
// is active), API keys are persisted to:
//
//   ~/Library/Application Support/com.wenshu.app/provider-keys.json
//
// with file mode `0600` (= owner read/write only). The file
// path is OUTSIDE the wenshu `.ws` library directory AND outside
// the agent's filesystem scope (= `SubAgentRunner` only reads
// files under `libraryRoot`; = per Sources/WenshuApp/Features/Agent/
// Store/SystemPrompt.swift the agent's reachable surface is the
// `.ws` lib; = the key file at `~/Library/Application Support/
// com.wenshu.app/` is unreachable by the in-wenshu AI). This
// satisfies the boss 2026-10-16 OOB "不能通过文枢的内部 AI
// 问出来" requirement by file-path isolation (= the AI agent
// has no `FileManager` access to that path; = the key is
// outside its sandbox).
//
// Security note (= practical threat model):
//   - File mode 0600 (= macOS `chmod 600` on creation) limits
//     access to the current user account.
//   - File is plaintext JSON (= not encrypted at rest). This is
//     the explicit trade-off the user opts into when flipping
//     the toggle off (= they want file-based storage instead
//     of Keychain; = the user accepts the plaintext trade-off).
//   - macOS Keychain = the canonical wenshu path; = the toggle
//     defaults ON. File storage is the escape hatch.
//
// The backend implements the same `ProviderKeychainStoring`
// protocol (= save / load / delete / list / metadata). The
// file format is a flat JSON dictionary `{ "<provider-slug>":
// "<key>" }`. The file is read on every `loadKeySync` (= no
// caching; = the file is the source of truth) and rewritten
// on every `saveKeySync` (= simple and small enough; = ~1 KB
// for typical wenshu setups with 2-3 configured providers).

import Foundation

final class FileProviderKeyStore: ProviderKeychainStoring, @unchecked Sendable {
    /// File name within the Application Support directory.
    /// Hard-coded to `provider-keys.json` (= visible name; = the
    /// file mode + the Application Support path provide the
    /// permissions isolation).
    static let fileName = "provider-keys.json"

    /// Computed file URL. The Application Support directory is the
    /// canonical macOS location (= sandbox-safe + per-user; =
    /// persists across wenshu updates + doesn't get bundled into
    /// the `.ws` library when the user shares / syncs it).
    /// Per Apple HIG: `FileManager.default.url(for: .applicationSupportDirectory,
    /// in: .userDomainMask, appropriateFor: nil, create: true)`.
    static let fileURL: URL = {
        let fm = FileManager.default
        let dir = (try? fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? fm.temporaryDirectory
        let appDir = dir.appendingPathComponent("com.wenshu.app", isDirectory: true)
        if !fm.fileExists(atPath: appDir.path) {
            try? fm.createDirectory(
                at: appDir,
                withIntermediateDirectories: true
            )
        }
        return appDir.appendingPathComponent(fileName)
    }()

    /// In-process cache (= the file is small; = the cache
    /// prevents a disk hit on every `loadKeySync`). The cache
    /// is invalidated on `saveKeySync` / `deleteKeySync` (= the
    /// next `loadKeySync` re-reads from disk). NSLock guards
    /// cross-thread reads (= `ProviderKeychainStoring` is
    /// `Sendable`; = callers can be on any thread).
    private var cache: [String: String]?
    private let lock = NSLock()

    init() {}

    // MARK: - ProviderKeychainStoring

    func saveKeySync(_ key: String, for provider: Provider) throws {
        guard !key.isEmpty else { throw ProviderKeychainError.invalidKeyFormat }
        lock.lock()
        var dict = loadLocked() ?? [:]
        dict[provider.slug] = key
        try writeLocked(dict: dict)
        cache = dict
        lock.unlock()
    }

    func loadKeySync(for provider: Provider) -> String? {
        lock.lock(); defer { lock.unlock() }
        if let cache = cache {
            return cache[provider.slug]
        }
        guard let dict = loadLocked() else { return nil }
        cache = dict
        return dict[provider.slug]
    }

    func deleteKeySync(for provider: Provider) throws {
        lock.lock()
        var dict = loadLocked() ?? [:]
        dict.removeValue(forKey: provider.slug)
        try writeLocked(dict: dict)
        cache = dict
        lock.unlock()
    }

    func listProvidersWithKeys() -> [String] {
        lock.lock(); defer { lock.unlock() }
        let dict = loadLocked() ?? [:]
        return dict.keys.sorted()
    }

    // MARK: - File IO (= caller must hold the lock)

    /// Read the on-disk JSON dictionary. Returns nil when the
    /// file is missing (= first-run; = empty store) or
    /// unreadable / corrupt (= best-effort skip; = the user
    /// can re-enter the key without crashing). Never throws
    /// (= `ProviderKeychainStoring.loadKeySync` returns nil
    /// for "not found"; = the caller treats nil as
    /// "configure a key", not as an error).
    private func loadLocked() -> [String: String]? {
        guard FileManager.default.fileExists(atPath: Self.fileURL.path) else {
            return [:]
        }
        guard let data = try? Data(contentsOf: Self.fileURL) else {
            return nil
        }
        return try? JSONDecoder().decode([String: String].self, from: data)
    }

    /// Write the dictionary to disk. Throws on IO failure (= the
    /// caller = `Settings Save` button = surfaces the error
    /// to the user). Sets file mode to 0600 (= owner-only
    /// read/write) on the file.
    private func writeLocked(dict: [String: String]) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(dict)
        try data.write(to: Self.fileURL, options: [.atomic])
        // Lock down to owner-only (= best-effort; = the user
        // can still chmod; = this is the canonical macOS
        // pattern from `NSData.WritingOptions.atomic` +
        // `FileManager.setAttributes`). The error is swallowed
        // because the write already succeeded; = a chmod
        // failure is a permission issue the user needs to
        // diagnose manually (= = not a save failure).
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: Self.fileURL.path
        )
    }
}
