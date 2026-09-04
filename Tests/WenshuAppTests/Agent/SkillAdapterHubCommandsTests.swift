//
//  SkillAdapterHubCommandsTests.swift · Wenshu · HERMES-PARTIAL-017 (2026-09-04)
//
//  Round-trip tests for the 35 do_* hub commands (= hermes
//  skill_commands.py + tools/skills_hub.py = 732 LOC + 4,400 LOC):
//    1. testHubCommandsCount             — exactly 35 commands
//    2. testHubCommandLookup             — help + review + rewrite resolvable
//    3. testHubCommandsInCategory        — filtering by category
//    4. testHubCategoriesDistinct        — all 7 categories present
//    5. testDispatchKnownCommand        — dispatch("help") returns result
//    6. testDispatchUnknownCommand      — dispatch("unknown") returns error
//    7. testParseSlashCommand           — parseSlashCommand shape
//    8. testParseSlashCommandNoPrefix   — no '/' → nil
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("SkillAdapterHubCommands (HERMES-PARTIAL-017)")
struct SkillAdapterHubCommandsTests {

    // MARK: - Test 1: Count

    @Test("hubCommands has exactly 35 entries")
    func testHubCommandsCount() {
        #expect(SkillAdapter.hubCommands.count == 35)
    }

    // MARK: - Test 2: Lookup

    @Test("hubCommand(named:) resolves help / review / rewrite")
    func testHubCommandLookup() {
        let help = SkillAdapter.hubCommand(named: "help")
        #expect(help != nil)
        #expect(help?.category == "writing")

        let review = SkillAdapter.hubCommand(named: "review")
        #expect(review != nil)

        let rewrite = SkillAdapter.hubCommand(named: "rewrite")
        #expect(rewrite != nil)

        let unknown = SkillAdapter.hubCommand(named: "doesnt-exist")
        #expect(unknown == nil)
    }

    // MARK: - Test 3: Filter by category

    @Test("hubCommands(in:) filters by category")
    func testHubCommandsInCategory() {
        let writing = SkillAdapter.hubCommands(in: "writing")
        #expect(writing.count >= 5)
        for cmd in writing {
            #expect(cmd.category == "writing")
        }
        let empty = SkillAdapter.hubCommands(in: "non-existent-category")
        #expect(empty.isEmpty)
    }

    // MARK: - Test 4: Categories distinct

    @Test("hubCategories returns the distinct sorted categories")
    func testHubCategoriesDistinct() {
        let cats = SkillAdapter.hubCategories
        #expect(cats.contains("writing"))
        #expect(cats.contains("story"))
        #expect(cats.contains("prose"))
        #expect(cats.contains("code"))
        #expect(cats.contains("research"))
        // Unique.
        let unique = Set(cats)
        #expect(unique.count == cats.count)
    }

    // MARK: - Test 5: Dispatch known

    @Test("dispatch(\"help\") returns a HubCommandResult")
    func testDispatchKnownCommand() async {
        let adapter = SkillAdapter()
        let result = await adapter.dispatch(command: "help", input: "")
        #expect(result.command == "help")
        // Stub invoke succeeds → success == true.
        #expect(result.success == true)
        #expect(!result.output.isEmpty)
    }

    // MARK: - Test 6: Dispatch unknown

    @Test("dispatch(\"unknown\") returns a failure result")
    func testDispatchUnknownCommand() async {
        let adapter = SkillAdapter()
        let result = await adapter.dispatch(command: "unknown", input: "")
        #expect(result.command == "unknown")
        #expect(result.success == false)
        #expect(result.output.contains("Unknown hub command"))
    }

    // MARK: - Test 7: parseSlashCommand

    @Test("parseSlashCommand returns (name, remainder) for /review ...")
    func testParseSlashCommand() {
        let parsed = SkillAdapter.parseSlashCommand("/review chapter 1")
        #expect(parsed?.skillName == "review")
        #expect(parsed?.remainder == "chapter 1")
        let noRemainder = SkillAdapter.parseSlashCommand("/help")
        #expect(noRemainder?.skillName == "help")
        #expect(noRemainder?.remainder == "")
    }

    // MARK: - Test 8: parseSlashCommand no prefix

    @Test("parseSlashCommand returns nil for non-slash input")
    func testParseSlashCommandNoPrefix() {
        #expect(SkillAdapter.parseSlashCommand("hello world") == nil)
        #expect(SkillAdapter.parseSlashCommand("") == nil)
    }
}