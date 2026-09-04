// OpenAIImageGenAdapter.swift · Wenshu (文枢) · v0.34
//
// v0.34 boss 2026-09-02 OOB: OpenAI DALL-E image generation adapter
// (= port of Card-master `src/ai/infrastructure/openai-images-adapter.ts`).
//
// OpenAI image gen API: POST https://api.openai.com/v1/images/generations
// Body: { model, prompt, n, size, response_format }.
// Response: { data[0].b64_json } (= base64-encoded PNG) or
// { data[0].url } (= temporary CDN URL). We use `response_format = b64_json`
// for single-step download (= no second HTTP roundtrip).
//
// Auth: `Authorization: Bearer <OPENAI_API_KEY>`.

import Foundation

/// OpenAI DALL-E adapter (= fallback provider per boss Q34 grill
/// recommendation). Reads API key from `ProviderKeychain`.
struct OpenAIImageGenAdapter: ImageGenProvider {
    let id: ImageGenProviderID = .openai
    private let apiKey: String?
    private let endpoint: URL
    private let session: URLSession

    init(apiKey: String?, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.endpoint = URL(string: "https://api.openai.com/v1/images/generations")!
        self.session = session
    }

    var hasAPIKey: Bool {
        guard let apiKey else { return false }
        return !apiKey.isEmpty
    }

    func generate(_ request: ImageGenRequest) async throws -> ImageGenResponse {
        guard hasAPIKey else {
            throw ImageGenError.apiKeyMissing(provider: .openai)
        }

        // Map 256x192 -> closest DALL-E 3 supported size.
        // DALL-E 3 sizes: 1024x1024 / 1024x1792 / 1792x1024.
        // 4:3 aspect at small size has no exact match = nearest is
        // 1024x1024 (square). Trade-off: square thumbnail is fine for
        // a card grid (= card background is already 4:3 but the
        // thumbnail is inset with letterboxing). v0.34 note: if
        // DALL-E 3 grows to support 512x384 / 256x192, switch.
        let size = "1024x1024"

        let requestBody: [String: Any] = [
            "model": "dall-e-3",
            "prompt": request.prompt,
            "n": 1,
            "size": size,
            "response_format": "b64_json"
        ]
        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey!)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            throw ImageGenError.networkFailure(provider: .openai, underlying: error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw ImageGenError.badStatus(provider: .openai, status: 0, body: "Non-HTTP response")
        }

        switch http.statusCode {
        case 200..<300:
            break
        case 401, 403:
            throw ImageGenError.apiKeyInvalid(provider: .openai)
        case 429:
            throw ImageGenError.rateLimited(provider: .openai)
        default:
            let body = String(data: data, encoding: .utf8) ?? "<binary>"
            throw ImageGenError.badStatus(provider: .openai, status: http.statusCode, body: body)
        }

        // Parse response (= data[0].b64_json).
        struct OpenAIResponse: Decodable {
            struct Datum: Decodable {
                let b64_json: String?
                let url: String?
            }
            let data: [Datum]
        }

        let decoded: OpenAIResponse
        do {
            decoded = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        } catch {
            throw ImageGenError.decodeFailure(provider: .openai, underlying: error)
        }
        guard let first = decoded.data.first else {
            throw ImageGenError.emptyResponse(provider: .openai)
        }
        let imageData: Data
        if let b64 = first.b64_json, let decoded64 = Data(base64Encoded: b64) {
            imageData = decoded64
        } else if let urlString = first.url, let imageURL = URL(string: urlString) {
            // Fallback: GET the URL.
            do {
                (imageData, _) = try await session.data(from: imageURL)
            } catch {
                throw ImageGenError.networkFailure(provider: .openai, underlying: error)
            }
        } else {
            throw ImageGenError.emptyResponse(provider: .openai)
        }

        guard !imageData.isEmpty else {
            throw ImageGenError.emptyResponse(provider: .openai)
        }

        return ImageGenResponse(
            imageData: imageData,
            contentType: "image/png",
            sourceURL: endpoint
        )
    }
}