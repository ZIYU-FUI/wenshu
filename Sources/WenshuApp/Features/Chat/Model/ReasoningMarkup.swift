// ReasoningMarkup.swift
//
// Splits an assistant's reasoning into labelled steps.
//
// Hermes does this on the model side: the model writes its work log with
// action and result markers, and the interface renders each one as its own
// labelled block, so the reader can see what was attempted and what came
// back. The markers are part of the model's own output, so a model that
// never learned to write them produces one undifferentiated block of
// reasoning.
//
// That is why the tool-derived activity exists alongside this: the tool
// calls are a fact, the markers are the model's own account of itself. This
// parser handles the markers when they are there, and the activity fills
// the gap when they are not.
//
// The parsing is fence-aware on purpose. A code block can contain
// something that looks like a marker, and a marker inside a fence is text,
// not structure.

import Foundation

/// One piece of the assistant's reasoning.
enum ReasoningSegment: Equatable, Sendable {
    /// Ordinary reasoning prose.
    case prose(String)
    /// The assistant said it was doing something.
    case action(String)
    /// The assistant said something came back.
    case result(String)

    var text: String {
        switch self {
        case .prose(let text), .action(let text), .result(let text): return text
        }
    }
}

enum ReasoningMarkupParser {
    /// The markers this parser understands.
    ///
    /// `thinking` and `reflection` are read but not given their own block:
    /// they are the model narrating to itself, which is prose. `action` and
    /// `result` are the two that carry a step.
    ///
    /// Two spellings are accepted. The bracketed one (`[[action: ...]]`) is
    /// the form the system prompt teaches, so it is what a model following
    /// the instructions will write. The angle-bracket one (`<action>`) is
    /// the form Hermes uses, so a model that learned that habit is still
    /// understood.
    private static let knownTags: Set<String> = ["thinking", "reflection", "action", "result"]

    /// Split the reasoning into segments.
    static func parse(_ content: String) -> [ReasoningSegment] {
        let segments = splitFenceAware(content).flatMap { chunk -> [ReasoningSegment] in
            guard chunk.isCode else { return parseTags(chunk.text) }
            let trimmed = chunk.text.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? [] : [.prose(chunk.text)]
        }
        return mergeAdjacentProse(segments)
    }

    /// Whether the content carries any marker at all.
    ///
    /// Used to decide whether the structured rendering is worth it: text
    /// without markers renders identically either way, so there is no reason
    /// to take the other path.
    static func hasMarkup(_ content: String) -> Bool {
        splitFenceAware(content).contains { chunk in
            guard !chunk.isCode else { return false }
            return nextMarker(in: chunk.text, from: chunk.text.startIndex) != nil
        }
    }

    // MARK: - Fence handling

    /// A run of text plus whether it sits inside a code fence.
    private struct Chunk {
        let text: String
        let isCode: Bool
    }

    /// Split the content on code fences, marking the fenced runs.
    ///
    /// A fence that is never closed runs to the end of the content, which is
    /// what a reader would see too.
    private static func splitFenceAware(_ content: String) -> [Chunk] {
        var chunks: [Chunk] = []
        var current = ""
        var inCode = false
        for line in content.split(separator: "\n", omittingEmptySubsequences: false) {
            let text = String(line)
            if text.hasPrefix("```") {
                if inCode {
                    current += text + "\n"
                    chunks.append(Chunk(text: current, isCode: true))
                    current = ""
                    inCode = false
                } else {
                    if !current.isEmpty {
                        chunks.append(Chunk(text: current, isCode: false))
                        current = ""
                    }
                    current = text + "\n"
                    inCode = true
                }
            } else {
                current += text + "\n"
            }
        }
        if !current.isEmpty {
            chunks.append(Chunk(text: current, isCode: inCode))
        }
        return chunks
    }

    // MARK: - Tag handling



    /// The tag name at the given position, if the position starts one.
    private static func tagName(in content: String, at index: String.Index) -> String? {
        let after = content.index(after: index)
        guard after < content.endIndex, content[after] != "/" else { return nil }
        let rest = content[after...]
        let name = rest.prefix { $0.isLetter }
        return name.isEmpty ? nil : String(name)
    }


    /// A located marker, in either spelling.
    private struct Marker {
        let name: String
        /// The range the marker's content occupies.
        let contentRange: Range<String.Index>
        /// The range the whole marker occupies.
        let markerRange: Range<String.Index>
    }

    /// Find the next marker, in either spelling.
    ///
    /// The bracketed form comes first because it is the form the prompt
    /// teaches, so it is the one a cooperating model writes.
    private static func nextMarker(in content: String, from cursor: String.Index) -> Marker? {
        var search = cursor
        while search < content.endIndex {
            // Bracketed form: "[[action: content]]".
            if let open = content.range(of: "[[", range: search..<content.endIndex) {
                let afterOpen = open.upperBound
                // The colon that ends the name is found without a length
                // limit: a bracketed run that is not a marker simply has a
                // name that is not one of the known ones, and is skipped.
                guard let colon = content.range(of: ":", range: afterOpen..<content.endIndex)
                else {
                    search = open.upperBound
                    continue
                }
                let name = String(content[afterOpen..<colon.lowerBound])
                    .trimmingCharacters(in: .whitespaces)
                guard knownTags.contains(name),
                      let close = content.range(of: "]]", range: colon.upperBound..<content.endIndex)
                else {
                    search = open.upperBound
                    continue
                }
                return Marker(
                    name: name,
                    contentRange: colon.upperBound..<close.lowerBound,
                    markerRange: open.lowerBound..<close.upperBound
                )
            }
            // Angle-bracket form: "<action>content</action>".
            if let open = content.range(of: "<", range: search..<content.endIndex) {
                guard let name = tagName(in: content, at: open.lowerBound), knownTags.contains(name),
                      let close = content.range(of: "</\(name)>", range: open.upperBound..<content.endIndex)
                else {
                    search = open.upperBound
                    continue
                }
                // The content starts after the tag name, not after the
                // opening angle bracket: "<action>text</action>" carries
                // the name and its ">" between the bracket and the text.
                guard let contentStart = content.index(
                    open.upperBound,
                    offsetBy: name.count + 1,
                    limitedBy: close.lowerBound
                ) else {
                    search = open.upperBound
                    continue
                }
                return Marker(
                    name: name,
                    contentRange: contentStart..<close.lowerBound,
                    markerRange: open.lowerBound..<close.upperBound
                )
            }
            return nil
        }
        return nil
    }

    /// Split one chunk into segments by its markers.
    private static func parseTags(_ content: String) -> [ReasoningSegment] {
        var segments: [ReasoningSegment] = []
        var outputCursor = content.startIndex
        var searchCursor = content.startIndex

        while let marker = nextMarker(in: content, from: searchCursor) {
            if marker.markerRange.lowerBound > outputCursor {
                segments.append(.prose(String(content[outputCursor..<marker.markerRange.lowerBound])))
            } else if marker.markerRange.lowerBound < outputCursor {
                // The marker starts before the text already consumed, so
                // it overlaps what was read. It is skipped rather than
                // read backwards, which would be out of range.
                searchCursor = marker.markerRange.upperBound
                outputCursor = marker.markerRange.upperBound
                continue
            }
            let inner = String(content[marker.contentRange])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !inner.isEmpty {
                switch marker.name {
                case "action": segments.append(.action(inner))
                case "result": segments.append(.result(inner))
                default: segments.append(.prose(inner))
                }
            }
            outputCursor = marker.markerRange.upperBound
            searchCursor = marker.markerRange.upperBound
        }

        if outputCursor < content.endIndex {
            segments.append(.prose(String(content[outputCursor...])))
        }
        return segments
    }

    /// Remove the newline the line splitting leaves behind.
    ///
    /// The splitting works line by line and rejoins them with a newline, so
    /// every chunk ends with one. The newline is not part of what the model
    /// wrote, and leaving it makes the comparison against the source text
    /// fail for no reason.
    private static func trimTrailingNewline(_ text: String) -> String {
        guard text.hasSuffix("\n") else { return text }
        return String(text.dropLast())
    }

    /// Fold neighbouring prose into one block and drop the blank ones.
    ///
    /// Without the folding a paragraph of reasoning would arrive as many
    /// one-line fragments, which is noise rather than structure. The blank
    /// blocks go because the line splitting leaves a newline behind, and an
    /// empty paragraph would render as an empty line above the steps.
    private static func mergeAdjacentProse(_ segments: [ReasoningSegment]) -> [ReasoningSegment] {
        var merged: [ReasoningSegment] = []
        for segment in segments {
            // The previous entry is read through an explicit unwrap rather
            // than an optional pattern: the pattern also matches a missing
            // entry, and then the index below would be out of range.
            if case .prose(let text) = segment,
               let previous = merged.last,
               case .prose(let previousText) = previous {
                merged[merged.count - 1] = .prose(previousText + text)
            } else {
                merged.append(segment)
            }
        }
        merged = merged.map { segment in
            if case .prose(let text) = segment {
                return .prose(trimTrailingNewline(text))
            }
            return segment
        }
        return merged.compactMap { segment in
            if case .prose(let text) = segment,
               text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return nil
            }
            return segment
        }
    }
}
