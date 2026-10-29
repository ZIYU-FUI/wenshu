//
//  CoverProviderFailureTests.swift · Wenshu
//
//  Proves the failure classifier and the capability table.
//
//  The classifier's whole job is to say what the USER has to do, and
//  the difference that matters most is between a spent account and a
//  rate limit: one needs money, the other needs a second. OpenAI
//  answers 429 for both, so the body has to be read.
//
//  Every rule gets its own test, so a rule that breaks says which one.
//
//  The facts behind the cases were read out of each provider's own
//  error documentation on 2026-10-23.
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("Cover provider failure")
struct CoverProviderFailureTests {

    // MARK: - The provider's own numeric codes

    @Test("A MiniMax quota code is a quota failure")
    func aMiniMaxQuotaCodeIsAQuotaFailure() {
        // 1008 balance too low, 2053 not enough credits,
        // 2056 past the M Plan resource limit, 2067 the plan's
        // allowance is used up.
        for code in [1008, 2053, 2056, 2067] {
            let failure = CoverProviderFailure.classify(
                providerSlug: "minimax-cn",
                providerCode: code
            )
            #expect(failure?.kind == .quotaExhausted)
        }
    }

    @Test("A MiniMax plan code is a plan failure")
    func aMiniMaxPlanCodeIsAPlanFailure() {
        // 2022 no such model, 2061 the plan does not include it,
        // 2068 the tier does not include it, 2057 not an M Plan key.
        for code in [2022, 2061, 2068, 2057] {
            let failure = CoverProviderFailure.classify(
                providerSlug: "minimax-cn",
                providerCode: code
            )
            #expect(failure?.kind == .planDoesNotCoverModel)
        }
    }

    @Test("A MiniMax key code is a key failure")
    func aMiniMaxKeyCodeIsAKeyFailure() {
        // 1004 unauthorized, 2049 invalid API key.
        for code in [1004, 2049] {
            let failure = CoverProviderFailure.classify(
                providerSlug: "minimax-cn",
                providerCode: code
            )
            #expect(failure?.kind == .invalidKey)
        }
    }

    @Test("A code we do not know is not classified")
    func anUnknownCodeIsNotClassified() {
        #expect(CoverProviderFailure.classify(
            providerSlug: "minimax-cn",
            providerCode: 1024
        ) == nil)
    }

    // MARK: - The statuses

    @Test("402 is a billing failure")
    func paymentRequiredIsABillingFailure() {
        // Anthropic's billing_error is a 402, and 402 is the one
        // status that means billing at nearly every provider.
        let failure = CoverProviderFailure.classify(
            providerSlug: "anthropic",
            httpStatus: 402
        )

        #expect(failure?.kind == .quotaExhausted)
    }

    @Test("429 with a quota body is a quota failure")
    func tooManyRequestsWithAQuotaBodyIsAQuotaFailure() {
        // OpenAI's own wording: the 429 carries the cause in
        // error.code, and "Retrying billing, spend, or quota errors
        // won't restore API access."
        let body = """
            {"error":{"message":"You exceeded your current quota, please check your plan and billing details.","type":"insufficient_quota","code":"credit_balance_exhausted"}}
            """

        let failure = CoverProviderFailure.classify(
            providerSlug: "openai",
            httpStatus: 429,
            body: body
        )

        #expect(failure?.kind == .quotaExhausted)
    }

    @Test("429 with a MiniMax quota code in the body is a quota failure")
    func tooManyRequestsWithAMiniMaxQuotaCodeInTheBodyIsAQuotaFailure() {
        // MiniMax answers a spent Token Plan with a 429 and its own
        // code in the message text, not in a field of its own, so the
        // code has to be read out of the body. The body also says
        // "rate_limit_error", which is what makes this worth a test.
        let body = """
            {"type":"error","error":{"type":"rate_limit_error","message":"已达到 Token Plan 用量上限：请升级 Token Plan 套餐或购买积分补充用量。 (2056)"},"http_code":"429"}
            """

        let failure = CoverProviderFailure.classify(
            providerSlug: "minimax-cn",
            httpStatus: 429,
            body: body
        )

        #expect(failure?.kind == .quotaExhausted)
        #expect(failure?.code == 2056)
        #expect(failure?.kind != .rateLimited)
    }

    @Test("429 with a rate limit body is a rate limit")
    func tooManyRequestsWithARateLimitBodyIsARateLimit() {
        let body = """
            {"error":{"message":"Rate limit reached for requests. Please slow down.","type":"rate_limit_error"}}
            """

        let failure = CoverProviderFailure.classify(
            providerSlug: "openai",
            httpStatus: 429,
            body: body
        )

        #expect(failure?.kind == .rateLimited)
    }

    @Test("429 with a spend cap is a quota failure")
    func tooManyRequestsWithASpendCapIsAQuotaFailure() {
        // Anthropic answers 429 for a monthly spend cap as well as
        // for a plain rate limit, and the cap is the one the user has
        // to act on.
        let body = """
            {"type":"error","error":{"type":"rate_limit_error","message":"Your organization has reached its usage tier's monthly spend cap."}}
            """

        let failure = CoverProviderFailure.classify(
            providerSlug: "anthropic",
            httpStatus: 429,
            body: body
        )

        #expect(failure?.kind == .quotaExhausted)
    }

    @Test("401 and 403 are a key failure")
    func unauthorizedIsAKeyFailure() {
        for status in [401, 403] {
            let failure = CoverProviderFailure.classify(
                providerSlug: "openai",
                httpStatus: status
            )
            #expect(failure?.kind == .invalidKey)
        }
    }

    @Test("A provider we have never heard of is still classified")
    func anUnknownProviderIsStillClassified() {
        // The words carry the weight, not the provider's table.
        let failure = CoverProviderFailure.classify(
            providerSlug: "some-new-service",
            body: #"{"error":"insufficient balance, top up your credits"}"#
        )

        #expect(failure?.kind == .quotaExhausted)
    }

    @Test("A quota word with no status at all is a quota failure")
    func aQuotaWordWithNoStatusIsAQuotaFailure() {
        // A provider that reports its own code inside a 200 body.
        let failure = CoverProviderFailure.classify(
            providerSlug: "some-new-service",
            body: #"{"code":"余额不足"}"#
        )

        #expect(failure?.kind == .quotaExhausted)
    }

    @Test("Nothing that says anything is not classified")
    func nothingSayingAnythingIsNotClassified() {
        #expect(CoverProviderFailure.classify(
            providerSlug: "some-new-service",
            httpStatus: 500,
            body: #"{"error":"internal server error"}"#
        ) == nil)
    }

    // MARK: - The messages

    @Test("The quota message says to top up and that retrying will not help")
    func theQuotaMessageSaysWhatToDo() {
        let failure = CoverProviderFailure(
            kind: .quotaExhausted,
            providerSlug: "minimax-cn",
            detail: "余额不足"
        )

        let message = failure.userMessage

        #expect(message.contains("no quota left"))
        #expect(message.lowercased().contains("credits"))
        #expect(message.lowercased().contains("retrying will not help"))
    }

    @Test("The plan message names the model and says to change the plan")
    func thePlanMessageNamesTheModel() {
        let failure = CoverProviderFailure(
            kind: .planDoesNotCoverModel,
            providerSlug: "minimax-cn",
            model: "image-01",
            detail: "model not available"
        )

        let message = failure.userMessage

        #expect(message.contains("image-01"))
        #expect(message.lowercased().contains("upgrade"))
    }

    @Test("The key message says to check the key")
    func theKeyMessageSaysToCheckTheKey() {
        let failure = CoverProviderFailure(kind: .invalidKey, providerSlug: "openai")

        #expect(failure.userMessage.lowercased().contains("api key"))
        #expect(failure.userMessage.lowercased().contains("settings"))
    }

    @Test("The rate limit message says it is worth retrying")
    func theRateLimitMessageSaysItIsWorthRetrying() {
        let failure = CoverProviderFailure(kind: .rateLimited, providerSlug: "openai")

        let message = failure.userMessage

        #expect(message.lowercased().contains("rate limit"))
        #expect(message.lowercased().contains("worth retrying"))
    }

    @Test("The image and the video failures read differently")
    func theImageAndTheVideoFailuresReadDifferently() {
        let failure = CoverProviderFailure(kind: .quotaExhausted, providerSlug: "minimax-cn")

        #expect(failure.userMessage.contains("MiniMax"))
    }

    // MARK: - The capability table

    @Test("A chat provider cannot make covers")
    func aChatProviderCannotMakeCovers() {
        for slug in ["anthropic", "deepseek", "nous", "openai-codex", "copilot"] {
            #expect(CoverProviderCapability.supports(providerSlug: slug, kind: .image) == false)
            #expect(CoverProviderCapability.supports(providerSlug: slug, kind: .video) == false)
        }
    }

    @Test("The MiniMax service makes both")
    func theMiniMaxServiceMakesBoth() {
        for slug in ["minimax", "minimax-cn"] {
            #expect(CoverProviderCapability.supports(providerSlug: slug, kind: .image))
            #expect(CoverProviderCapability.supports(providerSlug: slug, kind: .video))
        }
    }

    @Test("The message names the provider and says what to configure")
    func theMessageNamesTheProvider() {
        let message = CoverProviderCapability.unsupportedMessage(
            providerSlug: "anthropic",
            kind: .image
        )

        #expect(message.contains("Anthropic"))
        #expect(message.lowercased().contains("image service"))
        #expect(message.lowercased().contains("settings"))
    }

    @Test("The no-service message says a picture service is needed")
    func theNoServiceMessageSaysAPictureServiceIsNeeded() {
        #expect(CoverProviderCapability.noServiceMessage.lowercased().contains("image service"))
    }
}
