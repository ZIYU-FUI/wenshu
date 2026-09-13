//
//  Persistence/WSProviderKey.swift · Wenshu · v0.72 SwiftData migration Phase 1
//
//  Migration commit 8 of 21 @Model classes: WSProviderKey.
//  Note: the `provider_keys` table in WenshuWorkspace.swift was actually
//  metadata-only (= the actual API keys live in AppleKeychain per AGENTS.md §11).
//  WSProviderKey is the SwiftData metadata index (= encrypted BLOB + slug + timestamps).
//
//  SECURITY CONTRACT (= per AGENTS.md §11 Keychain rule):
//    - The Data stored in `encryptedKey` MUST be AES-GCM ciphertext.
//    - Plaintext API keys live ONLY in AppleKeychain (Security framework).
//    - At write time: encrypt with master key (fetched from AppleKeychain)
//      → store Data as encryptedKey.
//    - At read time: fetch encryptedKey → decrypt with master key
//      → use plaintext for HTTP request.
//    - The master key NEVER leaves AppleKeychain.
//
//  This pattern preserves "AppleKeychain for keys" (= wenshu's existing
//  contract) while migrating storage from raw sqlite3 BLOB to SwiftData Data.

import Foundation
import SwiftData

@Model
public final class WSProviderKey {
    @Attribute(.unique) var providerSlug: String
    /// AES-GCM ciphertext (= never plaintext per AGENTS.md §11)
    var encryptedKey: Data
    var createdAt: Date
    var updatedAt: Date

    init(providerSlug: String, encryptedKey: Data) {
        self.providerSlug = providerSlug
        self.encryptedKey = encryptedKey
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    /// Update ciphertext (caller provides new AES-GCM encrypted blob).
    func update(encryptedKey newKey: Data) {
        self.encryptedKey = newKey
        self.updatedAt = Date()
    }
}
