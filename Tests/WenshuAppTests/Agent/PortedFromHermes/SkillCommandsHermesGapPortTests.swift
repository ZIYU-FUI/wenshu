//
//  SkillCommandsHermesGapPortTests.swift · Wenshu · P4-SKILL-COMMANDS-HERMES-PORT (2026-09-19)
//
//  Verifies the new hermes port addition to
//  `Core/Agent/Skill/SkillCommands.swift` (= hermes
//  `agent/skill_commands.py` 732 LOC Python, focusing on the
//  pure helpers per Q112 = 1 ticket per file).
//
//  Per AGENTS.md §11.3 wenshu-side wins: pure helper port; = no
//  scan_skill_commands / _load_skill_payload /
//  _build_skill_message / build_preloaded_skills_prompt (=
//  those fall into SkillBundles + SkillAdapter per the
//  wenshu-side-wins pattern).
//

import XCTest
@testable import WenshuApp

final class SkillCommandsHermesGapPortTests: XCTestCase {

    // MARK: -- resolveSkillCommandKey tests (= hermes L470-L484)

    func testResolveSkillCommandKey_emptyCommand_returnsNil() {
        XCTAssertNil(resolveSkillCommandKey("", availableKeys: ["/foo"]))
    }

    func testResolveSkillCommandKey_exactMatch_returnsCanonicalKey() {
        let keys: Set<String> = ["/claude-code", "/gpt-5"]
        XCTAssertEqual(resolveSkillCommandKey("claude-code", availableKeys: keys), "/claude-code")
    }

    func testResolveSkillCommandKey_underscoreConvertedToHyphen() {
        let keys: Set<String> = ["/claude-code"]
        XCTAssertEqual(resolveSkillCommandKey("claude_code", availableKeys: keys), "/claude-code")
    }

    func testResolveSkillCommandKey_notInKeys_returnsNil() {
        let keys: Set<String> = ["/foo"]
        XCTAssertNil(resolveSkillCommandKey("bar", availableKeys: keys))
    }

    func testResolveSkillCommandKey_emptyAvailableKeys_returnsNil() {
        XCTAssertNil(resolveSkillCommandKey("anything", availableKeys: []))
    }

    // MARK: -- splitStackedSkillCommands tests (= hermes L553-L583)

    func testSplitStackedSkillCommands_emptyRest_returnsEmpty() {
        let result = splitStackedSkillCommands("", availableKeys: ["/foo"])
        XCTAssertTrue(result.extra.isEmpty)
        XCTAssertEqual(result.remaining, "")
    }

    func testSplitStackedSkillCommands_restWithoutSlash_returnsRemainder() {
        let result = splitStackedSkillCommands("hello world", availableKeys: ["/foo"])
        XCTAssertTrue(result.extra.isEmpty)
        XCTAssertEqual(result.remaining, "hello world")
    }

    func testSplitStackedSkillCommands_singleSlashResolved() {
        let keys: Set<String> = ["/foo"]
        let result = splitStackedSkillCommands("/foo do the thing", availableKeys: keys)
        XCTAssertEqual(result.extra, ["/foo"])
        XCTAssertEqual(result.remaining, "do the thing")
    }

    func testSplitStackedSkillCommands_twoSlashesResolved() {
        let keys: Set<String> = ["/foo", "/bar"]
        let result = splitStackedSkillCommands("/foo /bar final instruction", availableKeys: keys)
        XCTAssertEqual(result.extra, ["/foo", "/bar"])
        XCTAssertEqual(result.remaining, "final instruction")
    }

    func testSplitStackedSkillCommands_unresolvedSlashBecomesRemainder() {
        let keys: Set<String> = ["/foo"]
        let result = splitStackedSkillCommands("/foo /unknown do thing", availableKeys: keys)
        XCTAssertEqual(result.extra, ["/foo"])
        XCTAssertEqual(result.remaining, "/unknown do thing")
    }

    func testSplitStackedSkillCommands_capsAtMax() {
        let keys: Set<String> = ["/a", "/b", "/c", "/d", "/e", "/f", "/g", "/h", "/i"]
        let result = splitStackedSkillCommands("/a /b /c /d /e /f /g /h /i /j rest", availableKeys: keys)
        XCTAssertEqual(result.extra.count, maxStackedSkills - 1)
    }

    func testSplitStackedSkillCommands_duplicateSkillNotReAdded() {
        let keys: Set<String> = ["/foo"]
        let result = splitStackedSkillCommands("/foo /foo rest", availableKeys: keys)
        XCTAssertEqual(result.extra, ["/foo"])
        XCTAssertEqual(result.remaining, "/foo rest")
    }

    func testSplitStackedSkillCommands_underscoreConversion() {
        let keys: Set<String> = ["/claude-code"]
        let result = splitStackedSkillCommands("/claude_code rest", availableKeys: keys)
        XCTAssertEqual(result.extra, ["/claude-code"])
        XCTAssertEqual(result.remaining, "rest")
    }

    func testSplitStackedSkillCommands_leadingWhitespaceConsumed() {
        let keys: Set<String> = ["/foo"]
        let result = splitStackedSkillCommands("   /foo   rest", availableKeys: keys)
        XCTAssertEqual(result.extra, ["/foo"])
        XCTAssertEqual(result.remaining, "rest")
    }

    func testSplitStackedSkillCommands_trailingWhitespaceStripped() {
        let keys: Set<String> = ["/foo"]
        let result = splitStackedSkillCommands("/foo", availableKeys: keys)
        XCTAssertEqual(result.extra, ["/foo"])
        XCTAssertEqual(result.remaining, "")
    }

    // MARK: -- Constants tests

    func testMaxStackedSkills_matchesHermes() {
        XCTAssertEqual(maxStackedSkills, 8)
    }

    // MARK: -- Spec check

    func testSourceFile_documentedAsHermesPort() {
        let sourcePath = #file
            .replacingOccurrences(of: "SkillCommandsHermesGapPortTests.swift", with: "")
            + "SkillCommands.swift"
        guard let source = try? String(contentsOfFile: sourcePath, encoding: .utf8) else {
            XCTFail("Could not read SkillCommands.swift at \(sourcePath)")
            return
        }
        XCTAssertTrue(source.contains("P4-SKILL-COMMANDS-HERMES-PORT"))
        XCTAssertTrue(source.contains("agent/skill_commands.py"))
        XCTAssertTrue(source.contains("Wenshu-side wins"))
        XCTAssertTrue(source.contains("resolveSkillCommandKey"))
        XCTAssertTrue(source.contains("splitStackedSkillCommands"))
    }
}
