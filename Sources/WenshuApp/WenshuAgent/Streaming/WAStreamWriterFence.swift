//
//  WAStreamWriterFence.swift · Wenshu · WenshuAgent stream single-writer fence
//
//  Prevents the multi-stream race condition where two streaming
//  responses try to write to the same `messages[idx]` slot (= the user
//  sees jumbled text from both streams). Hermetic fence via a monotonic
//  token counter: every new stream call claims a fresh token; the
//  stream callback checks if its token is still current before
//  writing. If a newer stream has claimed, the older one bails out
//  (= a single source of truth, exactly hermes `stream_single_writer.py`).
//
//  Created: 2026-10-16 (WenshuAgent P3.2)
//  Source: hermes `agent/stream_single_writer.py` 38 LOC
//

import Foundation

public final class WAStreamWriterFence: @unchecked Sendable {
    private var currentToken: Int = 0
    private let lock = NSLock()

    public init() {}

    /// Claim a new token. Increment the counter atomically. The caller
    /// stores the returned token; later checks if it is still current.
    @discardableResult
    public func claim() -> Int {
        lock.lock()
        defer { lock.unlock() }
        currentToken += 1
        return currentToken
    }

    /// Check if the given token is still the current writer (= no
    /// newer stream has been claimed since). If false, the caller
    /// should bail out.
    public func isCurrent(_ token: Int) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return token == currentToken
    }
}
