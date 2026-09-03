//
//  AsyncDelegation.swift · Wenshu · v0.23 ticket 013.010 (hermes gap 9)
//
//  Boss 2026-08-23 拍: '全修, 参考原则 3'. Async delegation infrastructure.
//  Source: github.com/NousResearch/hermes-agent/blob/main/tools/async_delegation.py
//
//  Hermes pattern: parent agent dispatches subagent on daemon thread,
//  returns handle immediately. Subagent result pushed to completion queue
//  when done. Parent can keep working / receive user input while child runs.
//
//  wenshu impl: BackgroundDelegationHandle + AsyncDelegationRegistry actor.
//  No UI integration in v0.23 (UI integration deferred to v0.24+).
//

import Foundation

/// State of a background delegation.
public enum BackgroundDelegationState: String, Codable, Sendable {
    case pending
    case running
    case completed
    case failed
    case timeout
}

/// Handle for a background sub-agent delegation.
/// Mirrors hermes delegation record.
public struct BackgroundDelegationHandle: Sendable, Equatable {
    public let id: String
    public let agentName: String
    public let userMessage: String
    public var state: BackgroundDelegationState
    public let startedAt: Date
    public var completedAt: Date?
    public var result: String?

    public init(
        id: String = UUID().uuidString,
        agentName: String,
        userMessage: String,
        state: BackgroundDelegationState = .pending,
        startedAt: Date = Date(),
        completedAt: Date? = nil,
        result: String? = nil
    ) {
        self.id = id
        self.agentName = agentName
        self.userMessage = userMessage
        self.state = state
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.result = result
    }
}

/// AsyncDelegationRegistry: tracks background delegations.
/// Mirrors hermes _records (delegation_id → record dict) + completion queue.
public actor AsyncDelegationRegistry {
    private var records: [String: BackgroundDelegationHandle] = [:]
    private let maxRetained: Int = 50            // hermes _MAX_RETAINED_COMPLETED
    private let durableRetentionSeconds: TimeInterval = 7 * 24 * 60 * 60  // hermes 7 days
    private var completionQueue: [String] = []  // FIFO of completed IDs

    /// Register a new background delegation.
    public func register(handle: BackgroundDelegationHandle) {
        records[handle.id] = handle
    }

    /// Update an existing handle (e.g. state transition).
    public func update(_ handle: BackgroundDelegationHandle) {
        records[handle.id] = handle
    }

    /// Get a handle by id.
    public func get(id: String) -> BackgroundDelegationHandle? {
        return records[id]
    }

    /// List all running delegations (state == .running).
    public func runningDelegations() -> [BackgroundDelegationHandle] {
        return records.values.filter { $0.state == .running || $0.state == .pending }
    }

    /// List recent completed delegations (FIFO, max maxRetained).
    public func recentCompleted() -> [BackgroundDelegationHandle] {
        return completionQueue
            .compactMap { records[$0] }
            .filter { $0.state == .completed || $0.state == .failed }
    }

    /// Mark a delegation as completed (called when sub-agent finishes).
    public func markCompleted(id: String, result: String) {
        guard var handle = records[id] else { return }
        handle.state = .completed
        handle.completedAt = Date()
        handle.result = result
        records[id] = handle
        completionQueue.append(id)
        // LRU evict
        if completionQueue.count > maxRetained {
            let evicted = completionQueue.removeFirst()
            records.removeValue(forKey: evicted)
        }
    }

    /// Mark a delegation as failed.
    public func markFailed(id: String, error: String) {
        guard var handle = records[id] else { return }
        handle.state = .failed
        handle.completedAt = Date()
        handle.result = "(failed: \(error))"
        records[id] = handle
        completionQueue.append(id)
    }

    /// Cleanup old records beyond retention period.
    public func cleanup() {
        let now = Date()
        let cutoff = now.addingTimeInterval(-durableRetentionSeconds)
        records = records.filter { _, handle in
            let referenceDate = handle.completedAt ?? handle.startedAt
            return referenceDate > cutoff
        }
        completionQueue = completionQueue.filter { id in
            records[id] != nil
        }
    }
}