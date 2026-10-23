// PromptTierBuilder.swift
//
// Builds the stable tier from what the user chose.
//
// The tier used to be assembled from a fixed set of values: the provider
// was always "unknown", the locale was always Chinese, and every guidance
// switch was hardcoded. The ten switches in `PromptSettings` were stored,
// shown nowhere, and read by nothing.
//
// This file is where the user's choices become prompt content. Two rules
// shape it:
//
// - Every switch in `PromptSettings` maps to exactly one thing here, and
//   every thing here comes from a switch. A value that arrives hardcoded
//   is a value the user cannot change.
// - The guidance text names surfaces that exist. A prompt that tells the
//   model to call a tool it was not given produces a call that fails, so
//   the blocks follow what wenshu has: the memories the runtime injects,
//   and the knowledge tools the model can actually call.

import Foundation

/// Assembles the stable tier from the user's prompt settings.
public enum PromptTierBuilder {

    /// The stable tier, as the user's choices describe it.
    ///
    /// `provider` is a fact about the runtime rather than a choice: the
    /// app knows which provider is configured. The switches come from the
    /// settings the user picked.
    ///
    /// `locale` is the prompt's identity language. Wenshu writes Chinese
    /// novels, so that is the product default; the app's UI language picker
    /// does not reach the prompt (= a separate gap, named in the handoff).
    ///
    /// The project context files sit in the stable tier here, unlike in the
    /// three-tier assembler: the live path has no context tier, and the
    /// file it reads (AGENTS.md) is the project's own, so it belongs with
    /// the identity rather than in the volatile suffix.
    public static func stableTier(
        settings: PromptSettings,
        provider: SystemPrompt.ProviderGuidance,
        locale: SystemPrompt.Locale = .chinese,
        speakingStyle: SpeakingStyle = .literary,
        bookTitle: String? = nil
    ) -> String {
        SystemPrompt.stableTier(
            provider: provider,
            locale: locale,
            // The memory switch covers both blocks: earlier sessions reach
            // the model as injected memories, so the two are one capability
            // from the model's side of the prompt.
            memoryGuidance: settings.memoryGuidanceEnabled,
            sessionSearchGuidance: settings.memoryGuidanceEnabled,
            skillGuidance: settings.skillGuidanceEnabled,
            kanbanGuidance: nil,
            parallelToolGuidance: settings.toolGuidanceEnabled,
            taskCompletionGuidance: true,
            bookTitle: settings.includeBookContext ? bookTitle : nil,
            speakingStyle: speakingStyle,
            identityEnabled: settings.identityEnabled,
            helpGuidanceEnabled: settings.helpGuidanceEnabled,
            includeContextFiles: settings.includeProjectContextFiles,
            includeEnvironmentHints: settings.includeEnvironmentHints,
            providerGuidanceEnabled: settings.providerGuidanceEnabled,
            contextFileMaxChars: settings.projectContextFileMaxChars
        )
    }
}
