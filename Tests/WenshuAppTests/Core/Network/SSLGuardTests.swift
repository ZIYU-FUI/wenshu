//
//  SSLGuardTests.swift · Wenshu · HERMES-INTERNAL-004 (2026-09-04)
//
//  Round-trip tests for SSLGuard (= hermes ssl_guard.py port).
//
//  Tests covered:
//    1. testValidate_httpsStrict        — https + .strict → success
//    2. testValidate_httpRejected       — http + .strict → .insecureURL
//    3. testValidate_localhostSelfSigned — http://localhost + .allowSelfSigned → success
//    4. testValidate_bypassExplicit     — junk scheme + .bypass → success
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("SSLGuard (HERMES-INTERNAL-004)")
struct SSLGuardTests {

    @Test("strict mode accepts https URLs and rejects http URLs")
    func testValidate_httpsStrict() {
        let https = URL(string: "https://api.example.com/v1")!
        let http = URL(string: "http://api.example.com/v1")!

        if case .success = SSLGuard.validate(url: https, mode: .strict) {
            // expected
        } else {
            Issue.record("https URL should pass strict mode")
        }

        let httpResult = SSLGuard.validate(url: http, mode: .strict)
        #expect(httpResult == .failure(.insecureURL))
    }

    @Test("strict mode rejects http:// URLs with .insecureURL")
    func testValidate_httpRejected() {
        let http = URL(string: "http://example.com")!
        let result = SSLGuard.validate(url: http, mode: .strict)
        #expect(result == .failure(.insecureURL))
    }

    @Test("allowSelfSigned mode permits http://localhost for Ollama")
    func testValidate_localhostSelfSigned() {
        let localhostHTTP = URL(string: "http://localhost:11434/v1")!
        let localhostHTTPS = URL(string: "https://localhost:11434/v1")!
        let loopbackHTTP = URL(string: "http://127.0.0.1:11434/v1")!

        let r1 = SSLGuard.validate(url: localhostHTTP, mode: .allowSelfSigned)
        let r2 = SSLGuard.validate(url: localhostHTTPS, mode: .allowSelfSigned)
        let r3 = SSLGuard.validate(url: loopbackHTTP, mode: .allowSelfSigned)

        if case .success = r1 {} else { Issue.record("http://localhost should pass allowSelfSigned") }
        if case .success = r2 {} else { Issue.record("https://localhost should pass allowSelfSigned") }
        if case .success = r3 {} else { Issue.record("http://127.0.0.1 should pass allowSelfSigned") }
    }

    @Test("bypass mode accepts any URL scheme for explicit test paths")
    func testValidate_bypassExplicit() {
        let ftp = URL(string: "ftp://example.com/x")!
        let file = URL(string: "file:///etc/hosts")!
        if case .success = SSLGuard.validate(url: ftp, mode: .bypass) {} else {
            Issue.record("bypass should accept ftp://")
        }
        if case .success = SSLGuard.validate(url: file, mode: .bypass) {} else {
            Issue.record("bypass should accept file://")
        }
    }
}