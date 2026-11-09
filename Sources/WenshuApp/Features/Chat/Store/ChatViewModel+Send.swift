// ChatViewModel+Send.swift = part of ChatViewModel, = = moved out of ChatSessionViewModel.swift.
// The members below keep their own comments; = = the class's stored
// properties stay in ChatViewModel.swift (= = an extension cannot hold them).

import Foundation
import os.log
import WenshuAgent
import WenshuData

extension ChatViewModel {
    /// The front door for the chat input. It dispatches `/plan` and the other
    /// commands, and otherwise runs the turn.
    func routeInput() async {
        let input = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }

        // The `/plan` command surface: intercept `/plan <query>` BEFORE the slash-command
        // path (= /plan is a hub command that needs engine dispatch + plan
        // rendering, = not a normal skill). Strategy: extract the query after
        // `/plan ` and call PlanModeEngine.run to get a numbered plan. The plan
        // is surfaced as a system ChatMessage (= the text content includes the
        // numbered steps; =). This is the lightweight route — keeps the engine
        // integration self-contained (= no ChatMessagePart type change required
        // for this surface).
        if let planQuery = stripPlanPrefix(input) {
            await runPlanMode(query: planQuery)
            return
        }

        // Try @-mention subagent trigger FIRST (= higher priority than slash
        // commands, because @slug syntax is more specific — it names a known
        // sub-agent). Multiple mentions in one input spawn multiple sub-agents
        // concurrently (= AsyncDelegation.delegate is async; awaits are awaited
        // sequentially so the user sees the spawn order preserved in the chat
        // log).
        let mentions = SubAgentMentionParser.parseAll(input)
        if !mentions.isEmpty {
            for mention in mentions {
                do {
                    // The librarian is activated by an explicit
                    // procedure: = `@librarian import <source>` or
                    // `@librarian curate`. = A mention that names no
                    // procedure is not a librarian task, = and it
                    // falls through to the ordinary path rather than
                    // running a procedure nobody named.
                    let taskText: String
                    if mention.subagentSlug == "librarian" {
                        switch LibrarianActivation.parse(mention.task) {
                        case let .task(librarianTask):
                            // `curate` is deterministic, = so it runs
                            // here and does NOT go to a model. = The
                            // analyser is pure data analysis, = and a
                            // model asked to do it would have had no
                            // tool for it, = so it would have guessed.
                            if librarianTask.procedure == .curate {
                                await runCuration()
                                continue
                            }
                            taskText = LibrarianActivation.encodedTask(for: librarianTask)
                        case .notALibrarianTask, .unknownProcedure:
                            taskText = mention.task
                        }
                    } else {
                        taskText = mention.task
                    }
                    let result = try await delegate(
                        subagentProfile: mention.subagentSlug,
                        task: taskText,
                        context: [:],
                        registry: AsyncDelegationRegistry.shared,
                        // The scope says where the result goes. = Without
                        // it the handle carries no destination, = and a
                        // finished run has nowhere to deliver what it
                        // produced.
                        scope: AgentScope(
                            sessionID: sessionId,
                            bookID: currentBookID
                        )
                    )
                    let shortId = String(result.handle.id.prefix(8))
                    messages.append(ChatMessage(
                        role: .system,
                        source: .system,
                        content: ChatSubAgentReceipt.dispatched(handleID: shortId)
                    ))
                } catch {
                    Logger(subsystem: "com.wenshu.app", category: "chat.subagent")
                        .error("[wenshu.chat.subagent] dispatch failed error=\(String(describing: error), privacy: .public)")
                    messages.append(ChatMessage(
                        role: .system,
                        source: .system,
                        content: ChatSubAgentReceipt.failed(error: error)
                    ))
                }
            }
            inputText = ""
            return
        }

        // No slash match → existing LLM send path. The slash prefix (= `/review
        // chapter 1`) is sent verbatim to the LLM, which interprets it as a
        // prompt template per ChatHubCommands.
        await send()
    }

    // The `/plan` command surface.

    /// Strips the `/plan` prefix off the input (= the prefix is a command marker,
    /// not text the user typed).
    private func stripPlanPrefix(_ input: String) -> String? {
        guard input.hasPrefix("/plan") else { return nil }
        // Exact-match on "/plan" + whitespace (= no args means the command is
        // invalid for plan-mode; = send `/plan` to the LLM verbatim as a slash
        // command per ChatHubCommands).
        let afterPrefix = input.dropFirst("/plan".count)
        // Either whitespace (= normal command) or end-of-string
        // (= no args) is allowed.
        if afterPrefix.isEmpty {
            return nil
        }
        // First character must be whitespace (= prevents /plans
        // from matching /plan as a prefix).
        guard afterPrefix.first == " " else { return nil }
        let trimmed = afterPrefix.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Runs plan mode for the given query: it invokes the PlanModeEngine (= which
    /// wraps the model call) and reports a failure, so the user sees why the plan
    /// failed.
    private func runPlanMode(query: String) async {
        inputText = ""
        // Resolve connector + model from the active conductor (= same source of
        // truth ChatViewModel.send uses). The conductor owns a connector actor; =
        // use its currentModel. We don't currently have direct accessor for the
        // connector on WenshuConductor, so instantiate PlanModeEngine with
        // AnthropicConnector (= the conductor's default) + the current model id.
        // Future tickets may route through AppState.activeConnector; = out of
        // scope for this surface.
        let model = currentModel
        // The audit's package cleanup: resolve the active
        // connector through the public facade.
        let connector: any LLMConnector = WenshuAgent.shared.activeLLMConnector()
        let engine = PlanModeEngine(connector: connector, model: model)
        do {
            let plan = try await engine.run(query: query)
            // Surface the plan as a structured.plan ChatMessagePart (= rendered
            // via ChatPlanPartView) instead of a plain system text message. The
            // plan carries query + steps + connectorID + createdAt; =
            // ChatPlanPartView shows them as a numbered step list with an Approve
            // button (= the approve-button primitive; = Approve wiring is a).
            messages.append(ChatMessage(
                role: .system,
                source: .system,
                content: plan.query,
                parts: [ChatMessagePart.plan(plan)]
            ))
        } catch let error as PlanModeError {
            messages.append(ChatMessage(
                role: .system,
                source: .system,
                content: error.errorDescription
                    ?? String(localized: "chatview.plan.failed")
            ))
        } catch {
            messages.append(ChatMessage(
                role: .system,
                source: .system,
                content: String(localized: "chatview.plan.failed")
                    + ": \(error.localizedDescription)"
            ))
        }
    }

    /// send: send message → Wenshu main agent synthesis
    func send() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        // Allow image-only sends (= an attached screenshot with no text is still
        // a valid send; the image carries the meaning). Capture + clear the draft
        // path BEFORE constructing the user message so the message captures the
        // image atomically.
        let imagePath = attachedImagePath
        attachedImagePath = nil
        guard !text.isEmpty || imagePath != nil, !isSending else { return }
        let userMsg = ChatMessage(role: .user, source: .user, content: text, imagePath: imagePath)
        messages.append(userMsg)
        inputText = ""
        isSending = true

        // append AI placeholder message (name + avatar + "AI thinking..." in list immediately)
        let placeholderId = UUID()
        let placeholder = ChatMessage(id: placeholderId, role: .agent, source: .wenshu, content: "AI 思考中…", isPlaceholder: true)
        messages.append(placeholder)

        // Route through ChatRepositoryProtocol (= the data-layer seam). The Live
        // impl owns the StoredChatMessage mapping; = business layer speaks
        // ChatMessage only.
        do {
            try await repository.append(userMsg, sessionId: sessionId, bookID: currentBookID)
        } catch {
            Self.logSwallowedPersistenceFailure(operation: "append user message", error: error)
        }

        do {
            try Task.checkCancellation()
            // Streaming path = render each text chunk as it arrives (=
            // character-by-character, ChatGPT-style). The conductor path remains
            // blocking for now (= its WenshuConductor.handle returns a single
            // assembled reply = the WenshuConductor owns its own multi-agent
            // pipeline and isn't yet adapted to streaming). ships streaming for
            // the direct verifier path = the most common user flow. read the
            // model id from the canonical owner (= same value `vm.currentModel`
            // returns, via the shared AppState reference). No more raw
            // UserDefaults read here (= single owner maintained).
            let currentModel: String = self.currentModel
            // Per Apple HIG + 12 standard + Swift 6 strict-concurrency: migrate
            // from `NSLog` (= Swift 6 treats variadic as unavailable). Local
            // variable captures model name for the Logger interpolation (= Swift
            // 6 closure-capture rule).
            let modelForLog = currentModel
            Logger(subsystem: "com.wenshu.app", category: "chat.model")
                .info("[wenshu.model] effective model: \(modelForLog, privacy: .public) (AppState source)")
            var reply: String
            var replyThinking: String? // WenshuLLMBlock.thinking footnote UI
            var replyTokens: Int?
            if let conductor = conductor {
                // The conductor path streams as well, so the same streaming
                // switch below (= the one the direct path uses) handles
                // `LLMBlock` events from either source. Both paths accumulate
                // into the same parts array and the same thinking buffer, so the
                // placeholder renders the same way regardless of which path
                // emitted the event. The stream callback is `@Sendable` (= it can
                // be invoked from any actor, because the conversation loop runs
                // on a separate actor), so a local `var` cannot be captured: the
                // accumulator is a reference type, safe to capture in a
                // `@Sendable` closure (= each invocation is serial with respect
                // to the owning actor, so the reference is thread-safe here).
                let accumulator = StreamingAccumulator()
                // The buffer owns the rate at which the view updates. Its flush
                // handler is the single place that writes to the streaming
                // message, so the message is touched once per frame rather than
                // once per token.
                let buffer = StreamBuffer { [weak self] batch in
                    guard let self else { return }
                    self.applyStreamBatch(batch, placeholderId: placeholderId, accumulator: accumulator)
                }
                streamBuffer = buffer
                defer { self.streamBuffer = nil }
                let result = await conductor.handle(
                    userMessage: text,
                    sessionId: sessionId.rawValue,
                    model: currentModel,
                    bookID: currentBookID?.rawValue,
                    streamCallback: { [weak self] block in
                        // Log each stream block (= dev can
                        // confirm which part kinds the LLM actually emits). Tag
                        // with PATH=.. so it grep-parity with the other logs.
                        let kindTag: String = {
                            switch block {
                            case .text: return "text"
                            case .thinking: return "thinking"
                            case .toolUse: return "toolUse"
                            case .toolResult: return "toolResult"
                            }
                        }()
                        let kindTagForLog = kindTag
                        let modelForLog = currentModel
                        Logger(subsystem: "com.wenshu.app", category: "chat.conductor")
                            .info("[wenshu.conductor] PATH=stream BLOCK=\(kindTagForLog, privacy: .public) (model=\(modelForLog, privacy: .public)")
                        // The chunk goes into the buffer, not into the view.
                        //
                        // Every chunk used to enqueue its own MainActor task
                        // that rebuilt the whole message, so a long reply
                        // meant hundreds of queued tasks and hundreds of full
                        // message replacements, and the display rendered
                        // whatever state survived the queue (= text arriving
                        // in jumps). The buffer publishes once per frame
                        // instead, which is the only rate a person can read.
                        guard let self else { return }
                        await self.streamBuffer?.append(block)
                    }
                )
                // Publish whatever the buffer still holds before sealing the
                // message. Without this the last partial frame would land
                // after the bubble was already marked complete, and the tail
                // of the reply would appear late.
                buffer.flushNow()
                reply = result.reply
                replyThinking = result.thinking ?? accumulator.thinking
                replyTokens = result.totalTokens
                // Mark the conductor's bubble as sealed (= Hermes `pending:
                // false` flip after `message.complete`). Replace placeholder with
                // the final message.
                if let idx = messages.firstIndex(where: { $0.id == placeholderId }) {
                    // Per Apple HIG + 12 standard + Swift 6 strict-concurrency:
                    // migrate from `NSLog` (= Swift 6 treats variadic as
                    // unavailable). Local captures avoid closure-capture
                    // complaint.
                    let placeholderIDString = placeholderId.uuidString
                    let messageCount = messages.count
                    Logger(subsystem: "com.wenshu.app", category: "chat.scroll")
                        .info("[wenshu.scroll] conductor placeholder replace: id=\(placeholderIDString, privacy: .public) beforeCount=\(messageCount, privacy: .public) afterCount=\(messageCount, privacy: .public)")
                    messages[idx] = ChatMessage(
                        id: placeholderId,
                        role: .agent,
                        source: .wenshu,
                        content: reply,
                        tokens: replyTokens,
                        thinking: replyThinking,
                        parts: accumulator.parts,
                        streamState: .sealed
                    )
                }
            } else {
                // The conductor is now ALWAYS wired with the
                // active connector (= WenshuAppDelegate
                // + ChatView both pass `WenshuAppDelegateLLMHelpers.
                // activeLLMConnector()` at construction time). The
                // old `WenshuVerifier.streamChat` fallback (= the
                // "small liar" path that returned a single LLM reply
                // with no tool dispatch) is unreachable in production.
                // If we ever land here (= conductor is nil), the
                // agent is not configured at all. Surface the failure
                // plainly instead of silently running the no-ReAct
                // fallback. (= the WenshuLLMBlock / WenshuLLMError
                // types remain on disk for the legacy pipeline in
                // WenshuConductorLegacyPipeline; the streaming method
                // is gone.)
                reply = "（agent 未配置, 请检查 WenshuAppDelegate 是否注入了 connector）"
                let msgPrefixForLog = String(text.prefix(40))
                Logger(subsystem: "com.wenshu.app", category: "chat.conductor")
                    .error("[wenshu.conductor] PATH=missing-conductor REASON=conductor_was_nil msg_prefix=\(msgPrefixForLog, privacy: .public)")
            }
            // If the placeholder wasn't updated by streaming (= the
            // blocking path), set it now (= single-replacement).
            if !messages.contains(where: { $0.id == placeholderId }) {
                messages.append(ChatMessage(id: placeholderId, role: .agent, source: .wenshu, content: reply))
            }
            // Route the agent message through ChatRepositoryProtocol (=
            // data-layer seam). The Live impl builds the StoredChatMessage from
            // this ChatMessage (= handles the id-stringification +
            // empty-thinking-nil-collapse logic).
            let agentMsg = ChatMessage(
                id: placeholderId,
                role: .agent,
                source: .wenshu,
                content: reply,
                timestamp: Date(),
                tokens: replyTokens,
                thinking: replyThinking?.isEmpty == false ? replyThinking : nil
            )
            do {
                try await repository.append(agentMsg, sessionId: sessionId, bookID: currentBookID)
            } catch {
                Self.logSwallowedPersistenceFailure(operation: "append agent message", error: error)
            }
            recomputeContextUsed()

            // Trigger summary generation (LLM + saveSummary + deleteOldMessages
            // order) route through ChatRepositoryProtocol (= data-layer seam).
            // The Live impl hops to MainActor internally (= the protocol method
            // is async + the caller doesn't need a manual Task wrap anymore; =
            // was the bug-prone `Task { @MainActor in.. }` pattern that lost
            // errors silently).
            let verifier = WenshuVerifier()
            do {
                try await repository.summarizeIfNeeded(
                    sessionId: sessionId,
                    lastN: 10,
                    threshold: 20,
                    verifier: verifier,
                    bookID: currentBookID
                )
            } catch {
                Self.logSwallowedPersistenceFailure(operation: "summarizeIfNeeded", error: error)
            }
        } catch {
            // The chat layer does not collapse every error to a single generic
            // line: the granular `UserFacingError.from` mapping (= network, key,
            // rate limit, etc.) is the user-visible message, so the user can tell
            // a missing or wrong key from a transport timeout from a server error
            // from a malformed response body. The single-line collapse hid the
            // real cause (= a long think with no further detail = impossible to
            // distinguish key from network).
            let activeProvider = WenshuAppDelegateLLMHelpers.activeConnectorSlug()
            let rawDesc = String(describing: error)
            Logger(subsystem: "com.wenshu.app", category: "chat.persist")
                .error("[wenshu.chat.persist] operation=send_chat error=\(rawDesc, privacy: .public) provider=\(activeProvider, privacy: .public)")
            // Use the granular classifier (= surfaces the real
            // underlying message body, not the generic
            // generic line). Falls back to the raw
            // underlying description when no classifier matches
            // (= matches the previous behavior for unknown error
            // shapes).
            let userErr = UserFacingError.from(error)
            let errMsg: String
            switch userErr {
            case .modelConfigInvalid:
                errMsg = userErr.errorDescription ?? "模型配置有误"
            default:
                let granular = userErr.errorDescription ?? rawDesc
                errMsg = "[\(activeProvider)] \(granular)"
            }
            lastError = errMsg
            if let idx = messages.firstIndex(where: { $0.id == placeholderId }) {
                messages[idx] = ChatMessage(id: placeholderId, role: .system, source: .system, content: errMsg)
            }
        }
        isSending = false
    }
}
