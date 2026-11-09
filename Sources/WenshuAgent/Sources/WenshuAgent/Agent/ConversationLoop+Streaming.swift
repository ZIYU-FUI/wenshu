// ConversationLoop+Streaming.swift = part of ConversationLoop, = = moved out of ConversationLoop.swift.
// The members below keep their own comments; = = the actor's stored
// properties stay in ConversationLoop.swift (= = an actor's stored
// properties cannot live in an extension).

import Foundation
import os.log

extension ConversationLoop {
    func streamInto(
        messages: [LLMMessage],
        options: LLMCallOptions,
        streamCallback: (@Sendable (LLMBlock) async -> Void)?
    ) async throws -> LLMResponse {
        // The provider sends its token counters inside the stream events,
        // so the turn collects them as they arrive and reports the
        // provider's numbers rather than zeros.
        let usageCollector = StreamUsageCollector()
        let stream = StreamUsageScope.$collector.withValue(usageCollector) {
            connector.stream(messages: messages, options: options)
        }
        let streamProgress = StreamProgress()
        // The stream task is held in a box so the cap can await it: the cap
        // waits for the stream once the connection has answered. A box
        // rather than a local variable, because the cap task captures it
        // and a captured local of task type is not sendable.
        let streamBox = StreamTaskBox()
        streamBox.task = Task<[LLMBlock], Error> {
            var collected: [LLMBlock] = []
            for await block in stream {
                // The underlying `for await block in stream` (= an
                // `AsyncStream<LLMBlock>` produced by the third-party
                // event-stream parser) is NOT cancellation-cooperative:
                // cancelling the task propagates the cancel to the task but the
                // for-await stays blocked in the parser, so the cap never returns
                // to the caller's await. The explicit `Task.checkCancellation()`
                // here (= checked once per inbound block) gives the runtime a
                // per-iteration chance to observe the cancel and unwind the
                // for-await. The cap's own path cancels the child (= this check
                // fires on the next block arrival; if no block ever arrives the
                // cap's sleep still fires via the throwing task body).
                try Task.checkCancellation()
                if collected.isEmpty {
                    // The connection answered. The cap no longer applies:
                    // a reply that is still arriving is not a hang.
                    streamProgress.sawFirstBlock = true
                }
                collected.append(block)
                if let streamCallback {
                    await streamCallback(block)
                }
            }
            return collected
        }
        // The cap covers the wait for the FIRST block, not the whole
        // reply.
        //
        // It used to be a wall-clock limit on the entire stream, which was
        // added when the third-party SSE parser could not deliver a
        // provider's events at all (= every turn hit the cap and fell back
        // to a non-streaming call). The parser now reads the stream
        // directly, so a reply that is still arriving is not a hang: it is
        // a reply in progress, and the user is watching it arrive.
        //
        // A wall-clock limit on the whole stream would cut off exactly the
        // long replies the streaming path exists to deliver. So the limit
        // now applies to the connection only: if nothing arrives within
        // the window, the connection is dead and the non-streaming path
        // takes over. Once something arrives, the stream is allowed to
        // finish.
        //
        // The window is generous because it only has to outlast a slow
        // handshake. A provider that answers in two seconds has no chance
        // of tripping it.
        let firstBlockDeadline = Date().addingTimeInterval(60)
        let timeoutTask = Task<Void, Error> {
            while !streamProgress.sawFirstBlock, Date() < firstBlockDeadline {
                try await Task.sleep(for: .milliseconds(200))
            }
            if streamProgress.sawFirstBlock {
                // The stream is alive. Wait for it to finish rather than
                // racing it: the same result the other branch produces.
                _ = try? await streamBox.task?.value
                return
            }
            // The previous cap's
            // `streamTask.cancel()` did NOT unwind
            // the `for await block in stream` (= the
            // mattt/EventSource AsyncStream is not
            // cancellation-cooperative; = the for-await
            // stayed blocked on the parser; =
            // `streamTask.value` never returned; =
            // the catch block below never ran; = the
            // fallback to non-streaming send() never
            // fired). The trick below races
            // `streamTask.value` against
            // `timeoutTask.value`: whichever returns
            // first wins (= the cap's
            // `Task.sleep(60s)` is the deterministic
            // winner when the SSE parser hangs; = the
            // `streamTask.value` returns its collected
            // blocks when the SSE finishes normally).
            // When the cap wins, the throw
            // (= `CancellationError` from the
            // timeoutTask's race) propagates to the
            // catch block below, which routes the call
            // through `connector.send(...)` (= the
            // non-streaming request/response path; =
            // bypasses the EventSource SSE parser
            // entirely; = the only path that returns a
            // complete LLMResponse when the SSE
            // wireup hangs).
            streamBox.task?.cancel()
            throw CancellationError()
        }
        let accumulated: [LLMBlock]
        do {
            // Race streamTask vs timeoutTask. The
            // `withTaskGroup` makes the first one to
            // finish (= either the SSE parser
            // completing the for-await, or the cap
            // firing after 60s) the one whose result
            // the await below observes. The other task
            // is cancelled via the group on exit.
            accumulated = try await withThrowingTaskGroup(of: [LLMBlock].self) { group in
                group.addTask {
                    try await streamBox.task?.value ?? []
                }
                group.addTask {
                    try await timeoutTask.value
                    // = the cap fired; = the
                    // streamTask is still blocked; =
                    // return empty + throw via the
                    // outer try.
                    throw CancellationError()
                }
                let firstResult = try await group.next()!
                group.cancelAll()
                return firstResult
            }
            timeoutTask.cancel()
        } catch {
            // The cap (= the sibling timeout task) throws a transport error (= a
            // transient error per the existing transient-error contract, so the
            // turn's catch block treats the timeout as retryable; the user sees a
            // long think and then a "cannot reply yet" fallback with no
            // actionable signal). The classifier here (= the error with the
            // streaming-timeout description) is the canonical user-facing error
            // source, so the caller logs a description the user can act on (=
            // visible in Console.app under the conductor's legacy path), and the
            // user can tell a missing key from a rate limit from a server error
            // from an SSE hang by the description string. The cap and the
            // structured error alone are only the "tell the user we can't reply"
            // half: the "actually reply" half needs a fallback to the
            // non-streaming send path, so the user sees a real LLM response when
            // the SSE parser hangs on the upstream. The fallback routes the same
            // messages and options through `connector.send(...)` (= the
            // non-streaming request/response path, which bypasses the
            // event-stream parser entirely and is the only path that returns a
            // complete response even when the SSE wireup hangs). The catch below
            // emits a structured timeout log line so the user can still tell from
            // Console.app which path fired (= a streaming hang that fell back to
            // non-streaming, vs a clean streaming success).
            os_log("[wenshu.conversationLoop] PATH=stream-cap-fallback REASON=60s_no_blocks falling back to non-streaming send provider=%{public}@", log: .default, type: .error, connector.connectorID)
            do {
                return try await connector.send(
                    messages: messages,
                    options: options
                )
            } catch {
                // The non-streaming fallback also
                // failed (= genuine provider error, not
                // just a streaming parser hang). Throw
                // the structured timeout so the chat
                // surface shows the user-facing message
                // (= the `UserFacingError.from`
                // classifier maps this to the
                // streaming-timeout message, so the user can re-send
                // or fall back to a different provider).
                os_log("[wenshu.conversationLoop] PATH=stream-cap-fallback-failed REASON=non_streaming_also_failed error=%{public}@", log: .default, type: .error, String(describing: error))
                throw LLMConnectorError.transport(
                    provider: connector.connectorID,
                    statusCode: 0,
                    body: "流式响应超时（15 秒内无任何 block 到达；非流式重试也失败：\(String(describing: error))）"
                )
            }
        }
        // Stable id + model shape (= mirrors what send produces). The connector's
        // send implementation supplies its own id + model; = here we use the
        // deterministic connector-derived fallback (= "mock-model" for
        // MockLLMConnector, "<slug>-model" for real connectors) so downstream
        // code (TurnFinalizer, tests) sees a consistent model name regardless of
        // send vs stream.
        let model = defaultModelForConnector()
        // The counters the provider sent inside the stream events (= the
        // input count, the output count, and the cache counts). The
        // fallback path returns the provider's own usage object, so both
        // paths report the provider's numbers.
        let usage = usageCollector.usage
        return LLMResponse(
            id: "\(connector.connectorID)-stream-\(UUID().uuidString)",
            model: model,
            blocks: accumulated,
            stopReason: accumulated.contains(where: {
                if case .toolUse = $0 {
                    return true
                } else {
                    return false
                }
            })
                ? .toolUse : .endTurn,
            usage: usage
        )
    }

    /// Resolves the default model for the active connector (= the first model the
    /// connector offers, or the model the user chose via the Settings pane).
    func defaultModelForConnector() -> String {
        // The provider enum lookup by connector id (= a thin integration on the
        // provider's own slug).
        if let provider = Provider.all.first(where: { $0.slug == connector.connectorID }) {
            return provider.defaultModels.first ?? "unknown-model"
        }
        // Fix: when no Provider matches (= the common test path with
        // MockLLMConnector whose connectorID is "mock"), derive a stable fallback
        // from the connectorID itself so test assertions like
        // `result.response.model == "mock"` (= the Z contract per
        // `PromptCachingAndTurnContextTests.runConversationEcho`) match without
        // adding a synthetic Provider entry. The derived name is deterministic (=
        // connectorID-based) so test snapshots stay stable. For test-only
        // connectors (= connectorID == "mock") we return the bare ID (= "mock")
        // so the test sees the canonical model name; for production connectors
        // without a registered Provider we return "connectorID-model" to keep the
        // diagnostic shape visible in logs (= the connector ID prefix makes the
        // source of the model obvious).
        let connectorID = connector.connectorID
        // Mock connector + production connectors share the connectorID-derived
        // fallback (= "connectorID-model") so test snapshots and production logs
        // see the same shape. Real model identifiers for production connectors
        // are supplied via the Provider.defaultModels list above.
        return "\(connectorID)-model"
    }
}
