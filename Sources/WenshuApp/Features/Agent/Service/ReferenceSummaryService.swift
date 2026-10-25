//
//  ReferenceSummaryService.swift
//
//  The one-line semantic summary of a reference document.
//
//  Why: a reference document (= an imported research dossier, a
//  document the agent wrote) is too long to read whole, so the agent
//  needs a cheap way to answer "does this document constrain the
//  chapter I am writing?". The summary is that answer, and it is
//  written ONCE (= at save time) so the read path stays free.
//
//  Where it lands: `Reference.summary` (= the field the model already
//  has, the card summary the UI already shows, and the line the agent
//  already reads in `ReferenceDescriptor`). No new layer, no new
//  filter rule.
//
//  How it is produced: over the app's own chat model (= the provider
//  connector the chat already uses; = no second HTTP client and no
//  second provider stack). A remote failure is an error, not a silent
//  empty summary (= the same convention the rest of the app follows).
//

import Foundation
import WenshuAgent

/// What can go wrong while summarizing a reference document.
enum ReferenceSummaryError: Error, LocalizedError, Sendable {
    /// No chat model is available to write the summary.
    case noConnector(String)
    /// The model answered, but not with a line that can be used.
    case unreadableAnswer(String)
    /// The model ran out of budget before it answered.
    case answerTruncated(String)

    var errorDescription: String? {
        switch self {
        case .noConnector(let slug):
            return "No chat model is available to summarize the reference document (\(slug))."
        case .unreadableAnswer(let raw):
            return "The reference summary could not be read: \(raw.prefix(120))"
        case .answerTruncated(let detail):
            return "The reference summary was cut off before the model answered: \(detail)"
        }
    }
}

/// The one-line summary of a reference document.
///
/// The service is a value with injected seams (= the connector and the
/// model slug), so the tests drive it without a network and the
/// production wiring names the connector the user configured.
struct ReferenceSummaryService: Sendable {

    /// The prompt (= English on purpose: the repo writes code, comments
    /// and prompts in English; = the model is told to answer in the
    /// document's own language instead).
    static let prompt = """
    You write the one-line summaries a writing assistant uses to route \
    research documents.
    Rules:
    1. Answer with ONE line and nothing else: no preamble, no list, no quotes.
    2. Write in the same language as the document.
    3. Say what the document HOLDS (= the facts, the findings, the text), \
    not what it is for.
    4. Keep it under 40 words.
    """

    /// The token budget (= a thinking model reasons out of the same
    /// budget as the answer; = a tight budget would leave a thinking
    /// block and no answer).
    static let answerTokenBudget = 8000

    /// How much of the body the model sees (= the head of a document
    /// carries its topic; = a whole dossier would cost more than the
    /// summary is worth).
    static let bodyExcerptLimit = 4000

    /// The connector (= nil = no model is available).
    private let connector: @Sendable () -> (any LLMConnector)?
    /// The model slug (= the one the user picked for the chat).
    private let model: @Sendable () -> String

    init(
        connector: @escaping @Sendable () -> (any LLMConnector)? = {
            WenshuAppDelegateLLMHelpers.activeLLMConnector()
        },
        model: @escaping @Sendable () -> String = {
            WenshuAppDelegateLLMHelpers.activeModelSlug() ?? "MiniMax-M3"
        }
    ) {
        self.connector = connector
        self.model = model
    }

    /// Summarize the document in one line.
    ///
    /// - Throws: `ReferenceSummaryError` when no model answers or the
    ///   answer cannot be read. The caller decides what to do with a
    ///   failure; = the summary is never faked.
    func summarize(title: String, body: String) async throws -> String {
        guard let connector = connector() else {
            throw ReferenceSummaryError.noConnector(model())
        }
        let excerpt = String(body.prefix(Self.bodyExcerptLimit))
        let question = "Title: \(title)\n\nDocument:\n\(excerpt)"
        let response = try await connector.send(
            messages: [LLMMessage.user(question)],
            options: LLMCallOptions(
                model: model(),
                maxTokens: Self.answerTokenBudget,
                systemPrompt: Self.prompt,
                temperature: 0.2
            )
        )

        // A thinking model that ran out of budget leaves a thinking
        // block and no answer. That is a CUT-OFF answer, not an empty
        // one, and it has to be said as itself.
        if response.stopReason == .maxTokens {
            throw ReferenceSummaryError.answerTruncated(
                "the model used its whole budget of \(response.usage.outputTokens) tokens and did not answer"
            )
        }

        let text = response.blocks
            .compactMap { block -> String? in
                if case .text(let value) = block { return value }
                return nil
            }
            .joined(separator: "\n")

        return try Self.parse(text)
    }

    /// The model's one line (= the first non-empty line, unquoted).
    static func parse(_ text: String) throws -> String {
        let line = text
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty }
        guard var summary = line else {
            throw ReferenceSummaryError.unreadableAnswer(text)
        }
        // Strip the quotes a model likes to add.
        for quote in ["\"", "'", "\u{201C}", "\u{201D}", "`"] {
            if summary.hasPrefix(quote) && summary.hasSuffix(quote) && summary.count >= 2 {
                summary = String(summary.dropFirst().dropLast())
            }
        }
        summary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !summary.isEmpty else {
            throw ReferenceSummaryError.unreadableAnswer(text)
        }
        return summary
    }
}
