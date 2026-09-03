// WikiEntityPreflight.swift · Wenshu (文枢) · v0.34
//
// v0.34 boss 2026-09-02 OOB '其他工程上的机制我不太懂, 你看着定':
// LLM Wiki entity preflight validation (= port of Card-master
// `src/userscript/application/preflight.ts` `userscriptInstallationDiagnostics`).
//
// `WikiEntityPreflight.validate(...)` runs BEFORE `saveReference` is
// called. Returns `[PreflightIssue]` (= array; empty = pass). Critical
// issues block the write (= `EntityIngestion` throws on .error
// severity); warnings log but do not block.
//
// 5 checks (= boss-picked paths from the assistant-readiness.ts
// pattern):
// 1. id present (= non-empty UUID)
// 2. title present (= non-empty string after trim)
// 3. summary present (= non-empty string after trim)
// 4. body markdown present (= non-empty, first H1 matches title)
// 5. duplicate id (= scan all existing references for matching id)
//
// Apple-API-first check: Swift `Codable` + Foundation `UUID` +
// `String.trimmingCharacters` = Apple canonical validation primitives.
// No third-party libs.

import Foundation

/// Severity of a preflight issue (= mirrors ReadinessSeverity from
/// AI/WenshuReadinessCheck.swift; = separate type because the two
/// flows have different lifecycles: preflight = write-time, readiness
/// = launch-time).
enum PreflightSeverity: String, Codable, Sendable, Comparable {
    case warning    // (= log + continue; = non-blocking)
    case error      // (= block write; = EntityIngestion throws)

    private var rank: Int {
        switch self {
        case .warning: return 0
        case .error: return 1
        }
    }

    static func < (lhs: PreflightSeverity, rhs: PreflightSeverity) -> Bool {
        lhs.rank < rhs.rank
    }
}

/// A single preflight issue (= structured for both the throwing
/// path and the user-facing error rendering path).
struct PreflightIssue: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let severity: PreflightSeverity
    /// Chinese user-facing message (= boss 'UI 全中文' rule).
    let message: String
    /// Stable code (= user can grep / count; = e.g. "title.empty").
    let code: String
}

/// Runner. Validates a `Reference` against the existing store
/// (= duplicate-id check requires store scan). Stateless (= all
/// methods are static; = no per-instance config needed).
struct WikiEntityPreflight: Sendable {
    /// Validate a candidate reference. Returns the issues array
    /// (= empty = pass; non-empty = issues found; EntityIngestion
    /// decides whether to throw based on severity).
    ///
    /// The `existingReferences` parameter is the store's current
    /// snapshot (= passed in by the caller to avoid the preflight
    /// reaching into the store itself; = keeps the preflight
    /// testable in isolation).
    static func validate(
        _ reference: Reference,
        bodyMarkdown: String,
        existingReferences: [Reference]
    ) -> [PreflightIssue] {
        var issues: [PreflightIssue] = []

        // Check 1: id present.
        // (= Reference.id is UUID, which is non-empty by type; but
        // we still check for the "all zeros" sentinel which some
        // upstream callers accidentally produce.)
        if reference.id == UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)) {
            issues.append(PreflightIssue(
                id: "preflight-\(reference.id)-id.zero",
                severity: .error,
                message: "实体 ID 为空 UUID（=上游调用方传错了）",
                code: "id.zero"
            ))
        }

        // Check 2: title present.
        let titleTrimmed = reference.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if titleTrimmed.isEmpty {
            issues.append(PreflightIssue(
                id: "preflight-\(reference.id)-title.empty",
                severity: .error,
                message: "实体标题为空",
                code: "title.empty"
            ))
        }

        // Check 3: summary present (= boss 8/26 '卡片要 1 句话说明').
        let summaryTrimmed = reference.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        if summaryTrimmed.isEmpty {
            issues.append(PreflightIssue(
                id: "preflight-\(reference.id)-summary.empty",
                severity: .warning,
                message: "实体概要为空（= 卡片 chrome 会只显示标题没有 1 句话说明）",
                code: "summary.empty"
            ))
        }

        // Check 4: body markdown present + first H1 matches title.
        let bodyTrimmed = bodyMarkdown.trimmingCharacters(in: .whitespacesAndNewlines)
        if bodyTrimmed.isEmpty {
            issues.append(PreflightIssue(
                id: "preflight-\(reference.id)-body.empty",
                severity: .error,
                message: "实体正文为空",
                code: "body.empty"
            ))
        } else if !titleTrimmed.isEmpty {
            // First line should be "# <title>" (= H1 = title convention).
            let firstLine = bodyMarkdown.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? ""
            let expectedH1 = "# \(titleTrimmed)"
            if firstLine != expectedH1 {
                issues.append(PreflightIssue(
                    id: "preflight-\(reference.id)-body.h1.mismatch",
                    severity: .warning,
                    message: "正文首行 H1 与标题不一致（= 期望 '\(expectedH1)'，实际 '\(firstLine)'）",
                    code: "body.h1.mismatch"
                ))
            }
        }

        // Check 5: duplicate id (= scan existing).
        let duplicates = existingReferences.filter { $0.id == reference.id }
        if !duplicates.isEmpty {
            issues.append(PreflightIssue(
                id: "preflight-\(reference.id)-id.duplicate",
                severity: .error,
                message: "实体 ID 重复（= 已存在 '\(duplicates.first?.title ?? "未知")'）",
                code: "id.duplicate"
            ))
        }

        // Return sorted (= most-severe first; = EntityIngestion's
        // throw on .error finds the first critical issue first).
        return issues.sorted { $0.severity > $1.severity }
    }

    /// True if the issue list contains any .error severity (= the
    /// caller should throw and abort the write).
    static func hasErrors(_ issues: [PreflightIssue]) -> Bool {
        issues.contains { $0.severity == .error }
    }
}