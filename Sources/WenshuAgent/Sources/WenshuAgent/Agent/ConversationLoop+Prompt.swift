// ConversationLoop+Prompt.swift = part of ConversationLoop, = = moved out of ConversationLoop.swift.
// The members below keep their own comments; = = the actor's stored
// properties stay in ConversationLoop.swift (= = an actor's stored
// properties cannot live in an extension).

import Foundation
import os.log

extension ConversationLoop {
    /// Composes the effective system prompt via the PromptBuilder. The
    /// adapters read live data, and this method reads it from those adapters.
    func composeSystemPrompt(
        override: String?,
        persistent: String?,
        settings: AgentSettings = .init()
    ) async -> String? {
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
        let dynamic = PromptBuilder.dynamicTier(
            contextBundle: ContextEngine.ContextBundle(
                memories: prefetched.map { entry in
                    ContextEngine.MemoryEntry(source: entry.source, snippet: entry.snippet)
                },
                characterContext: [],
                worldContext: [],
                foreshadowContext: []
            ),
            memories: prefetched,
            callerExtras: [:],
            ephemeralHint: ephemeralHint
        )

        // No hint + no dynamic = no system prompt at all (= caller chose to send
        // the conversation without a system prompt; connector handles the
        // default).
        if ephemeralHint.isEmpty {
            return stable.isEmpty ? nil : stable
        }

        // Join stable + dynamic with the canonical separator (= same separator
        // SystemPrompt.build uses; matches PromptBuilder's buildOpenAISystem /
        // buildGeminiSystemInstruction output).
        return stable + "\n\n---\n\n" + dynamic
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
