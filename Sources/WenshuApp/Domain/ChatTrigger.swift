// ChatTrigger.swift · Wenshu (文枢) · v0.27 (FCP library replica)
//
// Detects when a chat message hints at a new entity (= a character /
// world fact / research reference) and emits an `IngestionRequest`
// for the LLM Wiki pipeline. v0.27 spec: '用户聊着小说的剧情，实体就
// 调研出来了，然后又被整个项目自动引用'.
//
// Trigger heuristics (v0.27 MVP, conservative):
// 1. Chinese quoted names (= 「张三」, 「万历十五年」)
// 2. BookTitle patterns (= 万历 / 永乐 / 大明 ...)
//
// v0.27 followups can add LLM-based extraction; v0.27-03 ships the
// rule-based trigger as the scaffolding.

import Foundation

/// An LLM Wiki ingestion request (= what the EntityIngestion pipeline
/// picks up to write entities into the reference library).
struct IngestionRequest: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let surfaceForm: String          // = e.g. "张三" / "万历十五年"
    let kind: SmartQueryEntityType   // = .character / .world / .reference
    let sourceMessageId: UUID?       // = which chat message triggered this
    let createdAt: Date

    init(
        id: UUID = UUID(),
        surfaceForm: String,
        kind: SmartQueryEntityType,
        sourceMessageId: UUID? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.surfaceForm = surfaceForm
        self.kind = kind
        self.sourceMessageId = sourceMessageId
        self.createdAt = createdAt
    }
}

/// Chat trigger detector (= the v0.27 scaffolding). Given a chat
/// message, returns IngestionRequests for any surface forms detected.
struct ChatTrigger: Sendable {
    /// Chinese quotation marks (= 「」+ 『』+ 《》).
    private let quotationRegex: NSRegularExpression
    /// Common Chinese book-title patterns (= v0.27 hard-coded list;
    /// future versions use LLM detection).
    private let bookTitlePatterns: [String]

    init() {
        self.quotationRegex = try! NSRegularExpression(
            pattern: "[\\u{300C}\\u{300D}\\u{300E}\\u{300F}\\u{300A}\\u{300B}]([^\\u{300C}\\u{300D}\\u{300E}\\u{300F}\\u{300A}\\u{300B}]+)[\\u{300D}\\u{300F}\\u{300B}]",
            options: []
        )
        self.bookTitlePatterns = [
            "万历十五年", "永乐大典", "大明王朝",
            "三国演义", "红楼梦", "水浒传", "西游记",
            "资治通鉴", "史记", "汉书"
        ]
    }

    /// Detect IngestionRequests in a chat message.
    func detect(in message: String, messageId: UUID? = nil) -> [IngestionRequest] {
        var requests: [IngestionRequest] = []
        requests.append(contentsOf: detectQuotedNames(in: message, messageId: messageId))
        requests.append(contentsOf: detectBookTitles(in: message, messageId: messageId))
        return dedupe(requests)
    }

    private func detectQuotedNames(in message: String, messageId: UUID?) -> [IngestionRequest] {
        let nsMessage = message as NSString
        let range = NSRange(location: 0, length: nsMessage.length)
        let matches = quotationRegex.matches(in: message, options: [], range: range)
        var requests: [IngestionRequest] = []
        for match in matches where match.numberOfRanges >= 2 {
            let innerRange = match.range(at: 1)
            guard innerRange.location != NSNotFound else { continue }
            let inner = nsMessage.substring(with: innerRange)
            requests.append(IngestionRequest(
                surfaceForm: inner,
                kind: .character,  // (= v0.27 default; future LLM extraction will refine)
                sourceMessageId: messageId
            ))
        }
        return requests
    }

    private func detectBookTitles(in message: String, messageId: UUID?) -> [IngestionRequest] {
        var requests: [IngestionRequest] = []
        for title in bookTitlePatterns where message.contains(title) {
            requests.append(IngestionRequest(
                surfaceForm: title,
                kind: .reference,
                sourceMessageId: messageId
            ))
        }
        return requests
    }

    /// Dedupe by (surfaceForm, kind) tuple.
    private func dedupe(_ requests: [IngestionRequest]) -> [IngestionRequest] {
        var seen: Set<String> = []
        var result: [IngestionRequest] = []
        for request in requests {
            let key = "\(request.surfaceForm)|\(request.kind.rawValue)"
            if seen.insert(key).inserted {
                result.append(request)
            }
        }
        return result
    }
}