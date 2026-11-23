//
//  E2ERecordingLLMConnector.swift · Wenshu
//
//  The thin connector wrapper the live end-to-end tests use: it
//  captures every send() call (= the request payload + the response)
//  and forwards to the real connector (= = so the network IO is real).
//
//  WHY A SEPARATE FILE
//  ===================
//  It is a FIXTURE, = = and three suites use it (= = the memory flow,
//  = = the auto-triggered research, = = the delegate path). = = A
//  fixture shared by three suites is its own subject, = = and it lives
//  here so each suite file is about its own flow.
//

import Foundation
import os
import WenshuAgent

/// Whether the live end-to-end tests run at all.
///
/// They are OFF by default (= CI-safe): a live test calls the real
/// endpoint with the keychain's key. The boss opts in with
/// `WENSHU_LIVE_API_TESTS=1`.
///
/// It is shared (= = the two live suites read their fixture from here),
/// = = so it lives here with the other shared fixture.
enum E2EShared {
    /// The .ws repository root the two live suites run against.
    static var anbaiqiangWSRoot: URL {
        return SourceLocator.repoRoot.appendingPathComponent(".scratch/anbaiqiang.ws")
    }

    /// Resets the reference library's four layers (= = so this suite starts clean).
    static func resetReferenceLibrary(wsRoot: URL) {
        let reflibRoot = wsRoot.appendingPathComponent("reference-library")
        for layer in ["raw", "entities", "abstracts", "indexes"] {
            let layerDir = reflibRoot.appendingPathComponent(layer)
            try? FileManager.default.removeItem(at: layerDir)
            try? FileManager.default.createDirectory(at: layerDir, withIntermediateDirectories: true)
        }
    }
}

enum E2ELive {
    /// A computed property (= = not a stored one: = = a stored global
    /// would need its own actor isolation, = = and this one is read
    /// from the suites' main actor).
    static var enabled: Bool {
        ProcessInfo.processInfo.environment["WENSHU_LIVE_API_TESTS"] == "1"
    }
}

// MARK: - Recording connector

/// One captured send() invocation (= request payload + LLM response).
/// File-scope (= the wrapper returns it from capturedCalls()).
struct CapturedLLMCall: Sendable {
    let requestMessages: [LLMMessage]
    let options: LLMCallOptions
    let response: LLMResponse
}

/// Thin LLMConnector wrapper that captures every send() call's input
/// (= messages + options) + output (= LLMResponse blocks). Forwards
/// to the wrapped real connector (= so the network IO is real).
///
/// Uses an NSLock for thread-safe `calls` append (= the wrapped
/// connector may invoke send from a background URLSession task; =
/// cross-actor writes to the captured array are safe via lock).
final class RecordingLLMConnector: LLMConnector, @unchecked Sendable {
    nonisolated let connectorID: String

    private let wrapped: any LLMConnector
    private let lock = OSAllocatedUnfairLock<[CapturedLLMCall]>(initialState: [])

    init(wrapping wrapped: any LLMConnector) {
        self.wrapped = wrapped
        connectorID = wrapped.connectorID
    }

    func send(messages: [LLMMessage], options: LLMCallOptions) async throws -> LLMResponse {
        let response = try await wrapped.send(messages: messages, options: options)
        let captured = CapturedLLMCall(
            requestMessages: messages,
            options: options,
            response: response
        )
        lock.withLock { state in
            state.append(captured)
        }
        return response
    }

    func stream(messages: [LLMMessage], options: LLMCallOptions) -> AsyncStream<LLMBlock> {
        // ConversationLoop.runTurn uses the streamInto path
        // (= for await block in connector.stream). We forward to
        // the wrapped connector's send directly (= the default
        // extension's `stream` calls `send`, but if the wrapped
        // connector overrides `stream with native SSE, the capture
        // would miss it). Calling `wrapped.send` here guarantees
        // every recorded block traces back to a single LLM HTTP call
        // (= the canonical observability shape for this test).
        AsyncStream { continuation in
            Task {
                do {
                    let response = try await wrapped.send(messages: messages, options: options)
                    // Capture (= same shape as send()'s capture).
                    let captured = CapturedLLMCall(
                        requestMessages: messages,
                        options: options,
                        response: response
                    )
                    lock.withLock { state in
                        state.append(captured)
                    }
                    // Yield blocks + finish (= mirrors the default
                    // extension's behavior in LLMConnector.swift:75).
                    for block in response.blocks {
                        continuation.yield(block)
                    }
                    continuation.finish()
                } catch {
                    continuation.yield(.text("[stream error] \(error)"))
                    continuation.finish()
                }
            }
        }
    }

    func capturedCalls() async -> [CapturedLLMCall] {
        lock.withLock { state in state }
    }
}
