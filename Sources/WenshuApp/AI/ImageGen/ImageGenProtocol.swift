// ImageGenProtocol.swift · Wenshu (文枢) · v0.34
//
// v0.34 boss 2026-09-02 OOB '我在让卡片缩略图, 有内容可以显示':
// Image generation provider abstraction (= port of Card-master
// `src/ai/domain/image-generation-protocol.ts` + `image-generation-protocol-registry.ts`).
//
// Each provider (DashScope / OpenAI / future Apple `ImageCreator`)
// implements `ImageGenProvider` with the same surface (= send prompt
// -> receive image bytes). `ImageGenService` picks the active
// provider from the registry, retries with a fallback on failure,
// and writes the resulting WebP bytes to the cache via `CacheManager`.
//
// Apple-API-first check: `URLSession.data(for:)` is the only Apple
// API needed; no third-party HTTP client required. Response data is
// raw bytes (= not JSON-encoded for image gen APIs = direct binary
// payload from DashScope / OpenAI image endpoints).

import Foundation

/// Provider identifier (= which AI image generation backend is active).
/// Per boss Q34 grill recommendation: DashScope primary, OpenAI
/// fallback. Future expansion: Apple `ImageCreator` (= macOS 27
/// on-device Stable Diffusion fallback = no API key, no network).
enum ImageGenProviderID: String, Codable, Sendable, CaseIterable {
    case dashscope = "dashscope"
    case openai = "openai"

    /// User-facing Chinese label (= boss 8/25 'UI 全中文' rule).
    var displayName: String {
        switch self {
        case .dashscope: return "阿里 DashScope"
        case .openai:    return "OpenAI DALL-E"
        }
    }
}

/// Request to an image generation provider. Built by `ImageGenService`
/// (= caller does not construct this directly).
struct ImageGenRequest: Sendable {
    /// English prompt sent to the image gen API. Derived from the
    /// reference's title + summary + entity category (= e.g. "An
    /// illustration of a Ming-dynasty scholar writing at a desk,
    /// ink wash painting style").
    let prompt: String

    /// Output image dimensions (= small to keep .ws library size
    /// bounded per boss 2026-09-02 OOB '生成图片的尺寸要控制一下,
    /// 我们的卡片不大, 不要搞成很大的图, 增加 .ws 库文件的尺寸').
    /// Default = 256x192 (= 4:3 aspect, retina @ 2x = 128x96 PT = fits
    /// a single card thumbnail; ~1/16 the area of 1024x768).
    /// Apple HIG: small output images are sharper on retina than
    /// downscaled large images (= less aliasing).
    let width: Int
    let height: Int

    /// JPEG quality (0.0-1.0). Default 0.7 (= ~15 KB at 256x192, vs
    /// ~200 KB for PNG at 1024x768 = ~13x smaller).
    /// v0.34 ImageGenService enforces a 30 KB ceiling (= if a request
    /// exceeds 30 KB, the service re-encodes at 0.5 quality).
    let quality: Double

    init(prompt: String, width: Int = 256, height: Int = 192, quality: Double = 0.7) {
        self.prompt = prompt
        self.width = width
        self.height = height
        self.quality = quality
    }
}

/// Response from an image generation provider. Raw image bytes
/// (= PNG = `Data`) + content type for cache write.
struct ImageGenResponse: Sendable {
    let imageData: Data
    let contentType: String
    /// Original URL the bytes were fetched from (= for audit /
    /// debugging; not surfaced to users).
    let sourceURL: URL
}

/// Error from an image generation provider (= translated to
/// `UserFacingError` in Issue 06).
enum ImageGenError: Error, LocalizedError {
    case apiKeyMissing(provider: ImageGenProviderID)
    case apiKeyInvalid(provider: ImageGenProviderID)
    case rateLimited(provider: ImageGenProviderID)
    case networkFailure(provider: ImageGenProviderID, underlying: Error)
    case badStatus(provider: ImageGenProviderID, status: Int, body: String)
    case emptyResponse(provider: ImageGenProviderID)
    case decodeFailure(provider: ImageGenProviderID, underlying: Error)

    var errorDescription: String? {
        switch self {
        case .apiKeyMissing(let p):   return "未配置 \(p.displayName) 的 API 密钥。请前往设置 → 服务配置 → 图像生成填写。"
        case .apiKeyInvalid(let p):   return "\(p.displayName) 的 API 密钥无效或已过期。"
        case .rateLimited(let p):     return "\(p.displayName) 限流中，请稍后再试。"
        case .networkFailure(let p, _): return "连接 \(p.displayName) 失败。请检查网络。"
        case .badStatus(let p, let s, _): return "\(p.displayName) 返回 HTTP \(s)。请稍后再试。"
        case .emptyResponse(let p):   return "\(p.displayName) 返回了空内容。"
        case .decodeFailure(let p, _): return "\(p.displayName) 响应解析失败。"
        }
    }
}

/// Protocol every image gen provider implements. `ImageGenService`
/// holds an array of these (= fallback chain: try primary, retry with
/// fallback if primary errors).
protocol ImageGenProvider: Sendable {
    var id: ImageGenProviderID { get }

    /// Synchronous API key presence check (= cheap, run at startup).
    /// Returns false if the API key is missing / empty in `ProviderKeychain`.
    var hasAPIKey: Bool { get }

    /// Send a generation request. Throws `ImageGenError` on any
    /// failure (= caller decides whether to retry with the fallback
    /// provider).
    func generate(_ request: ImageGenRequest) async throws -> ImageGenResponse
}