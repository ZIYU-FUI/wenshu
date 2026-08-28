// SkillMetaTests.swift · Wenshu · v0.28
//
// Hermes-port validation tests for SkillMeta.swift
// (= wenshu M6 ticket 19 = hermes-port batch 3 ninth ticket).
//
// Tests cover:
// - SkillMeta.parse for SKILL.md frontmatter formats
// - SkillMeta.isSuitableForRuntime (= hermes platforms check)
// - SkillMeta.matches trigger matching
// - SkillCommandExtractor.extract single command parsing
// - SkillCommandExtractor.extractAll chained commands
// - Flag parsing (-flag / --flag)

import Foundation
import Testing
@testable import WenshuApp

@Suite("SkillMeta + SkillCommandExtractor (hermes verbatim port — M6 ticket 19)")
struct SkillMetaTests {

    // MARK: - Frontmatter parsing

    @Test("parse simple SKILL.md frontmatter")
    func parseSimple() {
        let md = """
        ---
        name: hello
        description: A simple greeting skill
        version: 1.0.0
        author: test-author
        license: MIT
        ---
        """
        let meta = SkillMeta.parse(skillMDContent: md)
        #expect(meta.name == "hello")
        #expect(meta.description == "A simple greeting skill")
        #expect(meta.version == "1.0.0")
        #expect(meta.author == "test-author")
        #expect(meta.license == "MIT")
    }

    @Test("parse SKILL.md with inline list fields")
    func parseInlineLists() {
        let md = """
        ---
        name: list-test
        description: test
        platforms: [linux, macos, windows]
        tags: [wiki, knowledge-base, research]
        ---
        """
        let meta = SkillMeta.parse(skillMDContent: md)
        #expect(meta.platforms == ["linux", "macos", "windows"])
        #expect(meta.tags == ["wiki", "knowledge-base", "research"])
    }

    @Test("parse SKILL.md with nested list fields")
    func parseNestedLists() {
        let md = """
        ---
        name: nested-test
        description: test
        related_skills:
          - obsidian
          - arxiv
        when_to_use:
          - ingest
          - add
          - process
        ---
        """
        let meta = SkillMeta.parse(skillMDContent: md)
        #expect(meta.relatedSkills == ["obsidian", "arxiv"])
        #expect(meta.whenToUse == ["ingest", "add", "process"])
    }

    @Test("parse SKILL.md without frontmatter (= empty defaults)")
    func parseNoFrontmatter() {
        let md = "Just body content, no frontmatter"
        let meta = SkillMeta.parse(skillMDContent: md)
        #expect(meta.name == "")
        #expect(meta.description == "")
        #expect(meta.version == "0.0.0")
    }

    // MARK: - Suitability

    @Test("isSuitableForRuntime returns true when macos in platforms")
    func suitableForMacos() {
        let meta = SkillMeta(name: "x", description: "x", platforms: ["macos", "linux"])
        #expect(meta.isSuitableForRuntime() == true)
    }

    @Test("isSuitableForRuntime returns false when only windows")
    func notSuitableForWindowsOnly() {
        let meta = SkillMeta(name: "x", description: "x", platforms: ["windows"])
        #expect(meta.isSuitableForRuntime() == false)
    }

    @Test("isSuitableForRuntime returns true for empty platforms list")
    func suitableForEmptyPlatforms() {
        let meta = SkillMeta(name: "x", description: "x", platforms: [])
        #expect(meta.isSuitableForRuntime() == true)
    }

    // MARK: - Trigger matching

    @Test("matches returns true for trigger phrase in whenToUse")
    func matchesTrigger() {
        let meta = SkillMeta(name: "x", description: "x", whenToUse: ["ingest", "add"])
        #expect(meta.matches(trigger: "Please ingest this article") == true)
        #expect(meta.matches(trigger: "add a new source") == true)
        #expect(meta.matches(trigger: "unrelated request") == false)
    }

    @Test("matches is case-insensitive")
    func matchesCaseInsensitive() {
        let meta = SkillMeta(name: "x", description: "x", whenToUse: ["INGEST"])
        #expect(meta.matches(trigger: "please ingest this") == true)
    }

    // MARK: - Command extraction

    @Test("extract returns nil for non-slash messages")
    func extractNonSlash() {
        #expect(SkillCommandExtractor.extract(from: "hello world") == nil)
    }

    @Test("extract parses simple command")
    func extractSimple() {
        let cmd = SkillCommandExtractor.extract(from: "/hello world")
        #expect(cmd?.skillName == "hello")
        #expect(cmd?.args == "world")
        #expect(cmd?.flags.isEmpty == true)
    }

    @Test("extract parses command with no args")
    func extractNoArgs() {
        let cmd = SkillCommandExtractor.extract(from: "/hello")
        #expect(cmd?.skillName == "hello")
        #expect(cmd?.args == "")
    }

    @Test("extract parses quoted args preserving whitespace")
    func extractQuotedArgs() {
        let cmd = SkillCommandExtractor.extract(from: #"/hello "foo bar baz""#)
        #expect(cmd?.skillName == "hello")
        #expect(cmd?.args == "\"foo bar baz\"")
    }

    @Test("extract parses flag-prefixed args")
    func extractFlags() {
        let cmd = SkillCommandExtractor.extract(from: "/hello -v --debug file.md")
        #expect(cmd?.skillName == "hello")
        #expect(cmd?.flags.contains("v") == true)
        #expect(cmd?.flags.contains("debug") == true)
        #expect(cmd?.args == "file.md")
    }

    @Test("extractAll parses multiple chained commands")
    func extractAllChained() {
        let commands = SkillCommandExtractor.extractAll(from: "/hello world /foo bar")
        #expect(commands.count == 2)
        #expect(commands[0].skillName == "hello")
        #expect(commands[1].skillName == "foo")
    }

    @Test("extractAll returns empty array when no commands")
    func extractAllEmpty() {
        let commands = SkillCommandExtractor.extractAll(from: "no commands here")
        #expect(commands.isEmpty)
    }

    // MARK: - Frontmatter split

    @Test("splitFrontmatter correctly partitions content")
    func splitFrontmatter() {
        let content = "---\nname: x\n---\n# body"
        let (fm, body) = SkillMeta.splitFrontmatter(content)
        #expect(fm.contains("name: x"))
        #expect(body.contains("# body"))
    }
}