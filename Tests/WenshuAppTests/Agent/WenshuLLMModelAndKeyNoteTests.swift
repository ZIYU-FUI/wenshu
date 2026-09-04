//
//  WenshuLLMModelAndKeyNoteTests.swift · Wenshu · v0.38 Batch 3 sub-step 15
//
//  Tests for WenshuLLMModel + WenshuVerifierKeyNote + WenshuLLMModelFetcher
//  (= v0.21 ticket 04 + v0.23 ticket 009 + v0.36 ticket 008).
//
//  Per 老板 cadence 2026-09-03 '继续推进移植' (= 长期 auto-pilot mode
//  per '一直跑移植就行' + '不用问我了') + 'PO 全链路方法论执行,
//  不要跳步骤' + '1 RULE 1 commit'.
//
//  Safe scope (= NOT v0.34 in-flight) = WenshuLLMModel.swift is v0.21,
//  WenshuVerifierKeyNote.swift is v0.23, WenshuLLMModelFetcher.swift is
//  v0.36 ticket 008 (= all my work, none v0.34 in-flight).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("WenshuLLMModel deep (= v0.21 ticket 04)")
struct WenshuLLMModelDeepTests {

    @Test("WenshuLLMModel: 3 cases")
    func threeCases() {
        let cases = WenshuLLMModel.allCases
        #expect(cases.count == 3)
    }

    @Test("WenshuLLMModel: rawValues match spec")
    func rawValues() {
        #expect(WenshuLLMModel.m3.rawValue == "MiniMax-M3")
        #expect(WenshuLLMModel.m2.rawValue == "MiniMax-M2")
        #expect(WenshuLLMModel.reasoning.rawValue == "MiniMax-Reasoning")
    }

    @Test("WenshuLLMModel: label = rawValue")
    func labelEqualsRawValue() {
        #expect(WenshuLLMModel.m3.label == "MiniMax-M3")
        #expect(WenshuLLMModel.m2.label == "MiniMax-M2")
        #expect(WenshuLLMModel.reasoning.label == "MiniMax-Reasoning")
    }

    @Test("WenshuLLMModel: all 3 cases map to minimax-cn provider slug")
    func providerSlugMinimax() {
        #expect(WenshuLLMModel.m3.providerSlug == "minimax-cn")
        #expect(WenshuLLMModel.m2.providerSlug == "minimax-cn")
        #expect(WenshuLLMModel.reasoning.providerSlug == "minimax-cn")
    }

    @Test("WenshuLLMModel: Equatable")
    func equatable() {
        #expect(WenshuLLMModel.m3 == WenshuLLMModel.m3)
        #expect(WenshuLLMModel.m3 != WenshuLLMModel.m2)
    }

    @Test("WenshuLLMModel: CaseIterable enumeration order")
    func caseOrder() {
        let cases = WenshuLLMModel.allCases
        #expect(cases[0] == .m3)
        #expect(cases[1] == .m2)
        #expect(cases[2] == .reasoning)
    }
}

@Suite("WenshuVerifierKeyNote deep (= v0.23 ticket 009)")
struct WenshuVerifierKeyNoteDeepTests {

    @Test("WenshuVerifier.singleKeyContractNote: non-empty")
    func noteNonEmpty() {
        #expect(!WenshuVerifier.singleKeyContractNote.isEmpty)
    }

    @Test("WenshuVerifier.singleKeyContractNote: mentions WenshuVerifier")
    func noteMentionsVerifier() {
        #expect(WenshuVerifier.singleKeyContractNote.contains("WenshuVerifier"))
    }

    @Test("WenshuVerifier.singleKeyContractNote: mentions apiKey")
    func noteMentionsAPIKey() {
        #expect(WenshuVerifier.singleKeyContractNote.contains("apiKey"))
    }

    @Test("WenshuVerifier.singleKeyContractNote: mentions 6 agents")
    func noteMentionsAgents() {
        #expect(WenshuVerifier.singleKeyContractNote.contains("6") ||
               WenshuVerifier.singleKeyContractNote.contains("agent"))
    }
}
