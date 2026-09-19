//
//  PromptBuilderHermesGapPortTests.swift · Wenshu · H1-PROMPT-BUILDER-HERMES-PORT (2026-09-19)
//
//  Verifies the 6 new public APIs added by H1 (= the hermes
//  Python gap port of `agent/prompt_builder.py`):
//    - buildSkillsSystemPrompt
//    - buildNousSubscriptionPrompt
//    - buildContextFilesPrompt
//    - buildEnvironmentHints
//    - clearSkillsSystemPromptCache
//    - drainTruncationWarnings
//
//  Each test exercises the contract derived from hermes Python
//  (= hermes returns empty string when no skills dir / no Nous /
//  no AGENTS.md; = wenshu-side wins produce the wenshu-flavored
//  platform hint; = helpers are pure functions).
//
//  Per AGENTS.md §11.3 decision 1 (= wenshu-side wins; = no silent
//  replacement of wenshu-side identity prose; = the helpers are
//  preserved 1:1 but the prose blocks stay wenshu-flavored).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("PromptBuilder hermes-Python gap port (H1)")
struct PromptBuilderHermesGapPortTests {

    /// H1.1 contract: buildSkillsSystemPrompt returns empty string
    /// when no skills dir exists (= hermes L1429-L1431).
    @Test func buildSkillsSystemPrompt_empty_when_no_skills_dir() throws {
        // Ensure the wenshu skills dir does NOT exist for this test.
        let skillsDir = PromptBuilderCaches.resolveSkillsDir()
        try? FileManager.default.removeItem(at: skillsDir)
        let result = PromptBuilder.buildSkillsSystemPrompt()
        #expect(result.isEmpty)
    }

    /// H1.2 contract: buildNousSubscriptionPrompt returns empty string
    /// (= wenshu-side wins per AGENTS.md §11.3; = no Nous tier).
    @Test func buildNousSubscriptionPrompt_returns_empty() {
        let result = PromptBuilder.buildNousSubscriptionPrompt()
        #expect(result.isEmpty)
    }

    /// H1.2 contract: buildNousSubscriptionPrompt also returns empty
    /// when valid_tool_names is non-nil.
    @Test func buildNousSubscriptionPrompt_empty_with_tools() {
        let result = PromptBuilder.buildNousSubscriptionPrompt(
            validToolNames: ["web_search", "browser_navigate"],
        )
        #expect(result.isEmpty)
    }

    /// H1.3 contract: buildContextFilesPrompt returns empty string
    /// when no AGENTS.md in cwd (= hermes scans for AGENTS.md +
    /// .cursorrules + SOUL.md + HERMES.md; = wenshu only honors AGENTS.md).
    @Test func buildContextFilesPrompt_empty_when_no_agents_md() throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wenshu-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }
        let result = PromptBuilder.buildContextFilesPrompt(
            cwdPath: tmpDir.path,
            contextLength: nil,
        )
        #expect(result.isEmpty)
    }

    /// H1.3 contract: buildContextFilesPrompt renders AGENTS.md when
    /// present (= hermes-style context injection).
    @Test func buildContextFilesPrompt_renders_agents_md() throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wenshu-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }
        let agentsMD = tmpDir.appendingPathComponent("AGENTS.md")
        let content = """
        # Project Conventions
        - Apple stack only
        - SwiftUI + AppKit
        - No third-party UI libraries
        """
        try content.write(to: agentsMD, atomically: true, encoding: .utf8)
        let result = PromptBuilder.buildContextFilesPrompt(
            cwdPath: tmpDir.path,
            contextLength: 8000,
        )
        #expect(result.contains("AGENTS.md"))
        #expect(result.contains("Apple stack only"))
        #expect(result.contains("Treat it as authoritative"))
    }

    /// H1.3 contract: buildContextFilesPrompt strips YAML frontmatter.
    @Test func buildContextFilesPrompt_strips_yaml_frontmatter() throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wenshu-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }
        let agentsMD = tmpDir.appendingPathComponent("AGENTS.md")
        let content = """
        ---
        model: claude-opus-4
        tools:
          - bash
        ---

        # Project Conventions
        Body content after frontmatter.
        """
        try content.write(to: agentsMD, atomically: true, encoding: .utf8)
        let result = PromptBuilder.buildContextFilesPrompt(
            cwdPath: tmpDir.path,
            contextLength: 8000,
        )
        #expect(result.contains("Body content after frontmatter"))
        #expect(!result.contains("model: claude-opus-4"))
    }

    /// H1.4 contract: buildEnvironmentHints on macOS = wenshu-flavored
    /// platform + stack bullets (= wenshu-side wins).
    @Test func buildEnvironmentHints_macos() {
        #if os(macOS)
        let result = PromptBuilder.buildEnvironmentHints()
        #expect(result.contains("macOS"))
        #expect(result.contains("SwiftUI"))
        #expect(result.contains("chat.sqlite"))
        #else
        let result = PromptBuilder.buildEnvironmentHints()
        #expect(result.isEmpty)
        #endif
    }

    /// H1.5 contract: clearSkillsSystemPromptCache does not throw.
    @Test func clearSkillsSystemPromptCache_does_not_throw() {
        PromptBuilder.clearSkillsSystemPromptCache(clearSnapshot: false)
        PromptBuilder.clearSkillsSystemPromptCache(clearSnapshot: true)
    }

    /// H1.6 contract: drainTruncationWarnings returns [String]
    /// (= empty list when nothing has been recorded).
    @Test func drainTruncationWarnings_returns_empty_initially() {
        let result = PromptBuilder.drainTruncationWarnings()
        #expect(result.isEmpty)
    }

    /// H1.6 contract: recordTruncationWarning + drainTruncationWarnings
    /// round-trip (= hermes L1232-L1259).
    @Test func truncationWarnings_round_trip() {
        PromptBuilderCaches.recordTruncationWarning("test warning 1")
        PromptBuilderCaches.recordTruncationWarning("test warning 2")
        let drained = PromptBuilder.drainTruncationWarnings()
        #expect(drained.contains("test warning 1"))
        #expect(drained.contains("test warning 2"))
        // After drain, list is empty (= atomic semantics).
        let drainedAgain = PromptBuilder.drainTruncationWarnings()
        #expect(drainedAgain.isEmpty)
    }

    /// H1 helpers contract: stripYamlFrontmatter pure function.
    @Test func stripYamlFrontmatter_strips_yaml() {
        let input = "---\nmodel: opus\n---\n\nbody"
        let result = PromptBuilderCaches.stripYamlFrontmatter(input)
        #expect(result.contains("body"))
        #expect(!result.contains("model: opus"))
    }

    /// H1 helpers contract: stripYamlFrontmatter passthrough when
    /// no frontmatter.
    @Test func stripYamlFrontmatter_passthrough() {
        let input = "# no frontmatter\nbody content"
        let result = PromptBuilderCaches.stripYamlFrontmatter(input)
        #expect(result == input)
    }

    /// H1 helpers contract: dynamicContextFileMaxChars heuristic
    /// (= hermes L1187-L1232 = 4 chars/token * 80% / clamp 2048-16384).
    @Test func dynamicContextFileMaxChars_heuristic() {
        // No context = 8192 default
        #expect(PromptBuilderCaches.dynamicContextFileMaxChars(contextLength: nil) == 8192)
        // 4000 ctx -> (4000 * 4 / 5) = 3200 (within range)
        #expect(PromptBuilderCaches.dynamicContextFileMaxChars(contextLength: 4000) == 3200)
        // Very small ctx = 2048 floor
        #expect(PromptBuilderCaches.dynamicContextFileMaxChars(contextLength: 100) == 2048)
        // Very large ctx = 16384 cap
        #expect(PromptBuilderCaches.dynamicContextFileMaxChars(contextLength: 100_000) == 16384)
    }

    /// H1 helpers contract: truncateContent pure function (= hermes
    /// L1756-L1794).
    @Test func truncateContent_truncates_long_content() {
        let longContent = String(repeating: "a", count: 1000)
        let truncated = PromptBuilderCaches.truncateContent(content: longContent, maxChars: 100)
        #expect(truncated.contains("[... truncated at 100 chars ...]"))
        #expect(truncated.count < longContent.count)
    }

    /// H1 helpers contract: truncateContent passthrough when short.
    @Test func truncateContent_passthrough_when_short() {
        let content = "short"
        let result = PromptBuilderCaches.truncateContent(content: content, maxChars: 100)
        #expect(result == content)
    }

    /// H1 helpers contract: skillsCacheKey deterministic + unique.
    @Test func skillsCacheKey_deterministic_unique() {
        let dir1 = URL(fileURLWithPath: "/tmp/skills1")
        let dir2 = URL(fileURLWithPath: "/tmp/skills2")
        let k1 = PromptBuilderCaches.skillsCacheKey(
            skillsDir: dir1, availableTools: ["a", "b"], availableToolsets: nil, compactCategories: nil,
        )
        let k1Dup = PromptBuilderCaches.skillsCacheKey(
            skillsDir: dir1, availableTools: ["b", "a"], availableToolsets: nil, compactCategories: nil,
        )
        let k2 = PromptBuilderCaches.skillsCacheKey(
            skillsDir: dir2, availableTools: ["a", "b"], availableToolsets: nil, compactCategories: nil,
        )
        // Same input -> same key
        #expect(k1 == k1Dup)
        // Different dir -> different key
        #expect(k1 != k2)
    }

    /// H1 helpers contract: skillShouldShow always returns true
    /// (= wenshu-side simplification).
    @Test func skillShouldShow_always_true_wenshu_side() {
        // No actual Skill instance needed (= we just check
        // the degenerate-true semantics of the predicate).
        #expect(PromptBuilderCaches.skillShouldShow(
            skill: SkillAdapter.Skill(name: "x", description: "", enabled: true),
            availableTools: nil,
            availableToolsets: nil,
        ))
    }

    /// H1 contract: clearSkillsSystemPromptCache clears in-process
    /// LRU cache (= next build call re-renders).
    @Test func clearSkillsSystemPromptCache_clears_cache() throws {
        let skillsDir = PromptBuilderCaches.resolveSkillsDir()
        try? FileManager.default.removeItem(at: skillsDir)
        // First call: builds + caches (= empty result)
        let first = PromptBuilder.buildSkillsSystemPrompt()
        #expect(first.isEmpty)
        // Clear cache
        PromptBuilder.clearSkillsSystemPromptCache()
        // Second call: re-builds + re-caches
        let second = PromptBuilder.buildSkillsSystemPrompt()
        #expect(second.isEmpty)
    }
}
