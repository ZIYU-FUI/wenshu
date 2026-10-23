//
//  Features/Cover/Service/CoverImageGenerator.swift
//
//   : CoverImageGenerator.
//  The one HTTP call that draws a cover.
//
//  The endpoint and its contract, both verified against the live
//  MiniMax API on 2026-10-22:
//
//  - POST https://api.minimaxi.com/v1/image_generation
//  - auth: "Authorization: Bearer <key>". The minimax-cn provider
//    profile's authHeader is .xApiKey, because the CHAT endpoint
//    wants that; the IMAGE endpoint is a different service on the
//    same domain and wants Bearer. So the header is set explicitly
//    here and the provider profile's authHeader is NOT reused.
//  - the URL is the literal absolute string. The provider's
//    defaultBaseURL is https://api.minimaxi.com/anthropic, which is
//    the Anthropic-compatible chat host, so the base URL cannot be
//    used to build this URL.
//  - body: {model, prompt, width, height, n, response_format,
//    prompt_optimizer}. The model is "image-01": the variant that
//    carries a native style parameter ("image-01-live") refuses
//    width and height outright, so the size cannot be controlled with
//    it.
//  - width and height must BOTH be at least 512. A banner-shaped
//    request of 752x304 is rejected with "invalid params, height must
//    be between [512,2048]". The request is therefore 1024x512 and
//    the crop to the stored 768x320 is local.
//  - the response is HTTP 200 even for a failure, with a non-zero
//    base_resp.status_code inside the body, and the picture arrives
//    as data.image_base64 = an ARRAY of base64 strings, each a JPEG.
//

import Foundation
import WenshuAgent

/// The image call, behind a protocol.
///
/// The protocol exists so the generation service can be tested
/// WITHOUT a network call: a stub replaces the real client, and the
/// service's rules (= one call per card, a failed generation keeps
/// the old picture) are then testable in isolation.
protocol CoverImageClient: Sendable {
    /// Draws one cover and returns the raw image bytes.
    func generateCover(subject: String) async throws -> Data
}

/// Draws a cover with an image model.
struct CoverImageGenerator: CoverImageClient {

    /// The image endpoint. Absolute, because the provider profile's
    /// base URL is the chat host.
    static let endpoint = "https://api.minimaxi.com/v1/image_generation"

    /// The model that can be sized.
    static let model = "image-01"

    /// The requested size. The endpoint's minimum is 512 on both
    /// sides; the stored banner is cropped to 768x320 locally.
    static let requestWidth = 1024
    static let requestHeight = 768

    /// The provider whose key and quota pay for a cover. Resolved
    /// through the public `Provider.by(slug:)` accessor, because the
    /// provider catalogue in the agent package is not re-exported to
    /// the app layer.
    static let providerSlug = "minimax-cn"

    /// The provider profile for the cover service.
    static var provider: Provider {
        Provider.by(slug: providerSlug) ?? .minimaxCn
    }

    /// Draws one cover.
    ///
    /// - Parameter subject: what the picture should show. The art
    ///   direction is prepended by the caller.
    /// - Returns: the raw JPEG bytes the model returned.
    func generateCover(subject: String) async throws -> Data {
        guard let key = ProviderKeychain.loadKeySync(for: Self.provider), !key.isEmpty else {
            throw CoverImageError.missingKey(Self.provider.slug)
        }

        var request = URLRequest(url: URL(string: Self.endpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "model": Self.model,
            "prompt": subject,
            "width": Self.requestWidth,
            "height": Self.requestHeight,
            "n": 1,
            "response_format": "base64",
            "prompt_optimizer": false,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw CoverImageError.httpStatus(http.statusCode)
        }

        let payload = try JSONDecoder().decode(CoverImageResponse.self, from: data)
        guard payload.baseResp.statusCode == 0 else {
            throw CoverImageError.providerRejected(
                statusCode: payload.baseResp.statusCode,
                message: payload.baseResp.statusMessage
            )
        }
        guard let encoded = payload.data?.imageBase64?.first, let decoded = Data(base64Encoded: encoded) else {
            throw CoverImageError.noImage
        }
        return decoded
    }
}

/// The image endpoint's response shape.
private struct CoverImageResponse: Decodable {
    struct BaseResp: Decodable {
        let statusCode: Int
        let statusMessage: String?

        enum CodingKeys: String, CodingKey {
            case statusCode = "status_code"
            case statusMessage = "status_msg"
        }
    }

    struct DataPayload: Decodable {
        let imageBase64: [String]?

        enum CodingKeys: String, CodingKey {
            case imageBase64 = "image_base64"
        }
    }

    let baseResp: BaseResp
    let data: DataPayload?

    enum CodingKeys: String, CodingKey {
        case baseResp = "base_resp"
        case data
    }
}

/// The failures the image call can raise.
enum CoverImageError: LocalizedError {
    case missingKey(String)
    case httpStatus(Int)
    case providerRejected(statusCode: Int, message: String?)
    case noImage

    var errorDescription: String? {
        switch self {
        case .missingKey(let slug):
            return "No API key is configured for \(slug), so a cover cannot be drawn."
        case .httpStatus(let code):
            return "The image service answered with HTTP \(code)."
        case .providerRejected(let statusCode, let message):
            return "The image service refused the request (\(statusCode)): \(message ?? "no reason given")."
        case .noImage:
            return "The image service answered without a picture."
        }
    }
}
