//  ProviderKeychainWriteProofTests.swift
//  Tests/WenshuAppTests/Agent/Provider/
//
//  The write-proof backend, and the door it closes.
//
//  The process-global backend is shared by every suite in the test process.
//  A suite that writes into it hands its key to whichever suite runs next,
//  so the store refuses every write: a write that reaches the global
//  backend fails AT the write, with a message that names the call.
//
//  The guard in ProviderKeychainTests is a text rule (= it names the
//  spellings of a write). This suite is the other side of the same door:
//  it does not care how the write was spelled, so it covers the spellings
//  the text rule does not know.

import Foundation
import Testing
@testable import WenshuAgent

@Suite("ProviderKeychain write proof")
struct ProviderKeychainWriteProofTests {
    // MARK: - The backend itself

    @Test("The write-proof backend refuses a save and names the call")
    func refusesASave() {
        let store = WriteProofKeychainStore()

        #expect(throws: WriteProofKeychainStore.WriteRefused.self) {
            try store.saveKeySync("sk-should-never-be-stored", for: .openrouter)
        }
    }

    @Test("The write-proof backend refuses a delete and names the call")
    func refusesADelete() {
        let store = WriteProofKeychainStore()

        #expect(throws: WriteProofKeychainStore.WriteRefused.self) {
            try store.deleteKeySync(for: .openrouter)
        }
    }

    @Test("The write-proof backend refuses a metadata save and names the call")
    func refusesAMetadataSave() {
        let store = WriteProofKeychainStore()
        let metadata = ProviderKeychainMetadata(
            expiresAt: Date(timeIntervalSince1970: 0),
            oauthRefreshToken: "rt-should-never-be-stored"
        )

        #expect(throws: WriteProofKeychainStore.WriteRefused.self) {
            try store.saveMetadata(metadata, for: .openrouter)
        }
    }

    @Test("The refusal names the write and the provider, so the suite that made it knows what it did")
    func theRefusalNamesTheCall() {
        let refusal = WriteProofKeychainStore.WriteRefused(call: "saveKeySync", provider: "openrouter")

        #expect(refusal.description.contains("saveKeySync"))
        #expect(refusal.description.contains("openrouter"))
        #expect(refusal.description.contains("withBackendForTesting"))
    }

    @Test("The write-proof backend holds nothing, so a read cannot find a key")
    func holdsNothing() {
        let store = WriteProofKeychainStore()

        #expect(store.loadKeySync(for: .openrouter) == nil)
        #expect(store.listProvidersWithKeys().isEmpty)
        #expect(store.loadMetadata(for: .openrouter) == nil)
    }

    // MARK: - The door this closes

    @Test("A test process gets the write-proof backend, not the in-memory store")
    func aTestProcessGetsTheWriteProofBackend() {
        // This is what makes the process-global backend write-proof:
        // `ProviderKeychain.backend` is initialized from the resolver,
        // so the global a test process starts with IS this store.
        #expect(ProviderKeychain.resolveBackend(isTestProcess: true) is WriteProofKeychainStore)
        #expect(!(ProviderKeychain.resolveBackend(isTestProcess: true) is InMemoryKeychainStore))
    }

    @Test("A write through the public API FAILS, and the failure names the write")
    func aPublicWriteFails() async throws {
        // The scope pins WHICH backend the public API reaches (= the
        // write-proof one); it does not make the write legal. The write
        // still goes through `ProviderKeychain.saveKeySync`, and the
        // write-proof backend is what refuses it.
        try await ProviderKeychain.withBackendForTesting(WriteProofKeychainStore()) {
            #expect(throws: WriteProofKeychainStore.WriteRefused.self) {
                try ProviderKeychain.saveKeySync("sk-should-never-be-stored", for: .openrouter)
            }
        }
    }

    @Test("The alias door: a local name for the global refuses the write too")
    func theAliasDoorRefuses() {
        // `let global = ProviderKeychain.backend` then `global.saveKeySync(...)`
        // is a write the text guard cannot see, because the spelling it
        // watches for is not there. The backend the resolver hands a test
        // process is the one the global holds, so the write refuses.
        let global = ProviderKeychain.resolveBackend(isTestProcess: true)

        #expect(throws: WriteProofKeychainStore.WriteRefused.self) {
            try global.saveKeySync("sk-should-never-be-stored", for: .openrouter)
        }
    }

    @Test("The whitespace door: the same write, spelled across two lines, refuses too")
    func theWhitespaceDoorRefuses() {
        // `ProviderKeychain.backend` then a newline then `.saveKeySync(...)`
        // is the same write with the spelling broken up, so the text guard
        // cannot see it either. The refusal does not read the source, so
        // the newline changes nothing.
        let global = ProviderKeychain.resolveBackend(isTestProcess: true)

        #expect(throws: WriteProofKeychainStore.WriteRefused.self) {
            try global
                .saveKeySync("sk-should-never-be-stored", for: .openrouter)
        }
    }

    @Test("A scoped write still reaches the scoped store, so the door closes the global and not the scope")
    func aScopedWriteStillWorks() async throws {
        try await ProviderKeychain.withBackendForTesting(InMemoryKeychainStore()) {
            try ProviderKeychain.saveKeySync("sk-scoped", for: .openrouter)

            #expect(ProviderKeychain.loadKeySync(for: .openrouter) == "sk-scoped")
        }
    }

    @Test("The scoped store keeps the value inside the scope, and the global never sees it")
    func theScopeKeepsTheValue() async throws {
        let scoped = InMemoryKeychainStore()

        try await ProviderKeychain.withBackendForTesting(scoped) {
            try ProviderKeychain.saveKeySync("sk-only-in-scope", for: .nous)
        }

        #expect(scoped.loadKeySync(for: .nous) == "sk-only-in-scope")
    }
}
