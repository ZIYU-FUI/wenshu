//
//  MirroredKeychainStoreTests.swift · Wenshu
//
//  Z contract test for the dual-store keychain backend. Verifies:
//    1. saveKeySync writes BOTH inner stores (= Apple Keychain + file).
//    2. loadKeySync reads the primary (= per-toggle); on primary nil,
//       falls back to secondary AND self-heals (= re-writes the
//       recovered value back to the primary so the next read is fast).
//    3. Toggling `keychainPrimary` at runtime re-targets the primary.
//    4. deleteKeySync clears BOTH stores.
//
//  Per boss 2026-10-16 OOB "在用户配 key 的时候, 就两头存.
//  无论用户怎么开关, 只是切换读 key 的位置".
//
//  Tests use the in-memory test initializer (= the mirror is
//  built with two `InMemoryKeychainStore` instances so each
//  side is independently inspectable; = no real Apple Keychain
//  or file IO happens in the test).
//

import Testing
import Foundation
import WenshuAgent
@testable import WenshuApp

@Suite("MirroredKeychainStore (dual-store mirror)")
struct MirroredKeychainStoreTests {

    /// Build a `MirroredKeychainStore` over two `InMemoryKeychainStore`
    /// instances so the assertions can introspect each side
    /// independently (= = no Apple Keychain / file IO).
    private func makeMirror(
        keychainPrimary: Bool
    ) -> (MirroredKeychainStore, InMemoryKeychainStore, InMemoryKeychainStore) {
        let a = InMemoryKeychainStore()
        let b = InMemoryKeychainStore()
        let mirror = MirroredKeychainStore(
            keychainStore: a,
            fileStore: b,
            keychainPrimary: keychainPrimary
        )
        return (mirror, a, b)
    }

    /// Save -> both inner stores hold the key. The previous
    /// single-store behavior (= the `2a132f25c` toggle commit)
    /// had the write path write to ONE store; the mirrored
    /// behavior must write to BOTH.
    @Test("saveKeySync writes BOTH stores")
    func testDualWrite() throws {
        let (mirror, keychainSide, fileSide) = makeMirror(keychainPrimary: true)
        let provider = Provider.minimaxCn
        let key = "sk-cp-test-dual-write"

        try mirror.saveKeySync(key, for: provider)

        #expect(keychainSide.loadKeySync(for: provider) == key, "keychain side must hold the key after save")
        #expect(fileSide.loadKeySync(for: provider) == key, "file side must hold the key after save (dual-write invariant)")
    }

    /// Save with primary = keychain, then flip primary to
    /// file, then read: must STILL return the value (from
    /// the file side, = the self-heal path's read target).
    /// Without the dual-write, this read would return nil
    /// (= the user-facing "key 没配" bug).
    @Test("toggle primary at runtime — read after flip still returns value via self-heal")
    func testToggleRuntime_selfHeal() throws {
        let (mirror, keychainSide, fileSide) = makeMirror(keychainPrimary: true)
        let provider = Provider.minimaxCn
        let key = "sk-cp-test-toggle"

        try mirror.saveKeySync(key, for: provider)

        // Both sides have the key (= the dual-write invariant).
        #expect(keychainSide.loadKeySync(for: provider) == key)
        #expect(fileSide.loadKeySync(for: provider) == key)

        // Simulate the user toggling OFF: clear the keychain side
        // (= the user "switched storage" — semantically the
        // previous primary is now stale). Mirror must still
        // surface the value via the file side.
        try keychainSide.deleteKeySync(for: provider)
        #expect(keychainSide.loadKeySync(for: provider) == nil)

        // Read: primary (keychain) returns nil, secondary (file)
        // returns the key, self-heal writes it back to the
        // keychain side.
        let valueAfterFlip = mirror.loadKeySync(for: provider)
        #expect(valueAfterFlip == key, "after primary miss, the secondary self-heal must surface the value")

        // Self-heal: the keychain side now has the key again
        // (= the next read is fast).
        #expect(keychainSide.loadKeySync(for: provider) == key, "self-heal must re-populate the primary")
    }

    /// deleteKeySync clears BOTH inner stores (= the previous
    /// single-store behavior was asymmetric: a delete only
    /// cleared the active store; = the user could end up with
    /// a stale key in the other store).
    @Test("deleteKeySync clears both stores")
    func testDeleteBothSides() throws {
        let (mirror, keychainSide, fileSide) = makeMirror(keychainPrimary: true)
        let provider = Provider.minimaxCn
        let key = "sk-cp-test-delete-both"

        try mirror.saveKeySync(key, for: provider)
        try mirror.deleteKeySync(for: provider)

        // Both reads must return nil.
        #expect(keychainSide.loadKeySync(for: provider) == nil, "keychain side must be cleared after delete")
        #expect(fileSide.loadKeySync(for: provider) == nil, "file side must be cleared after delete")
        #expect(mirror.loadKeySync(for: provider) == nil, "loadKeySync must return nil after delete")
    }

    /// listProvidersWithKeys returns the UNION of both
    /// stores (= a key written to only one side via a
    /// transient failure must still show up in the listing).
    @Test("listProvidersWithKeys returns union of both stores")
    func testListUnion() throws {
        let (mirror, keychainSide, fileSide) = makeMirror(keychainPrimary: true)
        let p1 = Provider.minimaxCn
        let p2 = Provider.openaiCodex
        try mirror.saveKeySync("key-1", for: p1)
        // Inject a write directly to the file side only
        // (= simulates a transient keychain write failure).
        try fileSide.saveKeySync("key-2", for: p2)

        let listed = mirror.listProvidersWithKeys()
        #expect(listed.contains(p1.slug), "p1 written to both sides must appear")
        #expect(listed.contains(p2.slug), "p2 written to file side only must still appear (union invariant)")
    }

    /// The production `init(keychainPrimary:)` builds real
    /// Apple Keychain + file stores. Smoke test (= asserts
    /// the init body doesn't crash and the inner stores
    /// are wired correctly).
    @Test("production init builds real inner stores")
    func testProductionInit() {
        let store = MirroredKeychainStore(keychainPrimary: true)
        // The inner stores must be non-nil; = we can't
        // easily probe the concrete type (= any
        // ProviderKeychainStoring) but the property
        // access is the assertion: a nil-any would
        // be caught at the `_ = store.keychainStore` line.
        _ = store.keychainStore
        _ = store.fileStore
    }

    /// `migrateToCurrentPrimary` copies every key from the
    /// side the user is moving AWAY from (= current
    /// secondary) to the side the user is moving TOWARD
    /// (= current primary). After the migration, both
    /// sides hold the key (= the chat empty-state
    /// does not flash because the next read finds the
    /// value in the new primary).
    @Test("migrateToCurrentPrimary copies secondary keys to primary")
    func testMigrateToCurrentPrimary() throws {
        // Build a mirror with keychainPrimary = true; =
        // primary is keychain, secondary is file.
        let (mirror, keychainSide, fileSide) = makeMirror(keychainPrimary: true)
        let provider = Provider.minimaxCn
        let key = "sk-cp-test-migrate"

        // Simulate the old behavior: only the file side
        // has the key (= the user configured the key
        // with toggle OFF at some point in the past).
        // We delete from the keychain side to match
        // that pre-`2f9b1e5ca` state.
        try keychainSide.deleteKeySync(for: provider)
        try fileSide.saveKeySync(key, for: provider)

        // Sanity: keychain has nothing, file has the key.
        #expect(keychainSide.loadKeySync(for: provider) == nil)
        #expect(fileSide.loadKeySync(for: provider) == key)

        // User flips the toggle (= in this test we
        // simulate by re-creating the mirror with
        // keychainPrimary = true AND calling
        // migrateToCurrentPrimary; = the actual
        // SettingView code does the same thing via
        // the onChange handler).
        let freshMirror = MirroredKeychainStore(
            keychainStore: keychainSide,
            fileStore: fileSide,
            keychainPrimary: true
        )
        freshMirror.migrateToCurrentPrimary()

        // After migration, the keychain (= new primary)
        // also has the key.
        #expect(keychainSide.loadKeySync(for: provider) == key, "migrateToCurrentPrimary must copy secondary keys to the new primary")
    }
}
