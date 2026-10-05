//
//  AgentBehavior.swift
//
//  Agent-behavior settings = wenshu's stable contract for the
//  LLM's reply style, scope, and surface preferences.
//
//  Scope (= v2.4 2026-09-25 decision):
//  - These settings are wenshu-PROVIDED PRESETS, not user-editable
//    text. Users pick from a closed enum; = same product philosophy
//    as wenshu's existing AppearanceMode (system / dark / light).
//  - Persisted to UserDefaults per-user (= follows the rest of
//    Settings → General → userAddress pattern).
//  - Read at LLM-call time by `SystemPrompt.stableTier()` (=
//    the canonical identity source) so the setting actually
//    affects the reply style.
//
//  Anti-pattern (= explicitly NOT done):
//  - No SOUL.md / AGENTS.md / user-editable markdown loader.
//    Per v2.4 2026-09-25 decision: "user cannot change agent definition, style, etc.".
//    User-customizable soul files would let non-technical users
//    degrade the LLM into an unusable state (= the wenshu 商业化
//    product prefers system-managed stable output over user
//    expression freedom; = same philosophy as Notion / Linear /
//    Bear's AI settings).
//
//  Adding a new agent-behavior setting in future tickets:
//  1. Add a new enum below (= closed set of presets).
//  2. Add a new `current<X>` + `setCurrent<X>` pair (UserDefaults
//     bridge).
//  3. Add a UI row in SettingView.swift `agentBehaviorTab`.
//  4. Add an i18n key in both en.lproj + zh-Hans.lproj.
//  5. Inject the new setting into SystemPrompt.stableTier()
//     (= the only place the LLM sees it).

import Foundation

// MARK: - SpeakingStyle

/// Reply style preset (= closed enum; = users pick from these 4,
/// no custom string input allowed). Drives the "Speaking style"
/// section appended to the system prompt.
enum SpeakingStyle: String, CaseIterable, Identifiable, Sendable {
    case formal
    case casual
    case literary
    case concise

    var id: String { rawValue }

    /// User-visible label (= follows the OS locale; = see String(localized:)
    /// fallback for non-localized environments).
    var label: String {
        switch self {
        case .formal:   return "演讲式"
        case .casual:   return "口语化"
        case .literary: return "文学化"
        case .concise:  return "简洁"
        }
    }

    /// Per-style guidance appended to the system prompt's stable
    /// tier. Sentences are short and concrete so the LLM picks up
    /// the register reliably.
    var promptGuidance: String {
        switch self {
        case .formal:
            return "Speaking style: formal. Use measured, third-person prose. Avoid colloquialisms, contractions, and rhetorical questions. Maintain a dignified narrative voice throughout."
        case .casual:
            return "Speaking style: casual. Use first/second-person direct address and natural spoken Chinese. Light contractions and everyday idiom are fine. Prioritize readability over elegance."
        case .literary:
            return "Speaking style: literary. Use rich sensory language, varied sentence lengths, occasional metaphors, and rhythmic prose. Aim for evocative, image-driven description."
        case .concise:
            return "Speaking style: concise. Keep replies short and information-dense. One idea per sentence. No flourish, no preamble, no closing pleasantries."
        }
    }
}

// MARK: - UserDefaults bridge

/// Centralized UserDefaults accessors for the agent-behavior
/// settings (= per-user, app-wide; = NOT per-book).
///
/// Adding a new setting? Add a new `currentX()` + `setCurrentX(_:)`
/// pair following the same shape.
enum AgentBehavior {
    /// UserDefaults key for `SpeakingStyle`. Stable (= never
    /// rename; = user data migration depends on it).
    static let speakingStyleKey = "wenshu.agent.behavior.speakingStyle"

    /// Read the user's currently-selected speaking style. Defaults
    /// to `.literary` (= the canonical wenshu writing-tool register;
    /// = a Chinese-novel assistant should sound like a writer by
    /// default, not like a customer-support bot).
    static func currentSpeakingStyle(
        defaults: UserDefaults = .standard
    ) -> SpeakingStyle {
        guard let raw = defaults.string(forKey: speakingStyleKey),
              let style = SpeakingStyle(rawValue: raw)
        else {
            return .literary
        }
        return style
    }

    /// Write a new speaking style selection.
    static func setCurrentSpeakingStyle(
        _ style: SpeakingStyle,
        defaults: UserDefaults = .standard
    ) {
        defaults.set(style.rawValue, forKey: speakingStyleKey)
    }
}