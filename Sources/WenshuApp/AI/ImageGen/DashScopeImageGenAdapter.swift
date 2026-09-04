// DashScopeImageGenAdapter.swift · Wenshu (文枢) · v0.34
//
// v0.34 boss 2026-09-02 OOB: DashScope image generation adapter (= port
// of Card-master `src/ai/infrastructure/dashscope-images-adapter.ts`).
//
// DashScope image gen API (= 阿里云): POST
// https://dashscope.aliyuncs.com/api/v1/services/aigc/text2image/image-synthesis
// Body: { model, input.text, parameters.size }.
// Response: { output.results[0].url } (= pre-signed CDN URL; the
// adapter then GETs the URL to fetch raw image bytes).
//
// Auth: `Authorization: Bearer <DASHSCOPE_API_KEY>`.
//
// Apple-API-first check: `URLSession.data(for:)` is the only Apple
// API needed (= direct async/await). No Alamofire / similar.

import Foundation

/// DashScope adapter (= primary provider per boss Q34 grill
/// recommendation). Reads API key from `ProviderKeychain`.
struct DashScopeImageGenAdapter: ImageGenProvider {
    let id: ImageGenProviderID = .dashscope
    private let apiKey: String?
    private let endpoint: URL
    private let session: URLSession

    init(apiKey: String?, session: URLSession = .shared) {
        self.apiKey = apiKey
        // v0.34: hard-coded endpoint. Future: allow override via
        // ProviderKeychain (= Card-master's `dashscope-images-adapter.ts`
        // also reads baseUrl from config but defaults to this URL).
        self.endpoint = URL(string: "https://dashscope.aliyuncs.com/api/v1/services/aigc/text2image/image-synthesis")!
        self.session = session
    }

    var hasAPIKey: Bool {
        guard let apiKey else { return false }
        return !apiKey.isEmpty
    }

    func generate(_ request: ImageGenRequest) async throws -> ImageGenResponse {
        guard hasAPIKey else {
            throw ImageGenError.apiKeyMissing(provider: .dashscope)
        }

        // Step 1: POST the generation request.
        let requestBody: [String: Any] = [
            "model": "wanx-v1",
            "input": ["text": request.prompt],
            "parameters": [
                // v0.34: 256x192 = small card thumbnail size per boss OOB
                // (= keep .ws library file size bounded; ~15 KB JPEG q=0.7).
                "size": "\(request.width)*\(request.height)",
                "n": 1,
                "style": "<photography>"
            ]
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
            throw ImageGenError.networkFailure(provider: .dashscope, underlying: error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw ImageGenError.badStatus(provider: .dashscope, status: 0, body: "Non-HTTP response")
        }

        switch http.statusCode {
        case 200..<300:
            break  // success path below
        case 401, 403:
            throw ImageGenError.apiKeyInvalid(provider: .dashscope)
        case 429:
            throw ImageGenError.rateLimited(provider: .dashscope)
        default:
            let body = String(data: data, encoding: .utf8) ?? "<binary>"
            throw ImageGenError.badStatus(provider: .dashscope, status: http.statusCode, body: body)
        }

        // Step 2: parse the response (= output.results[0].url).
        struct DashScopeResponse: Decodable {
            struct Output: Decodable {
                struct Result: Decodable {
                    let url: String
                }
                let results: [Result]
            }
            let output: Output
        }

        let decoded: DashScopeResponse
        do {
            decoded = try JSONDecoder().decode(DashScopeResponse.self, from: data)
        } catch {
            throw ImageGenError.decodeFailure(provider: .dashscope, underlying: error)
        }
        guard let urlString = decoded.output.results.first?.url,
              let imageURL = URL(string: urlString) else {
            throw ImageGenError.emptyResponse(provider: .dashscope)
        }

        // Step 3: GET the pre-signed CDN URL to fetch raw image bytes.
        let (imageData, imageResponse): (Data, URLResponse)
        do {
            (imageData, imageResponse) = try await session.data(from: imageURL)
        } catch {
            throw ImageGenError.networkFailure(provider: .dashscope, underlying: error)
        }
        guard let imageHTTP = imageResponse as? HTTPURLResponse,
              (200..<300).contains(imageHTTP.statusCode) else {
            throw ImageGenError.emptyResponse(provider: .dashscope)
        }
        guard !imageData.isEmpty else {
            throw ImageGenError.emptyResponse(provider: .dashscope)
        }

        let contentType = (imageHTTP.value(forHTTPHeaderField: "Content-Type")) ?? "image/png"
        return ImageGenResponse(imageData: imageData, contentType: contentType, sourceURL: imageURL)
    }
}