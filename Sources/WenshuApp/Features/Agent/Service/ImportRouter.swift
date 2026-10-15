//
//  ImportRouter.swift
//
//  Part of the markdown import feature. Pure protocol (= the orchestrator
//  imports the protocol, not the concrete router; = the unit tests inject
//  a stub router that returns canned ImportRoutingResult values per file).
//

import Foundation

// MARK: - ImportRouter (the seam between ImportService and the LLM agent)

/// Sealed seam between the orchestrator (= ImportService)
/// and the LLM agent (= WenshuConductor + Librarian; =
/// implemented in T4). Lets the orchestrator drive the
/// per-file routing without taking a hard dependency on
/// the conductor (= the unit tests inject a stub router
/// that returns canned ImportRoutingResult values per
/// file).
///
/// Why a protocol (= not a closure):
/// - The router may need to talk to a long-lived service
///   (= the conductor; = not safe to capture by value in
///   a closure).
/// - The router signature is stable (= the wire shape from
///   T1) and the orchestrator's tests want to inject a
///   stub; = a protocol is the canonical Swift seam for
///   this.
protocol ImportRouter: Sendable {
    /// Route + enrich one file. The router reads the file
    /// body from `filePath` (= it does NOT mutate the body; =
    /// the LLM's role is classification + metadata
    /// enrichment per the boss's 2026-10-09 directive).
    /// Returns the ImportRoutingResult (= destination +
    /// metadata); = the orchestrator dispatches on the
    /// destination to decide the write path.
    /// optional `progress` callback (= the
    /// router emits human-readable Chinese activity lines;
    /// = the orchestrator's `appendActivity` appends them
    /// to the per-row `activityLog`; = the sheet shows
    /// them in a scrolling terminal-like view in real
    /// time). nil = no logging (= the default; = tests
    /// don't need it).
    func route(
        _ input: ImportFileInput,
        progress: (@Sendable (String) async -> Void)?
    ) async throws -> ImportRoutingResult
    /// (= boss
    /// 2026-10-10 "我选
    /// 故事宪法，直
    /// 接跳到了步
    /// 骤 3，没
    /// 有重新
    /// 分析是
    /// 不是
    /// 内容
    /// 相同
    /// " 反馈).
    /// Phase 2 LLM
    /// decision: are
    /// the source body
    /// and the existing
    /// body "the same
    /// content"? (=
    /// the orchestrator
    /// invokes this
    /// ONLY when
    /// Phase 1 found a
    /// same-titled file
    /// in the destination
    /// folder; = the
    /// LLM returns
    /// `isContentSame`
    /// + `confidence`;
    /// = the orchestrator
    /// uses the
    /// threshold from
    /// `ImportDocumentTemplate.contentSameConfidenceThreshold`
    /// to decide
    /// between skip
    /// and overwrite).
    func isContentSame(
        sourceBody: String,
        existingBody: String,
        sourceTitle: String
    ) async throws -> ContentSameResult
}
