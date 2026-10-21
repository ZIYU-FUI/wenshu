//
//  ToolGuardrailsAndErrorClassifierTests.swift · Wenshu · v0.38 Batch 3 sub-step 2
//
//  Tests for ToolGuardrails + ErrorClassifier (= v0.36 ticket 015).
//
// Per cadence 2026-09-03 'resume' (= auto-pilot mode
// per 'ok' + ') + 'PO execute,
// don't' + '1 RULE 1 commit'.
//
//  Safe scope (= NOT v0.34 in-flight) = ToolGuardrails + ErrorClassifier
//  are v0.36 ticket 015 (= my work). Tests are additive coverage.
//

import Testing
import Foundation
import WenshuAgent
@testable import WenshuApp

@Suite("ToolGuardrails deep (= v0.36 ticket 015)")
struct ToolGuardrailsDeepTests {

    // MARK: - ToolNameWhitelist

    @Test("ToolNameWhitelist: empty by default")
    func whitelistEmptyByDefault() async {
        let whitelist = ToolNameWhitelist()
        let isEmpty = await whitelist.isEmpty
        #expect(isEmpty)
    }

    @Test("ToolNameWhitelist: set + contains")
    func whitelistSetAndContains() async {
        let whitelist = ToolNameWhitelist()
        await whitelist.set(["ReadFile", "WriteFile"])
        #expect(await whitelist.contains("ReadFile"))
        #expect(await whitelist.contains("WriteFile"))
        #expect(await whitelist.contains("Bash") == false)
    }

    @Test("ToolNameWhitelist: isEmpty = false after set")
    func whitelistNotEmptyAfterSet() async {
        let whitelist = ToolNameWhitelist()
        await whitelist.set(["ReadFile"])
        #expect(await whitelist.isEmpty == false)
    }

    @Test("ToolNameWhitelist: replace set clears previous")
    func whitelistReplace() async {
        let whitelist = ToolNameWhitelist()
        await whitelist.set(["ReadFile", "WriteFile"])
        await whitelist.set(["Bash"])
        #expect(await whitelist.contains("ReadFile") == false)
        #expect(await whitelist.contains("WriteFile") == false)
        #expect(await whitelist.contains("Bash"))
    }

    // MARK: - ToolGuardrailsResult

    @Test("ToolGuardrailsResult: pass has no reason")
    func resultPass() {
        let result = ToolGuardrailsResult.pass
        #expect(result.passed == true)
        #expect(result.reason == nil)
    }

    @Test("ToolGuardrailsResult: failure has reason")
    func resultFailure() {
        let result = ToolGuardrailsResult.failure(reason: "input too large")
        #expect(result.passed == false)
        #expect(result.reason == "input too large")
    }

    @Test("ToolGuardrailsResult: Equatable")
    func resultEquatable() {
        let a = ToolGuardrailsResult.pass
        let b = ToolGuardrailsResult.pass
        let c = ToolGuardrailsResult.failure(reason: "x")
        #expect(a == b)
        #expect(a != c)
    }

    // MARK: - ToolGuardrails.check

}

@Suite("ErrorClassifier deep (= v0.36 ticket 015)")
struct ErrorClassifierDeepTests {

    // MARK: - LLMErrorCategory

    @Test("LLMErrorCategory: 8 categories per ADR-0008 + ticket 015")
    func llmErrorCategoryCount() {
        let allCases = LLMErrorCategory.allCases
        #expect(allCases.count == 8)
        // All raw values unique
        let raws = Set(allCases.map { $0.rawValue })
        #expect(raws.count == 8)
    }

    @Test("LLMErrorCategory: rateLimit + serverError + contextLengthExceeded are well-known")
    func llmErrorCategoryCoreNames() {
        let raws = LLMErrorCategory.allCases.map { $0.rawValue }
        #expect(raws.contains("rateLimit"))
        #expect(raws.contains("serverError"))
        #expect(raws.contains("contextLengthExceeded"))
        #expect(raws.contains("unauthorized"))
        #expect(raws.contains("badRequest"))
        #expect(raws.contains("modelNotFound"))
        #expect(raws.contains("networkUnreachable"))
        #expect(raws.contains("unknown"))
    }

    @Test("LLMErrorCategory: Codable round-trip")
    func llmErrorCategoryCodable() throws {
        for category in LLMErrorCategory.allCases {
            let encoded = try JSONEncoder().encode(category)
            let decoded = try JSONDecoder().decode(LLMErrorCategory.self, from: encoded)
            #expect(decoded == category)
        }
    }

    // MARK: - ErrorClassifier.classify(error:httpResponse:) (= NOT PORTED)
    //
    // `ErrorClassifier.classify(error:httpResponse:)` never landed, so there is
    // nothing to verify here. The gap is named so it stays visible; the port
    // needs its own ticket and its own design.

}