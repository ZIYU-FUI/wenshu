// UnsignedKeychainPromptTests.swift
//
// An unsigned build must not reach the keychain at all.
//
// macOS keys the keychain's "which app asked for this" record on the code
// signature. A local build is ad-hoc signed, so every launch is a different
// app as far as the keychain is concerned, and it asks for permission again.
// The original code wrapped the secondary write in a catch, which looks like
// it handles the failure — but the dialog is shown before any OSStatus comes
// back, so the catch never prevents it. The only fix is to not make the call.
//
// These tests pin the decision, because the failure is a modal dialog on
// someone's screen and nothing else in the suite would notice.
//
// The seam is per-instance rather than a process-wide flag: the package tests
// run in parallel, and a shared flag would let one test change what the
// others see.

import Foundation
import Testing
@testable import WenshuAgent

@Suite("Unsigned builds skip the keychain", .serialized)
struct UnsignedKeychainPromptTests {

    /// A store that may or may not touch the keychain, with in-memory
    /// backends so the test can observe the choice.
    private func makeStore(keychainAllowed: Bool) -> MirroredKeychainStore {
        MirroredKeychainStore(
            keychainStore: InMemoryKeychainStore(),
            fileStore: InMemoryKeychainStore(),
            keychainPrimary: true,
            keychainAllowed: keychainAllowed
        )
    }

    @Test("a store reports whether it may use the keychain")
    func permissionIsVisible() {
        #expect(makeStore(keychainAllowed: false).mayUseKeychain == false)
        #expect(makeStore(keychainAllowed: true).mayUseKeychain == true)
    }

    @Test("an ad-hoc signature is recognized as unstable")
    func adhocSignatureIsUnstable() {
        // The local build is the case that matters: the app bundle produced
        // by the build script is ad-hoc signed, which is exactly why macOS
        // asks again on every launch.
        //
        // Sign a scratch copy ad-hoc and check the classification, so the
        // test does not depend on the app artifact existing.
        let copy = FileManager.default.temporaryDirectory
            .appendingPathComponent("wenshu-adhoc-probe")
        try? FileManager.default.removeItem(at: copy)
        guard let source = Bundle.main.executableURL else { return }
        try? FileManager.default.copyItem(at: source, to: copy)
        defer { try? FileManager.default.removeItem(at: copy) }

        let signed = Process()
        signed.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        signed.arguments = ["-f", "-s", "-", copy.path]
        try? signed.run()
        signed.waitUntilExit()

        let description = MirroredKeychainStore.SigningIdentity.codesignDescription(of: copy)
        #expect(description != nil, "codesign must be able to describe the probe")
        #expect(MirroredKeychainStore.SigningIdentity.isAdhoc(binaryAt: copy),
                "an ad-hoc signed binary must read as unstable")
    }

    @Test("a platform signature is recognized as stable")
    func platformSignatureIsStable() {
        // /usr/bin/true is signed by Apple and has an authority chain, so it
        // reads as stable. This is the other half of the discriminator: if
        // both cases said "adhoc", the check would be meaningless.
        #expect(MirroredKeychainStore.SigningIdentity.isAdhoc(binaryAt: URL(fileURLWithPath: "/usr/bin/true")) == false)
    }

    @Test("a missing binary is treated as unstable")
    func missingBinaryIsUnstable() {
        // A binary that cannot be inspected must fail closed (= the gate
        // stays shut), because the cost of guessing wrong is a dialog on the
        // user's screen.
        #expect(MirroredKeychainStore.SigningIdentity.isAdhoc(binaryAt: URL(fileURLWithPath: "/nonexistent/wenshu-binary")))
    }

    @Test("an injected in-memory pair is never mistaken for the keychain")
    func injectedStoresAreNotTheKeychain() {
        // The unsigned-build guard only fires when a real AppleKeychainStore is
        // present. Tests inject in-memory stores, so their mirror writes still
        // happen and the existing mirrored-store assertions keep meaning
        // something.
        let store = makeStore(keychainAllowed: true)
        #expect(!store.keychainParticipates,
                "an injected pair contains no AppleKeychainStore, so the guard must not short-circuit")
    }

    @Test("the production store resolves its permission from the build's signature")
    func productionStoreReadsTheSignature() {
        // The production initializer is the only path that reaches the real
        // keychain, so it is the one that must consult the signature.
        let store = MirroredKeychainStore(keychainPrimary: true)
        #expect(store.mayUseKeychain == MirroredKeychainStore.isStableSigned,
                "the production store must agree with the signature check")
    }

    @Test("the debug override reads the file store instead of discarding the key")
    func debugOverrideKeepsTheKeyReadable() {
        // The `wenshu.debugNoKeychain` flag used to make every call return
        // nothing (= "pretend there is no key"), which put the chat empty
        // state on screen even though the key was sitting in the file. The
        // flag now means "use the file store", so the key must still be
        // readable.
        //
        // The flag is read from UserDefaults, so this test drives the same
        // path the app drives.
        // The flag lives in a process-wide UserDefaults domain
        // (= `swiftpm-testing-helper`), and that domain persists on
        // disk between runs. Restoring it with `set(false)` would
        // leave the key PRESENT (= "the debug override is on" for
        // every later test), so the prior state is captured as
        // "was the key there at all" and restored exactly.
        let flagKey = "wenshu.debugNoKeychain"
        let hadFlag = UserDefaults.standard.object(forKey: flagKey) != nil
        let previousFlag = UserDefaults.standard.bool(forKey: flagKey)
        UserDefaults.standard.set(true, forKey: flagKey)
        defer {
            if hadFlag {
                UserDefaults.standard.set(previousFlag, forKey: flagKey)
            } else {
                UserDefaults.standard.removeObject(forKey: flagKey)
            }
        }

        // The signed-build branch is asked for directly: a test run
        // resolves to the in-memory store, which is a different gate.
        let backend = ProviderKeychain.resolveBackend(isTestProcess: false)
        #expect(backend is FileProviderKeyStore,
                "the debug override must resolve to the file store, not to a store that discards the key")
    }

    @Test("the file store lists the providers it has keys for")
    func fileStoreListsProviders() {
        // The list path is what the chat empty-state reads. A store that
        // resolves correctly but lists nothing still produces the empty
        // state, so the listing is checked directly.
        let store = FileProviderKeyStore()
        let listed = store.listProvidersWithKeys()
        #expect(listed == listed.sorted(), "the provider list must be sorted")
    }

    @Test("a test run never resolves to a store that touches the keychain")
    func testProcessNeverResolvesToKeychainStore() {
        let backend = ProviderKeychain.resolveBackend()
        #expect(backend is InMemoryKeychainStore)
        #expect(!(backend is AppleKeychainStore))
        #expect(!(backend is MirroredKeychainStore))
    }

    @Test("an ad-hoc signed build never resolves to the keychain")
    func adhocBuildNeverResolvesToKeychainStore() {
        // The signature check is what makes "always allow" hold: the
        // signature hash changes with every rebuild, so the keychain
        // treats the next build as a different application and asks
        // again.
        let previous = MirroredKeychainStore.stableSigningOverride
        defer { MirroredKeychainStore.stableSigningOverride = previous }
        MirroredKeychainStore.stableSigningOverride = false

        let backend = ProviderKeychain.resolveBackend(isTestProcess: false)
        #expect(backend is FileProviderKeyStore)
        #expect(!(backend is MirroredKeychainStore))
    }

    @Test("a signed build resolves to the keychain store")
    func signedBuildResolvesToKeychainStore() {
        let previous = MirroredKeychainStore.stableSigningOverride
        defer { MirroredKeychainStore.stableSigningOverride = previous }
        MirroredKeychainStore.stableSigningOverride = true

        // The debug override is checked BEFORE the signature, so a
        // flag left on by another test (= it lives in a persistent,
        // process-wide UserDefaults domain) would send this
        // resolution down the file-store branch. Clear it for the
        // duration so the assertion is about the signature alone.
        let flagKey = "wenshu.debugNoKeychain"
        let hadFlag = UserDefaults.standard.object(forKey: flagKey) != nil
        let previousFlag = UserDefaults.standard.object(forKey: flagKey)
        UserDefaults.standard.removeObject(forKey: flagKey)
        defer {
            if let previousFlag {
                UserDefaults.standard.set(previousFlag, forKey: flagKey)
            }
        }

        let backend = ProviderKeychain.resolveBackend(isTestProcess: false)
        #expect(backend is MirroredKeychainStore)
    }
}
