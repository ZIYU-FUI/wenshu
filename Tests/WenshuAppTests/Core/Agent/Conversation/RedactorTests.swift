//
//  RedactorTests.swift · Wenshu · HERMES-INTERNAL-009 (2026-09-04)
//
//  Round-trip tests for Redactor (= hermes redact.py port).
//
//  Tests covered:
//    1. testRedact_email             — email redacted to [REDACTED_EMAIL]
//    2. testRedact_phoneNumber       — phone redacted to [REDACTED_PHONE]
//    3. testRedact_apiKey            — sk-/AKIA API keys redacted
//    4. testRedact_multipleRules     — multiple rules fire in one pass
//    5. testRedact_noMatch           — plain text unchanged
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("Redactor (HERMES-INTERNAL-009)")
struct RedactorTests {

    @Test("redact masks email addresses")
    func testRedact_email() {
        let redactor = Redactor()
        let input = "Contact me at alice@example.com for details."
        let output = redactor.redact(input)
        #expect(output.contains("[REDACTED_EMAIL]"))
        #expect(!output.contains("alice@example.com"))
    }

    @Test("redact masks E.164 phone numbers")
    func testRedact_phoneNumber() {
        let redactor = Redactor()
        let input = "Call +14155551234 today!"
        let output = redactor.redact(input)
        #expect(output.contains("[REDACTED_PHONE]"))
        #expect(!output.contains("+14155551234"))
    }

    @Test("redact masks sk- and AKIA API keys")
    func testRedact_apiKey() {
        let redactor = Redactor()
        let input = "OpenAI key: sk-proj1234567890abcdef. AWS: AKIAIOSFODNN7EXAMPLE."
        let output = redactor.redact(input)
        #expect(output.contains("[REDACTED_API_KEY]"))
        #expect(!output.contains("sk-proj1234567890abcdef"))
        #expect(!output.contains("AKIAIOSFODNN7EXAMPLE"))
    }

    @Test("redact applies multiple rules in a single pass")
    func testRedact_multipleRules() {
        let redactor = Redactor()
        let input = "Email alice@example.com or phone +14155551234 or key sk-proj1234567890abcdef."
        let output = redactor.redact(input)
        #expect(output.contains("[REDACTED_EMAIL]"))
        #expect(output.contains("[REDACTED_PHONE]"))
        #expect(output.contains("[REDACTED_API_KEY]"))
    }

    @Test("redact leaves plain text unchanged when no rule matches")
    func testRedact_noMatch() {
        let redactor = Redactor()
        let input = "Just a normal sentence about cooking recipes."
        let output = redactor.redact(input)
        #expect(output == input)
    }
}