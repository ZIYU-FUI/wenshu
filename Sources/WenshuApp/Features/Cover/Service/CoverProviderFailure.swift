//
//  Features/Cover/Service/CoverProviderFailure.swift
//
//   : CoverProviderFailure.
//  A provider failure, named for what the user has to do about it.
//
//  A cover that cannot be made used to be reported in the provider's
//  own words, or in the app's, and neither of them said what the
//  user could DO. "The image service answered with HTTP 429" reads
//  like a broken program; "the account has no credits left" reads
//  like a bill.
//
//  So every provider failure is classified into a KIND, and the kind
//  decides the message. There are four kinds, and the difference
//  between them is what the reader does next:
//
//  - the quota is used up: add credits, then try again. Retrying
//    first does nothing, and OpenAI's own error page says so.
//  - the plan does not cover the model: pick another model, or
//    upgrade.
//  - the key is wrong: fix the key.
//  - the service is rate limiting: wait a moment and try again.
//    This one is worth retrying, and it says so.
//
//  The classifier is GENERAL. It works from three inputs (= the HTTP
//  status, the provider's own code, the provider's own body) and
//  three of its rules need no knowledge of the provider at all:
//
//  - 402 means the account's billing. It is the one status that
//    means billing at nearly every provider.
//  - 429 is AMBIGUOUS. OpenAI answers 429 for a credit balance, a
//    spend cap, a usage cap AND for a plain rate limit, and
//    Anthropic answers 429 for a rate limit AND for a monthly spend
//    cap. So 429 is decided by the body: a quota word makes it a
//    quota failure, and anything else is a rate limit.
//  - 401 and 403 mean the key.
//
//  A provider we have never heard of is therefore still classified
//  correctly, because the body carries the words. The numeric table
//  is one input among several, and it is keyed by provider, because
//  the same number means different things at different providers.
//
//  The tables below were read out of each provider's own error
//  documentation on 2026-10-23.
//

import Foundation
import WenshuAgent

/// A provider failure the user has to act on.
struct CoverProviderFailure: Equatable, Sendable {

    /// What the user has to do about it.
    enum Kind: Equatable, Sendable {
        /// The account has no quota or credits left.
        case quotaExhausted
        /// The account's plan does not include the model.
        case planDoesNotCoverModel
        /// The key is missing, wrong, or not accepted.
        case invalidKey
        /// The service is rate limiting right now.
        case rateLimited
    }

    /// A provider's own numeric codes, and what each group means.
    struct CodeTable: Sendable {
        /// The account has no quota or credits left.
        let quota: Set<Int>
        /// The plan does not include the model.
        let plan: Set<Int>
        /// The key is not accepted.
        let key: Set<Int>

        /// A code the provider's own table names.
        ///
        /// The table is the authority on what a number means, so a number
        /// it does not list (= a count, a version, a year) is not a code
        /// and must not be read as one.
        func knows(_ code: Int) -> Bool {
            quota.contains(code) || plan.contains(code) || key.contains(code)
        }
    }

    /// The numeric codes we know, keyed by provider.
    ///
    /// MiniMax's own error table, 2026-10-23:
    ///   1008 balance too low, 2053 not enough credits,
    ///   2056 past the M Plan resource limit,
    ///   2067 the plan's allowance is used up,
    ///   2022 no such model, 2061 the plan does not include it,
    ///   2068 the plan's tier does not include it,
    ///   2057 the key is not an M Plan key,
    ///   1004 unauthorized, 2049 invalid API key.
    static let codeTables: [String: CodeTable] = [
        "minimax": CodeTable(
            quota: [1008, 2053, 2056, 2067],
            plan: [2022, 2061, 2068, 2057],
            key: [1004, 2049]
        ),
        "minimax-cn": CodeTable(
            quota: [1008, 2053, 2056, 2067],
            plan: [2022, 2061, 2068, 2057],
            key: [1004, 2049]
        ),
    ]

    /// The words a body carries when the account has no quota.
    ///
    /// OpenAI's 429 body names the cause in `error.code`
    /// (= credit_balance_exhausted, organization_spend_limit_exceeded,
    /// project_spend_limit_exceeded, organization_usage_limit_exceeded)
    /// or in `error.type` (= insufficient_quota), and Anthropic's
    /// 429 body says "monthly spend cap". The Chinese words are
    /// there for the providers that answer in Chinese.
    static let quotaWords = [
        "insufficient_quota",
        "credit_balance_exhausted",
        "spend_limit_exceeded",
        "usage_limit_exceeded",
        "spend cap",
        "spend limit",
        "usage cap",
        "exceeded your current quota",
        "insufficient balance",
        "no prepaid credits",
        "payment required",
        "quota exceeded",
        "余额不足",
        "积分不足",
        "额度已用完",
        "配额不足",
        "token plan 用量上限",
    ]

    /// The words a body carries when the service is rate limiting.
    static let rateLimitWords = [
        "rate limit",
        "rate_limit",
        "too many requests",
        "slow down",
        "请求频率超限",
    ]

    /// The words a body carries when the plan does not cover the
    /// model.
    static let planWords = [
        "model_not_found",
        "does not have access to model",
        "no access to model",
        "plan does not support",
        "tier does not support",
        "not available for this plan",
        "模型不存在",
        "不支持该模型",
    ]

    /// The words a body carries when the key is not accepted.
    static let keyWords = [
        "invalid api key",
        "incorrect api key",
        "unauthorized",
        "authentication_error",
        "no api key provided",
        "invalid authentication",
        "无效的 api key",
        "未授权",
    ]

    /// What the user has to do about it.
    let kind: Kind

    /// The provider that failed.
    let providerSlug: String

    /// The model the call asked for, when it is known.
    let model: String?

    /// The provider's own code, when it sent one.
    let code: Int?

    /// The provider's own words, when it sent any.
    let detail: String?

    init(
        kind: Kind,
        providerSlug: String,
        model: String? = nil,
        code: Int? = nil,
        detail: String? = nil
    ) {
        self.kind = kind
        self.providerSlug = providerSlug
        self.model = model
        self.code = code
        self.detail = detail
    }

    /// The message the user reads.
    ///
    /// It names the provider, says what happened, and says what to
    /// do. The rate limit says it is worth retrying, because it is:
    /// the other three are not.
    var userMessage: String {
        let name = Self.displayName(for: providerSlug)
        let suffix = detail.map { " (\($0))" } ?? ""
        switch kind {
        case .quotaExhausted:
            return """
                The \(name) account has no quota left\(suffix). Add credits or upgrade the \
                plan, then try again: retrying will not help until the account is topped up.
                """
        case .planDoesNotCoverModel:
            let modelName = model.map { " The model \($0) is not on the plan." } ?? ""
            return """
                The \(name) plan does not cover this model.\(modelName)\(suffix) Choose a \
                model the plan includes, or upgrade the plan.
                """
        case .invalidKey:
            return """
                The \(name) service did not accept the API key\(suffix). Check the key in \
                Settings.
                """
        case .rateLimited:
            return """
                The \(name) service is rate limiting right now\(suffix). Wait a moment and \
                try again: this one is worth retrying.
                """
        }
    }

    /// The provider's name, for the message.
    static func displayName(for slug: String) -> String {
        Provider.by(slug: slug)?.name ?? slug
    }

    /// Classifies a provider failure.
    ///
    /// - Parameters:
    ///   - providerSlug: the provider that failed.
    ///   - httpStatus: the HTTP status, when the call got one.
    ///   - providerCode: the provider's own code, when it sent one
    ///     (MiniMax puts it in `base_resp.status_code`).
    ///   - body: the provider's own body, when it sent one. The
    ///     words in it are what decide an ambiguous status.
    ///   - detail: what the message should show. It defaults to the
    ///     body, but a provider that sends a short message beside its
    ///     body (= "insufficient balance") reads better with the
    ///     short one.
    ///   - model: the model the call asked for, when it is known.
    /// - Returns: the failure, or nil when nothing here says what
    ///   the user has to do.
    static func classify(
        providerSlug: String,
        httpStatus: Int? = nil,
        providerCode: Int? = nil,
        body: String? = nil,
        detail: String? = nil,
        model: String? = nil
    ) -> CoverProviderFailure? {
        let text = (body ?? "").lowercased()

        // The provider's own code, when the body carries it and the
        // caller passed none. MiniMax ends its refusal with the code
        // in parentheses, so the body is the only place the code is.
        // Only a code the provider's own table names is a code.
        let bodyCode: Int? = providerCode == nil
            ? codeTables[providerSlug.lowercased()].flatMap { table in
                guard let number = trailingCode(in: text), table.knows(number) else { return nil }
                return number
            }
            : nil

        let shown = detail ?? body.flatMap { $0.isEmpty ? nil : $0 }

        // 1. The provider's own numeric code, from the table we have
        //    for it.
        if let code = providerCode ?? bodyCode, let table = codeTables[providerSlug.lowercased()] {
            if table.quota.contains(code) {
                return CoverProviderFailure(kind: .quotaExhausted, providerSlug: providerSlug, model: model, code: code, detail: shown)
            }
            if table.plan.contains(code) {
                return CoverProviderFailure(kind: .planDoesNotCoverModel, providerSlug: providerSlug, model: model, code: code, detail: shown)
            }
            if table.key.contains(code) {
                return CoverProviderFailure(kind: .invalidKey, providerSlug: providerSlug, model: model, code: code, detail: shown)
            }
        }

        // 2. The words in the body, whatever the status. A provider
        //    that reports its own code inside a 200 body lands here.
        if let kind = kind(in: text) {
            return CoverProviderFailure(kind: kind, providerSlug: providerSlug, model: model, code: providerCode, detail: shown)
        }

        // 3. The statuses that mean the same thing everywhere.
        switch httpStatus {
        case 402:
            return CoverProviderFailure(kind: .quotaExhausted, providerSlug: providerSlug, model: model, code: providerCode, detail: shown)
        case 429:
            // 429 without a quota word is the plain rate limit.
            return CoverProviderFailure(kind: .rateLimited, providerSlug: providerSlug, model: model, code: providerCode, detail: shown)
        case 401, 403:
            return CoverProviderFailure(kind: .invalidKey, providerSlug: providerSlug, model: model, code: providerCode, detail: shown)
        default:
            return nil
        }
    }

    /// The kind the words in a body point at.
    ///
    /// The quota words come first: OpenAI's 429 body for a credit
    /// problem also says "rate limit" somewhere, and the quota is
    /// the one the user has to act on.
    static func kind(in text: String) -> Kind? {
        if quotaWords.contains(where: { text.contains($0) }) { return .quotaExhausted }
        if planWords.contains(where: { text.contains($0) }) { return .planDoesNotCoverModel }
        if keyWords.contains(where: { text.contains($0) }) { return .invalidKey }
        if rateLimitWords.contains(where: { text.contains($0) }) { return .rateLimited }
        return nil
    }

    /// The number the body writes in trailing parentheses.
    ///
    /// MiniMax ends its refusal with the code in parentheses, so the
    /// body is the only place the code is. The last such number in the
    /// body is the code.
    private static func trailingCode(in text: String) -> Int? {
        var found: Int?
        var cursor = text.startIndex
        while let open = text[cursor...].firstIndex(of: "(") {
            let afterOpen = text.index(after: open)
            var digitsEnd = afterOpen
            while digitsEnd < text.endIndex, text[digitsEnd].isASCII, text[digitsEnd].isNumber {
                digitsEnd = text.index(after: digitsEnd)
            }
            let spaced = open > text.startIndex && text[text.index(before: open)] == " "
            if digitsEnd > afterOpen,
               digitsEnd < text.endIndex,
               text[digitsEnd] == ")",
               spaced,
               let value = Int(text[afterOpen..<digitsEnd]) {
                found = value
            }
            cursor = afterOpen
        }
        return found
    }
}
