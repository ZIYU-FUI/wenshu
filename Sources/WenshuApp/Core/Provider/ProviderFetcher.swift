//
//  ProviderFetcher.swift · v0.21 ticket 03
//

import Foundation

actor ProviderModelCache {
    static let shared = ProviderModelCache()
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

enum ProviderFetcher {
    static func fetchLiveModelIds(provider: Provider, apiKey: String) async -> [String]? {
        guard !apiKey.isEmpty, provider.slug != "custom" else { return nil }
        let base = provider.defaultBaseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let candidates = provider.apiMode == "anthropic_messages"
            ? [base + "/v1", base]
            : [base, base + "/v1"]
        var headers: [String: String] = ["User-Agent": "wenshu/0.21"]
        switch provider.authHeader {
        case .xApiKey:
            headers["x-api-key"] = apiKey
            headers["anthropic-version"] = "2023-06-01"
        case .bearer:
            headers["Authorization"] = "Bearer \(apiKey)"
        }
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

    static func loadModelIds(provider: Provider, apiKey: String) async -> [String] {
        let cacheKey = "\(provider.slug)|\(apiKey.prefix(8))"
        if let cached = await ProviderModelCache.shared.get(cacheKey) {
            NSLog("[wenshu.provider] \(provider.slug) cache hit: \(cached.count) models")
            return cached
        }
        if let live = await fetchLiveModelIds(provider: provider, apiKey: apiKey) {
            NSLog("[wenshu.provider] \(provider.slug) live: \(live.count) models")
            await ProviderModelCache.shared.set(live, for: cacheKey)
            return live
        }
        NSLog("[wenshu.provider] \(provider.slug) fallback curated")
        return provider.defaultModels
    }
}
