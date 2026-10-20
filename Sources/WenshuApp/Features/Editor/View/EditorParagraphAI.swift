//
//  EditorParagraphAI.swift
//
//  The paragraph-rewrite pipeline behind the editor's paragraph
//  toolbar (= expand / shorten / rephrase / shift tone / simplify /
//  dramatize).
//
//  One concern: build the prompt for a transform, send it to the
//  active connector, take the first text block back as the rewritten
//  paragraph. The View that owns the buttons and the busy flag lives
//  in `EditorView`.
//
//  The transform prompts come from `EditorTransformTools` (= the
//  Swift port of the editing tools), and the connector is injected
//  so the test target can drive it with a mock.
//

import Foundation
import WenshuAgent

/// Runs the paragraph transform pipeline and returns the rewritten text.
struct EditorParagraphAI {

    /// Run the paragraph transform pipeline (= build prompt prefix + call
    /// connector + extract first .text block) and return the rewritten
    /// paragraph. Throws on connector failure (= transport / auth / decode);
    /// the caller owns the graceful-degradation wrapper.
    ///
    /// - Parameters:
    ///   - selectedText: the user's selected text (= empty short-circuits to
    ///     "" per the defensive-defaults rule; matches the toolbar's
    ///     `disabled(selectedText.isEmpty)`).
    ///   - transform: which of the `EditorTransform` cases to apply.
    ///   - connector: the active connector (= injected for testability).
    ///   - options: the per-call options (= model + maxTokens).
    /// - Returns: the rewritten paragraph (= the first .text block of the
    ///   connector response; "" if the connector returned no text blocks).
    static func apply(
        selectedText: String,
        transform: EditorTransform,
        connector: any LLMConnector,
        options: LLMCallOptions
    ) async throws -> String {
        guard !selectedText.isEmpty else { return "" }
        let tools = EditorTransformTools()
        let prefix = await tools.promptPrefix(for: transform)
        let prompt = "\(prefix)\n\n\(selectedText)"
        let response = try await connector.send(
            messages: [LLMMessage.user(prompt)],
            options: options
        )
        let text = response.blocks.first { block in
            if case .text = block { return true }
            return false
        }.flatMap { block -> String? in
            if case let .text(s) = block { return s }
            return nil
        } ?? ""
        return text
    }
}
