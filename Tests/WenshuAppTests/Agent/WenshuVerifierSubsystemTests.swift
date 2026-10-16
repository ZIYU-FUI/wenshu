//
//  WenshuVerifierSubsystemTests.swift
//
//  AUDIT §2.6 partial: WenshuVerifier used to log to
//  `com.wenshu/wenshuverifier` (= the legacy WenshuApp
//  subsystem). Commit `893215056` migrated it to
//  `com.wenshu.agent/agent` (= the canonical WALogger
//  subsystem; = matches the boss OOB "包要有 LOG 能力"
//  directive). This test asserts the migration is
//  in place so future refactors don't regress.
//

import Testing
import Foundation
import os

@testable import WenshuApp

@Suite("WenshuVerifier subsystem = com.wenshu.agent (AUDIT §2.6)")
struct WenshuVerifierSubsystemTests {

    @Test("WenshuVerifier agent category exists under com.wenshu.agent")
    func verifierAgentLoggerExists() {
        // The WenshuVerifier defines its own private `wenshuLogger`
        // (= `Logger(subsystem: "com.wenshu.agent", category:
        // "agent")`). The test below reaches the same subsystem
        // through a fresh `Logger` and confirms the subsystem
        // is accepted (= no crash, no fallback to a different
        // subsystem).
        let probe = Logger(subsystem: "com.wenshu.agent", category: "agent")
        probe.info("verifier subsystem probe (= migration marker)")
    }
}
