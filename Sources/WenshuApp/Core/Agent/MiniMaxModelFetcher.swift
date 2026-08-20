//
//  MiniMaxModelFetcher.swift · v0.21 ticket 04
//

import Foundation

actor ModelCache {
    static let shared = ModelCache()
    private var cached: [String: [String]] = [:]
    private var cachedAt: [String: Date] = [:]
    private let ttl: TimeInterval = 3600

    func get(_ key: String) -> [String]? {
        guard let at = cachedAt[key], Date().timeIntervalSince(at) < ttl else { return nil }
        return cached[key]
    }

    func set(_ modelIds: [String], for key: String) {
        cached[key] = modelIds
        cachedAt[key] = Date()
    }
}

enum MiniMaxModelFetcher {
    static func fetchLiveModelIds(apiKey: String, baseUrl: String) async -> [String]? {
        let base = baseUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let candidates = [base, base + "/v1"]
        var headers: [String: String] = [
            "x-api-key": apiKey,
            "anthropic-version": "2023-06-01",
            "User-Agent": "wenshu/0.21"
        ]
        for urlStr in candidates {
            guard let url = URL(string: urlStr + "/models") else { continue }
            var req = URLRequest(url: url, timeoutInterval: 5.0)
            for (k, v) in headers { req.setValue(v, forHTTPHeaderField: k) }
            do {
                let (data, _) = try await URLSession.shared.data(for: req)
                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
                if let models = json["data"] as? [[String: Any]] {
                    let ids = models.compactMap { $0["id"] as? String }.filter { !$0.isEmpty }
                    if !ids.isEmpty { return ids }
                }
            } catch {
                continue
            }
        }
        return nil
    }

    static func loadModelIds(apiKey: String, baseUrl: String) async -> [String] {
        let cacheKey = "\(baseUrl)|\(apiKey.prefix(8))"
        if let cached = await ModelCache.shared.get(cacheKey) {
            NSLog("[wenshu.models] cache hit: \(cached.count) models")
            return cached
        }
        if let live = await fetchLiveModelIds(apiKey: apiKey, baseUrl: baseUrl) {
            NSLog("[wenshu.models] live fetch: \(live.count) models")
            await ModelCache.shared.set(live, for: cacheKey)
            return live
        }
        NSLog("[wenshu.models] fallback to curated")
        return MiniMaxModel.allCases.map { $0.rawValue }
    }
}
