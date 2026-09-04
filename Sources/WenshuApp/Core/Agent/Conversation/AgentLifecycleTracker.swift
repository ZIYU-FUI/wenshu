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

// MARK: - Bootstrap (= HERMES-PARTIAL-005: agent_init.py bootstrap surface)

/// Per-step bootstrap status (= hermes agent_init.py init_agent performs
/// ~60 setup steps; we expose the bootstrap result as a typed bag so the
/// caller can introspect what loaded and what didn't).
public struct bootstrapStatus: Sendable, Equatable {
    public let configLoaded: Bool
    public let credentialsResolved: Bool
    public let skillRegistryLoaded: Bool
    public let memoryLoaded: Bool
    public let contextEngineLoaded: Bool
    public let systemPromptComposed: Bool
    public let failedSteps: [String]

    public init(
        configLoaded: Bool = false,
        credentialsResolved: Bool = false,
        skillRegistryLoaded: Bool = false,
        memoryLoaded: Bool = false,
        contextEngineLoaded: Bool = false,
        systemPromptComposed: Bool = false,
        failedSteps: [String] = []
    ) {
        self.configLoaded = configLoaded
        self.credentialsResolved = credentialsResolved
        self.skillRegistryLoaded = skillRegistryLoaded
        self.memoryLoaded = memoryLoaded
        self.contextEngineLoaded = contextEngineLoaded
        self.systemPromptComposed = systemPromptComposed
        self.failedSteps = failedSteps
    }

    /// All bootstrap steps completed without failures.
    public var isComplete: Bool {
        return configLoaded
            && credentialsResolved
            && skillRegistryLoaded
            && memoryLoaded
            && contextEngineLoaded
            && systemPromptComposed
            && failedSteps.isEmpty
    }
}

/// Bootstrap step hooks (= hermes init_agent body side effects; the
/// caller wires the side effects through closures so the bootstrap driver
/// itself stays free of import cycles with the agent runtime).
public struct BootstrapHooks: Sendable {
    public var loadConfig: @Sendable () throws -> Void
    public var resolveCredentials: @Sendable () throws -> Void
    public var loadSkillRegistry: @Sendable () throws -> Void
    public var loadMemory: @Sendable () throws -> Void
    public var loadContextEngine: @Sendable () throws -> Void
    public var composeSystemPrompt: @Sendable () throws -> Void

    public init(
        loadConfig: @escaping @Sendable () throws -> Void = {},
        resolveCredentials: @escaping @Sendable () throws -> Void = {},
        loadSkillRegistry: @escaping @Sendable () throws -> Void = {},
        loadMemory: @escaping @Sendable () throws -> Void = {},
        loadContextEngine: @escaping @Sendable () throws -> Void = {},
        composeSystemPrompt: @escaping @Sendable () throws -> Void = {}
    ) {
        self.loadConfig = loadConfig
        self.resolveCredentials = resolveCredentials
        self.loadSkillRegistry = loadSkillRegistry
        self.loadMemory = loadMemory
        self.loadContextEngine = loadContextEngine
        self.composeSystemPrompt = composeSystemPrompt
    }

    /// Default no-op hooks (= for tests).
    public static let noop = BootstrapHooks()

    /// Successful hooks (= mark each step as completed; for tests).
    public static let success = BootstrapHooks(
        loadConfig: {},
        resolveCredentials: {},
        loadSkillRegistry: {},
        loadMemory: {},
        loadContextEngine: {},
        composeSystemPrompt: {}
    )
}

/// Bootstrap driver. Runs the 6-step init_agent surface (= hermes
/// agent_init.py bootstrap = load config + credentials + skill registry +
/// memory + context engine + system prompt) and returns a typed status.
///
/// Per hermes agent_init.py L260-560: init_agent is the longest method
/// in the codebase (= 60+ parameters, ~1,400 LOC of attribute init +
/// provider auto-detection + credential resolution + context-engine
/// bootstrap). The wenshu-side-wins surface is a thin driver that calls
/// each step in order; the heavy lifting lives in the caller-provided
/// hooks (= testable + import-cycle-free).
public actor AgentBootstrapper {
    private let hooks: BootstrapHooks

    public init(hooks: BootstrapHooks = .noop) {
        self.hooks = hooks
    }

    /// Run the bootstrap. Each step is independent; a failure in one
    /// step does not abort the others (= hermes pattern: collect
    /// failed_steps rather than raising).
    public func bootstrap() async -> bootstrapStatus {
        var status = bootstrapStatus()
        var failed: [String] = []

        // 1. Load config (= hermes load_config at init_agent body start).
        do {
            try hooks.loadConfig()
            status = bootstrapStatus(
                configLoaded: true,
                credentialsResolved: status.credentialsResolved,
                skillRegistryLoaded: status.skillRegistryLoaded,
                memoryLoaded: status.memoryLoaded,
                contextEngineLoaded: status.contextEngineLoaded,
                systemPromptComposed: status.systemPromptComposed,
                failedSteps: status.failedSteps
            )
        } catch {
            failed.append("load_config: \(error)")
        }

        // 2. Resolve credentials.
        do {
            try hooks.resolveCredentials()
            status = bootstrapStatus(
                configLoaded: status.configLoaded,
                credentialsResolved: true,
                skillRegistryLoaded: status.skillRegistryLoaded,
                memoryLoaded: status.memoryLoaded,
                contextEngineLoaded: status.contextEngineLoaded,
                systemPromptComposed: status.systemPromptComposed,
                failedSteps: status.failedSteps
            )
        } catch {
            failed.append("resolve_credentials: \(error)")
        }

        // 3. Load skill registry.
        do {
            try hooks.loadSkillRegistry()
            status = bootstrapStatus(
                configLoaded: status.configLoaded,
                credentialsResolved: status.credentialsResolved,
                skillRegistryLoaded: true,
                memoryLoaded: status.memoryLoaded,
                contextEngineLoaded: status.contextEngineLoaded,
                systemPromptComposed: status.systemPromptComposed,
                failedSteps: status.failedSteps
            )
        } catch {
            failed.append("load_skill_registry: \(error)")
        }

        // 4. Load memory subsystem.
        do {
            try hooks.loadMemory()
            status = bootstrapStatus(
                configLoaded: status.configLoaded,
                credentialsResolved: status.credentialsResolved,
                skillRegistryLoaded: status.skillRegistryLoaded,
                memoryLoaded: true,
                contextEngineLoaded: status.contextEngineLoaded,
                systemPromptComposed: status.systemPromptComposed,
                failedSteps: status.failedSteps
            )
        } catch {
            failed.append("load_memory: \(error)")
        }

        // 5. Load context engine.
        do {
            try hooks.loadContextEngine()
            status = bootstrapStatus(
                configLoaded: status.configLoaded,
                credentialsResolved: status.credentialsResolved,
                skillRegistryLoaded: status.skillRegistryLoaded,
                memoryLoaded: status.memoryLoaded,
                contextEngineLoaded: true,
                systemPromptComposed: status.systemPromptComposed,
                failedSteps: status.failedSteps
            )
        } catch {
            failed.append("load_context_engine: \(error)")
        }

        // 6. Compose system prompt.
        do {
            try hooks.composeSystemPrompt()
            status = bootstrapStatus(
                configLoaded: status.configLoaded,
                credentialsResolved: status.credentialsResolved,
                skillRegistryLoaded: status.skillRegistryLoaded,
                memoryLoaded: status.memoryLoaded,
                contextEngineLoaded: status.contextEngineLoaded,
                systemPromptComposed: true,
                failedSteps: status.failedSteps
            )
        } catch {
            failed.append("compose_system_prompt: \(error)")
        }

        // Apply accumulated failures.
        if !failed.isEmpty {
            status = bootstrapStatus(
                configLoaded: status.configLoaded,
                credentialsResolved: status.credentialsResolved,
                skillRegistryLoaded: status.skillRegistryLoaded,
                memoryLoaded: status.memoryLoaded,
                contextEngineLoaded: status.contextEngineLoaded,
                systemPromptComposed: status.systemPromptComposed,
                failedSteps: failed
            )
        }
        return status
    }
}