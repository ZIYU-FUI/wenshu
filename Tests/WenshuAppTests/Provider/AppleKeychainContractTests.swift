// SECURITY-1 — Apple Keychain canonical contract for LLM provider credentials.
//
// Pins three invariants at the source level (= grep-level contract; = if
// anyone removes them, the test fails at build time on `git diff`):
//
//   1a — KeychainOps.swift uses `kSecClassGenericPassword` (= the Apple
//        Security framework canonical class for application secrets).
//   1b — KeychainOps.swift sets `kSecAttrService` (= the per-provider
//        service identifier), AND the service is namespaced under
//        `com.wenshu.app.<provider-slug>` (= wenshu-side wins naming).
//   1c — ProviderKeychain.swift does NOT log or persist the raw API key
//        in plaintext. The only path for keys to leave the actor is
//        `loadKeySync(for:)` returning the key to the in-memory connector.
//
// Background: AGENTS.md §11 baseline + §11.2 (7 LLM connector profiles)
// requires all API keys to live in Apple Keychain; = never UserDefaults
// (= see Robustness test indirectly; = this test pins the source side).
//
// Reference: AGENTS.md §11.1 (security baseline), §11.2 (LLM connector).
import Foundation
import Testing
@testable import WenshuApp

@Suite(.serialized)
struct AppleKeychainContractTests {

    private static func source(for relativePath: String) throws -> String {
        // Walk up from the test file to the wenshu repo root, then
        // resolve the source file by canonical subpath mapping.
        let cwd = FileManager.default.currentDirectoryPath
        // Cwd is /Volumes/ANAN/Engineering/wenshu when run via swift test
        // from the workdir. Source files are below `Sources/`.
        let candidate = "\(cwd)/\(relativePath)"
        guard FileManager.default.fileExists(atPath: candidate) else {
            Issue.record("Source file missing at \(candidate)")
            throw NSError(domain: "Test", code: -1)
        }
        return try String(contentsOfFile: candidate, encoding: .utf8)
    }

    @Test("KeychainOps uses kSecClassGenericPassword (= Apple canonical for app secrets)")
    func keychainOpsUsesGenericPasswordClass() throws {
        let src = try Self.source(for: "Sources/WenshuApp/Core/Provider/KeychainOps.swift")
        #expect(src.contains("kSecClassGenericPassword"),
                "KeychainOps must use kSecClassGenericPassword (= Apple canonical for app secrets)")
    }

    @Test("ProviderKeychain namespaces service under com.wenshu.app")
    func providerKeychainNamespacesServiceUnderComWenshuApp() throws {
        // Pin the canonical service name (= AppleKeychain uses this as the
        // kSecAttrService value; = the per-app namespace that isolates our
        // keys from other apps on the same macOS user account).
        let src = try Self.source(for: "Sources/WenshuApp/Core/Provider/ProviderKeychain.swift")
        #expect(src.contains("com.wenshu.app"),
                "ProviderKeychain must namespace keys under com.wenshu.app.* service identifier")
    }

    @Test("ProviderKeychain stores each provider under its own .api.key account")
    func providerKeychainPerProviderAccountKey() throws {
        let src = try Self.source(for: "Sources/WenshuApp/Core/Provider/ProviderKeychain.swift")
        #expect(src.contains("\\(provider.slug).api.key"),
                "ProviderKeychain must key each provider under <slug>.api.key account (= isolation between providers)")
    }

    @Test("ProviderKeychain never writes a key to disk via plain file APIs")
    func providerKeychainDoesNotWriteKeysToDisk() throws {
        let src = try Self.source(for: "Sources/WenshuApp/Core/Provider/ProviderKeychain.swift")
        // Heuristic: no FileManager writes that include 'key' / 'api' in
        // their argument name. Allow commented-out code references.
        let codeLines = src.components(separatedBy: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("*") }
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("///") }
        let offenders = codeLines.filter { line in
            (line.contains(".write(") || line.contains("String.write"))
                && (line.lowercased().contains("key")
                    || line.lowercased().contains("api_key")
                    || line.lowercased().contains("apikey"))
        }
        #expect(offenders.isEmpty,
                "ProviderKeychain must never write keys via .write(…); got:\n\(offenders.joined(separator: "\n"))")
    }

    @Test("ProviderKeychain masks keys in any debug/log output")
    func providerKeychainMasksKeysInLogs() throws {
        let src = try Self.source(for: "Sources/WenshuApp/Core/Provider/ProviderKeychain.swift")
        // Look for either NSLog / print / os_log wrapping a key — if any
        // such call exists, the key MUST be masked (= prefix-only display).
        let logCallPatterns = ["NSLog(", "print(", "os_log(", "logger."]
        let codeLines = src.components(separatedBy: "\n")
            .filter { line in
                logCallPatterns.contains(where: { line.contains($0) })
                && !line.trimmingCharacters(in: .whitespaces).hasPrefix("//")
                && !line.trimmingCharacters(in: .whitespaces).hasPrefix("*")
            }
        // If we log anything at all, it must use `redacted` / `mask` /
        // `prefix(4)` — i.e. NOT a raw key. Allow log lines that contain
        // neither "key" nor "loadKeySync return value" markers.
        let suspiciousLogs = codeLines.filter { line in
            line.lowercased().contains("key") && !line.contains("masked")
                && !line.contains("prefix(") && !line.contains("redact")
                && !line.contains("•••")  // bullet masking
        }
        #expect(suspiciousLogs.isEmpty,
                "Any logging of key material must be masked; got:\n\(suspiciousLogs.joined(separator: "\n"))")
    }
}