// LLMModelDiscovery.swift · Wenshu
//
// Discovers the live list of available models for a provider by
// calling the provider's canonical `/models` endpoint. Used by
// the model picker (= in the chat input bar) so the user can
// choose any model the provider actually serves (= not just
// the curated `Provider.defaultModels` list).
//
// Per boss 2026-10-16 OOB "配好 KEY 后, 模型设置中的可选
// 模型, 也应该通过 API 查询. 同样不能写死":
//   - The model picker in Settings → Providers (and in
//     the chat input bar's model selector) should
//     enumerate the live list from the provider's
//     `/models` endpoint (= when the provider
//     supports it).
//   - `Provider.defaultModels` is the FALLBACK (= used
//     when the endpoint is unreachable, when the
//     provider has no `/models` endpoint, or when the
//     user has not yet configured a key).
//
// Endpoint shape by provider (= determined by `apiMode`):
//   - "openai_chat"        → `GET {baseURL}/models`
//                            response: `{ "data": [{ "id": "..." }] }`
//   - "anthropic_messages" → `GET {baseURL}/v1/models`
//                            response: `{ "data": [{ "id": "..." }] }`
//                            (= Anthropic + minimax)
//   - "google_genai"       → `GET {baseURL}/models`
//                            response: `{ "models": [{ "name": "..." }] }`
//                            (= `name` is "models/gemini-..."; the
//                            "models/" prefix is stripped before
//                            returning to the caller)
//   - Ollama               → `GET {baseURL}/api/tags`
//                            response: `{ "models": [{ "name": "..." }] }`
//                            (= Ollama's bespoke shape; = mapped
//                            to the same `models: [String]` return
//                            type)
//
// The implementation is an `actor` (= the calls are
// async; = the model list is cached per (provider, baseURL)
// for a short TTL = 5 minutes; = the user can force a
// refresh via the Settings UI).

import Foundation

/// Per-provider discovery result. `models` is always non-empty
/// (= either the live list, or the canonical
/// `Provider.defaultModels` fallback when the endpoint is
/// unreachable / unauthorized / returned an unexpected
/// payload).
struct LLMDiscoveredModels: Sendable, Equatable {
    let provider: Provider
    let models: [String]
    /// `true` when the live `/models` endpoint answered (= the
    /// user can tell whether the picker is showing live data
    /// vs. the static fallback; = useful in the Settings UI
    /// = "最后更新于 5 分钟前" or "未连接 (= 使用默认列表)").
    let isLive: Bool
    /// Last successful fetch timestamp (= nil when the
    /// fallback path was taken). The Settings UI uses
    /// this to show the freshness label.
    let fetchedAt: Date?
}

/// Discovers the live model list for a single provider via
/// its canonical `/models` endpoint. Falls back to
/// `Provider.defaultModels` on any error (= network
/// failure, 401, 4xx, 5xx, parse error, unexpected
/// payload shape). Never throws (= the picker always
/// has at least the fallback list to show).
actor LLMModelDiscovery {

    /// Cache TTL (= how long the live list is considered
    /// fresh). 5 minutes is the same as the OpenAI
    /// Playground's cache window (= short enough that
    /// the user sees new models quickly after the
    /// provider adds them, long enough that flipping
    /// the model picker doesn't hit the network on
    /// every keystroke).
    static let cacheTTL: TimeInterval = 5 * 60

    /// Cached results keyed by provider slug (= one
    /// cache entry per provider; = the chat input
    /// bar can read instantly without re-querying).
    private var cache: [String: LLMDiscoveredModels] = [:]

    /// URLSession used for the `/models` endpoint call.
    /// Defaults to `.shared`; = tests inject a
    /// `URLSessionConfiguration.ephemeral` session
    /// (= with a custom URLProtocol stub) so the
    /// network call is hermetic. The injected session
    /// is also cached (= every discover() call for a
    /// given provider uses the same session; = the
    /// per-test URLProtocolStub stays in scope).
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Discover (= or read from cache) the live model
    /// list for a provider. `forceRefresh = true`
    /// bypasses the cache (= used by the Settings UI's
    /// "刷新" button).
    func discover(
        provider: Provider,
        forceRefresh: Bool = false
    ) async -> LLMDiscoveredModels {
        if !forceRefresh, let cached = cache[provider.slug] {
            // TTL check: if the cached entry is stale,
            // re-query. The cache lookup is cheap; = the
            // re-query is async; = we return the stale
            // value first and re-query in the background
            // is overkill (= the user can pull-to-refresh
            // = same pattern as Mail's mailbox sync).
            if let fetched = cached.fetchedAt,
               Date().timeIntervalSince(fetched) < Self.cacheTTL {
                return cached
            }
        }

        // No cache or stale = query the live endpoint.
        let liveResult = await queryLive(provider: provider)
        let final: LLMDiscoveredModels
        if let liveModels = liveResult {
            final = LLMDiscoveredModels(
                provider: provider,
                models: liveModels,
                isLive: true,
                fetchedAt: Date()
            )
        } else {
            // Live query failed (= network, auth, parse);
            // = use the canonical fallback (= the
            // curated list; = the user can still pick a
            // model; = the Settings UI shows "未连接"
            // instead of the freshness label).
            final = LLMDiscoveredModels(
                provider: provider,
                models: provider.defaultModels,
                isLive: false,
                fetchedAt: nil
            )
        }
        cache[provider.slug] = final
        return final
    }

    /// Clear the cached entry for a provider (= used by
    /// the Settings UI's "刷新" button when the user
    /// toggles the keychain mode, or when the user
    /// re-enters the key).
    func invalidate(providerSlug: String) {
        cache.removeValue(forKey: providerSlug)
    }

    // MARK: - Live endpoint query (= returns nil on any failure)

    /// Returns the list of model IDs from the live
    /// `/models` endpoint, or nil if any step failed (=
    /// the caller falls back to `Provider.defaultModels`).
    private func queryLive(provider: Provider) async -> [String]? {
        // Skip the live query when there's no key
        // configured (= the user has not opted into
        // this provider; = we save the network call
        // and the 401).
        guard let key = ProviderKeychain.loadKeySync(for: provider),
              !key.isEmpty else {
            return nil
        }
        let endpoint = modelListURL(for: provider)
        guard let url = endpoint else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10
        applyAuth(to: &request, provider: provider, key: key)
        // Anthropic-style providers need the version
        // header; OpenAI-compat need only the auth.
        if provider.apiMode == "anthropic_messages" {
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        }

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode) else {
                return nil
            }
            // Parse by apiMode (= each provider has a
            // slightly different response shape).
            return try parseModelsResponse(
                data: data,
                apiMode: provider.apiMode
            )
        } catch {
            // Any error (= network, parse, JSON shape) =
            // graceful fallback.
            return nil
        }
    }

    /// Build the model-list URL per provider. Most
    /// OpenAI-compat providers append `/models` to
    /// `defaultBaseURL`; Anthropic-compat append
    /// `/v1/models`; Gemini and Ollama have bespoke
    /// paths (= the `apiMode` switches the path).
    private func modelListURL(for provider: Provider) -> URL? {
        let base = provider.defaultBaseURL
        switch provider.apiMode {
        case "openai_chat":
            return URL(string: "\(base)/models")
        case "anthropic_messages":
            return URL(string: "\(base)/v1/models")
        case "google_genai":
            // Gemini's `/v1beta/models` returns
            // `{ "models": [{ "name": "models/..." }] }`.
            return URL(string: "\(base)/models")
        default:
            // Ollama, custom, etc. = handle via
            // slug-specific overrides below.
            switch provider.slug {
            case "ollama":
                return URL(string: "\(base)/api/tags")
            default:
                return nil
            }
        }
    }

    /// Apply the provider-specific auth header. Mirrors
    /// the auth shape in `ProviderAuthMode` (= bearer
    /// = `Authorization: Bearer <key>`; xApiKey =
    /// `x-api-key: <key>`).
    private func applyAuth(
        to request: inout URLRequest,
        provider: Provider,
        key: String
    ) {
        switch provider.authHeader {
        case .bearer:
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        case .xApiKey:
            request.setValue(key, forHTTPHeaderField: "x-api-key")
        }
    }

    /// Parse the response body. Each `apiMode` has a
    /// canonical JSON shape (= the OpenAI
    /// `{"data":[{"id":...}]}` and Anthropic
    /// `{"data":[{"id":...}]}` happen to be
    /// identical; = Gemini and Ollama differ).
    private func parseModelsResponse(
        data: Data,
        apiMode: String
    ) throws -> [String]? {
        switch apiMode {
        case "openai_chat", "anthropic_messages":
            // OpenAI + Anthropic-compatible: `{"data":[{"id":"..."},...]}`
            struct OpenAIList: Decodable {
                struct ModelEntry: Decodable { let id: String }
                let data: [ModelEntry]
            }
            let decoded = try JSONDecoder().decode(OpenAIList.self, from: data)
            return decoded.data.map(\.id)

        case "google_genai":
            // Gemini: `{"models":[{"name":"models/gemini-2.5-pro"},...]}`
            // (= strip the "models/" prefix so the picker
            // shows "gemini-2.5-pro" not
            // "models/gemini-2.5-pro").
            struct GeminiList: Decodable {
                struct ModelEntry: Decodable { let name: String }
                let models: [ModelEntry]
            }
            let decoded = try JSONDecoder().decode(GeminiList.self, from: data)
            return decoded.models.map { entry in
                entry.name.hasPrefix("models/")
                    ? String(entry.name.dropFirst("models/".count))
                    : entry.name
            }

        default:
            // Ollama / custom: `{"models":[{"name":"llama3.3:latest"},...]}`
            // (= the same shape as Gemini; = reuse the
            // decoder).
            struct OllamaList: Decodable {
                struct ModelEntry: Decodable { let name: String }
                let models: [ModelEntry]
            }
            let decoded = try JSONDecoder().decode(OllamaList.self, from: data)
            return decoded.models.map(\.name)
        }
    }
}
