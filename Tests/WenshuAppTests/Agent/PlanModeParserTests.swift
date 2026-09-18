//
//  PlanModeParserTests.swift · Wenshu · T20-PLAN-MODE (2026-09-18)
//
//  Verifies the PlanModeParser (= the pure-function half of
//  PlanModeEngine). The actor / LLMConnector half is exercised
//  by MockLLMConnector in a separate end-to-end test.
//
//  Contract surface:
//    - parses a standard numbered list into [PlanStep]
//    - "Title: detail" pattern splits on first colon
//    - markdown bold markers (**) are stripped
//    - continuation lines after a step attach to that step's detail
//    - empty / single-step / multi-step inputs
//    - gracefully returns [] for non-numbered content
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("PlanModeParser (T20)")
struct PlanModeParserTests {

    /// T20 contract: standard 3-step plan parses with indices preserved.
    @Test func parses_three_step_plan() {
        let raw = """
        1. Search for documentation: Find the latest SwiftUI reference for the streaming API.
        2. Plan the test cases: List 3 tests covering happy path + edge cases.
        3. Write the tests: Generate a test file with the 3 cases.
        """
        let steps = PlanModeParser.parseSteps(raw)
        #expect(steps.count == 3)
        #expect(steps[0].index == 1)
        #expect(steps[0].title == "Search for documentation")
        #expect(steps[0].detail == "Find the latest SwiftUI reference for the streaming API.")
        #expect(steps[1].index == 2)
        #expect(steps[1].title == "Plan the test cases")
        #expect(steps[2].index == 3)
        #expect(steps[2].title == "Write the tests")
    }

    /// T20 contract: continuation lines (= blank number prefix)
    /// attach to the previous step's detail.
    @Test func continuation_lines_attach_to_previous_step() {
        let raw = """
        1. First step: starts here
           continues on this line with more context
           and ends here
        2. Second step: short.
        """
        let steps = PlanModeParser.parseSteps(raw)
        #expect(steps.count == 2)
        #expect(steps[0].title == "First step")
        #expect(steps[0].detail.contains("continues on this line"))
        #expect(steps[0].detail.contains("and ends here"))
    }

    /// T20 contract: markdown bold markers (**) are stripped from
    /// the title.
    @Test func bold_markers_stripped_from_title() {
        let raw = """
        **1. Read the file**: Open foo.txt and read the first 50 lines.
        **2. Summarize**: Produce a 3-sentence summary.
        """
        let steps = PlanModeParser.parseSteps(raw)
        #expect(steps.count == 2)
        #expect(steps[0].title == "Read the file")
        #expect(steps[1].title == "Summarize")
    }

    /// T20 contract: lines without numbered prefix are ignored
    /// (= preambles, trailing notes).
    @Test func preamble_lines_ignored() {
        let raw = """
        Here is the plan I propose:
        1. First step: detail A.
        2. Second step: detail B.

        Let me know if this works.
        """
        let steps = PlanModeParser.parseSteps(raw)
        #expect(steps.count == 2)
        #expect(steps[0].index == 1)
        #expect(steps[1].index == 2)
    }

    /// T20 contract: step with no colon (= title only, no detail).
    @Test func title_only_step_no_colon() {
        let raw = """
        1. Just a title
        2. Title with detail: detail here.
        """
        let steps = PlanModeParser.parseSteps(raw)
        #expect(steps.count == 2)
        #expect(steps[0].title == "Just a title")
        #expect(steps[0].detail == "")
        #expect(steps[1].title == "Title with detail")
        #expect(steps[1].detail == "detail here.")
    }

    /// T20 contract: empty input returns empty steps.
    @Test func empty_input_returns_empty_steps() {
        let steps = PlanModeParser.parseSteps("")
        #expect(steps.isEmpty)
    }

    /// T20 contract: no numbered content (= plain text, prose)
    /// returns empty steps.
    @Test func no_numbered_content_returns_empty() {
        let raw = "This is just some prose with no numbered steps at all."
        let steps = PlanModeParser.parseSteps(raw)
        #expect(steps.isEmpty)
    }

    /// T20 contract: 10+ step plan (= indices > 9 = two-digit
    /// numbering) parses correctly.
    @Test func multi_digit_indices() {
        var raw = ""
        for i in 1...12 {
            raw += "\(i). Step number \(i): description for step \(i).\n"
        }
        let steps = PlanModeParser.parseSteps(raw)
        #expect(steps.count == 12)
        #expect(steps[9].index == 10)
        #expect(steps[11].index == 12)
    }

    /// T20 contract: parse(...) returns nil when no numbered steps
    /// (= Plan engine raises planParseFailed).
    @Test func parse_returns_nil_for_no_steps() {
        let raw = "This is just prose."
        let plan = PlanModeParser.parse(
            response: raw,
            query: "test query",
            connectorID: "mock"
        )
        #expect(plan == nil)
    }

    /// T20 contract: parse(...) returns Plan when steps found.
    @Test func parse_returns_plan_for_valid_input() {
        let raw = "1. First: do this.\n2. Second: do that."
        let plan = PlanModeParser.parse(
            response: raw,
            query: "test query",
            connectorID: "anthropic"
        )
        #expect(plan != nil)
        #expect(plan?.query == "test query")
        #expect(plan?.connectorID == "anthropic")
        #expect(plan?.steps.count == 2)
    }
}