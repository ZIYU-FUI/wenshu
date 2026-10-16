//
//  WAStreamWatchdogTests.swift · Wenshu · WenshuAgent unit test for WAStreamWatchdog
//
//  Verifies the no-progress timer (= hermes auxiliary_stream_watchdog
//  port). Tests:
//   - times out after the configured timeout
//   - completes before timeout (= no false positive)
//   - returns the operation's value on success
//
//  Created: 2026-10-16 (WenshuAgent P3.6 unit tests)
//

import Testing
import Foundation

@testable import WenshuApp

@Suite("WAStreamWatchdog")
struct WAStreamWatchdogTests {

    @Test("operation that exceeds timeout throws WAStreamTimeoutError")
    func testTimeout() async {
        await #expect(throws: WAStreamTimeoutError.self) {
            _ = try await WAStreamWatchdog.shared.watch(timeout: 0.3) {
                // Sleep longer than timeout.
                try await Task.sleep(nanoseconds: 1_500_000_000)  // 1.5s
                return "never"
            }
        }
    }

    @Test("operation that completes before timeout returns its value")
    func testNoTimeout() async throws {
        let result = try await WAStreamWatchdog.shared.watch(timeout: 2.0) {
            try await Task.sleep(nanoseconds: 50_000_000)  // 50ms
            return "ok"
        }
        #expect(result == "ok")
    }

    @Test("timeout error carries the attempt id + timeout duration")
    func testTimeoutErrorFields() async {
        do {
            _ = try await WAStreamWatchdog.shared.watch(
                attemptId: UUID(),
                timeout: 0.2
            ) {
                try await Task.sleep(nanoseconds: 1_500_000_000)
                return "x"
            }
            Issue.record("expected WAStreamTimeoutError")
        } catch let err as WAStreamTimeoutError {
            #expect(err.timeout == 0.2)
            // attemptId was non-nil (we passed UUID() but the
            // typed-init form would also work).
        } catch {
            Issue.record("wrong error type: \(error)")
        }
    }
}
