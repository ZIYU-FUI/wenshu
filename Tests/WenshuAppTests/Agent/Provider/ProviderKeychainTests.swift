//
//  ProviderKeychainTests.swift
//
//  Tests inject InMemoryKeychainStore via ProviderKeychain.withBackendForTesting
//  because `swift test` runs as a daemon session (no user-attached console) and
//  Apple Security framework refuses SecItemAdd with errSecInteractionNotAllowed
//  or errSecMissingEntitlement in that context.
//
//  The store is scoped to each test's OWN task (= the TaskLocal pattern) and
//  the process-global backend is never written: = the keys this suite saves
//  cannot reach a suite that runs later (= the global is shared by every
//  suite in the process, = and Swift Testing runs suites in parallel).
//
//  AppleKeychainStore behavior (production path) is exercised manually when
//  operator runs the .app bundle from build/Wenshu.app.
//

import Testing
import Foundation
import WenshuAgent
@testable import WenshuApp

@Suite("ProviderKeychain (Apple Security framework, multi-provider)", .serialized)
struct ProviderKeychainTests {

    // (= each test installs its own store, scoped to its own task = the
    // TaskLocal pattern; = the process-global backend is never written, =
    // so this suite leaves no key behind for a suite that runs later.)

    @Test("saveKey then loadKey returns same value")
    func saveAndLoad() async throws {
        try await ProviderKeychain.withBackendForTesting(InMemoryKeychainStore()) {
            let key = "redacted-sk-\(UUID().uuidString.prefix(8))"
            try ProviderKeychain.saveKeySync(key, for: .openrouter)
            let loaded = ProviderKeychain.loadKeySync(for: .openrouter)
            #expect(loaded == key)
            try ProviderKeychain.deleteKeySync(for: .openrouter)
        }
    }

    @Test("loadKey returns nil when no key stored")
    func loadEmpty() async throws {
        try await ProviderKeychain.withBackendForTesting(InMemoryKeychainStore()) {
            try ProviderKeychain.deleteKeySync(for: .anthropic)
            let loaded = ProviderKeychain.loadKeySync(for: .anthropic)
            #expect(loaded == nil)
        }
    }

    @Test("empty key throws invalidKeyFormat")
    func emptyKeyThrows() async {
        await ProviderKeychain.withBackendForTesting(InMemoryKeychainStore()) {
            await #expect(throws: ProviderKeychainError.self) {
                try ProviderKeychain.saveKeySync("", for: .nous)
            }
        }
    }

    @Test("different providers store keys independently")
    func providerIsolation() async throws {
        try await ProviderKeychain.withBackendForTesting(InMemoryKeychainStore()) {
            let openrouterKey = "redacted-sk-or-\(UUID().uuidString.prefix(8))"
            let nousKey = "redacted-sk-\(UUID().uuidString.prefix(8))"
            try ProviderKeychain.saveKeySync(openrouterKey, for: .openrouter)
            try ProviderKeychain.saveKeySync(nousKey, for: .nous)
            #expect(ProviderKeychain.loadKeySync(for: .openrouter) == openrouterKey)
            #expect(ProviderKeychain.loadKeySync(for: .nous) == nousKey)
            try ProviderKeychain.deleteKeySync(for: .openrouter)
            try ProviderKeychain.deleteKeySync(for: .nous)
        }
    }

    @Test("listProvidersWithKeys lists providers with stored keys")
    func testListProvidersWithKeys() async throws {
        try await ProviderKeychain.withBackendForTesting(InMemoryKeychainStore()) {
            // Cleanup fixture: prior minimax-cn key entry must be cleared before assertion
            try ProviderKeychain.deleteKeySync(for: .minimax)
            try ProviderKeychain.deleteKeySync(for: .minimaxCn)
            try ProviderKeychain.deleteKeySync(for: .anthropic)
            #expect(!ProviderKeychain.listProvidersWithKeys().contains("minimax"))
            try ProviderKeychain.saveKeySync("redacted-sk-", for: .minimax)
            #expect(ProviderKeychain.listProvidersWithKeys().contains("minimax"))
            try ProviderKeychain.saveKeySync("redacted-sk-ant-", for: .anthropic)
            #expect(ProviderKeychain.listProvidersWithKeys().contains("anthropic"))
            try ProviderKeychain.deleteKeySync(for: .minimax)
            try ProviderKeychain.deleteKeySync(for: .minimaxCn)
            try ProviderKeychain.deleteKeySync(for: .anthropic)
        }
    }

    // MARK: - The process-global backend stays untouched

    /// No suite may write the PROCESS-GLOBAL keychain backend.
    ///
    /// The global belongs to the whole test process, and Swift Testing runs
    /// suites in parallel, so a suite that saves a key into it hands that
    /// key to every suite that runs after it. The suite that saved it is
    /// then green in isolation and red in a full run, and the set of
    /// failures moves with the order the suites happened to run in.
    ///
    /// Four rules, all checkable without running a suite:
    ///   1. no test file writes the global directly (= the global's own
    ///      mutators),
    ///   2. no test file ASSIGNS the global (= the backend property set to
    ///      a store, which is the spelling production code itself uses
    ///      (= SettingView.swift)), and
    ///   3. every global install puts in an EMPTY store, so an install can
    ///      never carry a key, and
    ///   4. a file that writes through the PUBLIC API and ALSO installs a
    ///      global backend is an offender. Outside a
    ///      `withBackendForTesting` scope the public API writes the
    ///      process-global store, so the two together = the global gets
    ///      written. Neither half is enough: a public write with no
    ///      install is the live-gated suite's shape, and an install with no
    ///      public write is harmless.
    ///
    /// The needles are assembled at run time, so this file does not match
    /// its own rules.
    @Test("no suite writes the process-global keychain backend")
    func noSuiteWritesTheGlobalBackend() {
        let globalPrefix = "ProviderKeychain.backend."
        let globalWrites = ["saveKeySync", "deleteKeySync", "saveMetadata"]
        let installCall = "ProviderKeychain.setBackend" + "ForTesting("
        let emptyStore = "InMemoryKeychainStore()"
        // The public API's own writers: these reach the process-global
        // store whenever no scope is active. The prefix and the method
        // name are kept apart so this file does not match its own rule.
        let publicPrefix = "ProviderKeychain."
        let publicWrites = ["saveKeySync", "deleteKeySync", "saveMetadata"]
        // The assignment spelling, assembled at run time so this file does
        // not match its own rule.
        let assignment = "ProviderKeychain.backend" + " ="

        let testsRoot = SourceLocator.repoRoot.appendingPathComponent("Tests")
        let enumerator = FileManager.default.enumerator(
            at: testsRoot,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        var offenders: [String] = []
        var scanned = 0
        while let url = enumerator?.nextObject() as? URL {
            guard url.pathExtension == "swift" else { continue }
            scanned += 1
            let text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            for write in globalWrites where text.contains(globalPrefix + write) {
                offenders.append("\(url.lastPathComponent): writes the global backend directly")
            }
            if text.contains(assignment) {
                offenders.append("\(url.lastPathComponent): assigns the global backend directly")
            }
            var installsGlobal = false
            var cursor = text.startIndex
            while let range = text.range(of: installCall, range: cursor ..< text.endIndex) {
                let after = text[range.upperBound...]
                if let close = after.firstIndex(of: ")") {
                    // The closing parenthesis belongs to the argument
                    // (= the call's own parenthesis is the one before it).
                    let argument = String(after[after.startIndex ... close])
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if argument != emptyStore {
                        offenders.append(
                            "\(url.lastPathComponent): installs \(argument) into the global backend"
                        )
                    }
                }
                installsGlobal = true
                cursor = range.upperBound
            }
            // Rule 4: the public door AND the install door in one file.
            let publicWritesHere = publicWrites.filter { text.contains(publicPrefix + $0) }
            if installsGlobal, !publicWritesHere.isEmpty {
                offenders.append(
                    """
                    \(url.lastPathComponent): writes the global backend through the public API \
                    (\(publicWritesHere.map { publicPrefix + $0 }.joined(separator: ", "))) \
                    and also installs a global backend
                    """
                )
            }
        }
        #expect(scanned > 0, "the guard must read the test tree, not an empty directory")
        #expect(offenders.isEmpty, """
        a suite must not write the process-global keychain backend: \
        \(offenders.joined(separator: "; "))
        """)
    }
}
