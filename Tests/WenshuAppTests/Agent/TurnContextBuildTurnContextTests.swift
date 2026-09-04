//
//  TurnContextBuildTurnContextTests.swift · Wenshu · HERMES-PARTIAL-007 (2026-09-04)
//
//  Round-trip tests for TurnContextBuilder (= hermes build_turn_context
//  = 565 LOC) + the per-turn setup helper closures:
//    1. testBuildRunsAllHooksInOrder   — hooks fire 1→9 in hermes order
//    2. testSurrogateSanitization      — sanitize hook runs on user message
//    3. testRetryCounterResetCaptured  — reset counters flow into TurnContext
//    4. testCredentialRefresh          — refresh hook fires before prompt restore
//    5. testPreflightEstimateGate      — shouldRunPreflightEstimate branch (a)+(b)
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("TurnContextBuildTurnContext (HERMES-PARTIAL-007)")
struct TurnContextBuildTurnContextTests {

    // MARK: - Test 1: All hooks fire in hermes order

    actor OrderRecorder {
        var order: [String] = []
        func record(_ s: String) { order.append(s) }
        var snapshot: [String] { order }
    }

    @Test("buildTurnContext fires the 9 setup hooks in hermes order")
    func testBuildRunsAllHooksInOrder() async throws {
        let recorder = OrderRecorder()
        let hooks = TurnContextBuilder.Hooks(
            installSafeStdio: { await recorder.record("stdio") },
            sanitizeSurrogates: { s in await recorder.record("sanitize"); return s },
            restorePrimaryRuntime: { await recorder.record("restore_runtime") },
            setAuxiliaryRuntimeMain: { _, _, _, _, _ in await recorder.record("aux") },
            resetToolGuardrails: { await recorder.record("guardrails") },
            refreshCredentials: { await recorder.record("creds") },
            restoreOrBuildSystemPrompt: { await recorder.record("prompt"); return "you are wenshu" },
            resetRetryCounters: { await recorder.record("retry"); return ["x": 0] },
            persistUserMessage: { _, _ in await recorder.record("persist") }
        )
        let builder = TurnContextBuilder(hooks: hooks)
        let ctx = builder.buildTurnContext(
            userMessage: "hi",
            conversationHistory: [],
            model: "claude-3-5"
        )
        let order = await recorder.snapshot
        let expected = ["stdio", "aux", "restore_runtime", "creds", "retry", "guardrails", "sanitize", "prompt", "persist"]
        #expect(order == expected)
        #expect(ctx.systemMessage == "you are wenshu")
        #expect(ctx.userMessage == "hi")
    }

    // MARK: - Test 2: Sanitization runs

    @Test("surrogate sanitization hook is applied to the user message")
    func testSurrogateSanitization() {
        let hooks = TurnContextBuilder.Hooks(
            sanitizeSurrogates: { s in
                // strip lone surrogates (Unicode scalars > 0xD800 but not in valid pairs)
                s.unicodeScalars.filter { $0.value < 0xD800 || $0.value > 0xDFFF }.reduce(into: "") { $0 += String($1) }
            }
        )
        let builder = TurnContextBuilder(hooks: hooks)
        let dirty = "hello\u{0}world"  // NUL char — hermes strips these too
        let clean = "hello world"
        let ctx = builder.buildTurnContext(
            userMessage: dirty,
            conversationHistory: [],
            model: "mock"
        )
        #expect(ctx.userMessage == clean)
    }

    // MARK: - Test 3: Retry counters captured

    @Test("resetRetryCounters output flows into TurnContext.resetCounters")
    func testRetryCounterResetCaptured() {
        let hooks = TurnContextBuilder.Hooks(
            resetRetryCounters: {
                [
                    "invalid_tool": 0,
                    "invalid_json": 0,
                    "empty_content": 0,
                    "incomplete_scratchpad": 0,
                    "codex_incomplete": 0,
                    "thinking_prefill": 0
                ]
            }
        )
        let builder = TurnContextBuilder(hooks: hooks)
        let ctx = builder.buildTurnContext(
            userMessage: "x",
            conversationHistory: [],
            model: "m"
        )
        #expect(ctx.resetCounters["invalid_tool"] == 0)
        #expect(ctx.resetCounters["invalid_json"] == 0)
        #expect(ctx.resetCounters["empty_content"] == 0)
        #expect(ctx.resetCounters.count == 6)
    }

    // MARK: - Test 4: Credential refresh fires before prompt restore

    actor TimingRecorder {
        var timeline: [String] = []
        func mark(_ s: String) { timeline.append(s) }
        var snapshot: [String] { timeline }
    }

    @Test("credential refresh runs before system prompt restore (= hermes order)")
    func testCredentialRefresh() async throws {
        let rec = TimingRecorder()
        let hooks = TurnContextBuilder.Hooks(
            refreshCredentials: { await rec.mark("creds") },
            restoreOrBuildSystemPrompt: { await rec.mark("prompt"); return "ok" }
        )
        let builder = TurnContextBuilder(hooks: hooks)
        _ = builder.buildTurnContext(userMessage: "x", conversationHistory: [], model: "m")
        let t = await rec.snapshot
        #expect(t.firstIndex(of: "creds")! < t.firstIndex(of: "prompt")!)
    }

    // MARK: - Test 5: shouldRunPreflightEstimate + compressionMadeProgress

    @Test("shouldRunPreflightEstimate returns true on branch (a) message-count overflow")
    func testPreflightEstimateGate() {
        // branch (a): message count exceeds protected range
        let shouldA = TurnContextBuilder.shouldRunPreflightEstimate(
            messagesCount: 50,
            protectFirstN: 2,
            protectLastN: 10,
            thresholdTokens: 100_000,
            estimatedTokens: 1_000
        )
        #expect(shouldA == true)
        // branch (b): tiny history but huge tokens
        let shouldB = TurnContextBuilder.shouldRunPreflightEstimate(
            messagesCount: 3,
            protectFirstN: 2,
            protectLastN: 10,
            thresholdTokens: 100_000,
            estimatedTokens: 200_000
        )
        #expect(shouldB == true)
        // neither branch: small conversation, small tokens
        let shouldNo = TurnContextBuilder.shouldRunPreflightEstimate(
            messagesCount: 3,
            protectFirstN: 2,
            protectLastN: 10,
            thresholdTokens: 100_000,
            estimatedTokens: 500
        )
        #expect(shouldNo == false)
    }

    @Test("compressionMadeProgress honors the >5% material-progress threshold")
    func testCompressionProgressThreshold() {
        // row count reduction → progress
        #expect(TurnContextBuilder.compressionMadeProgress(origMessageCount: 100, newMessageCount: 80, origTokens: 1000, newTokens: 1000) == true)
        // >5% token reduction → progress
        #expect(TurnContextBuilder.compressionMadeProgress(origMessageCount: 100, newMessageCount: 100, origTokens: 1000, newTokens: 800) == true)
        // <5% reduction → no progress
        #expect(TurnContextBuilder.compressionMadeProgress(origMessageCount: 100, newMessageCount: 100, origTokens: 1000, newTokens: 980) == false)
        // zero orig tokens + no row reduction → no progress
        #expect(TurnContextBuilder.compressionMadeProgress(origMessageCount: 100, newMessageCount: 100, origTokens: 0, newTokens: 0) == false)
    }
}