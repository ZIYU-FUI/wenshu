// ConversationLoop+Prompt.swift = part of ConversationLoop, = = moved out of ConversationLoop.swift.
// The members below keep their own comments; = = the actor's stored
// properties stay in ConversationLoop.swift (= = an actor's stored
// properties cannot live in an extension).

import Foundation

extension ConversationLoop {
    /// The composed prompt, and the sizes of the parts that went into it.
    ///
    /// The text is what the provider receives. The sizes are what the
    /// meter's breakdown reports: the memory is prefetched into the
    /// dynamic tier, so a caller that only had the composed text could
    /// not tell the memory's share from the rest of the prompt.
    struct ComposedSystemPrompt: Sendable {
        /// The prompt the provider receives (= nil when there is none).
        let text: String?
        /// The tokens the prefetched memories contributed.
        let memoryTokens: Int
    }

    /// Composes the effective system prompt via the PromptBuilder. The
    /// adapters read live data, and this method reads it from those adapters.
    func composeSystemPrompt(
        override: String?,
        persistent: String?,
        settings: AgentSettings = .init()
    ) async -> ComposedSystemPrompt {
        // Determine the ephemeral hint source (= which string flows into
        // the dynamic tier's "Context: ..." section).
        let ephemeralHint = override ?? persistent ?? ""

        // Stable tier: always the byte-stable identity (no caller override
        // path for the stable tier — stable tier is byte-stable BY DEFINITION).
        //
        // The user's prompt settings decide which guidance blocks appear.
        // Without them the tier is assembled from fixed values, so a switch
        // the user flipped in the settings screen changes nothing.
        let stable = PromptTierBuilder.stableTier(
            settings: settings.prompt,
            provider: SystemPrompt.ProviderGuidance(providerSlug: connector.connectorID)
        )

        // Dynamic tier: composed via PromptBuilder. so the LLM sees relevant
        // context on the first token. The memory prefetch reads the user's stored
        // memories (= the turn's memory store, = on the main actor). A turn that
        // turned the memory off must not read it: = the turn asked for a clean
        // context, = and the read is a main-actor hop that can block the turn
        // behind whatever the main actor is doing.
        let prefetched: [MemoryAdapter.MemoryEntry]
        if settings.memory.enabled, settings.prompt.memoryGuidanceEnabled {
            // The loop's own provider comes first (= the same order the
            // write path uses), = so a caller that injected a provider
            // gets that one, = and the read and the write agree.
            let provider: any MemoryProvider
            if let memoryProvider {
                provider = memoryProvider
            } else {
                provider = await MemoryAdapter.resolveProvider(for: settings.memory)
            }
            prefetched = await MemoryAdapter(provider: provider).retrieve(
                forUserMessage: ephemeralHint,
                bookId: nil
            )
        } else {
            prefetched = []
        }
        // The book's own report: = the conflicts its claims produce and
        // the threads it never closes. = The app supplies it (= the
        // runtime owns no book), = = and the turn reads it once, = = so
        // the report reaches the model with the rest of the turn.
        let continuity = await continuityProvider?.continuityReport() ?? ContinuityReport()
        let dynamic = PromptBuilder.dynamicTier(
            contextBundle: ContextEngine.ContextBundle(
                memories: prefetched.map { entry in
                    ContextEngine.MemoryEntry(source: entry.source, snippet: entry.snippet)
                },
                characterContext: [],
                worldContext: continuity.worldContext,
                foreshadowContext: continuity.foreshadowContext
            ),
            memories: prefetched,
            callerExtras: [:],
            ephemeralHint: ephemeralHint
        )

        // No hint + no dynamic = no system prompt at all (= caller chose to send
        // the conversation without a system prompt; connector handles the
        // default).
        if ephemeralHint.isEmpty {
            return ComposedSystemPrompt(
                text: stable.isEmpty ? nil : stable,
                memoryTokens: ContextUsageMeasure.tokens(
                    prefetched.map(\.snippet).joined(separator: "\n")
                )
            )
        }

        // Join stable + dynamic with the canonical separator (= same separator
        // SystemPrompt.build uses; matches PromptBuilder's buildOpenAISystem /
        // buildGeminiSystemInstruction output).
        return ComposedSystemPrompt(
            text: stable + "\n\n---\n\n" + dynamic,
            memoryTokens: ContextUsageMeasure.tokens(
                prefetched.map(\.snippet).joined(separator: "\n")
            )
        )
    }

    /// Trim the turn's accumulated tool results to the turn's cap.
    ///
    /// The request carries every result the turn has produced, so the
    /// results are trimmed oldest-first until their total fits the cap.
    /// The newest results are the ones the model still needs, so they
    /// survive longest. A result that is already inside the cap is left
    /// alone.
    ///
    /// The trimmed result keeps a head and gains a marker saying how much
    /// was dropped, so the model reads that the result was cut rather
    /// than believing the cut text is the whole result.
    static func trimTurnToolResults(
        _ messages: [LLMMessage],
        budget: ToolResultBudget
    ) -> [LLMMessage] {
        // The tool results in the order they arrived, with the text each
        // one carries.
        let results: [(index: Int, output: String)] = messages.enumerated().compactMap { index, message in
            guard message.role == .tool else { return nil }
            var output = ""
            for block in message.blocks {
                if case let .toolResult(_, text, _) = block {
                    output += text
                }
            }
            return (index, output)
        }
        let total = results.reduce(0) { $0 + $1.output.count }
        guard total > budget.maxTurnCharacters else { return messages }

        // The results that keep their whole text are the newest ones:
        // they are the ones the model still needs. The oldest give way.
        var keptCount = 0
        var keptTotal = 0
        for result in results.reversed() {
            guard keptTotal + result.output.count <= budget.maxTurnCharacters else { break }
            keptTotal += result.output.count
            keptCount += 1
        }
        var cutIndices = Array(results.dropLast(keptCount).map(\.index))
        let outputByIndex = Dictionary(uniqueKeysWithValues: results.map { ($0.index, $0.output) })

        // Every cut result needs room for its marker (= the text that
        // says how much of the result was dropped). The markers are
        // reserved before the previews are handed out, so the turn's
        // total stays inside the cap; when the markers alone do not fit
        // beside the kept results, one more of the newest kept results
        // gives way.
        var markerTotal = cutIndices.reduce(0) { total, index in
            total + Self.trimMarker(dropped: (outputByIndex[index] ?? "").count).count
        }
        while keptCount > 0, keptTotal + markerTotal > budget.maxTurnCharacters {
            // The oldest of the kept results gives way, so the markers
            // have somewhere to sit.
            let freed = results[results.count - keptCount]
            keptCount -= 1
            keptTotal -= freed.output.count
            cutIndices.append(freed.index)
            markerTotal += Self.trimMarker(dropped: freed.output.count).count
        }

        // What is left of the cap after the kept results and the markers
        // are paid for. It goes to the previews, and the newest cut
        // result gets it first (= it is the closest to the model's
        // attention). A cut result therefore keeps as much of itself as
        // the turn's cap has room for, not a fixed-size excerpt.
        var previewAllowance = max(0, budget.maxTurnCharacters - keptTotal - markerTotal)
        var replacements: [Int: String] = [:]
        for index in cutIndices.reversed() {
            let output = outputByIndex[index] ?? ""
            let room = min(output.count, previewAllowance)
            previewAllowance -= room
            let preview = String(output.prefix(room))
            replacements[index] = preview + Self.trimMarker(dropped: output.count - room)
        }

        return messages.enumerated().map { index, message in
            guard let replacement = replacements[index] else { return message }
            let rewritten = message.blocks.map { block -> LLMBlock in
                guard case let .toolResult(id, _, isError) = block else { return block }
                return .toolResult(
                    toolUseID: id,
                    output: replacement,
                    isError: isError
                )
            }
            return LLMMessage(role: message.role, blocks: rewritten)
        }
    }

    /// The marker that tells the reader the result was cut.
    ///
    /// It names how much was DROPPED (= the result's own size minus what
    /// the reader still sees), so the model reads that the text it sees
    /// is a cut of a larger result rather than the whole result, and the
    /// number it reads is the number that was dropped.
    static func trimMarker(dropped: Int) -> String {
        "\n[trimmed \(dropped) chars]"
    }

    /// Record what the request's prompt carried.
    ///
    /// The reading is what the chat zone's meter shows: the provider's
    /// own count of the prompt, and the measured size of the parts that
    /// made it up.
    func recordContextUsage(
        conversationId: String,
        messages: [LLMMessage],
        systemPrompt: ComposedSystemPrompt,
        toolSchemas: [ToolRegistrySchema],
        usage: LLMUsage
    ) async {
        let measured = ContextUsageMeasure.messageTokens(messages)
        let systemTokens = ContextUsageMeasure.tokens(systemPrompt.text ?? "")
        let categories: [ContextUsageCategory] = [
            ContextUsageCategory(id: .systemPrompt, tokens: systemTokens),
            ContextUsageCategory(
                id: .toolSchemas,
                tokens: ContextUsageMeasure.toolSchemaTokens(toolSchemas)
            ),
            ContextUsageCategory(id: .messages, tokens: measured.conversation),
            ContextUsageCategory(id: .toolResults, tokens: measured.toolResults),
            ContextUsageCategory(id: .memory, tokens: systemPrompt.memoryTokens),
        ]
        await ContextUsageRecorder.shared.record(
            conversationId: conversationId,
            snapshot: ContextUsageSnapshot(
                promptTokens: usage.promptTokens,
                completionTokens: usage.outputTokens,
                cacheReadTokens: usage.cacheReadTokens,
                cacheCreationTokens: usage.cacheCreationTokens,
                contextWindow: connector.contextWindow,
                categories: categories
            )
        )
    }

    /// Compress the history when it has grown past the budget.
    ///
    /// Returns the reduced history, or nil when nothing was needed (= the
    /// caller keeps what it had). The provider call for the summary goes
    /// through the same connector as the turn itself: a summary produced by a
    /// different model than the one reading it is a summary with a different
    /// sense of what mattered.
    ///
    /// `incomingMessage` is measured with the history but never returned: the
    /// caller appends it itself when it builds the request, so folding it into
    /// the compressed history would deliver it twice.
    func compressIfNeeded(
        messages history: [LLMMessage],
        incomingMessage: String,
        systemMessage: String
    ) async -> [LLMMessage]? {
        let window = connector.contextWindow
        let withIncoming = history + [LLMMessage(role: .user, blocks: [.text(incomingMessage)])]
        guard historyCompressor.needsCompression(withIncoming, contextWindow: window) else {
            return nil
        }
        // Compress the history alone. The incoming message is what the model is
        // being asked, not what it did, and replacing it with a summary would
        // answer a different question.
        let outcome = await historyCompressor.compress(history) { [weak self] middle in
            await self?.summariseHistory(middle, systemMessage: systemMessage)
        }
        switch outcome {
        case let .unnecessary(untouched):
            return untouched.count < history.count ? untouched : nil
        case let .pruned(reduced, _):
            return reduced.count < history.count ? reduced : nil
        case let .summarised(reduced, _, _):
            return reduced
        }
    }

    /// One provider call that turns a slice of history into prose.
    ///
    /// Deliberately small and non-streaming. A summary that fails returns nil
    /// and the caller keeps the un-summarised transcript, so a provider hiccup
    /// costs a little context rather than the turn.
    private func summariseHistory(
        _ messages: [LLMMessage],
        systemMessage: String
    ) async -> String? {
        guard !messages.isEmpty else { return nil }
        let transcript = messages.map { message in
            let role = message.role == .user ? "老板" : "文枢"
            let text = message.blocks.map(\.textValue).joined(separator: " ")
            return "\(role)：\(text)"
        }.joined(separator: "\n")

        let instruction = """
        把下面这段写作过程压缩成一份交接笔记，供同一个助手在后续对话里接着写。

        写清楚这些，不要加评论：
        - 已经确定的剧情、人物设定、世界规则
        - 尚未解决的情节伏笔
        - 用户明确表达过的偏好和约束
        - 故事当前进行到哪里

        不要复述原文，不要评价，不要加建议。控制在 400 字以内。

        \(transcript)
        """
        do {
            let response = try await connector.send(
                messages: [
                    LLMMessage(role: .user, blocks: [.text(instruction)]),
                ],
                options: LLMCallOptions(
                    model: defaultModelForConnector(),
                    maxTokens: 1024,
                    systemPrompt: systemMessage,
                    temperature: 0.2,
                    reasoningEffort: nil,
                    tools: []
                )
            )
            let text = response.blocks.map(\.textValue).joined().trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : text
        } catch {
            return nil
        }
    }

    /// Flatten a reply's text blocks for the guards (= the content-filter and
    /// tail-punctuation checks both read prose, not block structure).
    static func flattenText(_ blocks: [LLMBlock]) -> String {
        blocks.compactMap { block in
            if case let .text(text) = block {
                return text
            }
            return nil
        }.joined(separator: "\n")
    }

    /// Progress label for a retry, so the user sees why the agent is still
    /// working rather than a bare spinner.
    static func retryLabel(for verdict: ResponseVerdict) -> String {
        switch verdict.reason {
        case .emptyReply: return "empty reply"
        case .truncated, .incompleteSentence: return "incomplete reply"
        case .contextOverflow: return "context too long"
        case .contentFiltered: return "filtered by provider"
        case .quotaExhausted: return "quota exhausted"
        case .transientError: return "connection issue"
        case .permanentError, .none: return "error"
        }
    }
}
