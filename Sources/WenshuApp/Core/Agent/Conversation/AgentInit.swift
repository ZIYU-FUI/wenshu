//
//  AgentInit.swift · Wenshu · P9-AGENT-INIT-HERMES-PORT (2026-09-19)
//
//  AIAgent bootstrap helpers. Faithful 1:1 port of
//  hermes `agent/agent_init.py` pure helpers per spec
//  §3.1 #23 = TICKET-HERMES-GAP-006 follow-up.
//
//  Wenshu-side wins (= per AGENTS.md §11.3):
//
//  Hermes `agent_init.py` is the implementation of
//  `AIAgent.__init__` (= 60+ parameters, 1400 lines of
//  attribute initialization + provider auto-detection +
//  credential resolution + context-engine bootstrap).
//  The full `init_agent` body is too large to port in a
//  single Q112 ticket (= would exceed the 1-ticket-1-file
//  scope), so this P9 ticket ports only the 3 hermes
//  PURE HELPERS that are reusable outside the AIAgent
//  class:
//
//    1. _resolve_compression_threshold (= hermes L93-L120)
//    2. _normalized_custom_base_url (= hermes L183-L187)
//    3. _custom_provider_model_matches (= hermes L189-L194)
//
//  These 3 helpers close the audit-described gap
//  (= "wrong file = subagent lifecycle, NOT for
//  agent_init bootstrap"). The wenshu-side bootstrap
//  layer (`WenshuConductor.bootstrap()`) already exists
//  and is the source of truth per AGENTS.md §11.3; this
//  hermes port adds the reusable pure helpers that
//  WenshuConductor can opt into for parity with hermes
//  behavior.
//
//  Per AGENTS.md §11.3 wenshu-side wins:
//   - Pre-existing `WenshuConductor` + `RuntimeHelpers`
//     + `WenshuAppDelegate` own the actual bootstrap flow.
//   - The hermes Codex gpt-5.4/5.5 autoraise notice logic
//     (= hermes `_codex_gpt55_autoraise_notice_marker`)
//     is hermes-specific (Codex OAuth family = the only
//     provider with this autoraise pattern; = wenshu's
//     MiniMax CN connector doesn't share this behavior).
//   - The `init_agent` body itself (= hermes L260-L2100)
//     is out of scope for this ticket per Q112 (= one
//     ticket per file = the body is 1840+ lines and would
//     require multiple split tickets per Q46 stop-rule).
//
//  Hermes Python line ranges cited in doc-comments below
//  (= for traceability back to
//  `/Volumes/ANAN/.hermes/agent/agent_init.py`).
//
//  Per AGENTS.md §11 hard rule: Apple Foundation only. No
//  third-party imports.
//

import Foundation

// MARK: - CompressionThresholdResult

/// Result of resolving the compression threshold (= hermes
/// `_resolve_compression_threshold` return tuple at
/// `agent/agent_init.py` L93-L120).
///
/// - `effectiveThreshold`: The threshold to use for
///   compaction (= global_threshold or per-model override).
/// - `autoraiseNotice`: When the Codex autoraise actually
///   raised the threshold (= a Codex gpt-5.4/5.5 272K family
///   or gpt-5.3-codex-spark model with a higher per-model
///   threshold), this is `{"model", "from", "to"}` so the
///   UI can show the one-time notice; otherwise nil.
public struct CompressionThresholdResult: Sendable, Equatable {
    public let effectiveThreshold: Double
    public let autoraiseNotice: AutoraiseNotice?

    public init(
        effectiveThreshold: Double,
        autoraiseNotice: AutoraiseNotice? = nil
    ) {
        self.effectiveThreshold = effectiveThreshold
        self.autoraiseNotice = autoraiseNotice
    }
}

/// Codex autoraise notice (= hermes dict shape at
/// `agent/agent_init.py` L114-L118).
public struct AutoraiseNotice: Sendable, Equatable {
    public let model: String?
    public let from: Double
    public let to: Double

    public init(model: String?, from: Double, to: Double) {
        self.model = model
        self.from = from
        self.to = to
    }
}

// MARK: - Public API

/// Pure-function: combine the user's global compaction
/// threshold with a per-model override (= hermes
/// `_resolve_compression_threshold` at
/// `agent/agent_init.py` L93-L120).
///
/// - Parameters:
///   - globalThreshold: The user's configured global
///     compaction threshold (= baseline).
///   - modelThreshold: The per-model override threshold
///     (= optional).
///   - model: The model slug (= used for the autoraise
///     notice metadata; = optional).
///   - isCodexAutoraise: When true, the override is a
///     Codex autoraise (= must never lower a higher
///     user-configured threshold).
/// - Returns: `(effective_threshold, autoraise_notice)`.
///   `autoraise_notice` is `{"model", "from", "to"}` only
///   when a Codex autoraise actually raised the threshold,
///   otherwise nil.
///
/// **Codex autoraise rule** (= hermes L107-L119): The
/// Codex overrides are *autoraises* — they must never
/// LOWER a higher user-configured threshold. A user who
/// already set `compression.threshold` above the raised
/// value deliberately keeps more raw context, and
/// silently dropping them would both waste usable window
/// and contradict the feature's purpose (= use more of
/// the window). Other overrides (= e.g. Arcee Trinity)
/// keep their existing unconditional behavior.
public func resolveCompressionThreshold(
    globalThreshold: Double,
    modelThreshold: Double?,
    model: String? = nil,
    isCodexAutoraise: Bool = false
) -> CompressionThresholdResult {
    guard let modelThreshold = modelThreshold else {
        return CompressionThresholdResult(effectiveThreshold: globalThreshold)
    }
    if isCodexAutoraise {
        // Autoraise never lowers; keep the user's
        // higher/equal threshold.
        if modelThreshold <= globalThreshold + 1e-9 {
            return CompressionThresholdResult(effectiveThreshold: globalThreshold)
        }
        return CompressionThresholdResult(
            effectiveThreshold: modelThreshold,
            autoraiseNotice: AutoraiseNotice(
                model: model,
                from: globalThreshold,
                to: modelThreshold
            )
        )
    }
    return CompressionThresholdResult(effectiveThreshold: modelThreshold)
}

/// Pure-function: normalize a custom base URL value
/// (= hermes `_normalized_custom_base_url` at
/// `agent/agent_init.py` L183-L187).
///
/// - Returns: The trimmed value with any trailing slash
///   removed, or empty string for non-string inputs.
public func normalizedCustomBaseURL(_ value: Any) -> String {
    guard let str = value as? String else { return "" }
    return str.trimmingCharacters(in: .whitespaces)
        .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
}

/// Pure-function: test whether a custom-provider config
/// entry matches the agent's model (= hermes
/// `_custom_provider_model_matches` at
/// `agent/agent_init.py` L189-L194).
///
/// - Parameters:
///   - agentModel: The agent's currently selected model
///     slug.
///   - entry: The custom-provider config entry (= dict
///     shape; = `{"model": ...}` field is checked).
/// - Returns: true when the entry's `model` matches the
///   agent model (= or when the entry has no `model` field
///   = the entry is wildcard).
public func customProviderModelMatches(
    agentModel: String,
    entry: [String: Any]
) -> Bool {
    let providerModelRaw = (entry["model"] as? String ?? "")
        .trimmingCharacters(in: .whitespaces)
        .lowercased()
    guard !providerModelRaw.isEmpty else {
        return true
    }
    let agentModelNorm = agentModel
        .trimmingCharacters(in: .whitespaces)
        .lowercased()
    return providerModelRaw == agentModelNorm
}
