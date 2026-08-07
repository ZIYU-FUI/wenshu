import Foundation

public final class LLMService: @unchecked Sendable {
    public static var shared: LLMService {
        get throws { try LLMService() }
    }

    private let provider: MinimaxProvider

    public init(keychain: KeychainHelper = .shared) throws {
        guard let key = keychain.loadKey(), !key.isEmpty else { throw LLMError.missingAPIKey }
        provider = MinimaxProvider(model: .m3, apiKey: key)
    }

    public func streamChat(system: String, messages: [(String, String)]) -> AsyncThrowingStream<String, Error> {
        provider.streamMessage(system: system, messages: messages.map { (role: $0.0, content: $0.1) })
    }
}
