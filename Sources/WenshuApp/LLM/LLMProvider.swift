import Foundation

public protocol LLMProvider: Sendable {
    var model: String { get }
    func streamMessage(system: String, messages: [(role: String, content: String)]) -> AsyncThrowingStream<String, Error>
}
