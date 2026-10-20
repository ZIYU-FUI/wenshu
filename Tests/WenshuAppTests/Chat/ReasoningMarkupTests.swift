// ReasoningMarkupTests.swift
//
// The reasoning is split into labelled steps so the reader can see what
// the assistant was doing, not just what it eventually said.
//
// Hermes gets this from the model: the model writes its work log with
// action and result markers. A model that never learned to write them
// produces one undifferentiated block, which is why the tool-derived
// activity exists alongside this parser.

import Foundation
import Testing
@testable import WenshuApp

@Suite("Reasoning markup")
struct ReasoningMarkupTests {

    @Test("a marker with no prose is still a step")
    func markerAloneBecomesAStep() {
        let segments = ReasoningMarkupParser.parse("<action>Reading the outline</action>")
        #expect(segments == [.action("Reading the outline")])
    }

    @Test("prose around a marker is kept")
    func proseAroundAMarkerIsKept() {
        let segments = ReasoningMarkupParser.parse("Let me check.\n<action>Reading</action>\nThen I will answer.")
        #expect(segments.count == 3)
        #expect(segments[0] == .prose("Let me check."))
        #expect(segments[1] == .action("Reading"))
        #expect(segments[2] == .prose("\nThen I will answer."))
    }

    @Test("action and result are different kinds")
    func actionAndResultDiffer() {
        let segments = ReasoningMarkupParser.parse(
            "<action>Reading chapter-03.md</action><result>It has 40 lines</result>"
        )
        #expect(segments == [
            .action("Reading chapter-03.md"),
            .result("It has 40 lines"),
        ])
    }

    @Test("thinking and reflection stay prose")
    func thinkingAndReflectionStayProse() {
        let segments = ReasoningMarkupParser.parse("<thinking>considering</thinking><reflection>maybe</reflection>")
        #expect(segments.count == 1)
        #expect(segments[0] == .prose("consideringmaybe"))
    }

    @Test("a marker inside a code fence is text")
    func markerInsideCodeFenceIsText() {
        let content = """
        Here is the snippet:
        ```
        <action>not a marker</action>
        ```
        """
        let segments = ReasoningMarkupParser.parse(content)
        #expect(!segments.contains { $0 == .action("not a marker") },
                "a marker inside a fence is code, not structure")
    }

    @Test("an unclosed marker does not swallow the rest")
    func unclosedMarkerDoesNotSwallowTheRest() {
        // The model may have been cut off mid-sentence. Treating the rest of
        // the message as marker content would hide the reply.
        let segments = ReasoningMarkupParser.parse("<action>Reading the outl")
        #expect(segments == [.prose("<action>Reading the outl")])
    }

    @Test("neighbouring prose is merged")
    func neighbouringProseIsMerged() {
        let segments = ReasoningMarkupParser.parse("first <thinking>x</thinking> second")
        #expect(segments.count == 1)
    }

    @Test("markup detection matches the parser")
    func markupDetectionMatchesTheParser() {
        #expect(ReasoningMarkupParser.hasMarkup("<action>x</action>"))
        #expect(!ReasoningMarkupParser.hasMarkup("just prose"))
        #expect(!ReasoningMarkupParser.hasMarkup("```\n<action>x</action>\n```"))
    }

    @Test("an empty reasoning produces no segments")
    func emptyReasoningProducesNoSegments() {
        #expect(ReasoningMarkupParser.parse("").isEmpty)
    }
}

@Suite("Tool activity")
struct ToolActivityTests {

    @Test("a file read is described with its target")
    func fileReadIsDescribed() {
        let text = ToolActivityNarrator.action(
            toolName: "ReadFile",
            arguments: #"{"path": "chapters/chapter-03.md"}"#
        )
        #expect(text.contains("chapters/chapter-03.md"))
        #expect(text.contains("Reading"))
    }

    @Test("a web search is described with its query")
    func webSearchIsDescribed() {
        let text = ToolActivityNarrator.action(
            toolName: "web_search",
            arguments: #"{"query": "sea navigation 1800s"}"#
        )
        #expect(text.contains("sea navigation 1800s"))
    }

    @Test("an unknown tool still reads as a sentence")
    func unknownToolStillReads() {
        let text = ToolActivityNarrator.action(toolName: "mystery_tool", arguments: "{}")
        #expect(text.contains("mystery_tool"))
        #expect(text.first?.isUppercase == true)
    }

    @Test("malformed arguments do not break the sentence")
    func malformedArgumentsDoNotBreakTheSentence() {
        let text = ToolActivityNarrator.action(toolName: "ReadFile", arguments: "not json")
        #expect(text == "Reading a file")
    }

    @Test("an empty result has no summary")
    func emptyResultHasNoSummary() {
        #expect(ToolActivityNarrator.result(toolName: "ReadFile", output: "   ") == "Finished reading")
    }

    @Test("a long target is shortened")
    func longTargetIsShortened() {
        let long = String(repeating: "a", count: 200)
        let text = ToolActivityNarrator.action(toolName: "ReadFile", arguments: #"{"path": "\#(long)"}"#)
        #expect(text.count < 80)
    }
}
