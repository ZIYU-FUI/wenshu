//
//  Redactor.swift · Wenshu · HERMES-INTERNAL-009 (2026-09-04)
//
//  1:1 port of hermes redact.py (= hermes-internal module #9, boss
//  2026-09-04 OOB 'A'). Strip PII / secrets before logging.
//
//  Pure-data struct (= Sendable) with a configurable regex rule set.
//  Default rules cover email, phone, API keys, JWT, auth headers —
//  the minimal surface that wenshu's logger needs to mask structured
//  secrets. Not an actor (= pure functional transform).
//

import Foundation

public struct RedactionRule: Sendable, Equatable {
    public let pattern: String  // regex
    public let replacement: String

    public init(pattern: String, replacement: String) {
        self.pattern = pattern
        self.replacement = replacement
    }
}

public struct Redactor: Sendable {

    private let rules: [CompiledRule]

    // v0.37 fix: Regex is not Sendable; wrap in @unchecked Sendable so the
    // owning Redactor struct stays Sendable (= required for actor storage
    // and across isolation boundaries). The regex is constructed at init
    // time and never mutated; safe to share.
    private struct CompiledRule: @unchecked Sendable {
        let regex: Regex<AnyRegexOutput>
        let replacement: String
    }

    public init(rules: [RedactionRule] = Redactor.defaultRules) {
        self.rules = rules.compactMap { rule in
            guard let compiled = try? Regex<AnyRegexOutput>(rule.pattern) else {
                return nil
            }
            return CompiledRule(regex: compiled, replacement: rule.replacement)
        }
    }

    /// Apply every rule in order. Returns the redacted text. Rules with
    /// invalid regex patterns are skipped at init time (rather than
    /// thrown at redact-time) so a single broken rule never breaks
    /// the whole redactor.
    public func redact(_ text: String) -> String {
        var result = text
        for rule in rules {
            result = replaceAll(in: result, rule: rule)
        }
        return result
    }

    /// Perform regex replacement by walking all matches and rebuilding
    /// the string. Foundation's `Regex.replacing` exists but its API
    /// requires literal-string template substitution; we want to emit
    /// a custom replacement for each match, so we walk manually.
    /// Swift Regex API: firstMatch(in:) takes a Substring; the returned
    /// `match.range` is a Range<String.Index> over the original String.
    private func replaceAll(in text: String, rule: CompiledRule) -> String {
        var output = ""
        var cursor = text.startIndex
        while cursor < text.endIndex {
            let searchRange = cursor..<text.endIndex
            guard let match = try? rule.regex.firstMatch(in: text[searchRange]) else {
                output.append(contentsOf: text[cursor..<text.endIndex])
                break
            }
            let swiftRange = match.range
            output.append(contentsOf: text[cursor..<swiftRange.lowerBound])
            output.append(rule.replacement)
            cursor = swiftRange.upperBound
        }
        return output
    }
}

public extension Redactor {
    static let defaultRules: [RedactionRule] = [
        // Email addresses
        RedactionRule(
            pattern: #"[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}"#,
            replacement: "[REDACTED_EMAIL]"
        ),
        // E.164 phone numbers (+countrycode with 7-15 digits)
        RedactionRule(
            pattern: #"\+[1-9]\d{6,14}(?![A-Za-z0-9])"#,
            replacement: "[REDACTED_PHONE]"
        ),
        // Generic API key prefix patterns (sk-, ghp_, AKIA, xai-, etc.)
        RedactionRule(
            pattern: #"\b(?:sk-[A-Za-z0-9_\-]{10,}|ghp_[A-Za-z0-9]{10,}|AKIA[A-Z0-9]{16}|xai-[A-Za-z0-9]{30,}|AIza[A-Za-z0-9_\-]{30,}|tvly-[A-Za-z0-9]{10,}|exa_[A-Za-z0-9]{10,})"#,
            replacement: "[REDACTED_API_KEY]"
        ),
        // JWT tokens (header.payload[.signature])
        RedactionRule(
            pattern: #"eyJ[A-Za-z0-9_\-]{10,}(?:\.[A-Za-z0-9_\-]{4,}){0,2}"#,
            replacement: "[REDACTED_JWT]"
        ),
        // Authorization headers (Bearer/Basic/Token + credential)
        RedactionRule(
            pattern: #"(?i)((?:Proxy-)?Authorization:\s*)[^\s\"']+"#,
            replacement: "$1[REDACTED_AUTH]"
        ),
    ]
}