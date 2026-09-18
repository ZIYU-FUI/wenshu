//
//  PlanModeEngine.swift · Wenshu · T20-PLAN-MODE (2026-09-18)
//
//  Hermes-style plan-mode coordinator. When the user invokes
//  `/plan <query>`, the engine calls the LLM with a system prompt
//  that asks for a numbered plan (= no tool execution; = pure
//  planning). The plan is returned as a `Plan` (= numbered steps)
//  and rendered in ChatView as a collapsible card. The user
//  approves -> re-send the original query with the plan attached
//  as additional system context; = the LLM then executes against
//  the approved plan.
//
//  Hermes parity: Hermes desktop's `/plan` mode does exactly this
//  (= the plan mode is a thin wrapper around the LLM call that
//  changes the system prompt = no separate inference path). The
//  wenshu-side equivalent lives here so future tickets (= plan
//  editor + approval UI + auto-decomposition) can build on the
//  same shape.
//
//  Hermes equivalent: useChatSendPlanMode (= runtime/chat/plan.ts).
//

import Foundation

/// One step in a plan. Backend-agnostic (= the engine parses the
/// LLM response into these structs regardless of which provider
/// generated the text).
public struct PlanStep: Equatable, Sendable, Hashable, Codable {
    /// 1-based index (Hermes uses 1-based numbering for plan
    /// steps; = matches the markdown source `1. ... 2. ...`).
    public let index: Int
    /// Short title for the step (= the line BEFORE the colon,
    /// or the first sentence if no colon).
    public let title: String
    /// Detailed description (= everything after the title on
    /// the first line + any continuation lines).
    public let detail: String

    public init(index: Int, title: String, detail: String) {
        self.index = index
        self.title = title
        self.detail = detail
    }

    /// One-line display label for the step (= the title; = with
    /// the 1-based index prefixed when shown in a numbered list).
    public var displayLabel: String {
        return "\(index). \(title)"
    }
}

/// Result of `/plan <query>` = the full plan structure.
public struct Plan: Equatable, Sendable, Hashable, Codable {
    /// Original user query that triggered the plan.
    public let query: String
    /// Ordered list of steps (= 1-based).
    public let steps: [PlanStep]
    /// The connector that produced this plan (= cached for
    /// debugging + future approval UI = which provider generated
    /// the plan).
    public let connectorID: String
    /// When the plan was generated (= for staleness checks in
    /// future UI work).
    public let createdAt: Date

    public init(
        query: String,
        steps: [PlanStep],
        connectorID: String,
        createdAt: Date = Date()
    ) {
        self.query = query
        self.steps = steps
        self.connectorID = connectorID
        self.createdAt = createdAt
    }
}

/// Errors thrown by PlanModeEngine.
public enum PlanModeError: LocalizedError, Sendable {
    case missingConnector
    case planParseFailed(rawResponse: String)
    case planEmpty(query: String)
    case transport(underlying: String)

    public var errorDescription: String? {
        switch self {
        case .missingConnector:
            return "No LLM connector available (= configure a provider in Settings → LLM Connector)."
        case .planParseFailed(let raw):
            return "Could not parse plan from LLM response (= expected numbered steps; = see raw: \(raw.prefix(200)))."
        case .planEmpty:
            return "Plan engine returned zero steps (= the model did not produce a parseable plan)."
        case .transport(let underlying):
            return "Plan mode transport error: \(underlying)"
        }
    }
}

/// Pure helper (= no actor / Sendable boundary) that parses an
/// LLM response into a `Plan`. Used by `PlanModeEngine.run(...)`
/// AND by tests (= no LLM network needed for parser coverage).
///
/// Parsing strategy (= Hermes-equivalent):
///   1. Split the response into lines.
///   2. Look for lines starting with `^\d+\.` (= "1. " / "2. " etc.).
///   3. For each numbered line: split on the FIRST colon to
///      extract the title (= everything before the colon on the
///      same line; = "**Title**: detail" pattern). The detail is
///      everything after the colon on the same line + any
///      continuation lines (lines that don't start with a new
///      number).
///   4. Lines that don't start with a number (= preambles,
///      trailing summaries) are ignored.
///
/// The parser is intentionally lenient (= markdown bullets like
/// "**" + bold + indentation are tolerated). A failed parse
/// (= zero numbered lines found) returns `nil`; = the caller
/// raises `PlanModeError.planParseFailed`.
public enum PlanModeParser {

    /// Parse a raw LLM response into a `Plan` (= query = the
    /// user's original query, steps = parsed steps). Returns
    /// nil if no numbered steps were found.
    public static func parse(
        response raw: String,
        query: String,
        connectorID: String,
        now: Date = Date()
    ) -> Plan? {
        let steps = parseSteps(raw)
        guard !steps.isEmpty else { return nil }
        return Plan(
            query: query,
            steps: steps,
            connectorID: connectorID,
            createdAt: now
        )
    }

    /// Lower-level parser (= only the steps list). Public for
    /// test coverage.
    public static func parseSteps(_ raw: String) -> [PlanStep] {
        var steps: [PlanStep] = []
        let lines = raw.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var currentIndex: Int?
        var currentTitle: String = ""
        var currentDetailLines: [String] = []
        let flush: () -> Void = {
            if let idx = currentIndex {
                let detail = currentDetailLines
                    .joined(separator: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                steps.append(PlanStep(index: idx, title: currentTitle, detail: detail))
            }
            currentIndex = nil
            currentTitle = ""
            currentDetailLines = []
        }
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // Detect a numbered line: "1." / "2." / "10." etc. at start.
            // Allow optional leading whitespace + bold markers (= "**1.**").
            if let (idx, rest) = parseNumberedPrefix(trimmed) {
                // Flush previous step before starting a new one.
                if currentIndex != nil { flush() }
                // Split on FIRST colon (= "Title: detail" pattern).
                let (title, detail) = splitTitleDetail(rest)
                currentIndex = idx
                currentTitle = title
                currentDetailLines = [detail]
            } else if currentIndex != nil && !trimmed.isEmpty {
                // Continuation line of the current step (= not a new
                // numbered line + non-empty = belongs to current).
                currentDetailLines.append(trimmed)
            }
            // Empty lines + non-matching lines (= preambles) are ignored.
        }
        // Flush the last step at end of input.
        if currentIndex != nil { flush() }
        return steps
    }

    /// Parse "1. ..." / "**2.** ..." / "10. Title: detail" etc.
    /// Returns (index, remainder) or nil if the line isn't a
    /// numbered step.
    private static func parseNumberedPrefix(_ line: String) -> (Int, String)? {
        // Strip optional leading markdown (= "**").
        var s = line
        var stripped = ""
        while s.hasPrefix("**") {
            stripped.append("**")
            s = String(s.dropFirst(2))
        }
        // Require "<digits>. <text>".
        guard let dotIdx = s.firstIndex(of: ".") else { return nil }
        let beforeDot = s[..<dotIdx]
        guard !beforeDot.isEmpty,
              let idx = Int(beforeDot.trimmingCharacters(in: .whitespaces)) else {
            return nil
        }
        // The line starts with a valid "<int>." prefix.
        let afterDot = s[s.index(after: dotIdx)...].trimmingCharacters(in: .whitespaces)
        return (idx, afterDot)
    }

    /// Split on FIRST colon (= "Title: detail" pattern). If no
    /// colon present, the entire line is the title and detail
    /// is empty.
    private static func splitTitleDetail(_ line: String) -> (String, String) {
        // Strip trailing bold markers from the title (= "**").
        if let colonIdx = line.firstIndex(of: ":") {
            let titlePart = String(line[..<colonIdx])
                .trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "*"))
                .trimmingCharacters(in: .whitespaces)
            let detailPart = String(line[line.index(after: colonIdx)...])
                .trimmingCharacters(in: .whitespaces)
            return (titlePart, detailPart)
        }
        let title = line.trimmingCharacters(in: CharacterSet(charactersIn: "*"))
        return (title, "")
    }
}

/// PlanModeEngine: thin wrapper around an LLMConnector that
/// invokes the connector with a planning-only system prompt and
/// parses the response into a Plan.
///
/// Engine is `actor`-isolated because it touches an LLMConnector
/// (= a Sendable / actor-isolated type). Sendable closure
/// callbacks use the same pattern as the rest of wenshu agent
/// code (= hermes-port Z contract).
public actor PlanModeEngine {

    private let connector: any LLMConnector
    private let model: String

    public init(connector: any LLMConnector, model: String) {
        self.connector = connector
        self.model = model
    }

    /// The system prompt that asks the LLM for a numbered plan
    /// (= no tool execution). Public so tests can assert the
    /// exact prompt text (= keeps the engine's contract
    /// verifiable without making a network call).
    public static let planSystemPrompt: String = """
        You are in PLAN MODE. Respond with a numbered list of steps
        (= use 1. 2. 3. format). Do NOT call tools. Do NOT execute
        anything. Only describe the steps the assistant would take
        to answer the user's question. Each step should have a
        short title followed by a colon and a one-or-two-sentence
        detail (= "1. Search for X: Find the latest documentation
        for X in the library."). Wait for the user to approve
        before executing.
        """

    /// Run `/plan <query>` against the active connector. Returns
    /// a parsed `Plan` (= numbered steps) or throws `PlanModeError`.
    /// Does NOT execute tools (= plan mode only).
    public func run(query: String) async throws -> Plan {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PlanModeError.planEmpty(query: query)
        }
        let messages: [LLMMessage] = [
            .init(role: .user, blocks: [.text(query)])
        ]
        let options = LLMCallOptions(
            model: model,
            maxTokens: 2048,
            systemPrompt: Self.planSystemPrompt,
            temperature: 0.4,
            reasoningEffort: nil
        )
        let response: LLMResponse
        do {
            response = try await connector.send(messages: messages, options: options)
        } catch {
            throw PlanModeError.transport(underlying: error.localizedDescription)
        }
        // Concatenate all .text blocks (= planning-mode responses are
        // typically plain text without tool calls, but the
        // LLMResponse.blocks list may contain multiple .text blocks).
        let raw = response.blocks
            .compactMap { block -> String? in
                if case .text(let s) = block { return s }
                return nil
            }
            .joined(separator: "\n")
        guard let plan = PlanModeParser.parse(
            response: raw,
            query: query,
            connectorID: connector.connectorID
        ) else {
            throw PlanModeError.planParseFailed(rawResponse: raw)
        }
        guard !plan.steps.isEmpty else {
            throw PlanModeError.planEmpty(query: query)
        }
        return plan
    }
}