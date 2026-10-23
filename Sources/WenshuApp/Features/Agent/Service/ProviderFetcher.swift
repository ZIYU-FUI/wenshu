// ProviderFetcher.swift

import Foundation
import WenshuAgent
import os

private let wenshuLogger = Logger(subsystem: "com.wenshu", category: "providerfetcher")

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

/// A provider's live model ids. nil = there is no live list (= the
/// caller falls back to the curated list).
protocol ProviderModelIdsSource: Sendable {
    func fetchLiveModelIds(provider: Provider, apiKey: String) async -> [String]?
}

/// The production source: the provider's models endpoint behind the
/// shared TTL cache. Called only when a live list is possible.
struct LiveModelIdsSource: ProviderModelIdsSource {
    func fetchLiveModelIds(provider: Provider, apiKey: String) async -> [String]? {
        let cacheKey = "\(provider.slug)|\(apiKey.prefix(8))"
        if let cached = await ProviderModelCache.shared.get(cacheKey) {
            wenshuLogger.info("[wenshu.provider] \(provider.slug) cache hit: \(cached.count) models")
            return cached
        }
        guard let live = await Self.requestModelIds(provider: provider, apiKey: apiKey) else { return nil }
        wenshuLogger.info("[wenshu.provider] \(provider.slug) live: \(live.count) models: \(live.joined(separator: ", "))")
        await ProviderModelCache.shared.set(live, for: cacheKey)
        return live
    }

    /// The models endpoint of the provider. nil when the request fails
    /// or the payload carries no usable model id.
    private static func requestModelIds(provider: Provider, apiKey: String) async -> [String]? {
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
}

enum ProviderFetcher {
    /// The model ids to offer for a provider: the live list when the
    /// source has one, the curated list otherwise.
    ///
    /// `source` is the seam. Production asks the provider's endpoint;
    /// a test substitutes a source that answers on purpose, so both
    /// branches are reachable without a network.
    static func loadModelIds(
        provider: Provider,
        apiKey: String,
        source: any ProviderModelIdsSource = LiveModelIdsSource()
    ) async -> [String] {
        guard canFetchLiveModelIds(provider: provider, apiKey: apiKey) else {
            wenshuLogger.info("[wenshu.provider] \(provider.slug) fallback curated")
            return provider.defaultModels
        }
        if let live = await source.fetchLiveModelIds(provider: provider, apiKey: apiKey) {
            return live
        }
        wenshuLogger.info("[wenshu.provider] \(provider.slug) fallback curated")
        return provider.defaultModels
    }

    /// A live model list needs a key and a provider that has an
    /// endpoint of its own (= a custom provider's endpoint is supplied
    /// by the user, so there is nothing to ask here).
    private static func canFetchLiveModelIds(provider: Provider, apiKey: String) -> Bool {
        !apiKey.isEmpty && provider.slug != "custom"
    }
}
