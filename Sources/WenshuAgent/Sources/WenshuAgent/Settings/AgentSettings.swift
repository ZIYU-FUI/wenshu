// AgentSettings.swift
//
// One settings surface for every agent behaviour knob (see OOB.md #2026-10-20).
//
// Two rules shape this file. First, the defaults in each initialiser ARE the
// hermes defaults: there is no parallel constants table to drift against.
// Second, the package never reads UserDefaults. The app layer owns persistence
// and injection (= user-visible settings live in Features/Settings); anything
// here that reached for UserDefaults would make the package impossible to
// test and impossible to embed.
//
// Adding a mechanism means adding its settings in the same commit (= a knob
// that arrives hardcoded is a knob that never arrives configurable).

import Foundation

/// Aggregate settings for one agent runtime.
public struct AgentSettings: Sendable, Equatable {
    public var prompt: PromptSettings
    public var turn: TurnSettings
    public var context: ContextSettings
    public var recovery: RecoverySettings
    public var memory: MemorySettings
    public var tools: ToolSettings

    public init(
        prompt: PromptSettings = .init(),
        turn: TurnSettings = .init(),
        context: ContextSettings = .init(),
        recovery: RecoverySettings = .init(),
        memory: MemorySettings = .init(),
        tools: ToolSettings = .init()
    ) {
        self.prompt = prompt
        self.turn = turn
        self.context = context
        self.recovery = recovery
        self.memory = memory
        self.tools = tools
    }
}

/// Toggles for system prompt assembly (= hermes `agent.*` guidance toggles).
public struct PromptSettings: Sendable, Equatable {
    // Section switches.
    public var identityEnabled: Bool
    public var providerGuidanceEnabled: Bool
    public var memoryGuidanceEnabled: Bool
    public var skillGuidanceEnabled: Bool
    public var toolGuidanceEnabled: Bool
    /// The "consult the project conventions before acting" pointer.
    public var helpGuidanceEnabled: Bool

    // Tier sources.
    /// Project context files (= AGENTS.md and friends) into the context tier.
    public var includeProjectContextFiles: Bool
    /// Book-level context (= title, current chapter) into the context tier.
    public var includeBookContext: Bool
    /// Runtime environment hints into the volatile tier.
    public var includeEnvironmentHints: Bool

    /// Tools the agent may call. Empty means every registered tool (= the
    /// whitelist itself lands with the tool-exposure work).
    public var visibleTools: Set<String>

    /// Cap for a project context file before it is truncated. Zero means
    /// derive it from the model's context window (= hermes's
    /// context_file_max_chars, which likewise scales with the window and
    /// floors at 20k).
    public var projectContextFileMaxChars: Int

    public init(
        identityEnabled: Bool = true,
        providerGuidanceEnabled: Bool = true,
        memoryGuidanceEnabled: Bool = true,
        skillGuidanceEnabled: Bool = true,
        toolGuidanceEnabled: Bool = true,
        helpGuidanceEnabled: Bool = true,
        includeProjectContextFiles: Bool = true,
        includeBookContext: Bool = true,
        includeEnvironmentHints: Bool = true,
        visibleTools: Set<String> = [],
        projectContextFileMaxChars: Int = 0
    ) {
        self.identityEnabled = identityEnabled
        self.providerGuidanceEnabled = providerGuidanceEnabled
        self.memoryGuidanceEnabled = memoryGuidanceEnabled
        self.skillGuidanceEnabled = skillGuidanceEnabled
        self.toolGuidanceEnabled = toolGuidanceEnabled
        self.helpGuidanceEnabled = helpGuidanceEnabled
        self.includeProjectContextFiles = includeProjectContextFiles
        self.includeBookContext = includeBookContext
        self.includeEnvironmentHints = includeEnvironmentHints
        self.visibleTools = visibleTools
        self.projectContextFileMaxChars = projectContextFileMaxChars
    }
}

/// Turn-loop knobs. Fields arrive as the corresponding mechanism lands.
public struct TurnSettings: Sendable, Equatable {
    /// Hard ceiling on iterations within one turn.
    public var maxIterations: Int
    /// Retries for a turn that failed for a retryable reason.
    public var maxAttempts: Int

    public init(maxIterations: Int = 90, maxAttempts: Int = 3) {
        self.maxIterations = maxIterations
        self.maxAttempts = maxAttempts
    }
}

/// Context-window knobs.
public struct ContextSettings: Sendable, Equatable {
    /// Fraction of the window at which compression starts.
    public var compressionThreshold: Double
    /// Fraction kept after compression.
    public var compressionKeepRatio: Double

    public init(compressionThreshold: Double = 0.85, compressionKeepRatio: Double = 0.3) {
        self.compressionThreshold = compressionThreshold
        self.compressionKeepRatio = compressionKeepRatio
    }
}

/// Recovery knobs (= the retry ladder's rung boundaries).
public struct RecoverySettings: Sendable, Equatable {
    /// Whether an empty assistant reply triggers a retry.
    public var retryOnEmptyReply: Bool
    /// Whether a truncated reply triggers a retry.
    public var retryOnTruncation: Bool
    /// Backoff before the second attempt, in seconds.
    public var retryBackoffSeconds: Double

    public init(
        retryOnEmptyReply: Bool = true,
        retryOnTruncation: Bool = true,
        retryBackoffSeconds: Double = 2.0
    ) {
        self.retryOnEmptyReply = retryOnEmptyReply
        self.retryOnTruncation = retryOnTruncation
        self.retryBackoffSeconds = retryBackoffSeconds
    }
}

/// Which memory implementation backs the agent.
public enum MemoryBackend: String, Sendable, CaseIterable, Equatable {
    /// Memory lives in the user's library as plain Markdown. No key, nothing
    /// leaves the machine, and the user can read and edit it themselves.
    case localMarkdown
    /// Memory is hosted by an external service with stronger semantic
    /// retrieval. Needs an endpoint and a key.
    case remoteService
}

/// Memory subsystem knobs.
public struct MemorySettings: Sendable, Equatable {
    public var backend: MemoryBackend
    public var enabled: Bool
    public var retentionDays: Int
    public var maxEntries: Int

    /// Local-backend only: folder name under the active library.
    public var localDirectory: String
    /// Remote-backend only: service endpoint.
    public var remoteEndpoint: String

    public init(
        backend: MemoryBackend = .localMarkdown,
        enabled: Bool = true,
        retentionDays: Int = 90,
        maxEntries: Int = 500,
        localDirectory: String = "Memory",
        remoteEndpoint: String = ""
    ) {
        self.backend = backend
        self.enabled = enabled
        self.retentionDays = retentionDays
        self.maxEntries = maxEntries
        self.localDirectory = localDirectory
        self.remoteEndpoint = remoteEndpoint
    }
}

/// Tool-exposure knobs. Fields arrive as the tool work lands.
public struct ToolSettings: Sendable, Equatable {
    /// Whether tools may run without asking.
    public var autoApprove: Bool
    /// Whether tool calls are recorded in the transcript.
    public var recordTranscripts: Bool

    public init(autoApprove: Bool = false, recordTranscripts: Bool = true) {
        self.autoApprove = autoApprove
        self.recordTranscripts = recordTranscripts
    }
}