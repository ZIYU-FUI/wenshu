//
//  CronjobToolsTests.swift · Wenshu · HERMES-PARTIAL-010 (2026-09-04)
//
//  Round-trip tests for the CronjobTools LLM-facing dispatcher
// (= hermes cronjob_tools.py = 1,137 LOC):
//    1. testCreateAndList               — create + list round-trip
//    2. testGetUnknown                  — get nonexistent returns error
//    3. testPauseResume                 — pause / resume toggle enabled
//    4. testRemove                      — remove + verify gone
//    5. testUnknownAction               — unknown action returns error
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("CronjobTools (HERMES-PARTIAL-010)")
struct CronjobToolsTests {

    // MARK: - Test 1: Create + list

    @Test("create + list round-trip preserves the job")
    func testCreateAndList() async {
        let tools = CronjobTools()
        let createParams = CronjobTools.CronJobParams(
            schedule: "0 * * * *",
            prompt: "save the current chapter",
            name: "HourlySave"
        )
        let createResult = await tools.cronjob(action: "create", params: createParams)
        #expect(createResult.success == true)
        let listResult = await tools.cronjob(action: "list")
        #expect(listResult.success == true)
        #expect(listResult.output.contains("HourlySave"))
    }

    // MARK: - Test 2: Get unknown

    @Test("get nonexistent job returns failure")
    func testGetUnknown() async {
        let tools = CronjobTools()
        let result = await tools.cronjob(action: "get", params: CronjobTools.CronJobParams(jobId: "nope"))
        #expect(result.success == false)
        #expect(result.output.contains("No job with id"))
    }

    // MARK: - Test 3: Pause / resume

    @Test("pause then resume toggles enabled")
    func testPauseResume() async {
        let tools = CronjobTools()
        _ = await tools.cronjob(action: "create", params: CronjobTools.CronJobParams(
            schedule: "*/5 * * * *",
            prompt: "ping",
            name: "Ping"
        ))
        let list1 = await tools.cronjob(action: "list")
        // Extract the first job id from the output.
        let firstLine = list1.output.split(separator: "\n").first.map(String.init) ?? ""
        let id = firstLine.split(separator: ":").first.map(String.init) ?? ""
        let pauseResult = await tools.cronjob(action: "pause", params: CronjobTools.CronJobParams(jobId: id))
        #expect(pauseResult.success == true)
        let resumeResult = await tools.cronjob(action: "resume", params: CronjobTools.CronJobParams(jobId: id))
        #expect(resumeResult.success == true)
    }

    // MARK: - Test 4: Remove

    @Test("remove deletes the job")
    func testRemove() async {
        let tools = CronjobTools()
        _ = await tools.cronjob(action: "create", params: CronjobTools.CronJobParams(
            schedule: "0 0 * * *",
            prompt: "doomed",
            name: "Doomed"
        ))
        let list1 = await tools.cronjob(action: "list")
        let firstLine = list1.output.split(separator: "\n").first.map(String.init) ?? ""
        let id = firstLine.split(separator: ":").first.map(String.init) ?? ""
        let removeResult = await tools.cronjob(action: "remove", params: CronjobTools.CronJobParams(jobId: id))
        #expect(removeResult.success == true)
        let getResult = await tools.cronjob(action: "get", params: CronjobTools.CronJobParams(jobId: id))
        #expect(getResult.success == false)
    }

    // MARK: - Test 5: Unknown action

    @Test("unknown action returns failure with helpful list")
    func testUnknownAction() async {
        let tools = CronjobTools()
        let result = await tools.cronjob(action: "explode")
        #expect(result.success == false)
        #expect(result.output.contains("Unknown cronjob action"))
        #expect(result.output.contains("create"))
        #expect(result.output.contains("list"))
    }
}