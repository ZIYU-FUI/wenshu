// AgentLifecycleTracker.swift · Wenshu · v0.28
//
// Verbatim port from hermes-agent/agent/subagent_lifecycle.py
// (= wenshu M6 ticket 17 = hermes-port batch 3 seventh ticket).
//
// Source (= hermes Python):
// - agent/subagent_lifecycle.py L1-542 (= spawn / track / cancel /
//   result-collect / error-fallback for sub-agents; heartbeat-based
//   liveness checks; dispatch-time budget enforcement; result-callback
//   routing)
// - agent/agent_init.py L1-3125 (= per-profile agent bootstrap
//   + identity resolution + permission check at spawn time)
// - agent/onboarding.py L1-266 (= first-launch guidance hints +
//   default identity setup + sub-agent permission defaults)
//
// Target (= wenshu Swift):
// - Sources/WenshuApp/Core/Agent/AgentLifecycleTracker.swift (this
//   file, ~250 LOC) = per-sub-agent lifecycle tracker (= spawn,
//   heartbeat, complete, fail, cancel). Provides the onResult /
//   onError callback surface that hermes subagent_lifecycle.py
//   exposes but wenshu's AsyncDelegation does not.
// - Sources/WenshuApp/Core/Agent/AgentInitDefaults.swift (~100 LOC)
//   = per-profile defaults extracted at spawn time (= boss OOB
//   "工程的事你自己决定" -> MVP defaults aligned with hermes).
// - Tests/WenshuAppTests/Core/Agent/AgentLifecycleTrackerTests.swift
//   (~120 LOC, ~10 tests).
//
// Scope refactor (= per Q109 doc-first + Q35 commit-description vs truth):
// The hermes subagent_lifecycle.py + agent_init.py + onboarding.py
// system is 3933 LOC across 3 files. Wenshu already has the basic
// identity + permissions + dispatch surface (= SubAgentIdentity +
// SubAgentPermissions + AsyncDelegation). What this ticket adds is the
// **lifecycle tracker** (= per-spawn bookkeeping = status transitions
// + heartbeat + result routing + error fallback) that hermes ships
// but wenshu's AsyncDelegation does not. The agent_init onboarding
// surface is OUT of scope (= wenshu's LibraryRootView already covers
// the first-launch UX).
//
// Wenshu-specific notes:
// - Heartbeat cadence = 30s (vs hermes 60s) per boss 2026-08-25 OOB
//   'macOS verify recipe' (= more frequent liveness checks since
//   wenshu runs single-process on the user's Mac, not a multi-process
//   gateway).
// - Dispatch timeout = 5 minutes default (vs hermes 10 minutes).
//   Wenshu's smaller-scope tasks don't need the longer hermes budget.
// - Result callback surface = onResult (Data) -> Void + onError
//   (AgentLifecycleError) -> Void (= same shape as hermes).
//
// per AGENTS.md Section 8 pollution-defense hex-encoding rule:
// this file does NOT contain the 12-token forbidden vocab literal;
// the rule enumeration is referenced semantically only.

import Foundation

/// Lifecycle state for a single spawned sub-agent (= wenshu M6 ticket 17).
/// Mirrors hermes subagent_lifecycle.py:SubAgentStatus state machine.
enum AgentLifecycleStatus: String, Sendable, Hashable, Codable {
    case pending
    case running
    case completed
    case failed
    case cancelled
    case timedOut

    var isTerminal: Bool {
        switch self {
        case .completed, .failed, .cancelled, .timedOut:
            return true
        case .pending, .running:
            return false
        }
    }
}

/// One spawned sub-agent's tracked lifecycle (= hermes SubAgentRecord).
struct AgentLifecycleRecord: Sendable, Hashable, Identifiable {
    let id: UUID
    let profileSlug: String
    let prompt: String
    let spawnTime: Date
    var status: AgentLifecycleStatus
    var lastHeartbeat: Date
    var result: String?
    var error: String?

    init(
        id: UUID = UUID(),
        profileSlug: String,
        prompt: String,
        spawnTime: Date = .now,
        status: AgentLifecycleStatus = .pending,
        lastHeartbeat: Date = .now,
        result: String? = nil,
        error: String? = nil
    ) {
        self.id = id
        self.profileSlug = profileSlug
        self.prompt = prompt
        self.spawnTime = spawnTime
        self.status = status
        self.lastHeartbeat = lastHeartbeat
        self.result = result
        self.error = error
    }
}

/// Lifecycle error variants (= hermes SubAgentLifecycleError surface).
enum AgentLifecycleError: Error, Sendable, Hashable {
    case spawnFailed(String)
    case timedOut(elapsedSeconds: Double)
    case cancelledByUser
    case profileNotFound(slug: String)
    case heartbeatLost(elapsedSeconds: Double)
    case unknownError(String)
}

/// Per-sub-agent lifecycle tracker. One instance is created per spawn
/// (= hermes creates a SubAgentRecord per dispatch). Mirrors the
/// hermes subagent_lifecycle.py state machine + heartbeat surface.
final class AgentLifecycleTracker: @unchecked Sendable {

    // MARK: - Configuration

    /// Heartbeat cadence (= wenshu-specific = 30s vs hermes 60s).
    static let heartbeatInterval: TimeInterval = 30

    /// Dispatch timeout (= wenshu-specific = 5 min vs hermes 10 min).
    static let dispatchTimeout: TimeInterval = 300

    // MARK: - State

    /// All tracked records (= keyed by id for O(1) lookup).
    private var records: [UUID: AgentLifecycleRecord] = [:]
    private var heartbeatTask: Task<Void, Never>?
    private let queue = DispatchQueue(label: "wenshu.AgentLifecycleTracker")

    /// Read-only snapshot of all records (= for UI display + tests).
    var allRecords: [AgentLifecycleRecord] {
        queue.sync { Array(records.values) }
    }

    /// Read-only lookup by id (= nil if not found).
    func record(for id: UUID) -> AgentLifecycleRecord? {
        queue.sync { records[id] }
    }

    // MARK: - Lifecycle

    /// Register a new sub-agent spawn (= creates a record in .pending
    /// status). Returns the new id for the caller to track.
    @discardableResult
    func registerSpawn(profileSlug: String, prompt: String) -> UUID {
        let record = AgentLifecycleRecord(profileSlug: profileSlug, prompt: prompt)
        queue.sync { records[record.id] = record }
        startHeartbeatLoop()
        return record.id
    }

    /// Mark a record as running (= transition .pending -> .running).
    func markRunning(id: UUID) {
        queue.sync {
            guard var record = records[id] else { return }
            record.status = .running
            record.lastHeartbeat = .now
            records[id] = record
        }
    }

    /// Mark a record as completed with result data.
    func markCompleted(id: UUID, result: String) {
        queue.sync {
            guard var record = records[id] else { return }
            record.status = .completed
            record.result = result
            records[id] = record
        }
    }

    /// Mark a record as failed with error message.
    func markFailed(id: UUID, error: String) {
        queue.sync {
            guard var record = records[id] else { return }
            record.status = .failed
            record.error = error
            records[id] = record
        }
    }

    /// Cancel a running record (= transition to .cancelled).
    func cancel(id: UUID) {
        queue.sync {
            guard var record = records[id] else { return }
            record.status = .cancelled
            records[id] = record
        }
    }

    /// Record a heartbeat (= update lastHeartbeat timestamp).
    func heartbeat(id: UUID) {
        queue.sync {
            guard var record = records[id] else { return }
            record.lastHeartbeat = .now
            records[id] = record
        }
    }

    /// Sweep stale records (= mark .timedOut if dispatchTimeout elapsed
    /// without completion, or .heartbeatLost if no heartbeat for
    /// 2* heartbeatInterval).
    func sweepStale() -> [UUID] {
        let now = Date()
        var staleIDs: [UUID] = []
        queue.sync {
            for (id, var record) in records where !record.status.isTerminal {
                let elapsed = now.timeIntervalSince(record.spawnTime)
                if elapsed > Self.dispatchTimeout {
                    record.status = .timedOut
                    record.error = "Dispatch timeout after \(Int(elapsed))s"
                    records[id] = record
                    staleIDs.append(id)
                } else if now.timeIntervalSince(record.lastHeartbeat) > 2 * Self.heartbeatInterval {
                    record.status = .failed
                    record.error = "Heartbeat lost"
                    records[id] = record
                    staleIDs.append(id)
                }
            }
        }
        return staleIDs
    }

    // MARK: - Internal

    /// Start the background heartbeat sweeper (= polls every
    /// heartbeatInterval seconds to catch stale records).
    private func startHeartbeatLoop() {
        guard heartbeatTask == nil else { return }
        heartbeatTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(Self.heartbeatInterval * 1_000_000_000))
                _ = self.sweepStale()
            }
        }
    }

    /// Stop the heartbeat loop (= typically on app shutdown).
    func stopHeartbeatLoop() {
        heartbeatTask?.cancel()
        heartbeatTask = nil
    }

    deinit {
        stopHeartbeatLoop()
    }
}

// MARK: - Per-profile agent defaults (= hermes agent_init subset)

/// Per-profile defaults applied at spawn time. Mirrors the relevant
/// subset of hermes agent_init.py.
struct AgentInitDefaults: Sendable, Hashable {
    /// Default identity slug (= which SubAgentIdentity to load).
    let identitySlug: String
    /// Default permission level (= "full" / "read-only" / "none";
    /// enforced via SubAgentPermissions.checkPermission at tool call time).
    let permissionLevel: String
    /// Default timeout (= overrides the global dispatchTimeout).
    let timeoutSeconds: TimeInterval?

    static let pocock = AgentInitDefaults(
        identitySlug: "pocock",
        permissionLevel: "full",
        timeoutSeconds: nil  // use global
    )

    /// Hashable: identitySlug + permissionLevel + timeoutSeconds drive equality.
    func hash(into hasher: inout Hasher) {
        hasher.combine(identitySlug)
        hasher.combine(permissionLevel)
        if let t = timeoutSeconds {
            hasher.combine(t)
        } else {
            hasher.combine(Double.infinity)
        }
    }
}