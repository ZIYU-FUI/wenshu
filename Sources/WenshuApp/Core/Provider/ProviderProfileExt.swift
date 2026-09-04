// ProviderProfileExt.swift · Wenshu · v0.28
//
// Extension to the existing Provider struct (= v0.21 ticket 01) with the
// optional fields from hermes-agent/providers/base.py ProviderProfile
// (= wenshu M6 ticket 16 = hermes-port batch 3 sixth ticket).
//
// Source (= hermes Python):
// - providers/base.py L41-267 (= ProviderProfile dataclass with 30+
//   declarative fields = auth, endpoints, client quirks, model metadata,
//   request-time quirks)
// - agent/models_dev.py L1-1550 (= models.dev catalog fetcher + parser;
//   external JSON catalog at https://models.dev/api.json)
// - agent/model_metadata.py L1-3926 (= per-model metadata = cost,
//   context_window, capabilities, modalities)
//
// Target (= wenshu Swift):
// - Sources/WenshuApp/Core/Provider/ProviderProfileExt.swift (this file,
//   ~300 LOC) = optional extension to the existing Provider struct that
//   carries the hermes-side declarative fields. Pure data; no behavior.
// - Sources/WenshuApp/Core/Provider/ModelMetadata.swift (~120 LOC) =
//   per-model metadata struct (= hermes model_metadata.py ports the
//   subset relevant to wenshu's v1 minimax-cn-only deployment).
// - Tests/WenshuAppTests/Core/Provider/ProviderProfileExtTests.swift
//   (~80 LOC, 10 tests covering the extension surface).
//
// Scope refactor (= per Q109 doc-first + Q35 commit-description vs truth):
// The hermes ProviderProfile + models_dev + model_metadata system is
// 5743 LOC across 3 files. Wenshu's v0.21 Provider struct already covers
// the bulk of the auth + endpoints surface; the additions this ticket
// brings are the OPTIONAL fields (aliases, display_name, description,
// signup_url, user_agent_strategy, request_quirks) that hermes uses for
// advanced provider quirks (= OpenCode Zen WAF bypass, Kimi temperature
// omission, etc.).
//
// Wenshu's v1 deployment targets minimax cn only (= Anthropic-compatible
// protocol); the multi-provider complexity in hermes's models_dev
// catalog is OUT of scope for this ticket. The ModelMetadata struct
// added here covers ONLY the fields wenshu consumes (= display cost,
// context_window, capabilities), so a future v1.5+ migration to a
// second provider has a clean extension point.
//
// per AGENTS.md Section 8 pollution-defense hex-encoding rule:
// this file does NOT contain the 12-token forbidden vocab literal;
// the rule enumeration is referenced semantically only.

import Foundation

// MARK: - Optional Provider extensions (= hermes ProviderProfile fields)

/// Extension carrying hermes-side declarative fields on the existing
/// Provider struct. Used to express quirks (= OpenCode Zen WAF bypass,
/// Kimi temperature omission) without growing the base struct.
struct ProviderProfileExt: Sendable, Hashable {
    /// Alternative slugs that map to this provider (= e.g. 'openrouter'
    /// might also be 'or' or 'open-router'). Used when users type
    /// informal aliases in the chat input.
    let aliases: [String]

    /// Human-readable name for picker / labels (= e.g. 'GMI Cloud').
    /// Falls back to Provider.name if empty.
    let displayName: String

    /// Short description for the picker subtitle (= e.g. 'GMI Cloud
    /// (multi-model direct API)').
    let description: String

    /// Signup URL shown during the setup wizard.
    let signupURL: String

    /// User-Agent strategy (= which UA string to send on HTTP requests).
    /// Most providers accept the default. OpenCode Zen requires a
    /// non-default UA to bypass the WAF (= returns 403 for the
    /// Python-urllib default).
    let userAgentStrategy: UserAgentStrategy

    /// Request-time quirks (= how to shape requests to avoid known
    /// provider-specific bugs).
    let requestQuirks: [RequestQuirk]

    enum UserAgentStrategy: String, Sendable, Hashable, CaseIterable {
        case `default`           // send "Python-urllib/<ver>" (= standard)
        case customBrowserUA     // send "hermes-cli/<ver>" (= bypasses WAF)
        case omit                // omit UA header entirely
    }

    enum RequestQuirk: String, Sendable, Hashable, CaseIterable {
        case omitTemperature         // Kimi: server manages temperature
        case omitStopSequences       // some models reject stop= parameter
        case dropEmptyMessages       // some gateways 400 on empty content
        case useAnthropicVersionHeader  // Anthropic API requires
                                        // `anthropic-version: 2023-06-01`
    }

    static let empty = ProviderProfileExt(
        aliases: [],
        displayName: "",
        description: "",
        signupURL: "",
        userAgentStrategy: .default,
        requestQuirks: []
    )
}

extension Provider {
    /// The optional hermes-side extension surface. Defaults to `.empty`.
    /// (= backward-compatible: existing Provider instances that don't
    /// initialize this field get the default no-quirks behavior.)
    var profileExt: ProviderProfileExt {
        get {
            ProviderCatalog.profileExt(for: self.slug) ?? .empty
        }
    }
}

// MARK: - Per-model metadata (= hermes model_metadata.py subset)

/// Per-model metadata (= context window, capabilities, cost).
/// Mirrors the wenshu-relevant subset of hermes `model_metadata.py`.
/// Used by the chat UI to surface the current model's context budget
/// (= for token-budget warnings) + capabilities (= to gate which
/// features are available for the selected model).
struct ModelMetadata: Sendable, Hashable, Codable {
    /// Canonical model id (= e.g. 'claude-opus-4.8').
    let id: String

    /// Display name shown in the model picker.
    let displayName: String

    /// Provider slug (= e.g. 'openrouter', 'minimax-cn').
    let providerSlug: String

    /// Maximum context window in tokens.
    let contextWindow: Int

    /// Cost per million input tokens (= USD). 0 if free.
    let costPerMillionInput: Double

    /// Cost per million output tokens (= USD). 0 if free.
    let costPerMillionOutput: Double

    /// Capabilities (= which feature gates this model supports).
    let capabilities: Set<Capability>

    /// Modalities (= text / image / audio in/out).
    let modalities: Set<Modality>

    enum Capability: String, Sendable, Hashable, Codable, CaseIterable {
        case chat
        case streaming
        case tools
        case vision
        case extendedThinking
        case promptCaching
    }

    enum Modality: String, Sendable, Hashable, Codable, CaseIterable {
        case textInput
        case textOutput
        case imageInput
        case imageOutput
        case audioInput
        case audioOutput
    }
}

// MARK: - ModelMetadata catalog (= v1 model list)

extension ModelMetadata {
    /// Static catalog of known models (= the v1 deployment only ships
    /// the 3 canonical MiniMax series). Future models can extend this list.
    /// IDs are aligned with Provider.swift's `defaultModels` lists:
    ///   Provider.minimax.defaultModels = ["MiniMax-M3", "MiniMax-M2", "MiniMax-Reasoning"]
    ///   Provider.minimaxCn.defaultModels = ["MiniMax-M3", "MiniMax-M2", "MiniMax-Reasoning"]
    static let catalog: [ModelMetadata] = [
        ModelMetadata(
            id: "MiniMax-M3",
            displayName: "MiniMax M3",
            providerSlug: "minimax-cn",
            contextWindow: 128_000,
            costPerMillionInput: 0,
            costPerMillionOutput: 0,
            capabilities: [.chat, .streaming, .tools],
            modalities: [.textInput, .textOutput]
        ),
        ModelMetadata(
            id: "MiniMax-M2",
            displayName: "MiniMax M2",
            providerSlug: "minimax-cn",
            contextWindow: 128_000,
            costPerMillionInput: 0,
            costPerMillionOutput: 0,
            capabilities: [.chat, .streaming],
            modalities: [.textInput, .textOutput]
        ),
        ModelMetadata(
            id: "MiniMax-Reasoning",
            displayName: "MiniMax Reasoning",
            providerSlug: "minimax-cn",
            contextWindow: 128_000,
            costPerMillionInput: 0,
            costPerMillionOutput: 0,
            capabilities: [.chat, .streaming, .extendedThinking],
            modalities: [.textInput, .textOutput]
        )
    ]

    /// Lookup by canonical model id.
    static func metadata(forModelID id: String) -> ModelMetadata? {
        catalog.first { $0.id == id }
    }
}