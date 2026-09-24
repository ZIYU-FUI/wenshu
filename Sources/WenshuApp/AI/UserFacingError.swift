// UserFacingError.swift · Wenshu · v0.34
//
// `UserFacingError` is the single source of truth for mapping raw
// wenshu errors to Chinese user-facing text. Callers use either:
// 1. `UserFacingError.from(rawError)` (= translates any Error to
//    a localized message)
// 2. `UserFacingError.someCase` (= explicit case constructors
//    for typed call sites)
//
// Apple-API-first check: Swift `LocalizedError` (= Foundation
// built-in; no third-party dependency). Each case returns a
// `errorDescription: String?` (= SwiftUI + UIKit consume
// automatically via `.localizedDescription`).
//
// Coverage (= 12 cases = single-source-of-truth paths):

// 1. networkFailure
// 2. apiKeyMissing
// 3. apiKeyInvalid
// 4. rateLimited
// 5. outputTooLong
// 6. modelRefusal
// 7. contextTooLong
// 8. fileWriteFailure
// 9. databaseError
// 10. invalidUserInput
// 11. timeout
// 12. unknown (= catch-all fallback)

import Foundation

/// Wenshu user-facing error envelope (= central Chinese translation
/// for raw wenshu errors). Conforms to `LocalizedError` (= Apple
/// canonical pattern) so SwiftUI/UIKit auto-renders
/// `.localizedDescription` in alerts / banners / form validation.
public enum UserFacingError: Error, LocalizedError {
    case networkFailure(underlying: String? = nil)
    case apiKeyMissing(provider: String)
    case apiKeyInvalid(provider: String)
    case rateLimited(provider: String)
    case outputTooLong(model: String)
    case modelRefusal(reason: String? = nil)
    case contextTooLong(tokenCount: Int? = nil)
    case fileWriteFailure(path: String? = nil, underlying: String? = nil)
    case databaseError(operation: String, underlying: String? = nil)
    case invalidUserInput(field: String? = nil, reason: String? = nil)
    case timeout(operation: String, seconds: Double? = nil)
    case unknown(underlying: String? = nil)

    public var errorDescription: String? {
        switch self {
        case .networkFailure:
            // Not user-actionable (= retry after a moment
            // usually resolves; we don't surface a "check your
            // router" instruction because that wastes the user's
            // time on a transient outage).
            return "网络断开，请检查连接后重试。"

        case .apiKeyMissing:
            // Provider-agnostic (= doesn't mention any specific
            // provider = user can pick ANY of the 7 LLM connectors
            // per AGENTS.md §11.2). The `provider:` associated value
            // is preserved for callers that want to inspect it (=
            // e.g. logging / analytics), but the user-visible
            // message is generic.
            return "未配置 LLM API 密钥。请前往 设置 → 服务配置 任选一个 LLM 连接器 (= Anthropic / OpenAI / DeepSeek / Gemini / Ollama / OpenRouter / MiniMax) 填写。"

        case .apiKeyInvalid:
            // Same generic treatment as apiKeyMissing (= no provider
            // name in user-visible text; = works for any of the 7
            // connectors).
            return "LLM API 密钥无效或已过期。请前往 设置 → 服务配置 更新您的连接器密钥。"

        case .rateLimited(let provider):
            // Provider-specific rate-limit messages stay provider-bound
            // (= only providers that surface 429 use this path).
            // Generic fallback for any provider that returns 429
            // with an empty/unknown provider name.
            if provider.isEmpty || provider == "当前 Provider" {
                return "LLM 限流中，请稍后再试。"
            }
            return "\(provider) 限流中，请稍后再试。"

        case .outputTooLong(let model):
            return "本次输出超过 \(model) 的长度上限，模型已自动截断。请缩小输入或拆分为多次请求。"

        case .modelRefusal(let reason):
            if let reason {
                return "模型拒绝生成：\(reason)。请修改输入后重试。"
            }
            return "模型拒绝生成。请修改输入后重试。"

        case .contextTooLong(let tokenCount):
            if let tokenCount {
                return "对话上下文超过模型限制（当前约 \(tokenCount) tokens）。请开启新对话或精简历史。"
            }
            return "对话上下文超过模型限制。请开启新对话或精简历史。"

        case .fileWriteFailure(let path, _):
            if let path {
                return "文件写入失败：\(path)。请检查磁盘空间或文件权限。"
            }
            return "文件写入失败。请检查磁盘空间或文件权限。"

        case .databaseError(let operation, _):
            return "数据库 \(operation) 失败。请重试或重启应用。"

        case .invalidUserInput(let field, let reason):
            if let field {
                return "输入无效：\(field)\(reason.map { "（\($0)" } ?? "")"
            }
            return "输入无效，请检查后重试。"

        case .timeout(let operation, let seconds):
            if let seconds {
                return "\(operation) 超时（\(Int(seconds)) 秒）。请稍后重试。"
            }
            return "\(operation) 超时。请稍后重试。"

        case .unknown:
            return "未知错误，请稍后重试或重启应用。"
        }
    }
    /// Map any `Error` to a `UserFacingError` (= best-effort
    /// translation). Falls back to `.unknown` (= catch-all).
    ///
    /// Recognized input types (= each maps to the most-specific case):
    /// - `URLError` / `NWError` -> `.networkFailure`
    /// - `WenshuLLMError.missingAPIKey` -> `.apiKeyMissing`
    /// - `WenshuLLMError.invalidBaseURL` -> `.apiKeyInvalid`
    /// - `WenshuLLMError.httpError(429, _)` -> `.rateLimited`
    /// - `WenshuLLMError.httpError(401|403, _)` -> `.apiKeyInvalid`
    /// - `WenshuLLMError.httpError(408|504, _)` -> `.timeout`
    /// - `WenshuLLMError.httpError(413|400, _)` -> `.contextTooLong`
    /// - `WenshuLLMError.httpError(5xx, _)` -> `.networkFailure`
    /// - any other `Error` -> `.unknown(underlying: String(describing:))`
    ///
    /// Caller-side (= e.g. `ChatView`) consumes via:
    ///   `let userMsg = UserFacingError.from(rawError).errorDescription`
    public static func from(_ raw: Error, context provider: String? = nil) -> UserFacingError {
        if let wenshu = raw as? WenshuLLMError {
            switch wenshu {
            case .missingAPIKey:
                return .apiKeyMissing(provider: provider ?? "当前 Provider")
            case .invalidBaseURL:
                return .apiKeyInvalid(provider: provider ?? "当前 Provider")
            case .httpError(let status, _):
                switch status {
                case 401, 403:
                    return .apiKeyInvalid(provider: provider ?? "当前 Provider")
                case 408, 504:
                    return .timeout(operation: "LLM 调用", seconds: nil)
                case 413, 400:
                    return .contextTooLong()
                case 429:
                    return .rateLimited(provider: provider ?? "当前 Provider")
                case 500..<600:
                    return .networkFailure(underlying: "HTTP \(status)")
                default:
                    return .unknown(underlying: "HTTP \(status)")
                }
            }
        }
        if let urlErr = raw as? URLError {
            return .networkFailure(underlying: urlErr.localizedDescription)
        }
        if let _ = raw as? DecodingError {
            return .databaseError(operation: "解码", underlying: String(describing: raw))
        }
        if raw is CancellationError {
            return .unknown(underlying: "已取消")
        }
        return .unknown(underlying: String(describing: raw))
    }
}