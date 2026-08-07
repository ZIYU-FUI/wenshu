import Foundation

public struct SSEEvent: Equatable, Sendable {
    public let event: String
    public let data: String

    public init(event: String, data: String) {
        self.event = event
        self.data = data
    }
}

/// Incremental parser for server-sent events. Incomplete events remain buffered.
public final class SSEParser: @unchecked Sendable {
    private var buffer = Data()

    public init() {}

    @discardableResult
    public func append(_ bytes: Data) -> [SSEEvent] {
        buffer.append(bytes)
        var result: [SSEEvent] = []
        while let range = eventBoundary(in: buffer) {
            let eventData = buffer.subdata(in: 0..<range.lowerBound)
            buffer.removeSubrange(0..<range.upperBound)
            if let event = parse(eventData) { result.append(event) }
        }
        return result
    }

    @discardableResult
    public func append(_ string: String) -> [SSEEvent] {
        append(Data(string.utf8))
    }

    private func eventBoundary(in data: Data) -> Range<Int>? {
        let bytes = Array(data)
        guard let index = bytes.firstRange(of: [10, 10])?.lowerBound else {
            guard let index = bytes.firstRange(of: [13, 10, 13, 10])?.lowerBound else { return nil }
            return index..<(index + 4)
        }
        return index..<(index + 2)
    }

    private func parse(_ data: Data) -> SSEEvent? {
        guard let text = String(data: data, encoding: .utf8) else { return nil }
        var eventName = "message"
        var dataLines: [String] = []
        for line in text.split(omittingEmptySubsequences: false, whereSeparator: { $0 == "\n" || $0 == "\r" }) {
            if line.hasPrefix("event:") {
                eventName = line.dropFirst(6).trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("data:") {
                dataLines.append(String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces))
            }
        }
        guard !dataLines.isEmpty else { return nil }
        let dataString = dataLines.joined()
        guard let jsonData = dataString.data(using: .utf8),
              (try? JSONSerialization.jsonObject(with: jsonData)) != nil else { return nil }
        return SSEEvent(event: eventName, data: dataString)
    }
}
