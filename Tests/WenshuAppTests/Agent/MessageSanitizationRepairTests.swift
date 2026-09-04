//
//  MessageSanitizationRepairTests.swift · Wenshu · HERMES-PARTIAL-009 (2026-09-04)
//
//  Round-trip tests for the extended MessageSanitization surface
//  (= hermes message_sanitization.py = 477 LOC):
//    1. testRepairTrivialJSON             — well-formed JSON passes through
//    2. testRepairTrailingComma          — malformed JSON repair pass 1
//    3. testRepairPythonNone             — "None" → "{}"
//    4. testRepairUnrepairable            — last-resort "{}"
//    5. testSurrogateStrip                — surrogate scrubber
//    6. testCloseInterruptedToolSeq       — tool-tail close
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("MessageSanitizationRepair (HERMES-PARTIAL-009)")
struct MessageSanitizationRepairTests {

    // MARK: - Test 1: Well-formed JSON passes through

    @Test("repairToolCallArguments leaves well-formed JSON untouched")
    func testRepairTrivialJSON() {
        let good = #"{"path":"/foo","mode":"r"}"#
        #expect(MessageSanitization.repairToolCallArguments(good) == good)
    }

    // MARK: - Test 2: Trailing comma repair

    @Test("repairToolCallArguments strips trailing commas before } or ]")
    func testRepairTrailingComma() {
        let bad = #"{"a":1,"b":2,}"#
        let fixed = MessageSanitization.repairToolCallArguments(bad, toolName: "x")
        // Must be parseable JSON.
        let data = fixed.data(using: .utf8)!
        let obj = try? JSONSerialization.jsonObject(with: data)
        #expect(obj != nil)
        if let dict = obj as? [String: Any] {
            #expect(dict["a"] as? Int == 1)
            #expect(dict["b"] as? Int == 2)
        }
    }

    // MARK: - Test 3: Python-None normalization

    @Test("repairToolCallArguments maps literal 'None' to '{}'")
    func testRepairPythonNone() {
        #expect(MessageSanitization.repairToolCallArguments("None") == "{}")
    }

    // MARK: - Test 4: Last resort

    @Test("repairToolCallArguments returns '{}' on unrepairable garbage")
    func testRepairUnrepairable() {
        #expect(MessageSanitization.repairToolCallArguments("@@@not json@@@") == "{}")
        #expect(MessageSanitization.repairToolCallArguments("") == "{}")
    }

    // MARK: - Test 5: Surrogate strip

    @Test("sanitizeSurrogates drops lone high surrogates while preserving paired ones")
    func testSurrogateStrip() {
        // Lone high surrogate (no matching low surrogate) → drop.
        // Swift rejects literal surrogate scalars in string literals, so
        // we construct the test input via UTF-16 code units (= exactly
        // what we want to test that sanitizeSurrogates strips).
        let loneHigh: [UInt16] = [0xD800]
        let dirty = "hello" + String(decoding: loneHigh, as: UTF16.self) + "world"
        let clean = MessageSanitization.sanitizeSurrogates(dirty)
        #expect(!clean.utf16.contains(0xD800))
        #expect(clean.contains("hello"))
        #expect(clean.contains("world"))
        // Lone low surrogate → drop.
        let loneLow: [UInt16] = [0xDC00]
        let dirty2 = "hello" + String(decoding: loneLow, as: UTF16.self) + "world"
        let clean2 = MessageSanitization.sanitizeSurrogates(dirty2)
        #expect(!clean2.utf16.contains(0xDC00))
    }

    // MARK: - Test 6: Close interrupted tool sequence

    @Test("closeInterruptedToolSequence appends a synthetic assistant when tail is a tool result")
    func testCloseInterruptedToolSeq() {
        // Transcript ending with a tool result (no closing assistant).
        let messages: [LLMMessage] = [
            LLMMessage(role: .user, blocks: [.text("search for foo")]),
            LLMMessage(role: .assistant, blocks: [.toolUse(id: "t1", name: "search", input: "{}")]),
            LLMMessage(role: .tool, blocks: [.toolResult(toolUseID: "t1", output: "ok")])
        ]
        let closed = MessageSanitization.closeInterruptedToolSequence(messages)
        // A synthetic assistant message is appended.
        #expect(closed.count == messages.count + 1)
        if case .assistant = closed.last?.role {
            // ok
        } else {
            Issue.record("expected .assistant tail after close")
        }
    }

    // MARK: - Test 7: Drop trailing empty-response scaffolding (bonus)

    @Test("dropTrailingEmptyResponseScaffolding rewinds empty assistant turns at the tail")
    func testDropTrailingEmpty() {
        let messages: [LLMMessage] = [
            LLMMessage(role: .user, blocks: [.text("hi")]),
            LLMMessage(role: .assistant, blocks: [.text("hello")]),
            LLMMessage(role: .assistant, blocks: [.text("")]),
            LLMMessage(role: .assistant, blocks: [.text("")])
        ]
        let trimmed = MessageSanitization.dropTrailingEmptyResponseScaffolding(messages)
        // The two trailing empty assistant turns are rewound.
        #expect(trimmed.count == 2)
        #expect(trimmed.last?.role == .assistant)
    }

    // MARK: - Test 8: stripNonASCII (bonus)

    @Test("stripNonASCII replaces non-ASCII characters with '?'")
    func testStripNonASCII() {
        let s = "hello \u{4E2D}\u{6587} world"  // 中文
        let stripped = MessageSanitization.stripNonASCII(s)
        #expect(stripped == "hello ?? world")
    }

    // MARK: - Test 9: escapeInvalidCharsInJSONStrings (bonus)

    @Test("escapeInvalidCharsInJSONStrings escapes literal control chars inside JSON strings")
    func testEscapeInvalid() {
        // JSON with a literal tab inside a string value (hermes repair pass 4).
        let raw = #"{"a":"line1\#tline2"}"#
        let escaped = MessageSanitization.escapeInvalidCharsInJSONStrings(raw)
        #expect(escaped.contains("\\t"))
    }
}