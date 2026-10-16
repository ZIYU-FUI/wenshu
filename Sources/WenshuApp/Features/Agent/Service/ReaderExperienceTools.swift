// 
// … (= 79 rationale lines collapsed; = A112 docblock collapse per §1.8)
// 
import Foundation

// MARK: - Public surface
// … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
// / `agent/specialized/reader_experience.py`.
enum ReaderExperienceKind: String, Sendable, Codable, CaseIterable, Identifiable {
    /// Emotional intensity curve across the chapter.
    case tension
    /// Scene density (= dialogue vs. prose ratio).
    case pacing
    /// Setup-sentence density per 1000 words (= how many foreshadowing beats
    /// the chapter plants).
    case foreshadowingDensity
    /// Chapter-ending unresolved hook.
    case cliffhanger
    /// Resolves an earlier foreshadowed setup.
    case payoffDetector

    var id: String { rawValue }

    /// Display label for the SwiftUI tab.
    var displayName: String {
        switch self {
        case .tension:               return "Tension"
        case .pacing:                return "Pacing"
        case .foreshadowingDensity:  return "Foreshadowing"
        case .cliffhanger:           return "Cliffhanger"
        case .payoffDetector:        return "Payoff"
        }
    }

    /// One-sentence hint shown next to the picker.
    var hint: String {
        switch self {
        case .tension:
            return "Emotional intensity curve (= 0..1, higher = steeper escalation)."
        case .pacing:
            return "Scene density (= fast = dialogue-heavy; slow = description-heavy)."
        case .foreshadowingDensity:
            return "Setup-sentence density per 1000 words (= how many foreshadowing beats this chapter plants)."
        case .cliffhanger:
            return "Detects a chapter-ending question or unresolved pronoun."
        case .payoffDetector:
            return "Detects a chapter that resolves an earlier foreshadowed setup."
        }
    }

    // / SF Symbols 6 icon name (= Apple canonical; = used by Image(systemName:)
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / Lucide-era names removed Migrated to outline glyphs.
    var icon: String {
        switch self {
        case .tension:               return "waveform.path.ecg"           // Lucide 'activity'
        case .pacing:                return "gauge.with.dots.needle.bottom.50percent"  // Lucide 'gauge'
        case .foreshadowingDensity:  return "arrow.triangle.branch"       // Lucide 'git-fork'
        case .cliffhanger:           return "link.horizontal"             // Lucide 'anchor'
        case .payoffDetector:        return "checkmark.circle"            // Lucide 'check-circle-2'
        }
    }
}

/// A single evidence span inside the chapter text. The view layer renders
/// highlights inline (= matched text + the offset range).
struct ReaderExperienceHighlight: Sendable, Codable, Equatable, Hashable {
    // / Character offset into the chapter (= 0-based; Swift String uses
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / re-locate the span regardless of grapheme breaks).
    let utf8Offset: Int

    /// Length of the matched span in UTF-8 bytes.
    let utf8Length: Int

    /// The matched substring (= the chapter slice this highlight refers to).
    let text: String

    /// Short label (= e.g. "setup", "callback", "question", "dialogue line",
    /// "stress peak"). The view uses this as the badge text.
    let label: String

    init(utf8Offset: Int, utf8Length: Int, text: String, label: String) {
        self.utf8Offset = utf8Offset
        self.utf8Length = utf8Length
        self.text = text
        self.label = label
    }
}

// / One actionable hint for the writer (= "add more dialogue here", "raise
// … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
// / context.
struct ReaderExperienceSuggestion: Sendable, Codable, Equatable, Hashable {
    let text: String

    init(text: String) {
        self.text = text
    }
}

/// The analyzer output (= matches the task spec verbatim).
struct ReaderExperienceReport: Sendable, Codable, Equatable {
    let kind: ReaderExperienceKind
    // / Normalized score in 0..1. The semantics differ per kind (= see
    // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / detected, 1 = detected); we still expose it as 0..1 for UI uniformity.
    let score: Double
    /// Evidence spans (= the strings the analyzer matched).
    let highlights: [ReaderExperienceHighlight]
    /// Writer-facing suggestions.
    let suggestions: [ReaderExperienceSuggestion]
    /// Human-readable summary (= a one-paragraph description of what the
    /// analyzer found). The view renders this above the highlights list.
    let summary: String

    init(
        kind: ReaderExperienceKind,
        score: Double,
        highlights: [ReaderExperienceHighlight] = [],
        suggestions: [ReaderExperienceSuggestion] = [],
        summary: String = ""
    ) {
        self.kind = kind
        self.score = max(0.0, min(1.0, score))
        self.highlights = highlights
        self.suggestions = suggestions
        self.summary = summary
    }
}

// MARK: - Errors
// … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
// / `fatalError` paths).
enum ReaderExperienceAnalyzerError: Error, LocalizedError, Sendable, Equatable {
    case emptyChapter
    case unsupportedKind(String)

    var errorDescription: String? {
        switch self {
        case .emptyChapter:
            return "ReaderExperienceAnalyzer: chapter text is empty."
        case .unsupportedKind(let raw):
            return "ReaderExperienceAnalyzer: unsupported kind raw value `\(raw)`."
        }
    }
}

// MARK: - Actor
// … (= 10 rationale lines collapsed; = A112 docblock collapse per §1.8)
// / verbatim; the actor remains trivially testable).
actor ReaderExperienceAnalyzer {
    /// Reserved for future payoffDetector integration (= reading the per-book
    /// foreshadowing catalog from disk).
    private let bookStore: BookStore?

    /// FileManager override (= tests inject .default; production uses
    /// .default). Reserved for the same payoffDetector future feature work.
    private let fileManager: FileManager

    // / Internal init (= matches the `LongFormGuardrails` access-level
    // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / of the wenshu app (= all callers live inside the same module).
    init(bookStore: BookStore? = nil, fileManager: FileManager = .default) {
        self.bookStore = bookStore
        self.fileManager = fileManager
    }

    // MARK: - Public API
    // … (= 6 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / defensive — should never fire in practice since the enum is exhaustive).
    func analyze(
        chapterText: String,
        kind: ReaderExperienceKind
    ) async throws -> ReaderExperienceReport {
        let trimmed = chapterText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ReaderExperienceAnalyzerError.emptyChapter
        }

        switch kind {
        case .tension:
            return tensionReport(chapterText: trimmed)
        case .pacing:
            return pacingReport(chapterText: trimmed)
        case .foreshadowingDensity:
            return foreshadowingDensityReport(chapterText: trimmed)
        case .cliffhanger:
            return cliffhangerReport(chapterText: trimmed)
        case .payoffDetector:
            return payoffDetectorReport(chapterText: trimmed)
        }
    }

    // MARK: - 1. Tension analyzer
    // … (= 7 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / peak (= cliff-hanger style) returns close to 1.
    private func tensionReport(chapterText: String) -> ReaderExperienceReport {
        let paragraphs = Self.splitIntoParagraphs(chapterText)
        guard !paragraphs.isEmpty else {
            return ReaderExperienceReport(
                kind: .tension,
                score: 0,
                summary: "No paragraphs detected."
            )
        }

        let stressPerParagraph = paragraphs.map { stressScore(for: $0) }
        let slope = Self.normalizedSlope(of: stressPerParagraph)
        // Map slope from -1..1 (where 1 = strictly increasing) into 0..1.
        let score = max(0.0, min(1.0, (slope + 1.0) / 2.0))

        // Highlights = the top-3 paragraphs by stress score.
        let topStress: [(index: Int, score: Double)] = stressPerParagraph
            .enumerated()
            .map { (index: $0.offset, score: $0.element) }
            .sorted { $0.score > $1.score }
            .prefix(3)
            .map { $0 }

        var highlights: [ReaderExperienceHighlight] = []
        for entry in topStress where entry.score > 0 {
            if let offset = Self.utf8Offset(of: paragraphs[entry.index], in: chapterText) {
                let snippet = String(paragraphs[entry.index].prefix(80))
                highlights.append(
                    ReaderExperienceHighlight(
                        utf8Offset: offset,
                        utf8Length: paragraphs[entry.index].utf8.count,
                        text: snippet,
                        label: "stress peak (\(Self.formatPercent(entry.score)))"
                    )
                )
            }
        }

        var suggestions: [ReaderExperienceSuggestion] = []
        if score < 0.3 {
            suggestions.append(ReaderExperienceSuggestion(
                text: "Stakes feel flat. Raise the cost of inaction in at least one mid-chapter scene."
            ))
        } else if score > 0.85 {
            suggestions.append(ReaderExperienceSuggestion(
                text: "Tension climbs hard. Consider a brief release beat so the climax lands cleanly."
            ))
        } else {
            suggestions.append(ReaderExperienceSuggestion(
                text: "Tension curve is healthy. Verify the climax paragraph still has the highest stress."
            ))
        }

        let summary = "Tension slope = \(Self.formatPercent(score)) across \(paragraphs.count) paragraphs."
        return ReaderExperienceReport(
            kind: .tension,
            score: score,
            highlights: highlights,
            suggestions: suggestions,
            summary: summary
        )
    }

    // / Per-paragraph stress score. Computed as: stressTokens / max(1,
    // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / is clamped to 0..1.
    private func stressScore(for paragraph: String) -> Double {
        let lower = paragraph.lowercased()
        let words = Self.wordCount(of: paragraph)
        guard words > 0 else { return 0 }

        var hits = 0
        for token in Self.stressVocabulary {
            hits += Self.countOccurrences(of: token, in: lower)
        }
        let exclamationCount = paragraph.filter { $0 == "!" }.count
        let questionCount = paragraph.filter { $0 == "?" }.count
        hits += exclamationCount
        hits += questionCount

        // Density per 100 words, clamped.
        let raw = Double(hits) / Double(words) * 100.0
        return max(0.0, min(1.0, raw / 8.0))
    }

    // / The curated stress vocabulary (= small enough to keep the analyzer
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / closed-set).
    private static let stressVocabulary: [String] = [
        "danger", "dangerous",
        "death", "dead", "die", "dying",
        "blood", "wound", "wounded",
        "fear", "afraid", "terror", "terrified",
        "fight", "attack", "struck", "strike",
        "scream", "shout", "yell",
        "run", "flee", "escape", "chase",
        "enemy", "enemies",
        "weapon", "blade", "sword", "gun",
        "fire", "burn", "burning",
        "trap", "trapped",
        "ruin", "destroy", "destroyed",
        "fail", "failure",
        "lose", "lost", "losing",
        "warn", "warning",
        "danger", "peril", "doom",
        "kill", "killed", "murder",
    ]

    // MARK: - 2. Pacing analyzer
    // … (= 3 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / 1 = pure dialogue; 0 = pure description).
    private func pacingReport(chapterText: String) -> ReaderExperienceReport {
        let lines = chapterText.split(whereSeparator: { $0.isNewline }).map(String.init)
        let dialogueLines = lines.filter { Self.isDialogueLine($0) }.count
        let totalLines = max(lines.count, 1)
        let score = Double(dialogueLines) / Double(totalLines)

        var highlights: [ReaderExperienceHighlight] = []
        // Mark up to 5 dialogue lines (= the "evidence" the
        // analyzer used).
        let dialogueSamples = lines.filter { Self.isDialogueLine($0) }.prefix(5)
        for sample in dialogueSamples {
            if let offset = Self.utf8Offset(of: sample, in: chapterText) {
                let trimmed = sample.trimmingCharacters(in: .whitespacesAndNewlines)
                highlights.append(
                    ReaderExperienceHighlight(
                        utf8Offset: offset,
                        utf8Length: sample.utf8.count,
                        text: String(trimmed.prefix(80)),
                        label: "dialogue line"
                    )
                )
            }
        }

        var suggestions: [ReaderExperienceSuggestion] = []
        let label: String
        if score >= 0.5 {
            label = "fast"
            suggestions.append(ReaderExperienceSuggestion(
                text: "Pacing reads fast (= dialogue-heavy). Add a quiet beat so the high-stakes scenes land."
            ))
        } else if score >= 0.2 {
            label = "balanced"
            suggestions.append(ReaderExperienceSuggestion(
                text: "Pacing reads balanced. Keep alternating dialogue with action beats."
            ))
        } else {
            label = "slow"
            suggestions.append(ReaderExperienceSuggestion(
                text: "Pacing reads slow (= description-heavy). Open a scene with dialogue to accelerate entry."
            ))
        }

        let summary = "Pacing = \(label) (\(dialogueLines) dialogue lines of \(totalLines) total)."
        return ReaderExperienceReport(
            kind: .pacing,
            score: score,
            highlights: highlights,
            suggestions: suggestions,
            summary: summary
        )
    }

    // / A "dialogue line" = a line that starts with a quote mark (= either
    // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / close enough for the pacing signal).
    private static func isDialogueLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard let first = trimmed.first else { return false }
        return first == "\""
            || first == "“"
            || first == "”"
            || first == "\u{FF02}" // full-width
            || first == "「"
    }

    // MARK: - 3. Foreshadowing density
    // … (= 4 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / 1000 words = full score). - highlights = the matched setup sentences.
    private func foreshadowingDensityReport(chapterText: String) -> ReaderExperienceReport {
        let words = Self.wordCount(of: chapterText)
        guard words > 0 else {
            return ReaderExperienceReport(
                kind: .foreshadowingDensity,
                score: 0,
                summary: "Chapter is empty."
            )
        }
        let sentences = Self.splitIntoSentences(chapterText)
        var setupHits: [(sentence: String, offset: Int)] = []
        for sentence in sentences {
            if Self.isSetupSentence(sentence) {
                if let offset = Self.utf8Offset(of: sentence, in: chapterText) {
                    setupHits.append((sentence: sentence, offset: offset))
                }
            }
        }
        let density = Double(setupHits.count) / Double(words) * 1000.0
        let score = max(0.0, min(1.0, density / 5.0))

        var highlights: [ReaderExperienceHighlight] = []
        for hit in setupHits.prefix(10) {
            let snippet = String(hit.sentence.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80))
            highlights.append(
                ReaderExperienceHighlight(
                    utf8Offset: hit.offset,
                    utf8Length: hit.sentence.utf8.count,
                    text: snippet,
                    label: "setup"
                )
            )
        }

        var suggestions: [ReaderExperienceSuggestion] = []
        if score < 0.2 {
            suggestions.append(ReaderExperienceSuggestion(
                text: "Few setup beats detected. Plant at least one foreshadowing line so later payoffs feel earned."
            ))
        } else if score > 0.8 {
            suggestions.append(ReaderExperienceSuggestion(
                text: "Dense foreshadowing. Verify each setup has a matching payoff queued (= see Payoff analyzer)."
            ))
        } else {
            suggestions.append(ReaderExperienceSuggestion(
                text: "Setup density is healthy. Continue matching each setup with a payoff within 3-5 chapters."
            ))
        }

        let summary = "Setup density = \(setupHits.count) in \(words) words (= \(Self.formatDecimal(density)) per 1000)."
        return ReaderExperienceReport(
            kind: .foreshadowingDensity,
            score: score,
            highlights: highlights,
            suggestions: suggestions,
            summary: summary
        )
    }

    /// Setup-verb vocabulary (= small closed set; = the Python module keeps
    /// this set short to avoid false positives).
    private static let setupVerbs: [String] = [
        "promised", "promise", "promises",
        "warned", "warn", "warns", "warning",
        "remember", "remembered", "remembers",
        "noticed", "notice", "notices",
        "wondered", "wonder", "wonders",
        "sensed", "sense", "senses",
        "felt", "feel", "feels",
        "thought", "think", "thinks",
        "suspected", "suspect", "suspects",
        "predicted", "predict", "predicts",
        "hinted", "hint", "hints",
        "swore", "swear", "swears",
        "vowed", "vow", "vows",
        "asked", "ask", "asks",
        "mused", "muse", "muses",
    ]

    /// Setup openers (= phrase prefixes that signal "this will matter later").
    private static let setupOpeners: [String] = [
        "little did",
        "if only",
        "what if",
        "would later",
        "had no idea",
        "didn't know",
        "unknown to",
        "someday",
        "one day",
        "before long",
    ]

    private static func isSetupSentence(_ sentence: String) -> Bool {
        let lower = sentence.lowercased()
        // Check openers first (= cheaper; = match if the first
        // chunk matches one of the known openers).
        let words = lower.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard !words.isEmpty else { return false }

        // Opener match (= first 1..3 words).
        let first1 = words.prefix(1).joined(separator: " ")
        let first2 = words.prefix(2).joined(separator: " ")
        let first3 = words.prefix(3).joined(separator: " ")
        if setupOpeners.contains(first1)
            || setupOpeners.contains(first2)
            || setupOpeners.contains(first3) {
            return true
        }

        // Verb match (= any token in the sentence equals one of
        // the setup verbs).
        for token in words {
            // Strip simple punctuation (= commas / periods).
            let stripped = token.trimmingCharacters(in: .punctuationCharacters)
            if setupVerbs.contains(stripped) {
                return true
            }
        }
        return false
    }

    // MARK: - 4. Cliffhanger analyzer
    // … (= 5 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / suggesting an unresolved subject.
    private func cliffhangerReport(chapterText: String) -> ReaderExperienceReport {
        let sentences = Self.splitIntoSentences(chapterText)
        guard let lastSentence = sentences.last else {
            return ReaderExperienceReport(
                kind: .cliffhanger,
                score: 0,
                summary: "No sentences detected."
            )
        }
        let trimmed = lastSentence.trimmingCharacters(in: .whitespacesAndNewlines)

        var detected = false
        var reason = ""

        if trimmed.hasSuffix("?") {
            detected = true
            reason = "ends with a question mark"
        } else if trimmed.hasSuffix("…") || trimmed.hasSuffix("...") {
            detected = true
            reason = "ends with a trailing ellipsis"
        } else {
            let words = trimmed.split(whereSeparator: { $0.isWhitespace }).map(String.init)
            if words.count < 12, let lastWord = words.last {
                let normalized = lastWord
                    .trimmingCharacters(in: .punctuationCharacters)
                    .lowercased()
                if Self.unresolvedPronouns.contains(normalized) {
                    detected = true
                    reason = "ends on an unresolved pronoun (\(normalized))"
                }
            }
        }

        let score: Double = detected ? 1.0 : 0.0
        let summary: String
        var highlights: [ReaderExperienceHighlight] = []
        if detected {
            summary = "Cliffhanger detected — \(reason)."
            if let offset = Self.utf8Offset(of: lastSentence, in: chapterText) {
                let snippet = String(trimmed.prefix(80))
                highlights.append(
                    ReaderExperienceHighlight(
                        utf8Offset: offset,
                        utf8Length: lastSentence.utf8.count,
                        text: snippet,
                        label: "cliffhanger"
                    )
                )
            }
        } else {
            summary = "No cliffhanger detected in the final sentence."
        }

        let suggestions: [ReaderExperienceSuggestion]
        if detected {
            suggestions = [
                ReaderExperienceSuggestion(
                    text: "Cliffhanger present. Verify the next chapter answers the question within 200 words."
                )
            ]
        } else {
            suggestions = [
                ReaderExperienceSuggestion(
                    text: "No cliffhanger. Consider ending on a question or an unresolved pronoun to pull the reader forward."
                )
            ]
        }

        return ReaderExperienceReport(
            kind: .cliffhanger,
            score: score,
            highlights: highlights,
            suggestions: suggestions,
            summary: summary
        )
    }

    private static let unresolvedPronouns: Set<String> = [
        "he", "she", "it", "they",
        "him", "her", "them",
        "his", "hers", "its", "their", "theirs",
        "ours", "mine",
    ]

    // MARK: - 5. Payoff detector
    // … (= 6 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / feature work can split it into multiple payoff flavors).
    private func payoffDetectorReport(chapterText: String) -> ReaderExperienceReport {
        let lower = chapterText.lowercased()
        let hasResolution = Self.resolutionVerbs.contains { verb in
            Self.containsWord(verb, in: lower)
        }
        let hasCallback = Self.callbackPhrases.contains { phrase in
            lower.contains(phrase)
        }
        let detected = hasResolution && hasCallback

        let summary: String
        var highlights: [ReaderExperienceHighlight] = []

        if detected {
            summary = "Payoff detected — chapter resolves an earlier setup."
            // Highlight the first matched callback phrase (= the
            // strongest signal).
            for phrase in Self.callbackPhrases {
                if let range = lower.range(of: phrase) {
                    let utf8Start = lower.utf8.distance(from: lower.utf8.startIndex, to: range.lowerBound)
                    let matched = String(chapterText[chapterText.index(
                        chapterText.startIndex,
                        offsetBy: utf8Start
                    )..<chapterText.index(
                        chapterText.startIndex,
                        offsetBy: utf8Start + phrase.utf8.count
                    )])
                    highlights.append(
                        ReaderExperienceHighlight(
                            utf8Offset: utf8Start,
                            utf8Length: phrase.utf8.count,
                            text: matched,
                            label: "callback"
                        )
                    )
                    break
                }
            }
        } else if hasResolution && !hasCallback {
            summary = "Resolution verb present but no callback phrase — may not read as a payoff."
        } else if !hasResolution && hasCallback {
            summary = "Callback phrase present but no resolution verb — payoff may be implicit."
        } else {
            summary = "No payoff detected — chapter does not appear to resolve an earlier setup."
        }

        let suggestions: [ReaderExperienceSuggestion]
        if detected {
            suggestions = [
                ReaderExperienceSuggestion(
                    text: "Payoff present. Echo the original setup wording so readers feel the closure."
                )
            ]
        } else {
            suggestions = [
                ReaderExperienceSuggestion(
                    text: "No payoff detected. Add a callback phrase (e.g. 'as expected', 'just as planned') next to a resolution verb."
                )
            ]
        }

        return ReaderExperienceReport(
            kind: .payoffDetector,
            score: detected ? 1.0 : 0.0,
            highlights: highlights,
            suggestions: suggestions,
            summary: summary
        )
    }

    /// Resolution verbs (= small closed set; matches the Python module).
    private static let resolutionVerbs: [String] = [
        "won", "wins", "defeated", "defeats",
        "discovered", "discovers", "found", "finds",
        "killed", "kills",
        "escaped", "escapes",
        "saved", "saves",
        "revealed", "reveals",
        "returned", "returns",
        "arrived", "arrives",
        "conquered", "conquers",
        "recovered", "recovers",
        "survived", "survives",
    ]

    /// Callback phrases that signal "this resolves an earlier promise".
    private static let callbackPhrases: [String] = [
        "as expected",
        "as planned",
        "as predicted",
        "the plan worked",
        "just as",
        "at last",
        "finally",
        "as promised",
        "as foretold",
        "as foreseen",
        "as feared",
        "as hoped",
        "as warned",
    ]

    // MARK: - Shared text utilities
    // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / dropped.
    static func splitIntoParagraphs(_ text: String) -> [String] {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
        let blocks = normalized.components(separatedBy: "\n\n")
        var paragraphs: [String] = []
        for block in blocks {
            let trimmed = block.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                paragraphs.append(block)
            }
        }
        if paragraphs.isEmpty {
            // Fall back to single-newline split if the chapter
            // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // newlines throughout).
            for line in normalized.components(separatedBy: "\n") {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    paragraphs.append(line)
                }
            }
        }
        return paragraphs
    }

    // / Split chapter into sentences (= naive period / question / exclamation
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / "Dr.") are tolerated because the analyzer only needs a coarse signal.
    static func splitIntoSentences(_ text: String) -> [String] {
        var sentences: [String] = []
        var current = ""
        let chars = Array(text)
        for ch in chars {
            current.append(ch)
            if ch == "." || ch == "!" || ch == "?" || ch == "…" {
                let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    sentences.append(trimmed)
                }
                current = ""
            }
        }
        let trailing = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trailing.isEmpty {
            sentences.append(trailing)
        }
        return sentences
    }

    /// Word count (= whitespace-delimited tokens; = drops punctuation from the
    /// count via the split semantics).
    static func wordCount(of text: String) -> Int {
        let tokens = text.split(whereSeparator: { $0.isWhitespace })
        return tokens.filter { !$0.isEmpty }.count
    }

    /// Naive substring count (= counts non-overlapping matches).
    static func countOccurrences(of needle: String, in haystack: String) -> Int {
        guard !needle.isEmpty else { return 0 }
        var count = 0
        var searchRange = haystack.startIndex..<haystack.endIndex
        while let range = haystack.range(of: needle, range: searchRange) {
            count += 1
            searchRange = range.upperBound..<haystack.endIndex
        }
        return count
    }

    // / Word-boundary check (= returns true if `needle` appears as a complete
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / positives like "wins" matching "windows".
    static func containsWord(_ needle: String, in haystack: String) -> Bool {
        guard !needle.isEmpty else { return false }
        var searchRange = haystack.startIndex..<haystack.endIndex
        while let range = haystack.range(of: needle, range: searchRange) {
            let beforeOK: Bool
            if range.lowerBound == haystack.startIndex {
                beforeOK = true
            } else {
                let prevIndex = haystack.index(before: range.lowerBound)
                beforeOK = haystack[prevIndex].isWhitespace
                    || haystack[prevIndex].isNewline
                    || haystack[prevIndex] == "."
                    || haystack[prevIndex] == ","
                    || haystack[prevIndex] == "!"
                    || haystack[prevIndex] == "?"
            }
            let afterIndex = range.upperBound
            let afterOK: Bool
            if afterIndex == haystack.endIndex {
                afterOK = true
            } else {
                let ch = haystack[afterIndex]
                afterOK = ch.isWhitespace
                    || ch.isNewline
                    || ch == "."
                    || ch == ","
                    || ch == "!"
                    || ch == "?"
                    || ch == ";"
            }
            if beforeOK && afterOK {
                return true
            }
            searchRange = range.upperBound..<haystack.endIndex
        }
        return false
    }

    /// Locate the UTF-8 offset of the first occurrence of `needle` in
    /// `haystack`. Returns nil when not found.
    static func utf8Offset(of needle: String, in haystack: String) -> Int? {
        guard let range = haystack.range(of: needle) else { return nil }
        let utf8Start = haystack.utf8.distance(
            from: haystack.utf8.startIndex,
            to: range.lowerBound
        )
        return utf8Start
    }

    /// Compute the normalized slope (= 0..1) of a sequence of points via simple
    /// linear regression. Returns 0 for empty or single-element inputs.
    static func normalizedSlope(of values: [Double]) -> Double {
        guard values.count >= 2 else { return 0 }
        let n = Double(values.count)
        let xs = (0..<values.count).map { Double($0) }
        let meanX = xs.reduce(0, +) / n
        let meanY = values.reduce(0, +) / n
        var num = 0.0
        var den = 0.0
        for i in 0..<values.count {
            let dx = xs[i] - meanX
            num += dx * (values[i] - meanY)
            den += dx * dx
        }
        guard den > 0 else { return 0 }
        let slope = num / den
        // Slope is in score-units per paragraph-index. Map to
        // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // escalation").
        let referenceSlope = 0.1
        let normalized = slope / referenceSlope
        return max(-1.0, min(1.0, normalized))
    }

    /// Format a 0..1 score as a percentage string (= "73%").
    static func formatPercent(_ value: Double) -> String {
        let pct = Int((value * 100.0).rounded())
        return "\(pct)%"
    }

    /// Format a decimal (= 2 fractional digits).
    static func formatDecimal(_ value: Double) -> String {
        return String(format: "%.2f", value)
    }
}
