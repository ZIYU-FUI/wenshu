//
//  TitleGenerator.swift · Wenshu · HERMES-INTERNAL-008 (2026-09-04)
//
//  1:1 port of hermes title_generator.py (= hermes-internal module #8,
//  boss 2026-09-04 OOB 'A'). Auto-generate short session titles from
//  the first user message.
//
//  Two modes:
//    - heuristicTitle(from:) — fast, offline, first 6 words + ellipsis
//    - llmTitle(from:connector:) — optional LLM call via any LLMConnector
//      (= Anthropic / OpenAI / Gemini / DeepSeek / Ollama / OpenRouter
//      / minimax cn).
//

import Foundation

public enum TitleGenerator {

    /// Heuristic title (= first 6 words + ellipsis if truncated).
    /// Pure function — no LLM call, deterministic, offline.
    public static func heuristicTitle(from message: String) -> String {
        let cleaned = message
            .replacingOccurrences(of: "\n", with: " ")
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        guard !cleaned.isEmpty else { return "Untitled" }
        let words = cleaned.split(separator: " ").map(String.init)
        guard words.count > 6 else { return cleaned }
        return words.prefix(6).joined(separator: " ") + "..."
    }

    /// LLM-callable title via any connector. When `connector` is nil,
    /// falls back to the heuristic title (= hermes pattern: if the
    /// auxiliary LLM call fails or is not configured, the session gets
    /// a heuristic title rather than NULL).
    public static func llmTitle(
        from message: String,
        connector: (any LLMConnector)?
    ) async throws -> String {
        guard let connector else {
            return heuristicTitle(from: message)
        }
        let snippet = String(message.prefix(500))
        let prompt = """
        Generate a short, descriptive title (3-7 words) for a conversation that starts with the \
        following message. The title should capture the main topic or intent. \
        Return ONLY the title text, nothing else. No quotes, no punctuation at the end, no prefixes.

        User message:
        \(snippet)
        """
        let messages = [LLMMessage(role: .user, blocks: [.text(snippet)])]
        let options = LLMCallOptions(
            model: "auto",
            maxTokens: 64,
            systemPrompt: prompt,
            temperature: 0.3
        )
        let response = try await connector.send(messages: messages, options: options)
        let raw = response.blocks.first.flatMap { block -> String? in
            if case .text(let s) = block { return s }
            return nil
        } ?? ""
        let cleaned = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'`"))
        if cleaned.lowercased().hasPrefix("title:") {
            return String(cleaned.dropFirst("title:".count)).trimmingCharacters(in: .whitespaces)
        }
        if cleaned.isEmpty {
            return heuristicTitle(from: message)
        }
        return cleaned
    }
}