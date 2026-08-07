import Foundation

public enum LLMError: Error, LocalizedError, Sendable {
    case missingAPIKey
    case invalidResponse
    case httpError(statusCode: Int, body: String)

    public var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "Missing MiniMax API key"
        case .invalidResponse: return "Invalid response from the LLM service"
        case let .httpError(statusCode, _): return "LLM request failed with HTTP status \(statusCode)"
        }
    }
}
