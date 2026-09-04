//
//  AuxiliaryClientCoalescingTests.swift · Wenshu · HERMES-PARTIAL-002 (2026-09-04)
//
//  Round-trip tests for the AuxiliaryClient surface (= hermes
//  auxiliary_client.py = 7,469 LOC):
//    1. testSSECoalesceSingle           — single event passes through
//    2. testSSECoalesceManyTextAppend   — many small text events coalesce
//    3. testSSECoalesceNewTypeFlushes   — new eventType flushes prior
//    4. testSSECoalesceDrain            — drain emits all pending
//    5. testTaskConfigDefaults          — per-task config table
//    6. testProviderNormalization       — provider slug → family
//    7. testResolveVerify              — localhost → false, anthropic → true
//    8. testBuildCallKwags              — message + temperature shape
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("AuxiliaryClientCoalescing (HERMES-PARTIAL-002)")
struct AuxiliaryClientCoalescingTests {

    // MARK: - Test 1: Single SSE event passes through

    @Test("SSECoalescer passes a single event through unmodified")
    func testSSECoalesceSingle() async {
        let coalescer = SSECoalescer()
        let event = SSECoalescedEvent(eventType: "text", data: "hello")
        let flushed = await coalescer.push(event)
        #expect(flushed.isEmpty)
        let drained = await coalescer.take()
        #expect(drained.count == 1)
        #expect(drained.first?.data == "hello")
        #expect(drained.first?.coalescedCount == 1)
    }

    // MARK: - Test 2: Coalesce many small text events

    @Test("SSECoalescer appends many small text events into one")
    func testSSECoalesceManyTextAppend() async {
        let coalescer = SSECoalescer()
        for piece in ["Hel", "lo ", "wor", "ld"] {
            let event = SSECoalescedEvent(eventType: "text", data: piece)
            _ = await coalescer.push(event)
        }
        let drained = await coalescer.take()
        #expect(drained.count == 1)
        #expect(drained.first?.data == "Hello world")
        #expect(drained.first?.coalescedCount == 4)
    }

    // MARK: - Test 3: New eventType flushes prior

    @Test("SSECoalescer flushes prior events when a new eventType arrives")
    func testSSECoalesceNewTypeFlushes() async {
        let coalescer = SSECoalescer()
        _ = await coalescer.push(SSECoalescedEvent(eventType: "text", data: "hi"))
        // The next event has a different type → prior gets flushed.
        let flushed = await coalescer.push(SSECoalescedEvent(eventType: "tool_use", data: "{}"))
        #expect(flushed.count == 1)
        #expect(flushed.first?.eventType == "text")
        let drained = await coalescer.take()
        #expect(drained.count == 1)
        #expect(drained.first?.eventType == "tool_use")
    }

    // MARK: - Test 4: Drain

    @Test("SSECoalescer.drain returns all pending events")
    func testSSECoalesceDrain() async {
        let coalescer = SSECoalescer()
        _ = await coalescer.push(SSECoalescedEvent(eventType: "text", data: "a"))
        _ = await coalescer.push(SSECoalescedEvent(eventType: "text", data: "b"))
        _ = await coalescer.push(SSECoalescedEvent(eventType: "tool_use", data: "{}"))
        let drained = await coalescer.take()
        // text was coalesced to "ab", tool_use is separate.
        #expect(drained.count == 2)
        #expect(await coalescer.pendingCount() == 0)
    }

    // MARK: - Test 5: Per-task config defaults

    @Test("AuxiliaryTaskRegistry returns the right config per task")
    func testTaskConfigDefaults() {
        let sum = AuxiliaryTaskRegistry.config(for: "summarization")
        #expect(sum.provider == "anthropic")
        #expect(sum.model?.contains("haiku") == true)
        #expect(sum.temperature == 0.0)
        let kbn = AuxiliaryTaskRegistry.config(for: "kanban_decompose")
        #expect(kbn.model?.contains("sonnet") == true)
        let unknown = AuxiliaryTaskRegistry.config(for: "unknown_task_xyz")
        #expect(unknown.provider == nil)
    }

    // MARK: - Test 6: Provider normalization

    @Test("AuxiliaryProviderNormalization.normalizeProvider maps slugs")
    func testProviderNormalization() {
        #expect(AuxiliaryProviderNormalization.normalizeProvider("anthropic") == "anthropic")
        #expect(AuxiliaryProviderNormalization.normalizeProvider("openai-codex") == "openai")
        #expect(AuxiliaryProviderNormalization.normalizeProvider("gemini") == "google")
        #expect(AuxiliaryProviderNormalization.normalizeProvider("minimax") == "minimax-cn")
        #expect(AuxiliaryProviderNormalization.normalizeProvider(nil) == "unknown")
        #expect(AuxiliaryProviderNormalization.normalizeProvider("") == "unknown")
    }

    // MARK: - Test 7: Resolve verify

    @Test("AuxiliaryProviderNormalization.resolveVerify returns false for localhost / ollama")
    func testResolveVerify() {
        #expect(AuxiliaryProviderNormalization.resolveVerify(baseURL: "http://localhost:11434") == false)
        #expect(AuxiliaryProviderNormalization.resolveVerify(baseURL: "http://127.0.0.1:8080") == false)
        #expect(AuxiliaryProviderNormalization.resolveVerify(baseURL: "https://ollama.example.com") == false)
        #expect(AuxiliaryProviderNormalization.resolveVerify(baseURL: "https://api.anthropic.com") == true)
        #expect(AuxiliaryProviderNormalization.resolveVerify(baseURL: nil) == true)
    }

    // MARK: - Test 8: buildCallKwags

    @Test("AuxiliaryProviderNormalization.buildCallKwags produces well-shaped kwargs")
    func testBuildCallKwags() {
        let messages = [
            LLMMessage(role: .user, blocks: [.text("hello")]),
            LLMMessage(role: .assistant, blocks: [.text("hi")])
        ]
        let kwags = AuxiliaryProviderNormalization.buildCallKwags(
            model: "claude-3-5",
            messages: messages,
            systemPrompt: "you are wenshu",
            temperature: 0.7,
            maxTokens: 1024
        )
        #expect(kwags["model"] as? String == "claude-3-5")
        #expect(kwags["system"] as? String == "you are wenshu")
        #expect(kwags["temperature"] as? Double == 0.7)
        #expect(kwags["max_tokens"] as? Int == 1024)
        let msgs = kwags["messages"] as? [[String: Any]]
        #expect(msgs?.count == 2)
        #expect(msgs?[0]["role"] as? String == "user")
        #expect(msgs?[1]["role"] as? String == "assistant")
    }
}