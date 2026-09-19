//
//  SecretScopeHermesGapPortTests.swift · Wenshu · H3-SECRET-SCOPE-HERMES-PORT (2026-09-19)
//
//  Verifies the 3 new hermes port additions to
//  `Core/Auth/SecretScope.swift` (= hermes
//  `agent/secret_scope.py` env-file + global-env helpers):
//    - wenshuGlobalEnvExact (= hermes `_GLOBAL_ENV_EXACT` L99-L109,
//      wenshu-substituted per AGENTS.md §11.3)
//    - wenshuGlobalEnvPrefixes (= hermes `_GLOBAL_ENV_PREFIXES`
//      L111-L115, wenshu-substituted)
//    - isGlobalEnv (= hermes `_is_global_env` L117-L121)
//    - loadEnvFile (= hermes `load_env_file` L172-L202)
//    - buildProfileSecretScope (= hermes `build_profile_secret_scope`
//      L204-L209)
//
//  Per AGENTS.md §11.3 decision 1 (= wenshu-side wins):
//  the multiplex-contextvar logic (= `set_secret_scope`,
//  `get_secret`, `_SECRET_SCOPE`, `_MULTIPLEX_ACTIVE`,
//  `UnscopedSecretError`) is hermes-multi-profile-specific
//  (= wenshu is single-profile per AGENTS.md §11 "single-shelf
//  model"; = future ticket can port it if wenshu ever adds
//  multi-profile multiplexer).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("SecretScope hermes-Python gap port (H3)")
struct SecretScopeHermesGapPortTests {

    /// H3.1 contract: wenshuGlobalEnvExact contains WENSHU_HOME
    /// (= hermes L101 substitution per AGENTS.md §11.3).
    @Test func wenshuGlobalEnvExact_contains_wenshu_home() {
        #expect(SecretScope.wenshuGlobalEnvExact.contains("WENSHU_HOME"))
    }

    /// H3.1 contract: wenshuGlobalEnvExact does NOT contain
    /// HERMES_-prefixed entries (= hermes-prefixed entries
    /// replaced with wenshu-prefixed per wenshu-side wins).
    @Test func wenshuGlobalEnvExact_no_hermes_entries() {
        for entry in SecretScope.wenshuGlobalEnvExact {
            #expect(!entry.hasPrefix("HERMES_"),
                   "wenshu-global env should not contain hermes-prefixed: \(entry)")
        }
    }

    /// H3.1 contract: wenshuGlobalEnvExact contains OS essentials.
    @Test func wenshuGlobalEnvExact_contains_os_essentials() {
        for entry in ["PATH", "HOME", "USER", "LANG", "TZ", "TMPDIR"] {
            #expect(SecretScope.wenshuGlobalEnvExact.contains(entry),
                   "wenshu-global env should contain OS essential: \(entry)")
        }
    }

    /// H3.2 contract: wenshuGlobalEnvPrefixes contains TERMINAL_
    /// (= hermes L115 = "terminal/sandbox backend settings").
    @Test func wenshuGlobalEnvPrefixes_contains_terminal() {
        #expect(SecretScope.wenshuGlobalEnvPrefixes.contains("TERMINAL_"))
    }

    /// H3.2 contract: wenshuGlobalEnvPrefixes does NOT contain
    /// HERMES_-prefixed entries (= hermes L112-L114 = HERMES_KANBAN_
    /// and HERMES_TELEGRAM_ are hermes-specific).
    @Test func wenshuGlobalEnvPrefixes_no_hermes_entries() {
        for prefix in SecretScope.wenshuGlobalEnvPrefixes {
            #expect(!prefix.hasPrefix("HERMES_"),
                   "wenshu-global prefix should not be hermes-prefixed: \(prefix)")
        }
    }

    /// H3.3 contract: isGlobalEnv returns true for exact matches.
    @Test func isGlobalEnv_exact_match() {
        #expect(SecretScope.isGlobalEnv("WENSHU_HOME"))
        #expect(SecretScope.isGlobalEnv("PATH"))
        #expect(SecretScope.isGlobalEnv("HOME"))
    }

    /// H3.3 contract: isGlobalEnv returns true for prefix matches.
    @Test func isGlobalEnv_prefix_match() {
        #expect(SecretScope.isGlobalEnv("TERMINAL_BACKEND"))
        #expect(SecretScope.isGlobalEnv("TERMINAL_TIMEOUT"))
    }

    /// H3.3 contract: isGlobalEnv returns false for non-global vars.
    @Test func isGlobalEnv_rejects_non_global() {
        #expect(!SecretScope.isGlobalEnv("ANTHROPIC_API_KEY"))
        #expect(!SecretScope.isGlobalEnv("OPENAI_API_KEY"))
        #expect(!SecretScope.isGlobalEnv("MY_SECRET"))
    }

    /// H3.4 contract: loadEnvFile parses basic .env (= hermes L172-L202).
    @Test func loadEnvFile_parses_basic() throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wenshu-h3-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }
        let envPath = tmpDir.appendingPathComponent(".env")
        let content = """
        # This is a comment
        ANTHROPIC_API_KEY=sk-test-123
        OPENAI_API_KEY=sk-openai-456

        OPENROUTER_KEY=sk-or-789
        # Another comment
        """
        try content.write(to: envPath, atomically: true, encoding: .utf8)
        let result = SecretScope.loadEnvFile(envPath)
        #expect(result["ANTHROPIC_API_KEY"] == "sk-test-123")
        #expect(result["OPENAI_API_KEY"] == "sk-openai-456")
        #expect(result["OPENROUTER_KEY"] == "sk-or-789")
        #expect(result.count == 3)
    }

    /// H3.4 contract: loadEnvFile strips optional matching quotes
    /// (= hermes L195-L198).
    @Test func loadEnvFile_strips_quotes() throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wenshu-h3-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }
        let envPath = tmpDir.appendingPathComponent(".env")
        let content = """
        DOUBLE_QUOTED="hello world"
        SINGLE_QUOTED='foo bar'
        NO_QUOTES=baz
        MIXED_LEADING="leading-quote
        """
        try content.write(to: envPath, atomically: true, encoding: .utf8)
        let result = SecretScope.loadEnvFile(envPath)
        #expect(result["DOUBLE_QUOTED"] == "hello world")
        #expect(result["SINGLE_QUOTED"] == "foo bar")
        #expect(result["NO_QUOTES"] == "baz")
        // Mixed-leading (only leading quote, no closing) is treated
        // as literal (= matches hermes L195-L198 = strip only
        // matching quotes).
        #expect(result["MIXED_LEADING"]?.hasPrefix("\"") == true)
    }

    /// H3.4 contract: loadEnvFile strips "export " prefix
    /// (= hermes L188-L189).
    @Test func loadEnvFile_strips_export_prefix() throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wenshu-h3-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }
        let envPath = tmpDir.appendingPathComponent(".env")
        let content = """
        export KEY1=value1
        export KEY2=value2
        KEY3=value3
        """
        try content.write(to: envPath, atomically: true, encoding: .utf8)
        let result = SecretScope.loadEnvFile(envPath)
        #expect(result["KEY1"] == "value1")
        #expect(result["KEY2"] == "value2")
        #expect(result["KEY3"] == "value3")
    }

    /// H3.4 contract: loadEnvFile returns empty dict for missing
    /// file (= hermes L175-L178).
    @Test func loadEnvFile_returns_empty_for_missing() {
        let result = SecretScope.loadEnvFile(
            URL(fileURLWithPath: "/nonexistent/.env")
        )
        #expect(result.isEmpty)
    }

    /// H3.4 contract: loadEnvFile returns empty dict for invalid
    /// (= non-utf8) file (= hermes L177 = UnicodeDecodeError).
    @Test func loadEnvFile_returns_empty_for_invalid_utf8() throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wenshu-h3-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }
        let envPath = tmpDir.appendingPathComponent(".env")
        // Write invalid UTF-8 bytes
        let invalidBytes: [UInt8] = [0xFF, 0xFE, 0xFD, 0xFC]
        try Data(invalidBytes).write(to: envPath)
        let result = SecretScope.loadEnvFile(envPath)
        #expect(result.isEmpty)
    }

    /// H3.4 contract: loadEnvFile handles values with `=` chars
    /// (= hermes L186 = partition on first `=`).
    @Test func loadEnvFile_handles_value_with_equals() throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wenshu-h3-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }
        let envPath = tmpDir.appendingPathComponent(".env")
        let content = "URL=https://example.com/path?query=value&other=1"
        try content.write(to: envPath, atomically: true, encoding: .utf8)
        let result = SecretScope.loadEnvFile(envPath)
        #expect(result["URL"] == "https://example.com/path?query=value&other=1")
    }

    /// H3.5 contract: buildProfileSecretScope reads `<wenshu-home>/.env`
    /// (= hermes `build_profile_secret_scope` L204-L209).
    @Test func buildProfileSecretScope_reads_wenshu_home_env() throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wenshu-h3-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }
        let envPath = tmpDir.appendingPathComponent(".env")
        try "WENSHU_API_KEY=test-key".write(
            to: envPath, atomically: true, encoding: .utf8
        )
        let result = SecretScope.buildProfileSecretScope(wenshuHome: tmpDir)
        #expect(result["WENSHU_API_KEY"] == "test-key")
    }

    /// H3.5 contract: buildProfileSecretScope returns empty dict for
    /// missing .env (= hermes safe-default).
    @Test func buildProfileSecretScope_empty_for_missing() {
        let result = SecretScope.buildProfileSecretScope(
            wenshuHome: URL(fileURLWithPath: "/nonexistent")
        )
        #expect(result.isEmpty)
    }
}
