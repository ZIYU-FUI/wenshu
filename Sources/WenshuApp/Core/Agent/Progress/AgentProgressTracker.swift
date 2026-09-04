//
//  AgentProgressTracker.swift · Wenshu · v0.41 WIRE-AGENT-006
//
//  P2 #21 wire progress (boss 2026-09-04 OOB 'wire progress from
//  ConversationLoop into OpenBox so user sees step-by-step feedback').
//
//  Library-level (= global, not per-book) progress tracker. Stores
//  ephemeral in-memory entries keyed by chat session id; the OpenBox
//  panel (DynamicZoneView's progress strip) reads `current(sessionId:)`
//  every render cycle to display the running step + ETA.
//
//  Why an actor and not @Observable: the tracker is touched from
//  ConversationLoop (an actor) and from SwiftUI views (MainActor).
//  An actor is the lowest-friction bridge — no main-thread
//  MainActor.assumeIsolated needed in the loop, and views can
//  `await tracker.current(sessionId:)` from `.task` cycles.
//
//  Why no persistence: progress is ephemeral. Each user turn's
//  progress lives only for the duration of that turn. A new app
//  launch starts with an empty tracker (the user shouldn't see
//  stale "step 3 of 7" from a turn that finished yesterday).
//
//  Invariants:
//    1. One entry per `start()` call; advance() and complete() update
//       the most recent entry for that id.
//    2. `current(sessionId:)` returns the most-recent running entry
//       for the session, OR nil if no running entry exists. After
//       complete()/cancel(), the entry is no longer "running" so
//       current() will skip it.
//    3. `list(sessionId:)` returns ALL entries for the session in
//       insertion order (useful for tests + future timeline view).
//
//  Step catalog (matches ConversationLoop.runTurn hooks):
//    1 = "Reading user message"
//    2 = "Compressing context if needed"
//    3 = "Building prompt"
//    4 = "Calling LLM"          <- longest, gets ETA > 0
//    5 = "Parsing response"
//    6 = "Executing tools"
//    7 = "Finalizing reply"
//
//  Apple HIG: no persistence, no global singleton, no UIKit; Swift
//  Concurrency native. Matches KanbanStore's actor pattern (= per-
//  wenshu rule: any SQLite-or-store-style container is an actor).
//

import Foundation

/// A single progress entry (= one in-flight user turn).
///
/// `id` is unique per entry; `sessionId` ties the entry to a chat
/// session. `stepNumber` is 1-based; `totalSteps` is the constant
/// 8 (= see file header step catalog). `etaSeconds` is an estimate
/// (= nil = unknown; positive = estimated remaining seconds).
public struct AgentProgressEntry: Sendable, Codable, Equatable, Identifiable {
    public let id: UUID
    public let sessionId: String
    public var label: String
    public var stepNumber: Int
    public let totalSteps: Int
    public var etaSeconds: Int?
    public var status: Status
    public let createdAt: Date
    public var updatedAt: Date

    public enum Status: String, Sendable, Codable {
        case running
        case succeeded
        case failed
        case cancelled
    }

    public init(
        id: UUID = UUID(),
        sessionId: String,
        label: String,
        stepNumber: Int,
        totalSteps: Int,
        etaSeconds: Int? = nil,
        status: Status = .running,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.sessionId = sessionId
        self.label = label
        self.stepNumber = stepNumber
        self.totalSteps = totalSteps
        self.etaSeconds = etaSeconds
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// Global, library-level progress tracker (= ephemeral, in-memory).
///
/// Pass as a dependency to ConversationLoop (= default = a no-op
/// actor instance via `AgentProgressTracker.noop`). Call `start()`
/// at the beginning of a turn and `complete()` (or `cancel()`) at
/// the end. The OpenBox panel (`DynamicZoneView`'s progress strip)
/// polls `current(sessionId:)` every ~1s to render the running step.
///
/// WIRE-OPENBOX-001 (v0.41 P2 #21): also exposed via `.shared` so
/// the OpenBox progress panel can read the latest running entry
/// without needing a dependency-injection chain (= the panel is
/// constructed via `DynamicZoneView()` in WorkspaceView, no args).
/// The shared instance is the canonical wiring path: callers that
/// want progress emitted (= WenshuConductor, future tickets) pass
/// `AgentProgressTracker.shared` to `ConversationLoop(...progressTracker:)`;
/// callers that don't care (= unit tests) pass `.noop`.
public actor AgentProgressTracker {

    /// Shared singleton for the wenshu process (= WIRE-OPENBOX-001).
    /// The OpenBox panel reads from this; the agent writes to this.
    public static let shared: AgentProgressTracker = AgentProgressTracker()

    /// Default constant for the standard 7-step wenshu conversation
    /// turn (= matches ConversationLoop.runTurn hook order).
    public static let standardStepCount: Int = 7

    /// All entries keyed by entry id. `list(sessionId:)` filters
    /// by `entry.sessionId`.
    private var entries: [UUID: AgentProgressEntry] = [:]

    /// Insertion-ordered list of entry ids per session (= so
    /// `current(sessionId:)` and `list(sessionId:)` return entries
    /// in the order they were created).
    private var sessionOrder: [String: [UUID]] = [:]

    /// No-op singleton. Use when ConversationLoop doesn't need
    /// real progress emission (= e.g. unit tests that don't care).
    public static let noop: AgentProgressTracker = AgentProgressTracker()

    public init() {}

    /// Start a new progress entry for `sessionId`. Returns the
    /// created entry so callers can capture the `id` for later
    /// `advance()` / `complete()` / `cancel()` calls.
    public func start(
        sessionId: String,
        label: String,
        totalSteps: Int = AgentProgressTracker.standardStepCount
    ) async -> AgentProgressEntry {
        let now = Date()
        let entry = AgentProgressEntry(
            sessionId: sessionId,
            label: label,
            stepNumber: 1,
            totalSteps: totalSteps,
            etaSeconds: nil,
            status: .running,
            createdAt: now,
            updatedAt: now
        )
        entries[entry.id] = entry
        sessionOrder[sessionId, default: []].append(entry.id)
        return entry
    }

    /// Advance `entry` to the next step (label = new step label,
    /// stepNumber bumps by 1). Sets ETA to nil (= caller can
    /// override per-step; e.g. step 4 "Calling LLM" sets ETA > 0).
    public func advance(id: UUID, label: String) async {
        guard var entry = entries[id] else { return }
        entry.stepNumber = min(entry.stepNumber + 1, entry.totalSteps)
        entry.label = label
        entry.etaSeconds = nil
        entry.updatedAt = Date()
        entries[id] = entry
    }

    /// Set a custom step number (= e.g. when a step is skipped or
    /// the loop jumps). Also updates label + ETA.
    public func setStep(id: UUID, stepNumber: Int, label: String, etaSeconds: Int? = nil) async {
        guard var entry = entries[id] else { return }
        entry.stepNumber = max(1, min(stepNumber, entry.totalSteps))
        entry.label = label
        entry.etaSeconds = etaSeconds
        entry.updatedAt = Date()
        entries[id] = entry
    }

    /// Mark `entry` as complete (= default status = .succeeded).
    /// After this call, `current(sessionId:)` will skip the entry
    /// (= status != .running).
    public func complete(
        id: UUID,
        status: AgentProgressEntry.Status = .succeeded
    ) async {
        guard var entry = entries[id] else { return }
        entry.status = status
        entry.updatedAt = Date()
        entries[id] = entry
    }

    /// Mark `entry` as cancelled. Alias for `complete(id, .cancelled)`
    /// preserved for caller clarity (= the OpenBox panel treats
    /// .cancelled the same as .failed visually, but the API lets
    /// callers distinguish intent at the call site).
    public func cancel(id: UUID) async {
        await complete(id: id, status: .cancelled)
    }

    /// List all entries for a session, in insertion order.
    public func list(sessionId: String) async -> [AgentProgressEntry] {
        let ids = sessionOrder[sessionId] ?? []
        return ids.compactMap { entries[$0] }
    }

    /// Return the most-recent running entry for a session, OR nil
    /// if no running entry exists (= turn finished, cancelled, or
    /// session never started a turn on this tracker).
    public func current(sessionId: String) async -> AgentProgressEntry? {
        let ids = sessionOrder[sessionId] ?? []
        // Walk from the end (= most-recent insertion first); return
        // the first entry with status == .running.
        for id in ids.reversed() {
            if let entry = entries[id], entry.status == .running {
                return entry
            }
        }
        return nil
    }

    /// Return the most-recent running entry across ALL sessions.
    /// Useful for global "what's the agent doing right now" surfaces
    /// (= e.g. the OpenBox progress panel) that don't know the
    /// current sessionId at construction time.
    ///
    /// Walks all `sessionOrder` lists in insertion order (= most-
    /// recent session first), then each session's ids in reverse
    /// (= most-recent entry first). Returns the first running
    /// entry found, OR nil if no entry is currently running.
    public func currentLatestRunning() async -> AgentProgressEntry? {
        // Walk sessions in REVERSE insertion order (= most recently
        // created session first). Sessions are stored in a dictionary
        // so we collect + reverse-sort them by their first-seen id.
        let allSessionIds = Array(sessionOrder.keys)
        // For deterministic order, sort by session id (= the test
        // surface doesn't require any specific tie-break; here we
        // just want a stable iteration order).
        for sessionId in allSessionIds.sorted().reversed() {
            let ids = sessionOrder[sessionId] ?? []
            for id in ids.reversed() {
                if let entry = entries[id], entry.status == .running {
                    return entry
                }
            }
        }
        return nil
    }
}