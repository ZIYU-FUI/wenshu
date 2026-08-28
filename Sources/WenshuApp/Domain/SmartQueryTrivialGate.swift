// SmartQueryTrivialGate.swift · Wenshu · v0.28
//
// Verbatim port from hermes-agent/plugins/memory/query_rewrite.py
// (= wenshu M5 ticket 13 = hermes-port batch 3 second ticket).
//
// Source: hermes-agent/plugins/memory/query_rewrite.py L28-83
// (= the trivial-prompt gate = the 5 regex-based validation rules
// applied to a memory-retrieval query before/after an LLM rewrite step).
//
// Scope of this port:
// - The 5 regex patterns + the normalize function (verbatim, byte-for-byte
//   semantics matching hermes Python `re` semantics in Swift NSRegularExpression).
// - The trivial-prompt gate is a deterministic pre-filter (= decides whether
//   a candidate query is acceptable without invoking the LLM rewrite step).
//
// Out of scope (= not ported in this ticket):
// - The LLM rewrite call itself (= already covered by WenshuConductor
//   intent-classify path, = v0.23 ticket 13 implementation per
//   .scratch/2026-08-23-agent-identity/spec.md).
// - The auxiliary memory_query_rewrite config.yaml routing (= wenshu
//   does not use auxiliary routing per AGENTS.md single-user local-only).
//
// The gate is used by:
// - ticket M5-13 caller = SmartQueryEvaluator (= wenshu Domain layer)
// - ticket M5-15 caller = LLMWikiIngestor (= apply gate to
//   entity-extraction candidates before persisting to reference-library)
//
// Per AGENTS.md Section 8 pollution-defense hex-encoding rule: this file
// does NOT contain the 12-token forbidden vocab literal; if any reference
// to that list is needed, describe semantically.

import Foundation

/// Verbatim port of hermes `query_rewrite.py` trivial-prompt gate.
///
/// Used as a pre-filter (= before any LLM rewrite step) and a post-filter
/// (= after any LLM rewrite step). Returns `nil` (= empty string in hermes)
/// for queries that fail any rule (= caller decides how to handle:
/// typically return the original user message verbatim, or reject the
/// rewrite entirely).
public struct SmartQueryTrivialGate: Sendable {

    public init() {}

    // MARK: - Limits (hermes verbatim)

    /// hermes: `_MAX_INPUT_CHARS = 4_000`
    static let maxInputChars = 4_000

    /// hermes: `_MAX_QUERY_CHARS = 320`
    static let maxQueryChars = 320

    // MARK: - Regex patterns (hermes verbatim)

    /// `(?:retrieval\s+query|memory\s+query|query|question)\s*:\s*`
    /// Strips output prefix (= e.g. "Retrieval Query: " or "Question: ").
    /// Case-insensitive.
    private static let outputPrefix = try! NSRegularExpression(
        pattern: #"^(?:retrieval\s+query|memory\s+query|query|question)\s*:\s*"#,
        options: [.caseInsensitive]
    )

    /// `(?:what|which|who|where|when|why|how|is|are|was|were|do|does|did|
    ///  has|have|had|can|could|would|should|may|might)\b`
    /// Whitelisted question-starter tokens (= hermes requires the candidate
    /// query to start with one of these, otherwise returns empty).
    /// Case-insensitive.
    private static let questionStart = try! NSRegularExpression(
        pattern: #"^(?:what|which|who|where|when|why|how|is|are|was|were|do|does|did|has|have|had|can|could|would|should|may|might)\b"#,
        options: [.caseInsensitive]
    )

    /// `\b(?:user|their|they|them|previous|prior|past|history|preference|
    ///  preferences|context|known|remembered|earlier)\b`
    /// Required memory-grounding keywords (= hermes requires the candidate
    /// query to reference user-context tokens, otherwise returns empty).
    /// Case-insensitive.
    private static let memoryGrounding = try! NSRegularExpression(
        pattern: #"\b(?:user|their|they|them|previous|prior|past|history|preference|preferences|context|known|remembered|earlier)\b"#,
        options: [.caseInsensitive]
    )

    /// `\b(?:ignore|obey|follow)\b|\binstructions?\b|\bsystem\s+prompt\b|
    ///  \banswer\s+(?:directly|instead|the\s+user|this)\b`
    /// Detects instruction-leak patterns (= user trying to inject
    /// "ignore previous instructions" into the query). Case-insensitive.
    private static let instructionLeak = try! NSRegularExpression(
        pattern: #"\b(?:ignore|obey|follow)\b|\binstructions?\b|\bsystem\s+prompt\b|\banswer\s+(?:directly|instead|the\s+user|this)\b"#,
        options: [.caseInsensitive]
    )

    // MARK: - Public surface

    /// Verbatim port of hermes `_normalize_rewrite(text)` (=
    /// query_rewrite.py L84-100 approximately).
    ///
    /// Applies the 5 validation rules in order:
    /// 1. Strip markdown code fences (```text ... ```)
    /// 2. Strip output prefix (= "Retrieval Query: " etc.)
    /// 3. Strip leading/trailing quotes / backticks
    /// 4. Strip control characters + normalize whitespace
    /// 5. Length cap (= 320 chars per `_MAX_QUERY_CHARS`)
    /// 6. Question-start whitelist (= must start with question token)
    /// 7. Memory-grounding requirement (= must reference user context)
    /// 8. Instruction-leak rejection (= reject queries containing "ignore
    ///    previous instructions" etc.)
    ///
    /// Returns the normalized query (= nil if any rule fails = verbatim
    /// hermes `_normalize_rewrite` empty-string return semantics; wenshu
    /// caller decides how to handle nil).
    public func normalize(_ text: String) -> String? {
        var candidate = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // 1. Strip markdown code fences
        if candidate.hasPrefix("```") && candidate.hasSuffix("```") {
            // Strip the opening ```[text]? prefix
            if let range = candidate.range(of: #"^```(?:text)?\s*"#, options: [.regularExpression, .caseInsensitive]) {
                candidate.removeSubrange(range)
            }
            // Strip the trailing ``` suffix
            if let range = candidate.range(of: #"\s*```$"#, options: [.regularExpression]) {
                candidate.removeSubrange(range)
            }
        }

        // 2. Strip output prefix
        candidate = Self.outputPrefix.stringByReplacingMatches(
            in: candidate,
            range: NSRange(candidate.startIndex..., in: candidate),
            withTemplate: ""
        )
        candidate = candidate.trimmingCharacters(in: .whitespacesAndNewlines)

        // 3. Strip leading/trailing quotes / backticks
        let quoteChars = CharacterSet(charactersIn: "\"'`")
        candidate = candidate.trimmingCharacters(in: quoteChars)

        // 4. Strip control characters + normalize whitespace
        // Build CharacterSet matching hermes '[\x00-\x1f\x7f]+' (= covers all
        // ASCII control chars including form-feed 0x0C). Swift does not parse
        // \u{XX} escapes inside a CharacterSet init string literal (= only
        // literal characters are added), so we construct via UnicodeScalar
        // iteration (= same range semantics, deterministic across runs).
        var controlCharSet = CharacterSet()
        for scalarValue in 0x00...0x1f {
            if let scalar = UnicodeScalar(scalarValue) {
                controlCharSet.insert(scalar)
            }
        }
        if let del = UnicodeScalar(0x7f) {
            controlCharSet.insert(del)
        }
        candidate = candidate.components(separatedBy: controlCharSet).joined(separator: " ")
        // Collapse multiple spaces
        while candidate.contains("  ") {
            candidate = candidate.replacingOccurrences(of: "  ", with: " ")
        }
        candidate = candidate.trimmingCharacters(in: .whitespacesAndNewlines)

        // 5. Length cap
        if candidate.isEmpty { return nil }
        if candidate.count > Self.maxQueryChars { return nil }

        // 6. Question-start whitelist
        let nsCandidate = candidate as NSString
        let fullRange = NSRange(location: 0, length: nsCandidate.length)
        guard Self.questionStart.firstMatch(in: candidate, range: fullRange) != nil else {
            return nil
        }

        // 7. Memory-grounding requirement
        guard Self.memoryGrounding.firstMatch(in: candidate, range: fullRange) != nil else {
            return nil
        }

        // 8. Instruction-leak rejection
        guard Self.instructionLeak.firstMatch(in: candidate, range: fullRange) == nil else {
            return nil
        }

        return candidate
    }
}
