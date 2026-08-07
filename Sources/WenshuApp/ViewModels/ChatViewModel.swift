// ChatViewModel.swift · 文枢 (Wenshu) · v0.01.0 WO-004 → WO-005
//
// Main view model for the project-creation flow. Owns:
// - chat messages (with streaming state)
// - AI-suggested 举一反三 options
// - user-selected direction IDs
// - generated characters + world rules
// - one-shot navigation signal back to the View layer
// - (WO-005) reference to the active ProjectSnapshot for .ws persistence
//
// Per WO-004 spec: streams are mocked via `MockLLMResponse.streamingChunks`.
// WO-005 swaps in `LLMService.streamChat(...)` when:
//   - `FeatureFlag.useRealLLM == true`, AND
//   - macOS Keychain has an entry for `com.wenshu.llm / minimax-api-key`
// Otherwise (PM-direct / CI default) the mock fallback is used. The
// existing public API (`sendInitialStory`, `selectDirections`,
// `toggleSelection`, `reset`) is unchanged; WO-005 only ADDS new
// methods (`persist`) and a new `@Published var` (`currentProject`).
//
// Threading: `@MainActor` so all `@Published` mutations originate on the
// main thread. The `Task.sleep` inside the streaming loop is fine on
// @MainActor — it just yields.

import Foundation
import SwiftUI

@MainActor
final class ChatViewModel: ObservableObject {

    // MARK: - Published state

    @Published var messages: [ChatMessage] = []
    @Published var expandOptions: [ExpandOption] = []
    @Published var selectedDirectionIDs: Set<UUID> = []
    @Published var isGenerating: Bool = false
    @Published var characters: [CharacterSnapshot] = []
    @Published var worldRules: [WorldRuleSnapshot] = []

    /// WO-005: the `ProjectSnapshot` for the chat that's currently open.
    /// Set by `ChatView.onAppear`; cleared by `reset()`. `persist()` uses
    /// it to tag the saved note + future loaders (v0.02.0) to scope queries.
    @Published var currentProject: ProjectSnapshot? = nil

    /// One-shot navigation signal. The owning `ChatView` watches this via
    /// `onChange` and pushes the corresponding `AppRoute` onto its
    /// `NavigationStack`, then clears the signal. Cleared on `reset()` too.
    @Published var pendingNavigation: AppRoute? = nil

    // MARK: - Init

    init() {}

    // MARK: - Public API

    /// User submits the one-sentence story. Appends user message + streams
    /// a mock AI reply, then populates the 4-category `expandOptions`.
    func sendInitialStory(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // 1. User message.
        messages.append(ChatMessage(role: "user", content: trimmed))

        // 2. Streaming AI response.
        let aiMessageID = await appendStreamingMessage(MockLLMResponse.initialReply)

        // 3. Populate the 4-category options.
        expandOptions = MockLLMResponse.expandOptions()
        _ = aiMessageID // silence unused warning if any
    }

    /// User confirms selected directions. Appends a synthesized "已选择"
    /// user message + streams a confirmation AI reply, then populates
    /// characters and world rules, then signals navigation.
    func selectDirections() async {
        guard !selectedDirectionIDs.isEmpty else { return }

        let selectedTitles = expandOptions
            .filter { selectedDirectionIDs.contains($0.id) }
            .map { $0.title }
            .joined(separator: "、")

        // 1. User picks.
        messages.append(ChatMessage(
            role: "user",
            content: "已选择方向：\(selectedTitles)"
        ))

        // 2. Streaming AI confirmation.
        _ = await appendStreamingMessage(MockLLMResponse.confirmationReply)

        // 3. Populate characters + world rules.
        characters = MockLLMResponse.characters()
        worldRules = MockLLMResponse.worldRules()

        // 4. Signal navigation to CharacterWorldView.
        pendingNavigation = .characterWorld
    }

    /// Toggle one direction's selection. Drives the checkbox state in
    /// `ExpandOptionsView`.
    func toggleSelection(_ id: UUID) {
        if selectedDirectionIDs.contains(id) {
            selectedDirectionIDs.remove(id)
        } else {
            selectedDirectionIDs.insert(id)
        }
    }

    /// Clear all state. Called when the user returns from
    /// `CharacterWorldView` back to the project list.
    func reset() {
        messages = []
        expandOptions = []
        selectedDirectionIDs = []
        isGenerating = false
        characters = []
        worldRules = []
        currentProject = nil
        pendingNavigation = nil
    }

    /// Convenience: the current snapshot title shown above the chat list.
    func selectedSummary() -> String {
        expandOptions
            .filter { selectedDirectionIDs.contains($0.id) }
            .map { $0.title }
            .joined(separator: "、")
    }

    // MARK: - WO-005 · .ws persistence

    /// Persist the current chat's state to `WenshuProjectStore`. No-op if
    /// `currentProject` is nil (caller didn't set it) or if there's no user
    /// message yet (nothing to save).
    ///
    /// Called by `CharacterWorldView` immediately BEFORE `reset()`, so that
    /// `characters` and `worldRules` are still populated when we hand them
    /// to the store. Errors are swallowed and logged to stderr — v0.01.0
    /// has no UI affordance to surface them, and the SQLite store isn't
    /// loaded this phase anyway.
    func persist() async {
        guard let project = currentProject else { return }
        let initialStory = messages.first(where: { $0.role == "user" })?.content ?? ""
        guard !initialStory.isEmpty else { return }
        do {
            try await WenshuProjectStore.shared.save(
                project: project,
                characters: characters,
                worldRules: worldRules,
                initialStory: initialStory
            )
        } catch {
            FileHandle.standardError.write(Data(
                "ChatViewModel.persist: WenshuProjectStore.save failed: \(error)\n".utf8
            ))
        }
    }

    // MARK: - Private helpers

    /// Append a streaming AI message, yield chunks with a small delay, then
    /// flip `isStreaming` to false. Returns the message id.
    ///
    /// WO-005: when `FeatureFlag.useRealLLM == true` AND a key is in
    /// Keychain AND `LLMService.shared` can be constructed, real LLM
    /// stream chunks are consumed. Otherwise (the PM-direct / CI default),
    /// the WO-004 mock fallback runs.
    @discardableResult
    private func appendStreamingMessage(_ text: String) async -> UUID {
        let id = UUID()
        messages.append(ChatMessage(
            id: id,
            role: "assistant",
            content: "",
            isStreaming: true
        ))
        isGenerating = true
        defer { isGenerating = false }

        if shouldUseRealLLM(), let service = try? LLMService.shared {
            await streamFromRealLLM(id: id, service: service, fallbackText: text)
        } else {
            await streamFromMock(id: id, text: text)
        }

        if let idx = messages.firstIndex(where: { $0.id == id }) {
            messages[idx].isStreaming = false
        }
        return id
    }

    /// Decide whether to talk to the real LLM. Requires:
    ///   1. `FeatureFlag.useRealLLM == true`
    ///   2. A non-empty key present in Keychain (via `KeychainHelper`)
    ///   3. `LLMService.shared` to be constructible (same check, but we keep
    ///      them separate so the diagnostic surface is clearer if a future
    ///      keychain entry exists but is rejected).
    private func shouldUseRealLLM() -> Bool {
        guard FeatureFlag.useRealLLM else { return false }
        guard KeychainHelper.shared.loadKey() != nil else { return false }
        return (try? LLMService.shared) != nil
    }

    /// Consume `LLMService.streamChat(...)` and append each chunk to the
    /// assistant bubble. Falls back to the mock stream on any error so the
    /// UI never gets stuck mid-typewriter.
    private func streamFromRealLLM(
        id: UUID,
        service: LLMService,
        fallbackText: String
    ) async {
        let systemPrompt = "你是文枢,一个长篇小说创作助手。"
        // History = every message except the one we're currently streaming.
        let history = messages
            .filter { msg in msg.id != id && !msg.content.isEmpty && !msg.isStreaming }
            .map { ($0.role, $0.content) }
        do {
            let stream = service.streamChat(system: systemPrompt, messages: history)
            for try await chunk in stream {
                if Task.isCancelled { break }
                appendChunk(chunk, to: id)
            }
        } catch {
            // Real call blew up (network, parse, etc.) — fall back so the
            // user still sees a reply and isn't left staring at an empty
            // bubble. v0.01.0 has no UI affordance for surfacing the error.
            FileHandle.standardError.write(Data(
                "ChatViewModel.streamFromRealLLM: \(error); falling back to mock.\n".utf8
            ))
            await streamFromMock(id: id, text: fallbackText)
        }
    }

    /// WO-004 mock streaming: chunk the reply and `Task.sleep` between
    /// chunks to fake a typewriter effect.
    private func streamFromMock(id: UUID, text: String) async {
        for chunk in MockLLMResponse.streamingChunks(of: text) {
            if Task.isCancelled { break }
            try? await Task.sleep(for: .milliseconds(45))
            appendChunk(chunk, to: id)
        }
    }

    @MainActor
    private func appendChunk(_ chunk: String, to id: UUID) {
        if let idx = messages.firstIndex(where: { $0.id == id }) {
            messages[idx].content += chunk
        }
    }
}
