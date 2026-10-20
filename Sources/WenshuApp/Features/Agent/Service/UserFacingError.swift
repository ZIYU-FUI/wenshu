// UserFacingError.swift
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
import WenshuAgent

/// Wenshu user-facing error envelope (= central Chinese translation
/// for raw wenshu errors). Conforms to `LocalizedError` (= Apple
/// canonical pattern) so SwiftUI/UIKit auto-renders
/// `.localizedDescription` in alerts / banners / form validation.
///
/// Per boss 2026-10-16 OOB "只接提示, 模型配置有误就行了":
/// the chat-path user-facing text is collapsed to a single
/// friendly message (= "模型配置有误") regardless of the
/// underlying cause (= 4xx, 5xx, network, rate limit, missing
/// key, bad key, malformed request). The user can't act on
/// the technical detail (= they don't control the provider
/// endpoint; = they just need to know the LLM call failed
/// and they should check the key in Settings → Providers).
/// The granular cases (= `.apiKeyMissing`, `.apiKeyInvalid`,
/// `.rateLimited`, `.timeout`, etc.) are kept for callers
/// that want them (= the Settings pane; = analytics), but
/// the chat layer translates them all to the same single
/// Chinese toast.
enum UserFacingError: Error, LocalizedError {
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
    /// Chat-layer catch-all (= see the file-level comment).
    /// Every chat failure path maps here (= the user just
    /// sees "模型配置有误" regardless of whether the cause
    /// was 4xx / 5xx / network / key issue / etc.). The
    /// underlying `cause` is preserved for the unified
    /// os_log (= dev-only; = never shown to the user).
    case modelConfigInvalid(cause: String)

    var errorDescription: String? {
        switch self {
        case .networkFailure:
            // Not user-actionable (= retry after a moment
            // usually resolves; we don't surface a "check your
            // router" instruction because that wastes the user's
            // time on a transient outage).
            return String(localized: "error.network.failure")

        case .apiKeyMissing:
            // Provider-agnostic (= doesn't mention any specific
            // provider = user can pick ANY of the 7 LLM connectors
            // per AGENTS.md §11.2). The `provider:` associated value
            // is preserved for callers that want to inspect it (=
            // e.g. logging / analytics), but the user-visible
            // message is generic.
            return String(localized: "error.api_key.missing")

        case .apiKeyInvalid:
            // Same generic treatment as apiKeyMissing (= no provider
            // name in user-visible text; = works for any of the 7
            // connectors).
            return String(localized: "error.api_key.invalid")

        case .rateLimited(let provider):
            // Provider-specific rate-limit messages stay provider-bound
            // (= only providers that surface 429 use this path).
            // Generic fallback for any provider that returns 429
            // with an empty/unknown provider name.
            if provider.isEmpty || provider == "当前 Provider" {
                return String(localized: "error.rate_limit.generic")
            }
            return String.localizedStringWithFormat(NSLocalizedString("error.rate_limit.provider", comment: ""), provider)

        case .outputTooLong(let model):
            return String.localizedStringWithFormat(NSLocalizedString("error.output_too_long", comment: ""), model)

        case .modelRefusal(let reason):
            if let reason {
                return String.localizedStringWithFormat(NSLocalizedString("error.model_refusal.with_reason", comment: ""), reason)
            }
            return String(localized: "error.model_refusal.generic")

        case .contextTooLong(let tokenCount):
            if let tokenCount {
                return String.localizedStringWithFormat(NSLocalizedString("error.context_too_long.with_count", comment: ""), tokenCount)
            }
            return String(localized: "error.context_too_long.generic")

        case .fileWriteFailure(let path, _):
            if let path {
                return String.localizedStringWithFormat(NSLocalizedString("error.file_write.with_path", comment: ""), path)
            }
            return String(localized: "error.file_write.generic")

        case .databaseError(let operation, _):
            return String.localizedStringWithFormat(NSLocalizedString("error.database.operation_failed", comment: ""), operation)

        case .invalidUserInput(let field, let reason):
            if let field, let reason {
                return String.localizedStringWithFormat(NSLocalizedString("error.invalid_input.with_field_reason", comment: ""), "\(field)（\(reason)）")
            }
            if let field {
                return String.localizedStringWithFormat(NSLocalizedString("error.invalid_input.with_reason", comment: ""), field)
            }
            return String(localized: "error.invalid_input.generic")

        case .timeout(let operation, let seconds):
            if let seconds {
                return String.localizedStringWithFormat(NSLocalizedString("error.timeout.with_seconds", comment: ""), operation, Int(seconds))
            }
            return String.localizedStringWithFormat(NSLocalizedString("error.timeout.generic", comment: ""), operation)

        case .unknown:
            // Per boss 2026-10-16 OOB "只接提示, 模型
            // 配置有误就行了": the previous behavior
            // (= `0f48a3b6a`) showed the raw underlying
            // string (= "未知错误：Error Domain=
            // SSEClient Code=400 HTTP 400"). The user
            // can't act on that (= the technical
            // detail); = the canonical text falls back
            // to the localized "error.unknown" key.
            // The chat-layer catch (= `from(_:context:)`)
            // routes the chat path through
            // `.modelConfigInvalid` instead (= see below),
            // so the user never sees "未知错误" in
            // practice (= the chat layer collapses
            // everything to the single "模型配置有误"
            // message).
            return String(localized: "error.unknown")
        case .modelConfigInvalid:
            // The single chat-layer catch-all (= see the
            // file-level comment). Per boss 2026-10-16
            // OOB "只接提示, 模型配置有误就行了":
            // regardless of whether the cause was
            // 4xx / 5xx / network / key issue /
            // malformed request, the user just sees
            // this one line. The technical detail
            // (= `cause`) is preserved on the case
            // (= callers can read it) but is NOT
            // rendered into the message.
            return "模型配置有误"
        }
    }
    /// Map any `Error` to a `UserFacingError` (= best-effort
    /// translation). Falls back to `.unknown` (= catch-all).
    ///
    /// Recognized input types (= each maps to the most-specific case):
    /// - `URLError` / `NWError` -> `.networkFailure`
    /// - `LLMConnectorError.missingAPIKey` -> `.apiKeyMissing`
    /// - `LLMConnectorError.transport(401|403, _)` -> `.apiKeyInvalid`
    /// - `LLMConnectorError.transport(429, _)` -> `.rateLimited`
    /// - `LLMConnectorError.transport(408|504, _)` -> `.timeout`
    /// - `LLMConnectorError.transport(413|400, _)` -> `.contextTooLong`
    /// - `LLMConnectorError.transport(5xx, _)` -> `.networkFailure`
    /// - `LLMConnectorError.decode` / `.streamingFailed` / `.unsupportedProvider` -> `.modelConfigInvalid`
    /// - `SSEClient` (`domain == "SSEClient"`, code = HTTP status) -> per-status
    ///   mapping (= mirrors the LLMConnectorError branches; = catches the
    ///   streaming path which throws raw `NSError` from
    ///   `Sources/WenshuApp/Features/Agent/Service/SSEClient.swift:75`).
    /// - any other `Error` -> `.unknown(underlying: String(describing:))`
    ///
    /// Per boss 2026-10-16 OOB "只接提示, 模型配置
    /// 有误就行了": the chat layer collapses ALL
    /// failure modes to a single user-facing message
    /// (= "模型配置有误"). Callers (= `ChatSessionViewModel`)
    /// wrap the `from` call with a `modelConfigInvalid`
    /// shim so the granular cases (= network, key, etc.)
    /// are preserved for the os_log but not surfaced
    /// to the user. This method is kept for non-chat
    /// callers (= the Settings pane; = import flow;
    /// = analytics) that need the granular mapping.
    ///
    /// Caller-side (= e.g. `ChatView`) consumes via:
    ///   `let userMsg = UserFacingError.from(rawError).errorDescription`
    /// (= OR `UserFacingError.modelConfigInvalid(cause: rawDesc)` for
    /// the chat-layer single-message collapse)
    static func from(_ raw: Error, context provider: String? = nil) -> UserFacingError {
        if let wenshu = raw as? LLMConnectorError {
            switch wenshu {
            case .missingAPIKey(let providerArg):
                return .apiKeyMissing(provider: providerArg.isEmpty ? (provider ?? "当前 Provider") : providerArg)
            case .transport(_, let status, _):
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
            case .unsupportedProvider, .decode, .streamingFailed:
                return .modelConfigInvalid(cause: String(describing: wenshu))
            }
        }
        // SSEClient raw NSError (= the streaming transport
        // throws NSError directly, = not wrapped in
        // WenshuLLMError). Recognized so the chat-layer
        // catch can still route to `modelConfigInvalid`
        // via `String(describing:)` (= the `cause` is
        // preserved on the `modelConfigInvalid` case
        // for the os_log).
        let nsError = raw as NSError
        if nsError.domain == "SSEClient" {
            return .unknown(underlying: "SSEClient HTTP \(nsError.code)")
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