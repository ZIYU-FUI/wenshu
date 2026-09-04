// WenshuReadinessCheck.swift · Wenshu (文枢) · v0.34
//
// v0.34 boss 2026-09-02 OOB: wenshu startup readiness check (= port of
// Card-master `src/ai/domain/assistant-readiness.ts`).
//
// `WenshuReadinessCheck` runs at app launch to surface configuration
// gaps (= missing API key, unreachable provider endpoint, etc.) before
// the user clicks chat (= better UX = user sees the banner immediately,
// not after the first failed chat request).
//
// 3 capabilities are checked (= chat / LLM Wiki / image gen). Each
// capability has its own `ReadinessProvider` (= protocol). Results are
// surfaced to the user via a SwiftUI banner in the main UI (= Apple
// canonical `ContentUnavailableView` for macOS 14+).
//
// Apple-API-first check: `ContentUnavailableView` (= macOS 14+) for
// the banner UI = Apple canonical empty-state view. No third-party
// dependency needed.

import Foundation

/// Severity of a readiness issue. Drives whether the user-facing
/// banner is shown (= .critical) or just logged (= .warning).
enum ReadinessSeverity: String, Codable, Sendable, Comparable {
    case info       // (= informational; no banner)
    case warning    // (= degrade; banner shows but app still works)
    case critical   // (= blocking; banner shows + guides user to fix)

    /// Comparable: `critical > warning > info` (= `.critical` is the
    /// most severe).
    private var rank: Int {
        switch self {
        case .info: return 0
        case .warning: return 1
        case .critical: return 2
        }
    }

    static func < (lhs: ReadinessSeverity, rhs: ReadinessSeverity) -> Bool {
        lhs.rank < rhs.rank
    }
}

/// A single readiness issue (= capability = `chat` / `wiki` / `imageGen`,
/// code = specific failure mode, severity = how serious, message =
/// user-facing Chinese text shown in the banner).
struct ReadinessIssue: Identifiable, Hashable, Codable, Sendable {
    let id: String          // stable id (= e.g. "chat.apiKey.missing")
    let capability: ReadinessCapability
    let severity: ReadinessSeverity
    /// Chinese user-facing description (= Apple HIG localization =
    /// shipped in zh-Hans; v0.34 = single-locale).
    let message: String
    /// Suggested action (= "去设置 → 服务配置 → 图像生成填写").
    let actionLabel: String?
}

/// Which wenshu capability is being checked (= per Issue 05 spec).
enum ReadinessCapability: String, Codable, Sendable, CaseIterable {
    case chat       // (= wenshu chat via LLM provider)
    case wiki       // (= LLM Wiki entity ingestion)
    case imageGen   // (= AI thumbnail generation)

    /// User-facing Chinese display label (= boss 8/25 UI Chinese-only
    /// rule: every UI label reads in Chinese).
    var displayName: String {
        switch self {
        case .chat:     return "聊天"
        case .wiki:     return "资料库调研"
        case .imageGen: return "缩略图生成"
        }
    }
}

/// Single-capability readiness check. Each capability (= chat / wiki /
/// imageGen) has its own provider (= conforms to this protocol). The
/// runner aggregates results.
protocol ReadinessProvider: Sendable {
    var capability: ReadinessCapability { get }

    /// Synchronous check (= returns immediately). Used at startup.
    /// Returns an empty array if the capability is fully ready.
    func checkReadiness() async -> [ReadinessIssue]
}

/// Aggregated readiness result (= runs all providers + flattens
/// issues into a single severity-sorted list).
struct ReadinessReport: Sendable {
    let issues: [ReadinessIssue]
    let runAt: Date

    /// The most severe issue in the report (= `nil` if all providers
    /// report zero issues = fully ready).
    var topSeverity: ReadinessSeverity? {
        issues.map(\.severity).max()
    }

    /// True if any critical issue exists (= banner MUST show).
    var hasCritical: Bool {
        issues.contains { $0.severity == .critical }
    }

    /// True if fully ready (= zero issues).
    var isReady: Bool {
        issues.isEmpty
    }
}

/// Runner. Aggregates a list of `ReadinessProvider`s (= chat + wiki +
/// imageGen) into a single `ReadinessReport`. Per-Issue 02 + Issue 06
/// the providers consult `ProviderKeychain` (= existing wenshu key
/// storage) and ImageGen providers' `hasAPIKey` flag.
struct WenshuReadinessCheck: Sendable {
    let providers: [any ReadinessProvider]

    /// Run run all checks (= 1 async call per provider, results
    /// flattened + severity-sorted). Returns even when issues exist
    /// (= caller decides whether to show the banner).
    func run() async -> ReadinessReport {
        var allIssues: [ReadinessIssue] = []
        for provider in providers {
            let issues = await provider.checkReadiness()
            allIssues.append(contentsOf: issues)
        }
        // Sort by severity descending (= critical first).
        allIssues.sort { $0.severity > $1.severity }
        return ReadinessReport(issues: allIssues, runAt: .now)
    }
}

// MARK: = Default readiness providers (= chat + wiki + imageGen)

// v0.34 boss 2026-09-02 OOB: chat readiness provider. Checks if a
// primary LLM provider is configured in `ProviderKeychain` with a
// non-empty API key. The chat provider is the `currentProvider` set
// in `Settings` (= defaults to `.minimaxCn`).
struct ChatReadinessProvider: ReadinessProvider {
    let capability: ReadinessCapability = .chat
    let currentProvider: Provider

    func checkReadiness() async -> [ReadinessIssue] {
        guard let key = ProviderKeychain.loadKeySync(for: currentProvider),
              !key.isEmpty else {
            return [ReadinessIssue(
                id: "chat.apiKey.missing",
                capability: .chat,
                severity: .critical,
                message: "聊天未配置 API 密钥。",
                actionLabel: "前往设置 → 服务配置 → \(currentProvider.name) 填写"
            )]
        }
        return []
    }
}

// v0.34: wiki (= LLM Wiki entity ingestion) reuses the chat API key
// (= LLM Wiki talks to the same provider as chat). If the chat key is
// configured, wiki is ready; otherwise wiki is also blocked.
struct WikiReadinessProvider: ReadinessProvider {
    let capability: ReadinessCapability = .wiki
    let currentProvider: Provider

    func checkReadiness() async -> [ReadinessIssue] {
        guard let key = ProviderKeychain.loadKeySync(for: currentProvider),
              !key.isEmpty else {
            return [ReadinessIssue(
                id: "wiki.apiKey.missing",
                capability: .wiki,
                severity: .warning,
                message: "资料库调研未配置 API 密钥，将无法从聊天提取调研条目。",
                actionLabel: "前往设置 → 服务配置 → \(currentProvider.name) 填写"
            )]
        }
        return []
    }
}

// v0.34: image-gen readiness. Checks if at least one of the configured
// image-gen providers (= DashScope primary + OpenAI fallback) has an
// API key. If both are empty, image-gen is unavailable (= cards show
// the placeholder forever = info-level warning, not critical).
struct ImageGenReadinessProvider: ReadinessProvider {
    let capability: ReadinessCapability = .imageGen
    let primary: any ImageGenProvider
    let fallback: (any ImageGenProvider)?

    func checkReadiness() async -> [ReadinessIssue] {
        if primary.hasAPIKey || (fallback?.hasAPIKey ?? false) {
            return []
        }
        return [ReadinessIssue(
            id: "imageGen.apiKey.missing",
            capability: .imageGen,
            severity: .warning,
            message: "缩略图生成未配置 API 密钥，卡片封面将始终显示占位图。",
            actionLabel: "前往设置 → 服务配置 → 图像生成填写"
        )]
    }
}