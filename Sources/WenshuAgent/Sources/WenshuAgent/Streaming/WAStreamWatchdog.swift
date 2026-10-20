//
//  WAStreamWatchdog.swift · Wenshu · WenshuAgent no-progress timer
//
//  Race an async operation against a timeout. If the operation doesn't
//  complete in `timeout` seconds, cancel it (= throw
//  WAStreamTimeoutError). This is hermes `auxiliary_stream_watchdog.py`
//  ported to Swift; it solves the user-facing "AI 没回复" (= the SSE
//  stream is open but no chunks arrive) failure mode that the byte-level
//  parser alone can't detect.
//
//  Usage:
//      let response = try await WAStreamWatchdog.shared.watch(timeout: 30) {
//          try await connector.stream(messages: messages, options: options)
//      }
//
//  Default timeout = 30 seconds (= matches hermes).
//
//  Created: 2026-10-16 (WenshuAgent P3.2)
//  Source: hermes `agent/auxiliary_stream_watchdog.py` 180 LOC
//

import Foundation

public struct WAStreamTimeoutError: Error, Sendable, CustomStringConvertible {
    public let timeout: TimeInterval
    public let attemptId: UUID

    public var description: String {
        "WAStreamWatchdog timeout after \(Int(timeout))s (attempt \(attemptId.uuidString.prefix(8)))"
    }
}

public actor WAStreamWatchdog {
    public static let shared = WAStreamWatchdog()

    public init() {}

    /// Race the operation against a timeout. If the operation takes
    /// longer than `timeout` seconds, cancel it (= throw
    /// `WAStreamTimeoutError`). Cancellation is best-effort: the
    /// underlying operation is responsible for respecting
    /// `Task.isCancelled`.
    public func watch<T: Sendable>(
        attemptId: UUID = UUID(),
        timeout: TimeInterval = 30,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        let diagAttemptId = attemptId
        let start = Date()

        return try await withThrowingTaskGroup(of: T.self) { group in
            // The watchdog task
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                WALogger.watchdog.error("attempt \(diagAttemptId.uuidString.prefix(8), privacy: .public) timed out after \(Int(timeout), privacy: .public)s")
                throw WAStreamTimeoutError(timeout: timeout, attemptId: diagAttemptId)
            }

            // The actual operation
            group.addTask {
                let result = try await operation()
                WALogger.watchdog.info("attempt \(diagAttemptId.uuidString.prefix(8), privacy: .public) completed in \(Int(Date().timeIntervalSince(start) * 1000), privacy: .public)ms")
                return result
            }

            // First to finish wins
            defer { group.cancelAll() }
            guard let result = try await group.next() else {
                throw WAStreamTimeoutError(timeout: timeout, attemptId: diagAttemptId)
            }
            return result
        }
    }
}
