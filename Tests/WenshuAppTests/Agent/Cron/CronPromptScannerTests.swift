//
//  CronPromptScannerTests.swift · Wenshu · v0.23 ticket 013.007 (hermes gap 7)
//
// 
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("CronPromptScanner (hermes _scan_cron_prompt parity)")
struct CronPromptScannerTests {

    // MARK: - Clean

    // MARK: - Blocked (invisible unicode)

    // MARK: - Suspicious (high emoji density)

    // MARK: - Equatable

    @Test("CronPromptScanResult Equatable")
    func testEquatable() {
        #expect(CronPromptScanResult.clean == .clean)
        #expect(CronPromptScanResult.blocked(reason: "x") == .blocked(reason: "x"))
        #expect(CronPromptScanResult.blocked(reason: "x") != .blocked(reason: "y"))
    }
}
