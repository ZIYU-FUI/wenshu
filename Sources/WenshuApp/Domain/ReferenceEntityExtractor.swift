// Sources/WenshuApp/Domain/ReferenceEntityExtractor.swift
//
// Verbatim port from
// `hermes-agent/plugins/memory/holographic/store.py::_extract_entities`.
//
// Rules applied (in order, matching hermes verbatim):
// 1. Capitalized multi-word phrases  e.g. "John Doe"
// 2. Double-quoted terms             e.g. "Python"
// 3. Single-quoted terms             e.g. 'pytest'
// 4. AKA patterns                    e.g. "Guido aka BDFL" -> two entities
//
// Returns a deduplicated list preserving first-seen order (= dedup
// by case-insensitive lowercased comparison).
//
// Public surface:
// - `ReferenceEntityExtractor.extract(_:) -> [String]`
//
// Earlier draft advertised a `-> [IngestionRequest]` convenience
// overload, but `IngestionRequest` is internal so the overload
// would not compile if declared public. Removed; downstream
// callers compose `[String] -> [IngestionRequest]` at their own
// call site per atomic-coupling (= each consumer owns its own
// `IngestionRequest` construction).
// Per AGENTS.md Section 8 pollution-defense hex-encoding rule: this file
// does NOT contain the 12-token forbidden vocab literal; if any
// reference to that list is needed, describe semantically.

import Foundation

struct ReferenceEntityExtractor: Sendable {

    init() {}

    // MARK: - Regex patterns (hermes verbatim)

    /// `\b([A-Z][a-z]+(?:\s+[A-Z][a-z]+)+)\b` — multi-word capitalized phrases.
    /// Hermes regex: `\b([A-Z][a-z]+(?:\s+[A-Z][a-z]+)+)\b`
    /// Note: anchored on Latin script only. CJK entity extraction (= Chinese person / place names)
    /// remains handled by ChatTrigger.detectQuotedNames (= existing CN-quote detection).
    private static let capitalized = NSRegularExpression.literal(#"\b([A-Z][a-z]+(?:\s+[A-Z][a-z]+)+)\b"#
    )

    /// `"([^"]+)"` — double-quoted terms.
    private static let doubleQuote = NSRegularExpression.literal(#""([^"]+)""#
    )

    /// `'([^']+)'` — single-quoted terms.
    private static let singleQuote = NSRegularExpression.literal(#"'([^']+)'"#
    )

    /// AKA pattern (hermes verbatim):
    ///   `(\w+(?:\s+\w+)*)\s+(?:aka|also known as)\s+(\w+(?:\s+\w+)*)`
    /// case-insensitive.
    private static let aka = NSRegularExpression.literal(#"(\w+(?:\s+\w+)*)\s+(?:aka|also known as)\s+(\w+(?:\s+\w+)*)"#,
        options: [.caseInsensitive]
    )

    // MARK: - Public surface

    /// Extract entity candidate surface forms from the given text.
    ///
    /// Returns a deduplicated list preserving first-seen order (= dedup by
    /// case-insensitive lowercased comparison, identical to hermes Python
    /// behavior).
    func extract(_ text: String) -> [String] {
        var seen = Set<String>()
        var candidates: [String] = []

        func add(_ name: String) {
            let stripped = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !stripped.isEmpty else { return }
            let key = stripped.lowercased()
            if seen.insert(key).inserted {
                candidates.append(stripped)
            }
        }

        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)

        // 1. Capitalized multi-word phrases
        for match in Self.capitalized.matches(in: text, range: fullRange) {
            add(nsText.substring(with: match.range(at: 1)))
        }

        // 2. Double-quoted terms
        for match in Self.doubleQuote.matches(in: text, range: fullRange) {
            add(nsText.substring(with: match.range(at: 1)))
        }

        // 3. Single-quoted terms
        for match in Self.singleQuote.matches(in: text, range: fullRange) {
            add(nsText.substring(with: match.range(at: 1)))
        }

        // 4. AKA patterns -> each side yields a separate entity
        for match in Self.aka.matches(in: text, range: fullRange) {
            add(nsText.substring(with: match.range(at: 1)))
            add(nsText.substring(with: match.range(at: 2)))
        }

        return candidates
    }
}
