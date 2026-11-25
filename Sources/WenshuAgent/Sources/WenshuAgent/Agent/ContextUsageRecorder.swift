// ContextUsageRecorder.swift
//
// What the last request's prompt carried, measured.
//
// The chat zone's meter answers two questions: how full is the model's
// window, and what filled it. The first is a number the provider
// reports. The second needs the request's own shape, because a prompt
// is made of parts (= the system prompt, the tool schemas, the
// conversation's messages, the tool results) and the parts are what the
// writer can act on.
//
// So this records both: the provider's own counts (= the authoritative
// number) and the measured size of each part (= the explanation). The
// parts are measured in characters and converted with the same estimate
// the compressor uses (= characters over four), so the numbers here and
// the numbers the compressor acts on are the same scale.
//
// The recorder is per conversation, so a second conversation in the
// same process does not overwrite the first one's reading.

import Foundation

/// One part of a prompt, and its size.
///
/// `Codable` so the reading can be stored as it is (= the app writes the
/// meter's payload into the conversation's own row, and reads it back on
/// the next launch). An id the decoder no longer knows makes the whole
/// reading unreadable, and an unreadable reading is treated as no reading.
public struct ContextUsageCategory: Sendable, Equatable, Identifiable, Codable {
    /// The part's stable id (= the key the UI reads).
    public enum ID: String, Sendable, CaseIterable, Codable {
        case systemPrompt
        case toolSchemas
        case messages
        case toolResults
        case memory
    }

    public let id: ID
    /// The part's size in tokens (= measured, not reported).
    public let tokens: Int

    public init(id: ID, tokens: Int) {
        self.id = id
        self.tokens = tokens
    }
}

/// What one request's prompt carried.
///
/// `Codable` because the app stores the reading on the conversation's own
/// row: the encoder's output is the stored payload, so a shape this decoder
/// cannot read comes back as no reading rather than as a wrong number.
public struct ContextUsageSnapshot: Sendable, Equatable, Codable {
    /// The tokens the provider counted for the prompt (= its own report).
    ///
    /// This is the number the meter fills against: it is what the
    /// provider actually received, so it is the only count that cannot
    /// disagree with the provider's billing.
    public let promptTokens: Int

    /// The tokens the provider counted for the answer.
    ///
    /// Kept beside the prompt count and never added to it: the answer
    /// is not part of the window the next request has to fit.
    public let completionTokens: Int

    /// The tokens the provider served from its prompt cache.
    public let cacheReadTokens: Int

    /// The tokens the provider wrote into its prompt cache.
    public let cacheCreationTokens: Int

    /// The window the request was measured against.
    public let contextWindow: Int

    /// The prompt's parts, with their measured sizes.
    public let categories: [ContextUsageCategory]

    /// Whether the request's history was compressed before it went out.
    public let compressed: Bool

    public init(
        promptTokens: Int,
        completionTokens: Int,
        cacheReadTokens: Int = 0,
        cacheCreationTokens: Int = 0,
        contextWindow: Int,
        categories: [ContextUsageCategory] = [],
        compressed: Bool = false
    ) {
        self.promptTokens = promptTokens
        self.completionTokens = completionTokens
        self.cacheReadTokens = cacheReadTokens
        self.cacheCreationTokens = cacheCreationTokens
        self.contextWindow = contextWindow
        self.categories = categories
        self.compressed = compressed
    }

    /// The prompt's share of the window (= 0 when the window is unknown).
    public var occupancy: Double {
        guard contextWindow > 0 else { return 0 }
        return min(1, Double(promptTokens) / Double(contextWindow))
    }

    /// The measured size of one part.
    public func tokens(for id: ContextUsageCategory.ID) -> Int {
        categories.first { $0.id == id }?.tokens ?? 0
    }
}

/// The running reading, per conversation.
///
/// Fed from the turn path, so the number is available while the
/// conversation runs. The recorder itself is per process: = what it holds
/// dies with the process. The copy that outlives a relaunch is written by
/// the app into the conversation's own row, and read back from there.
public actor ContextUsageRecorder {
    public static let shared = ContextUsageRecorder()

    private var snapshotByConversation: [String: ContextUsageSnapshot] = [:]
    /// The conversation that recorded last (= the one just spent tokens).
    private var mostRecentConversationId: String?

    public init() {}

    /// Record one request's reading.
    public func record(conversationId: String, snapshot: ContextUsageSnapshot) {
        snapshotByConversation[conversationId] = snapshot
        mostRecentConversationId = conversationId
    }

    /// The reading for one conversation (= nil when nothing was recorded).
    public func snapshot(conversationId: String) -> ContextUsageSnapshot? {
        snapshotByConversation[conversationId]
    }

    /// The reading of the most recently used conversation.
    ///
    /// The footer does not always know which conversation the user is in
    /// (= the panel that shows the saving does not), and the conversation
    /// that just spent the tokens is the one whose reading is asked for.
    public func mostRecentSnapshot() -> ContextUsageSnapshot? {
        guard let last = mostRecentConversationId else { return nil }
        return snapshotByConversation[last]
    }
}

/// The size of a prompt's parts, measured.
///
/// The measure is characters over four (= the same estimate the
/// compressor uses), so a part's reported size and the compressor's
/// view of the same text agree.
public enum ContextUsageMeasure {
    /// The characters one token is worth.
    ///
    /// The package's own estimate: a token is four characters, so the
    /// measure is characters over four. The budget that bounds a turn's
    /// tool output converts the window with the same number, so the two
    /// sides of the budget speak the same scale.
    public static let charactersPerToken = 4

    /// The tokens a piece of text is worth.
    public static func tokens(_ text: String) -> Int {
        guard !text.isEmpty else { return 0 }
        return (text.count + charactersPerToken - 1) / charactersPerToken
    }

    /// The tokens a set of messages is worth, split into the
    /// conversation's own text and the tool results it carries.
    ///
    /// The two are separate parts because they are fixed differently: the
    /// conversation's text is what the writer produced, and the tool
    /// results are what the tools brought back.
    public static func messageTokens(
        _ messages: [LLMMessage]
    ) -> (conversation: Int, toolResults: Int) {
        var conversation = 0
        var toolResults = 0
        for message in messages {
            for block in message.blocks {
                switch block {
                case let .text(text):
                    conversation += tokens(text)
                case let .thinking(text, _):
                    conversation += tokens(text)
                case let .toolUse(_, _, input):
                    conversation += tokens(input)
                case let .toolResult(_, output, _):
                    toolResults += tokens(output)
                }
            }
        }
        return (conversation, toolResults)
    }

    /// The tokens a set of tool schemas is worth.
    ///
    /// The schemas travel as one JSON array on the wire, so their size is
    /// measured as the array's text rather than per field.
    public static func toolSchemaTokens(_ schemas: [ToolRegistrySchema]) -> Int {
        guard !schemas.isEmpty else { return 0 }
        let encoded = schemas
            .map { schema -> String in
                let fields = schema.inputSchema
                    .map { key, property in
                        "\(key):\(property.type):\(property.description)"
                    }
                    .joined(separator: ",")
                return "\(schema.name):\(schema.description):\(fields)"
            }
            .joined(separator: ",")
        return tokens(encoded)
    }
}
