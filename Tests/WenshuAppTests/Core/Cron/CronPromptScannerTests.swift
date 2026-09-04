//
//  CronPromptScannerTests.swift · Wenshu · v0.23 ticket 013.007 (hermes gap 7)
//
//  Boss 2026-08-23 拍: hermes _scan_cron_prompt parity.
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("CronPromptScanner (hermes _scan_cron_prompt parity)")
struct CronPromptScannerTests {

    // MARK: - Clean

    @Test("normal English prompt → clean")
    func testNormalPromptClean() {
        let result = CronPromptScanner.scan("Write 1000 words about a constable in Beijing 1930.")
        #expect(result == .clean)
    }

    @Test("normal Chinese prompt → clean")
    func testNormalChinesePromptClean() {
        let result = CronPromptScanner.scan("每晚 10 点提醒我写 1000 字")
        #expect(result == .clean)
    }

    @Test("empty prompt → clean")
    func testEmptyPromptClean() {
        let result = CronPromptScanner.scan("")
        #expect(result == .clean)
    }

    // MARK: - Blocked (invisible unicode)

    @Test("zero-width joiner (ZWJ) → blocked (hermes common injection vector)")
    func testZWJBlocked() {
        let prompt = "正常文本\u{200D}后面藏了 ZWJ"
        if case .blocked(let reason) = CronPromptScanner.scan(prompt) {
            #expect(reason.contains("U+200D"))
        } else {
            Issue.record("expected .blocked for ZWJ")
        }
    }

    @Test("zero-width space (ZWSP) → blocked")
    func testZWSPBlocked() {
        let prompt = "text\u{200B}hidden"
        if case .blocked = CronPromptScanner.scan(prompt) {
            // expected
        } else {
            Issue.record("expected .blocked for ZWSP")
        }
    }

    @Test("RTL override (RLO) → blocked (hermes _check_invisible_unicode)")
    func testRLOBlocked() {
        let prompt = "看起来正常\u{202E}但实际是 RTL 注入"
        if case .blocked = CronPromptScanner.scan(prompt) {
            // expected
        } else {
            Issue.record("expected .blocked for RLO")
        }
    }

    @Test("BOM (U+FEFF) → blocked")
    func testBOMBlocked() {
        let prompt = "\u{FEFF}text"
        if case .blocked = CronPromptScanner.scan(prompt) {
            // expected
        } else {
            Issue.record("expected .blocked for BOM")
        }
    }

    @Test("multiple invisible chars → blocked with full list")
    func testMultipleInvisiblesBlocked() {
        let prompt = "text\u{200B}\u{200D}\u{200C}more"
        if case .blocked(let reason) = CronPromptScanner.scan(prompt) {
            #expect(reason.contains("U+200B") || reason.contains("U+200D") || reason.contains("U+200C"))
        } else {
            Issue.record("expected .blocked for multiple invisibles")
        }
    }

    // MARK: - Suspicious (high emoji density)

    @Test("high emoji density → suspicious warning (not blocked)")
    func testHighEmojiDensity() {
        // 20 chars, 5 emojis = 25% > 5% threshold
        let prompt = "hello 😀😁😂🤣😍 world 🎉🎊🎈🎁🎂"
        if case .suspicious(let warning) = CronPromptScanner.scan(prompt) {
            #expect(warning.contains("emoji"))
        } else {
            Issue.record("expected .suspicious for high emoji density")
        }
    }

    @Test("low emoji density → clean")
    func testLowEmojiDensity() {
        // 30 chars, 1 emoji = 3.3% < 5% threshold
        let prompt = "Write a chapter with one smiley 😀 at the end."
        #expect(CronPromptScanner.scan(prompt) == .clean)
    }

    // MARK: - Equatable

    @Test("CronPromptScanResult Equatable")
    func testEquatable() {
        #expect(CronPromptScanResult.clean == .clean)
        #expect(CronPromptScanResult.blocked(reason: "x") == .blocked(reason: "x"))
        #expect(CronPromptScanResult.blocked(reason: "x") != .blocked(reason: "y"))
    }
}