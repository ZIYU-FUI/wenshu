//
//  CronPromptScanner.swift · Wenshu · v0.23 ticket 013.007 (hermes gap 7)
//
//  Boss 2026-08-23 拍: hermes _scan_cron_prompt parity.
//  Source: github.com/NousResearch/hermes-agent/blob/main/tools/cronjob_tools.py:260
//
//  Hermes pattern:
//    - _scan_cron_prompt detects invisible unicode / emoji ZWJ sequences in
//      cron prompts (LLM prompt injection vectors).
//    - _check_invisible_unicode blocks ZWJ, RLO, RTL, zero-width chars.
//    - _strip_legitimate_emoji_zwj allows known emoji but strips others.
//
//  wenshu impl: Swift port with conservative blocklist. Catches the most
//  common LLM-targeted injection vectors without breaking legitimate text.
//

import Foundation

/// Result of a cron prompt injection scan.
public enum CronPromptScanResult: Sendable, Equatable {
    /// Prompt is clean — proceed.
    case clean
    /// Found injection characters — block and surface reason.
    case blocked(reason: String)
    /// Prompt is suspicious (e.g. unusual unicode density) — warn but allow.
    case suspicious(warning: String)
}

/// Scanner for invisible-unicode + emoji ZWJ prompt injection vectors.
/// Mirrors hermes _scan_cron_prompt + _check_invisible_unicode.
public enum CronPromptScanner {

    /// Invisible / control characters that are common LLM prompt injection vectors.
    /// Source: hermes _check_invisible_unicode — ZWJ, RLO, RTL, zero-width chars.
    private static let invisibleChars: Set<Character> = {
        var chars = Set<Character>()
        // Zero-width joiner / non-joiner / space
        chars.insert("\u{200D}")  // ZWJ
        chars.insert("\u{200C}")  // ZWNJ
        chars.insert("\u{200B}")  // ZWSP (zero-width space)
        chars.insert("\u{FEFF}")  // BOM / ZWNBSP
        chars.insert("\u{2060}")  // Word joiner
        // Bidirectional control (RTL/LRO/RLO/PDF — used in prompt injection)
        chars.insert("\u{202E}")  // RLO
        chars.insert("\u{202D}")  // LRO
        chars.insert("\u{202C}")  // PDF
        chars.insert("\u{200F}")  // RTL mark
        chars.insert("\u{200E}")  // LTR mark
        // Soft hyphen, line separator, paragraph separator
        chars.insert("\u{00AD}")  // Soft hyphen
        chars.insert("\u{2028}")  // Line separator
        chars.insert("\u{2029}")  // Paragraph separator
        return chars
    }()

    /// Scan a cron prompt for invisible unicode characters.
    /// - Returns: .clean / .blocked(reason) / .suspicious(warning).
    public static func scan(_ prompt: String) -> CronPromptScanResult {
        // Iterate unicodeScalars (NOT Characters) to avoid grapheme clustering
        // (ZWJ + adjacent chars form 1 grapheme cluster → invisible in for-char loop).
        var foundInvisible: [Unicode.Scalar] = []
        for scalar in prompt.unicodeScalars {
            let char = Character(scalar)
            if invisibleChars.contains(char) {
                foundInvisible.append(scalar)
            }
        }
        if !foundInvisible.isEmpty {
            let codes = foundInvisible.map { String(format: "U+%04X", $0.value) }
            let uniqueCodes = Array(Set(codes)).sorted()
            return .blocked(reason: "invisible unicode chars detected: \(uniqueCodes.joined(separator: ", ")). hermes _check_invisible_unicode parity. likely prompt injection.")
        }
        // Heuristic: excessive emoji density (> 5% of chars) is suspicious.
        // Not a hard block, just warn (hermes _strip_legitimate_emoji_zwj allows some).
        let emojiCount = prompt.unicodeScalars.filter { $0.properties.isEmojiPresentation }.count
        if !prompt.isEmpty && Double(emojiCount) / Double(prompt.count) > 0.05 {
            return .suspicious(warning: "high emoji density (\(emojiCount)/\(prompt.count) = \(String(format: "%.1f%%", Double(emojiCount) / Double(prompt.count) * 100))). review for legitimate use.")
        }
        return .clean
    }
}