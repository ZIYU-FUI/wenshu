//  WenshuVerifier.swift · Wenshu · v0.23 ticket 009 (single-API-key default for all agents)
//
//  Boss 2026-08-23 拍: '让所有 agent 有同一个 key, 这是一个默认行为'.
//
//  Design contract (clarified boss 8/23):
//  - WenshuVerifier holds exactly 1 apiKey (sourced from Keychain via LLMKeychain).
//  - WenshuConductor holds exactly 1 WenshuVerifier instance.
//  - All 6 agents (1 main 文枢 + 5 sub-agents: researcher / writer /
//    analyst / archivist / auditor) call into the same verifier.
//  - Sub-agents do NOT have their own API key.
//  - User cannot configure a different key per agent (boss 8/23 拍:
//    '用户不能改相关配置. 我们的设置都有 gui 的设置页面').
//
//  This is the default behavior — no code change needed. This commit
//  documents the contract via inline comments + a unit test verifying
//  that 6-agent concurrent dispatch shares the verifier.
//

import Foundation

extension WenshuVerifier {
    /// v0.23 ticket 009: static documentation comment for single-key contract.
    /// No code behavior change — existing API surface already enforces
    /// single-verifier per conductor, single-apiKey per verifier.
    public static let singleKeyContractNote: String = """
    WenshuVerifier = 1 instance per WenshuConductor.
    WenshuConductor = 1 instance per app launch.
    WenshuVerifier.apiKey = 1 key (sourced from Keychain at init).
    All 6 agents (1 main + 5 sub) use the same verifier → same key.

    Boss 2026-08-23 拍: '让所有 agent 有同一个 key, 这是一个默认行为'.
    """
}
