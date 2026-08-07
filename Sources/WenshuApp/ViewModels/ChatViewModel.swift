// ChatViewModel.swift · 文枢 (Wenshu) · v0.01.0 WO-004
//
// Main view model for the project-creation flow. Owns:
// - chat messages (with streaming state)
// - AI-suggested 举一反三 options
// - user-selected direction IDs
// - generated characters + world rules
// - one-shot navigation signal back to the View layer
//
// Per WO-004 spec: streams are mocked via `MockLLMResponse.streamingChunks`
// (this is the only WO-004 file that "looks like" it calls an LLM). WO-005
// swaps the mock iterations for `LLMService.streamChat(...)` consumption;
// the public API (`sendInitialStory`, `selectDirections`, `reset`) does
// not change.
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
        pendingNavigation = nil
    }

    /// Convenience: the current snapshot title shown above the chat list.
    func selectedSummary() -> String {
        expandOptions
            .filter { selectedDirectionIDs.contains($0.id) }
            .map { $0.title }
            .joined(separator: "、")
    }

    // MARK: - Private helpers

    /// Append a streaming AI message, yield chunks with a small delay, then
    /// flip `isStreaming` to false. Returns the message id.
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

        for chunk in MockLLMResponse.streamingChunks(of: text) {
            if Task.isCancelled { break }
            try? await Task.sleep(for: .milliseconds(45))
            if let idx = messages.firstIndex(where: { $0.id == id }) {
                messages[idx].content += chunk
            }
        }
        if let idx = messages.firstIndex(where: { $0.id == id }) {
            messages[idx].isStreaming = false
        }
        return id
    }
}
