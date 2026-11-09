
/// The result of a single `ConversationLoop.runConversation` call: the
/// model's reply, the full message history, and the taskId used for tracing
/// and telemetry.
public struct ConversationResult: Sendable {
    public let response: LLMResponse
    public var messages: [LLMMessage]
    public let taskId: String

    public init(response: LLMResponse, messages: [LLMMessage], taskId: String) {
        self.response = response
        self.messages = messages
        self.taskId = taskId
    }
}
