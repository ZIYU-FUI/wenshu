//
//  ReasonScrubber.swift · Wenshu · HERMES-INTERNAL-003 (2026-09-04)
//
//  1:1 port of hermes think_scrubber.py (= hermes-internal module #3,
//  boss 2026-09-04 OOB 'A'). Thin specialization over wenshu's
//  MessageSanitization.swift (= the canonical hermes-port surface that
//  already strips C0 controls, surrogates, and unescaped JSON chars).
//
//  ReasonScrubber.scrub() strips reasoning/thinking blocks
//  (<think>...</think>, <reasoning>...</reasoning>, <thinking>...</thinking>,
//  <thought>...</thought>, <REASONING_SCRATCHPAD>...</REASONING_SCRATCHPAD>)
//  before persistence. The preserving-intent variant keeps a short marker
//  so internal logs can still see reasoning happened without leaking the
//  raw content.
//
//  Wenshu-side wins preserved: thin adapter. Delegates to
//  MessageSanitization.sanitizeText for the actual character handling
//  (= ensures the same control-char + surrogate policy applies).
//

import Foundation

public enum ReasonScrubber {

    // MARK: - Tag variants (= hermes think_scrubber._OPEN_TAG_NAMES)

    private static let openTagNames: [String] = [
        "think",
        "thinking",
        "reasoning",
        "thought",
        "REASONING_SCRATCHPAD",
    ]

    private static let openTags: [String] = openTagNames.map { "<\($0)>" }
    private static let closeTags: [String] = openTagNames.map { "</\($0)>" }

    // MARK: - Public API

    /// Strip every reasoning/thinking block from the input. Returns the
    /// remaining visible text (= collapses whitespace around the block
    /// so the output reads as continuous prose).
    public static func scrub(_ text: String) -> String {
        guard !text.isEmpty else { return text }
        var result = text
        for tag in openTags {
            result = stripBlocks(openingTag: tag, closingTag: closingTag(for: tag), in: result)
        }
        // Normalize runs of whitespace introduced by block removal
        // (= hermes keeps prose flow continuous after a stripped block).
        result = collapseWhitespace(result)
        // Pass through the canonical sanitizer (= C0 control strip + surrogates).
        return MessageSanitization.sanitizeText(result)
    }

    /// Same as scrub(), but emits a short marker `[reasoning: <tag>]` in
    /// place of each block — useful for internal logs where you want to
    /// see that reasoning occurred without exposing its raw content.
    public static func scrubPreservingIntent(_ text: String) -> String {
        guard !text.isEmpty else { return text }
        var result = text
        for tag in openTags {
            let close = closingTag(for: tag)
            let label = "[\(reasoningLabel(for: tag))]"
            result = replaceBlocks(
                openingTag: tag,
                closingTag: close,
                in: result,
                with: label
            )
        }
        return MessageSanitization.sanitizeText(result)
    }

    // MARK: - Internals

    private static func closingTag(for openingTag: String) -> String {
        // openingTag is e.g. "<thinking>"; closing tag is "</thinking>".
        guard openingTag.hasPrefix("<") && openingTag.hasSuffix(">") else {
            return ""
        }
        let inner = openingTag.dropFirst().dropLast()
        return "</\(inner)>"
    }

    private static func reasoningLabel(for openingTag: String) -> String {
        // openingTag is e.g. "<REASONING_SCRATCHPAD>"; return
        // "reasoning: REASONING_SCRATCHPAD".
        let inner = openingTag
            .replacingOccurrences(of: "<", with: "")
            .replacingOccurrences(of: ">", with: "")
        return "reasoning: \(inner)"
    }

    /// Strip every `<tag>...</tag>` block (= non-greedy, case-insensitive).
    /// Matches hermes _strip_think_blocks semantics: a closed pair is
    /// always an intentional bounded construct and is removed regardless
    /// of boundary position.
    private static func stripBlocks(openingTag: String, closingTag: String, in text: String) -> String {
        replaceBlocks(openingTag: openingTag, closingTag: closingTag, in: text, with: "")
    }

    /// Replace every `<tag>...</tag>` block with the given substitution.
    private static func replaceBlocks(
        openingTag: String,
        closingTag: String,
        in text: String,
        with replacement: String
    ) -> String {
        let openLower = openingTag.lowercased()
        let closeLower = closingTag.lowercased()
        let textLower = text.lowercased()

        var output = ""
        var cursor = text.startIndex

        while cursor < text.endIndex {
            let searchRange = cursor..<text.endIndex
            guard let openIdx = textLower.range(of: openLower, range: searchRange) else {
                output.append(contentsOf: text[cursor..<text.endIndex])
                break
            }
            // Append the prefix between cursor and the open tag.
            output.append(contentsOf: text[cursor..<openIdx.lowerBound])
            // Find the matching close tag after the open one.
            let afterOpen = openIdx.upperBound..<text.endIndex
            if let closeIdx = textLower.range(of: closeLower, range: afterOpen) {
                // Drop the entire block; emit the replacement.
                output.append(replacement)
                cursor = closeIdx.upperBound
            } else {
                // Unterminated open tag — preserve the rest verbatim so
                // prose that *mentions* the tag name is not over-stripped.
                output.append(contentsOf: text[openIdx.lowerBound..<text.endIndex])
                cursor = text.endIndex
            }
        }
        return output
    }

    /// Collapse runs of 3+ newlines into 2 (= preserves paragraph
    /// boundaries) and trim trailing whitespace on each line.
    private static func collapseWhitespace(_ text: String) -> String {
        // Collapse \n\n\n+ → \n\n
        var out = text
        while out.contains("\n\n\n") {
            out = out.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }
        // Trim trailing whitespace on each line.
        var normalizedLines = out.components(separatedBy: "\n").map { line in
            line.trimmingCharacters(in: CharacterSet(charactersIn: " \t"))
        }
        // Drop trailing empty lines.
        while normalizedLines.last == "" {
            normalizedLines.removeLast()
        }
        return normalizedLines.joined(separator: "\n")
    }
}