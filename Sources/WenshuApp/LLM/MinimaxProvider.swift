import Foundation

public enum MinimaxModel: String, Sendable {
    case m3 = "MiniMax-M3"
    case m27 = "MiniMax-M2.7"
    case m27Highspeed = "MiniMax-M2.7-highspeed"
    case m25 = "MiniMax-M2.5"
    case m25Highspeed = "MiniMax-M2.5-highspeed"
    case m21 = "MiniMax-M2.1"
    case m21Highspeed = "MiniMax-M2.1-highspeed"
    case m2 = "MiniMax-M2"
    case m2Her = "M2-her"
}

public struct MinimaxProvider: LLMProvider, Sendable {
    public let model: String
    private let apiKey: String
    private let endpoint = URL(string: "https://api.minimaxi.com/anthropic/v1/messages")!

    public init(model: MinimaxModel = .m3, apiKey: String) {
        self.model = model.rawValue
        self.apiKey = apiKey
    }

    public func streamMessage(system: String, messages: [(role: String, content: String)]) -> AsyncThrowingStream<String, Error> {
        let model = model
        let apiKey = apiKey
        let endpoint = endpoint
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var request = URLRequest(url: endpoint)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue(apiKey, forHTTPHeaderField: "X-Api-Key")
                    let body: [String: Any] = [
                        "model": model,
                        "max_tokens": 1024,
                        "system": system,
                        "messages": messages.map { ["role": $0.role, "content": $0.content] },
                        "stream": true
                    ]
                    request.httpBody = try JSONSerialization.data(withJSONObject: body)

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    guard let httpResponse = response as? HTTPURLResponse else { throw LLMError.invalidResponse }
                    guard (200..<300).contains(httpResponse.statusCode) else {
                        throw LLMError.httpError(statusCode: httpResponse.statusCode, body: "HTTP error")
                    }

                    let parser = SSEParser()
                    for try await byte in bytes {
                        for event in parser.append(Data([byte])) {
                            if event.event == "message_stop" {
                                continuation.finish()
                                return
                            }
                            if event.event == "content_block_delta",
                               let json = event.data.data(using: .utf8),
                               let object = try? JSONSerialization.jsonObject(with: json) as? [String: Any],
                               let delta = object["delta"] as? [String: Any],
                               let text = delta["text"] as? String {
                                continuation.yield(text)
                            }
                        }
                    }
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
