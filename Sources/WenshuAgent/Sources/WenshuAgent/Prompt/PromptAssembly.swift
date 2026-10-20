// PromptAssembly.swift
//
// Three cache tiers, ordered stable -> context -> volatile (= hermes
// agent/system_prompt.py::build_system_prompt_parts).
//
// The tier order is the whole point. A provider-side longest-prefix cache
// reuses everything up to the first byte that changed, so anything constant
// must sit in front of anything that is not. Identity and posture never change
// within a session; the project context changes per project; memory,
// timestamps and the working directory change most often. Ordered that way, a
// long novel session re-reads the same identity block every turn.
//
// Three placement rules follow, and the previous code got two of them wrong:
//
// - Book context (title) sits in the context tier AFTER the project context
//   files. Two chapters of one book then share the whole context block instead
//   of stopping at the first book-dependent line. It used to be pushed into
//   the stable tier "for cache stability", which bought a stability the cache
//   did not need and mistook session scope for session constancy.
// - User name joins book context, for the same reason.
// - The current chapter rides TurnNotes on the user message rather than the
//   prompt. It changes as the user writes, and a session-scoped prompt must not
//   change with it.
//
// Rebuilt only at session start and after compression (= hermes
// invalidate_system_prompt).
//
// Section text is delegated to SystemPrompt and PromptBuilder rather than
// restated here: two copies of the same guidance drift, and the older one wins
// because nobody remembers the newer one exists.

import Foundation

/// One assembled system prompt, split at the cache boundaries.
public struct PromptAssembly: Sendable, Equatable {
    /// Byte-stable for the life of a session: identity, posture, guidance.
    public let stable: String
    /// Project-scoped: session lines, then context files, then book context.
    public let context: String
    /// Most volatile: memory snapshot, timestamp, environment.
    public let volatile: String

    public init(stable: String = "", context: String = "", volatile: String = "") {
        self.stable = stable
        self.context = context
        self.volatile = volatile
    }

    /// The single string sent as the system message.
    ///
    /// Empty tiers are dropped rather than joined as empty separators, so a
    /// missing section does not shift the bytes the cache is keyed on.
    public var joined: String {
        [stable, context, volatile]
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }

    public var isEmpty: Bool { stable.isEmpty && context.isEmpty && volatile.isEmpty }
}

/// The inputs one session contributes to prompt assembly.
public struct PromptInputs: Sendable, Equatable {
    /// User's display name. Session-scoped, so it belongs to the context tier.
    public var userName: String?
    /// Book title. Session-scoped, so it belongs to the context tier.
    public var bookTitle: String?
    /// Rendered project context files.
    public var projectContext: String
    /// Memory snapshot taken at session start.
    public var memorySnapshot: String
    /// Rendered environment hints (host, home, working directory).
    public var environment: String
    /// Timestamp line.
    public var timestampLine: String

    public init(
        userName: String? = nil,
        bookTitle: String? = nil,
        projectContext: String = "",
        memorySnapshot: String = "",
        environment: String = "",
        timestampLine: String = ""
    ) {
        self.userName = userName
        self.bookTitle = bookTitle
        self.projectContext = projectContext
        self.memorySnapshot = memorySnapshot
        self.environment = environment
        self.timestampLine = timestampLine
    }
}

/// Assembles the three tiers from settings plus a session's inputs.
public struct PromptAssembler: Sendable {
    public var settings: PromptSettings
    public var provider: SystemPrompt.ProviderGuidance
    public var locale: SystemPrompt.Locale
    public var speakingStyle: SpeakingStyle

    public init(
        settings: PromptSettings = .init(),
        provider: SystemPrompt.ProviderGuidance = .unknown,
        locale: SystemPrompt.Locale = .chinese,
        speakingStyle: SpeakingStyle = .literary
    ) {
        self.settings = settings
        self.provider = provider
        self.locale = locale
        self.speakingStyle = speakingStyle
    }

    /// Build the three tiers for one session.
    ///
    /// Call once at session start and once after compression (= hermes
    /// build_system_prompt). Never per turn.
    public func assemble(_ inputs: PromptInputs) -> PromptAssembly {
        PromptAssembly(
            stable: stableTier(),
            context: contextTier(inputs),
            volatile: volatileTier(inputs)
        )
    }

    private func stableTier() -> String {
        // The stable tier reads no files. Project context files belong to the
        // context tier (= hermes: a shared AGENTS.md must stay reusable across
        // projects, and reading it here would put per-project bytes into the
        // prefix every project shares).
        SystemPrompt.stableTier(
            provider: provider,
            locale: locale,
            memoryGuidance: settings.memoryGuidanceEnabled,
            sessionSearchGuidance: settings.memoryGuidanceEnabled,
            skillGuidance: settings.skillGuidanceEnabled,
            kanbanGuidance: nil,
            parallelToolGuidance: settings.toolGuidanceEnabled,
            taskCompletionGuidance: true,
            userName: nil,
            bookTitle: nil,
            speakingStyle: speakingStyle,
            identityEnabled: settings.identityEnabled,
            helpGuidanceEnabled: settings.helpGuidanceEnabled,
            includeContextFiles: false,
            includeEnvironmentHints: false
        )
    }

    private func contextTier(_ inputs: PromptInputs) -> String {
        var parts: [String] = []

        // Session identity first: same for every chapter of one book, so it
        // stays inside the prefix the chapters share.
        var sessionLines: [String] = []
        if let userName = inputs.userName, !userName.isEmpty {
            sessionLines.append("User: \(userName)")
        }
        if let bookTitle = inputs.bookTitle, !bookTitle.isEmpty {
            sessionLines.append("Book: \(bookTitle)")
        }
        if !sessionLines.isEmpty {
            parts.append(sessionLines.joined(separator: "\n"))
        }

        // Project files after the session lines: constant across books, so
        // leading with them would lengthen the prefix every book shares.
        if settings.includeProjectContextFiles, !inputs.projectContext.isEmpty {
            let capped = PromptBuilder.truncateContent(
                inputs.projectContext,
                filename: "project-context",
                maxChars: settings.projectContextFileMaxChars
            )
            parts.append(capped)
        }

        // Book context last: the first line that differs between two books, so
        // it ends the prefix and nothing after it is wasted cache.
        if settings.includeBookContext, let bookTitle = inputs.bookTitle, !bookTitle.isEmpty {
            parts.append("## Current book\n\n\(bookTitle)")
        }

        return join(parts)
    }

    private func volatileTier(_ inputs: PromptInputs) -> String {
        var parts: [String] = []
        if !inputs.memorySnapshot.isEmpty {
            parts.append(inputs.memorySnapshot)
        }
        if !inputs.timestampLine.isEmpty {
            parts.append(inputs.timestampLine)
        }
        if settings.includeEnvironmentHints, !inputs.environment.isEmpty {
            parts.append(inputs.environment)
        }
        return join(parts)
    }

    private func join(_ parts: [String]) -> String {
        parts.filter { !$0.isEmpty }.joined(separator: "\n\n")
    }
}