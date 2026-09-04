//
//  SystemPromptAndSanitizationTests.swift · Wenshu · v0.38 Batch 3 sub-step 4
//
//  Tests for SystemPrompt + MessageSanitization (= v0.35 ticket 002/001).
//
//  Per 老板 cadence 2026-09-03 '继续推进移植' (= 长期 auto-pilot mode
//  per '一直跑移植就行' + '不用问我了') + 'PO 全链路方法论执行,
//  不要跳步骤' + '1 RULE 1 commit'.
//
//  Safe scope (= NOT v0.34 in-flight) = SystemPrompt + MessageSanitization
//  are v0.35 ticket 002/001 (= my work).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("SystemPrompt deep (= v0.35 ticket 002)")
struct SystemPromptDeepTests {

    @Test("SystemPrompt.build: produces non-empty output")
    func buildProducesOutput() {
        let prompt = SystemPrompt.build(ephemeralHint: "today is sunny")
        #expect(!prompt.isEmpty)
    }

    @Test("SystemPrompt.build: byte-stable across calls (= cache hit invariant)")
    func buildByteStable() {
        let p1 = SystemPrompt.build(ephemeralHint: "test")
        let p2 = SystemPrompt.build(ephemeralHint: "test")
        #expect(p1 == p2)
    }

    @Test("SystemPrompt.build: empty ephemeralHint still works")
    func buildEmptyHint() {
        let p1 = SystemPrompt.build(ephemeralHint: "")
        let p2 = SystemPrompt.build(ephemeralHint: "x")
        // Different ephemeralHint produces different output
        #expect(p1 != p2)
        #expect(!p1.isEmpty)
    }

    @Test("SystemPrompt.build: callerMessage appended")
    func buildCallerMessage() {
        let p1 = SystemPrompt.build(ephemeralHint: "h", callerMessage: nil)
        let p2 = SystemPrompt.build(ephemeralHint: "h", callerMessage: "extra")
        #expect(p1 != p2)
        #expect(p2.contains("extra"))
    }

    @Test("SystemPrompt.buildParts: stable + dynamic keys")
    func buildPartsHasBothKeys() {
        let parts = SystemPrompt.buildParts(ephemeralHint: "today is sunny")
        #expect(parts["stable"] != nil)
        #expect(parts["dynamic"] != nil)
        // dynamic contains the ephemeralHint
        #expect(parts["dynamic"]?.contains("today is sunny") == true)
    }

    @Test("SystemPrompt.buildParts: no dynamic when empty hint")
    func buildPartsNoDynamicWhenEmpty() {
        let parts = SystemPrompt.buildParts(ephemeralHint: "")
        #expect(parts["stable"] != nil)
        #expect(parts["dynamic"] == nil)
    }

    @Test("SystemPrompt.build: stable tier is multi-line with no clock data")
    func buildStableTierMultiLine() {
        let prompt = SystemPrompt.build(ephemeralHint: "x")
        #expect(prompt.contains("\n"))
        // No Date()/clock data should appear
        #expect(!prompt.contains("Date"))
        #expect(!prompt.contains("time"))
    }
}

@Suite("MessageSanitization (= v0.35 ticket 001)")
struct MessageSanitizationTests {

    @Test("sanitizeText: removes C0 control chars except \\n \\r")
    func sanitizeStripsC0() {
        let dirty = "Hello\u{0001}World\u{0007}!"
        let clean = MessageSanitization.sanitizeText(dirty)
        #expect(clean == "HelloWorld!")
    }

    @Test("sanitizeText: preserves newline + carriage return")
    func sanitizePreservesNewlines() {
        let text = "Line 1\nLine 2\r\nLine 3"
        let clean = MessageSanitization.sanitizeText(text)
        #expect(clean == "Line 1\nLine 2\r\nLine 3")
    }

    @Test("sanitizeText: preserves Unicode + emoji + CJK")
    func sanitizePreservesUnicode() {
        let text = "你好🌏αβγ"
        let clean = MessageSanitization.sanitizeText(text)
        #expect(clean == "你好🌏αβγ")
    }

    @Test("sanitizeText: removes DEL (U+007F)")
    func sanitizeRemovesDEL() {
        let text = "Hello\u{007F}World"
        let clean = MessageSanitization.sanitizeText(text)
        #expect(clean == "HelloWorld")
    }

    @Test("sanitizeText: empty input returns empty")
    func sanitizeEmpty() {
        #expect(MessageSanitization.sanitizeText("") == "")
    }

    @Test("sanitize: cleans all text blocks in messages")
    func sanitizeMessages() {
        let messages: [LLMMessage] = [
            LLMMessage(role: .user, blocks: [
                .text("Hello\u{0001}"),
                .text("World\u{0007}!")
            ])
        ]
        let clean = MessageSanitization.sanitize(messages)
        #expect(clean.count == 1)
        if case .text(let s) = clean[0].blocks[0] {
            #expect(s == "Hello")
        } else {
            Issue.record("expected text block")
        }
    }

    @Test("sanitize: preserves tool_use + tool_result structure")
    func sanitizePreservesToolBlocks() {
        let messages: [LLMMessage] = [
            LLMMessage(role: .assistant, blocks: [
                .toolUse(id: "t1", name: "ReadFile", input: "{}"),
                .toolResult(toolUseID: "t1", output: "content\u{0001}"),
                .thinking(text: "thinking\u{0007}", signature: "sig")
            ])
        ]
        let clean = MessageSanitization.sanitize(messages)
        #expect(clean[0].blocks.count == 3)
        // toolUse is preserved
        if case .toolUse(let id, let name, _) = clean[0].blocks[0] {
            #expect(id == "t1")
            #expect(name == "ReadFile")
        } else {
            Issue.record("expected toolUse block")
        }
        // toolResult has sanitized output
        if case .toolResult(let toolUseID, let output) = clean[0].blocks[1] {
            #expect(toolUseID == "t1")
            #expect(output == "content")  // control char stripped
        } else {
            Issue.record("expected toolResult block")
        }
        // thinking has sanitized text
        if case .thinking(let text, let sig) = clean[0].blocks[2] {
            #expect(text == "thinking")  // control char stripped
            #expect(sig == "sig")
        } else {
            Issue.record("expected thinking block")
        }
    }

    @Test("sanitize: empty text block becomes empty after sanitize")
    func sanitizeEmptyText() {
        let messages: [LLMMessage] = [
            LLMMessage(role: .user, blocks: [.text("")])
        ]
        let clean = MessageSanitization.sanitize(messages)
        // empty text stays empty
        if case .text(let s) = clean[0].blocks[0] {
            #expect(s == "")
        } else {
            Issue.record("expected text block")
        }
    }
}
