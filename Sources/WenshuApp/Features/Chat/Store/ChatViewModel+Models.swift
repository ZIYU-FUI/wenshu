// ChatViewModel+Models.swift = part of ChatViewModel, = = moved out of ChatSessionViewModel.swift.
// The members below keep their own comments; = = the class's stored
// properties stay in ChatViewModel.swift (= = an extension cannot hold them).

import Foundation
import os.log
import WenshuAgent
import WenshuData

extension ChatViewModel {
    /// When no `AppState` is injected (= a standalone `ChatViewModel` initialised
    /// without the app-wide environment), the model id defaults to the empty
    /// string read straight from `UserDefaults`, so the model picker shows nothing
    /// rather than a hard-coded model. The pattern is locked down by
    /// `ChatViewModelDefaultModelTests`.
    var currentModel: String {
        let raw = appState?.llmModel
            ?? UserDefaults.standard.string(forKey: "wenshu.llm.model")
            ?? ""
        // The model selection can be empty (= the first launch with no
        // `UserDefaults` entry AND no appState wiring). The chat would then send
        // a POST with an empty `model`, which the provider rejects with HTTP 400,
        // so the SSE stream emits no events and the chat bubble stays empty. Fall
        // back to the active provider's first default model (= the canonical
        // "this is the model the user configured" pick).
        if !raw.isEmpty {
            return raw
        }
        let activeSlug = WenshuAppDelegateLLMHelpers.activeConnectorSlug()
        let provider = Provider.by(slug: activeSlug)
        if let firstDefault = provider?.defaultModels.first, !firstDefault.isEmpty {
            return firstDefault
        }
        return "MiniMax-M3"
    }

    /// Updates the active scope (= called by the view layer when the user
    /// picks a different book). It sets the session id and reloads the
    /// history. It is a no-op when the scope is unchanged.
    func setCurrentBookID(_ bookID: BookID?) {
        if currentBookID == bookID {
            return
        }
        currentBookID = bookID
        // Per-book session id: same key prefix + bookID suffix so the global
        // session rows and the per-book session rows can coexist in the same
        // SwiftData store (= the WSChatMessage.bookID column is what scopes
        // reads, not the session id).
        sessionId = Self.makeSessionID(for: bookID)
        // Fire-and-forget reload against the new scope.
        Task { await self.loadHistory() }
    }

    /// Updates the active scope to a whole conversation scope.
    ///
    /// The scope is the chat zone's top bar's unit (= the repository
    /// conversation, = one per ordinary book, = the reference-library
    /// conversation), and it owns two things: the session id the
    /// conversation is stored under, and the book id the conversation is
    /// scoped to.
    ///
    /// It is a no-op when the scope is unchanged, so a repeated write of
    /// the same scope does not reload the history.
    func setScope(_ scope: ChatScope) {
        let newBookID = scope.bookID
        guard currentBookID != newBookID || sessionId != scope.sessionID else {
            return
        }
        currentBookID = newBookID
        // The scope owns the session id: a book scope keeps the per-book
        // key, and the two fixed scopes take their own keys (= the
        // repository conversation keeps the historical `default` key, =
        // so the rows written before this feature existed stay
        // reachable).
        sessionId = scope.sessionID
        // Fire-and-forget reload against the new scope.
        Task { await self.loadHistory() }
    }

    func switchModel(_ id: String) {
        // Write to the canonical owner (= AppState.llmModel), which then mirrors
        // to UserDefaults via its didSet. No raw UserDefaults call here (= single
        // owner maintained).
        appState?.llmModel = id
    }

    /// Opens the settings pane at the provider's API section. The UI layer must
    /// not call the data layer directly: the canonical route is the ChatZoneView,
    /// which is the UI layer, into the business layer.
    func openSettingsToProviderApi() {
        UserDefaultsStore.shared.setString("providerApi", forKey: .settingsTab)
    }

    func loadAvailableModels() async {
        // Use multi-provider discovery (= query all configured
        // `WenshuLLMModel.allCases` = 3 MiniMax-only cases).
        //
        // The optional models are read from the API, never written down:
        // use the live `loadLive()` (= calls
        // `LLMModelDiscovery.discover` for each
        // configured provider, which hits the
        // provider's `/models` endpoint and falls
        // back to `Provider.defaultModels` when the
        // endpoint is unreachable).
        let configured = await AvailableModelsDiscovery.loadLive()
        var modelIds: [String] = []
        for section in configured {
            for modelId in section.models {
                // Prefix with provider slug for clarity (e.g. "anthropic / claude-3.7-sonnet").
                modelIds.append(modelId)
            }
        }
        if modelIds.isEmpty {
            // No provider keys are configured, so fall back to the built-in model
            // list.
            modelIds = WenshuLLMModel.allCases.map { $0.rawValue }
        }
        availableModels = modelIds
        if !availableModels.contains(currentModel) {
            availableModels = [currentModel] + availableModels
        }
        recomputeContextUsed()
    }

    /// recomputeContextUsed: the conversation's CURRENT context usage
    /// (real LLM API usage, replaces the chars/4 heuristic).
    ///
    /// The number is the LATEST turn's `usage.totalTokens`, not the sum
    /// over the turns. Each turn's `totalTokens` is the provider's report
    /// for that request, and its INPUT side is the whole conversation so
    /// far — so adding the turns together counted the history once per
    /// turn and grew quadratically. Four turns of a 1,000-token
    /// conversation reported 10,000 tokens of context when the context was
    /// 1,000.
    ///
    /// That also matches what the number is compared against: the chat
    /// footer compares it with `tokenCompressionContextThreshold`, which
    /// is a CONTEXT-WINDOW limit, not a spend limit. A cumulative number
    /// measured against a window limit is the wrong unit.
    ///
    /// The latest turn with a token count is the one that was sent with
    /// the most history, so it is the one that reports the most context
    /// in use. Messages without a token count (= the user's own turns,
    /// which the provider does not bill as a separate request, and
    /// messages from before usage was recorded) are skipped.
    func recomputeContextUsed() {
        contextUsed = messages.last(where: { ($0.tokens ?? 0) > 0 })?.tokens ?? 0
        let totalContext = contextUsed
        let messageCount = messages.count
        Logger(subsystem: "com.wenshu.app", category: "chat.context")
            .info("[wenshu.context] context usage after recompute: total=\(totalContext, privacy: .public) messages=\(messageCount, privacy: .public)")
    }
}
