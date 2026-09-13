//
//  Persistence/Repositories/WSProviderKeyRepository.swift · Wenshu · v0.72 SwiftData migration Phase 2
//
//  Migration commit 31 of 42: WSProviderKeyRepository.
//  Per AGENTS.md §11.4.
//
//  SECURITY CONTRACT (= per AGENTS.md §11 "API keys via AppleKeychain
//  NEVER plaintext SQLite"):
//  - The Data stored in WSProviderKey.encryptedKey MUST be AES-GCM ciphertext.
//  - Plaintext API keys live ONLY in AppleKeychain (Security framework).
//  - At write: encrypt with master key (AppleKeychain) → store Data.
//  - At read: fetch Data → decrypt with master key → use for HTTP.
//
//  This repository stores the METADATA INDEX only (= encrypted BLOB
//  + slug + timestamps). The actual encryption/decryption uses
//  ProviderKeychain.AESKey (= AppleKeychain).

import Foundation
import SwiftData

@MainActor
public final class WSProviderKeyRepository {
    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    public init(container: ModelContainer = WSPersistenceContainer.shared) {
        self.container = container
    }

    public func saveMetadata(slug: String, encryptedKey: Data) throws {
        let descriptor = FetchDescriptor<WSProviderKey>(
            predicate: #Predicate { $0.providerSlug == slug }
        )
        if let existing = try context.fetch(descriptor).first {
            existing.update(encryptedKey: encryptedKey)
        } else {
            let model = WSProviderKey(providerSlug: slug, encryptedKey: encryptedKey)
            context.insert(model)
        }
        try context.save()
    }

    public func loadEncryptedKey(slug: String) throws -> Data? {
        let descriptor = FetchDescriptor<WSProviderKey>(
            predicate: #Predicate { $0.providerSlug == slug }
        )
        return try context.fetch(descriptor).first?.encryptedKey
    }

    public func listProviders() throws -> [String] {
        let descriptor = FetchDescriptor<WSProviderKey>(
            sortBy: [SortDescriptor(\.providerSlug)]
        )
        return try context.fetch(descriptor).map { $0.providerSlug }
    }

    public func deleteMetadata(slug: String) throws {
        let descriptor = FetchDescriptor<WSProviderKey>(
            predicate: #Predicate { $0.providerSlug == slug }
        )
        if let model = try context.fetch(descriptor).first {
            context.delete(model)
            try context.save()
        }
    }
}
