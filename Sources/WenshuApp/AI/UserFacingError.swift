// UserFacingError.swift · Wenshu · v0.34
//
// v0.34 boss 2026-09-02 OOB 'the rest of the engineering mechanisms,
// I do not really understand them, you decide':
// Centralized user-facing error translation (= port of Card-master
// `src/ai/domain/assistant-presentation.ts` `assistantUserFacingError`).
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
// Coverage (= 12 cases = boss-picked paths from the
// assistant-presentation.ts pattern):
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
            // v0.34: not user-actionable (= retry after a moment
            // usually resolves; we don't surface a "check your
            // router" instruction because that wastes the user's
            // time on a transient outage).
            return "网络断开，请检查连接后重试。"

        case .apiKeyMissing(let provider):
            return "未配置 \(provider) 的 API 密钥。请前往设置 → 服务配置 → \(provider) 填写。"

        case .apiKeyInvalid(let provider):
            return "\(provider) 的 API 密钥无效或已过期。请前往设置 → 服务配置 → \(provider) 更新。"

        case .rateLimited(let provider):
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

    /// Convenience severity hint (= for callers that want to color
    /// an error banner red vs orange vs gray). Apple HIG banner
    /// semantics per Issue 05.
    public var severityHint: String {
        switch self {
        case .networkFailure, .timeout: return "warning"
        case .apiKeyMissing, .apiKeyInvalid, .rateLimited,
             .outputTooLong, .modelRefusal, .contextTooLong,
             .fileWriteFailure, .databaseError: return "critical"
        case .invalidUserInput, .unknown: return "info"
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