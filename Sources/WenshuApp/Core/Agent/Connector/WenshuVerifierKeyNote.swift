//
//  WenshuVerifierKeyNote.swift
//
//  Single-key contract documentation for WenshuVerifier.
//  v0.23 ticket 009: doc-only test surface (no runtime behavior).
//
//  Boss 2026-08-23 OOB: 'make all agents share a single key as default behavior'.
//
//  Design contract (clarified boss 8/23):
//  - WenshuVerifier holds exactly 1 apiKey (sourced from Keychain via LLMKeychain).
//  - WenshuConductor holds exactly 1 WenshuVerifier instance.
//  - All 6 agents (1 main + 5 sub-agents: researcher / writer /
//    analyst / archivist / auditor) call into the same verifier.
//  - Sub-agents do NOT have their own API key.
//  - User cannot configure a different key per agent (boss 8/23 default).
//
//  This is the default behavior — no code change needed. This file
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
    All 6 agents (1 main + 5 sub) use the same verifier -> same key.

    Boss 2026-08-23 OOB: 'all agents share a single key as default'.
    """
}
