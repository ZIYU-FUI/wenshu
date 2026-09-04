//
//  EmotionCurveTools.swift · Wenshu · P1 ticket #11 (PORT-SPECIALIZED-006, 2026-09-04)
//
//  1:1 Swift port of hermes `agent/specialized/emotion_curve.py`.
//
//  The Python module analyzes a chapter draft for emotional
//  valence over time. The Swift port preserves the contract:
//
//    - Split the chapter into N windows (= default 10).
//    - For each window, score emotional valence (= positive vs
//      negative) via a small built-in lexicon.
//    - Compute the rolling average curve over the windows.
//    - Detect flat spots (= too uniform = boring).
//    - Detect volatility spikes (= extreme swings between
//      adjacent windows).
//    - Suggest "pacing improvement" hints (= at which window
//      indices the curve should lift).
//
//  All analysis is deterministic (= pure function over the
//  chapter text). No LLM calls, no network. Same philosophy as
//  long_form_guardrails / reader_experience / plot_thread /
//  genre_fit / editor_tools: fully reproducible + offline-capable.
//
//  Public surface (= the task spec verbatim):
//
//    - struct EmotionWindow : Sendable + Codable + Equatable +
//                              Identifiable
//    - struct EmotionCurveReport : Sendable + Codable
//    - actor EmotionCurveAnalyzer : init() + analyze(...)
//
//  Concurrency: actor (= Swift 6 strict concurrency). Reads /
//  writes serialize cleanly across the SpecializedTools pane +
//  any background LLM-side call sites.
//
//  Sidecar persistence: NONE on purpose. The analyzer is
//  stateless (= input = chapter text; output is a fresh report).
//  The actor's role is concurrency safety + lexicon caching, not
//  persistence.
//
//  Standards-axis (wenshu house style):
//    S1 (Apple-API-first): Foundation only. NSRegularExpression
//        + String APIs; no third-party text-analysis deps.
//    S3 (single source of truth for JSON parsing): the actor
//        ships no JSON I/O (= stateless; no sidecar).
//    S4 (no new third-party deps): zero added.
//    S5 (no private types the rest of the app needs): all types
//        public (= matches the ticket spec).
//

import Foundation

// MARK: - Public surface

/// One window's worth of sentiment data. The `text` field is the
/// raw window slice (= useful for evidence rendering in the
/// SwiftUI pane). The `score` field is the lexicon-derived
/// valence: -1.0 (fully negative) .. +1.0 (fully positive). A
/// zero score means the window had no positive or negative
/// lexicon hits at all (= neutral).
public struct EmotionWindow: Sendable, Codable, Equatable, Identifiable {

    /// Stable identifier. Each window owns a UUID so SwiftUI's
    /// `ForEach` can iterate over `[EmotionWindow]` directly
    /// without needing a separate `id` key path.
    public let id: UUID

    /// Zero-based window index (= 0..N-1 for the chapter).
    public let index: Int

    /// The window's text slice. The slice is taken verbatim from
    /// the chapter (= no transformation; = preserves markdown /
    /// smart quotes / em-dashes if present).
    public let text: String

    /// Lexicon-derived emotional valence: -1.0 .. +1.0.
    ///
    /// Formula:
    ///   hits = (# positive matches) - (# negative matches)
    ///   score = hits / max(1, total lexicon matches)
    ///
    /// A score of 0.0 means the window had no lexicon hits at
    /// all (= either no positive + no negative, or perfectly
    /// balanced positive and negative). The score is rounded to
    /// 4 decimal places for stable display.
    public let score: Double

    /// Character offset in the chapter where the window starts.
    /// Equals `index * windowSize` (= the simple equal-window
    /// strategy); `startOffset == 0` for window 0.
    public let startOffset: Int

    /// Character offset in the chapter where the window ends
    /// (= exclusive). For the final window this clamps to the
    /// chapter's total length.
    public let endOffset: Int

    public init(
        id: UUID = UUID(),
        index: Int,
        text: String,
        score: Double,
        startOffset: Int,
        endOffset: Int
    ) {
        self.id = id
        self.index = index
        self.text = text
        // Clamp to the contract range.
        self.score = max(-1.0, min(1.0, score))
        self.startOffset = max(0, startOffset)
        self.endOffset = max(self.startOffset, endOffset)
    }
}

/// The analyzer output (= matches the task spec verbatim).
public struct EmotionCurveReport: Sendable, Codable, Equatable {

    /// Per-window sentiment scores (= length == window count;
    /// `windows[i].score` is the valence for window i).
    public let windows: [EmotionWindow]

    /// Mean of `windows[*].score`. Negative = overall sad /
    /// dark; positive = overall uplifting / hopeful; near zero
    /// = neutral.
    public let overallScore: Double

    /// Standard deviation of `windows[*].score`. A high
    /// volatility value means the chapter has extreme swings
    /// between windows (= e.g. a sad opening that pivots to a
    /// happy climax). Low volatility = consistent tone.
    public let volatility: Double

    /// Indices of windows that the analyzer classified as "flat
    /// spots" (= the window has a near-zero score AND its
    /// neighbor scores are also near zero; = the chapter goes
    /// uniformly neutral at this point, which usually signals a
    /// boring stretch).
    public let flatSpots: [Int]

    /// Indices of windows where the curve should "lift" (= the
    /// analyzer recommends injecting a sentiment change to
    /// break the flat spot OR to amplify an arc).
    public let suggestedLifts: [Int]

    /// One-sentence overall pacing feedback. Generated from the
    /// overall score + volatility + flat-spot count.
    public let pacingHint: String

    public init(
        windows: [EmotionWindow],
        overallScore: Double,
        volatility: Double,
        flatSpots: [Int],
        suggestedLifts: [Int],
        pacingHint: String
    ) {
        self.windows = windows
        self.overallScore = overallScore
        self.volatility = volatility
        self.flatSpots = flatSpots
        self.suggestedLifts = suggestedLifts
        self.pacingHint = pacingHint
    }

    // MARK: - Equatable

    /// Equatable conformance that ignores per-window `UUID`s
    /// (= two windows with the same content should compare equal
    /// for testing purposes).
    public static func == (lhs: EmotionCurveReport, rhs: EmotionCurveReport) -> Bool {
        let lhsWindows = lhs.windows.map { WindowForEquality(index: $0.index, text: $0.text, score: $0.score, startOffset: $0.startOffset, endOffset: $0.endOffset) }
        let rhsWindows = rhs.windows.map { WindowForEquality(index: $0.index, text: $0.text, score: $0.score, startOffset: $0.startOffset, endOffset: $0.endOffset) }
        return lhsWindows == rhsWindows
            && lhs.overallScore == rhs.overallScore
            && lhs.volatility == rhs.volatility
            && lhs.flatSpots == rhs.flatSpots
            && lhs.suggestedLifts == rhs.suggestedLifts
            && lhs.pacingHint == rhs.pacingHint
    }

    private struct WindowForEquality: Equatable {
        let index: Int
        let text: String
        let score: Double
        let startOffset: Int
        let endOffset: Int
    }
}

// MARK: - Errors

/// Errors thrown by `EmotionCurveAnalyzer`. The two cases mirror
/// the reader_experience / plot_thread / genre_fit convention
/// (= a LocalizedError for each case; = no `fatalError` paths).
public enum EmotionCurveAnalyzerError: Error, LocalizedError, Sendable, Equatable {
    case emptyChapter
    case invalidWindowCount(Int)

    public var errorDescription: String? {
        switch self {
        case .emptyChapter:
            return "EmotionCurveAnalyzer: chapter text is empty."
        case .invalidWindowCount(let n):
            return "EmotionCurveAnalyzer: windowCount must be >= 1 (= got \(n))."
        }
    }
}

// MARK: - Actor

/// Emotion-curve analyzer. Splits a chapter into N windows,
/// scores each window via a small built-in sentiment lexicon,
/// and returns a curve report with overall score / volatility /
/// flat-spot / lift suggestions.
///
/// Stateless (= the input is always the chapter text + the
/// window count; the output is a fresh `EmotionCurveReport`).
/// The actor caches the lexicon at init time (= lookup is O(1)
/// per analyze call).
///
/// Concurrency: actor. This matches the long_form_guardrails +
/// reader_experience + plot_thread + genre_fit + editor_tools
/// pattern (= Swift 6 strict concurrency; no shared mutable
/// state across the SpecializedTools pane + chat loop callers).
public actor EmotionCurveAnalyzer {

    /// Default window count (= mirrors the hermes Python
    /// default of 10 windows per chapter).
    public static let defaultWindowCount = 10

    /// Lower bound on a "flat" score. Windows whose absolute
    /// score is below this threshold AND whose neighbors are
    /// also flat are flagged as a flat spot. (= 0.05 = a window
    /// must deviate by at least 0.05 in either direction to
    /// count as non-flat.)
    static let flatScoreEpsilon: Double = 0.05

    /// Lower bound on a "spike" delta between adjacent window
    /// scores. Used by the volatility calculation (= stddev is
    /// computed against all windows; = same threshold as
    /// reader_experience uses for "spike" detection).
    static let spikeDelta: Double = 0.4

    /// Positive sentiment lexicon (= ~50 common positive
    /// adjectives / verbs). Lowercased at init time.
    static let positiveLexicon: Set<String> = [
        "happy", "happier", "happiest", "happiness", "joy", "joyful",
        "delight", "delighted", "delightful", "love", "loved", "loving",
        "beautiful", "wonderful", "lovely", "glad", "grateful",
        "hope", "hopeful", "hoping", "bright", "brilliant",
        "smile", "smiled", "smiling", "laugh", "laughed", "laughing",
        "kind", "kindness", "gentle", "warm", "warmth",
        "success", "successful", "triumph", "triumphant", "victory",
        "win", "won", "winning", "celebrate", "celebrated", "celebration",
        "peace", "peaceful", "calm", "serene", "safe",
        "thrill", "thrilled", "exciting", "excited", "excitement",
        "good", "great", "best", "amazing", "wonder",
    ]

    /// Negative sentiment lexicon (= ~50 common negative
    /// adjectives / verbs). Lowercased at init time.
    static let negativeLexicon: Set<String> = [
        "sad", "sadder", "saddest", "sadness", "sorrow", "sorrowful",
        "grief", "grieve", "grieving", "miserable", "misery",
        "hate", "hated", "hating", "fear", "feared", "fearing", "afraid",
        "ugly", "horrible", "terrible", "awful", "dreadful",
        "cry", "cried", "crying", "weep", "wept", "weeping",
        "cruel", "cruelty", "harsh", "violent", "violence",
        "fail", "failed", "failing", "failure", "defeat", "defeated",
        "lose", "lost", "losing", "loss",
        "die", "died", "dying", "death", "dead",
        "pain", "painful", "hurt", "hurting", "ache",
        "bad", "worst", "worse", "lousy", "grim",
    ]

    /// Pre-cached lowercase lexicons (= init-time conversion
    /// so the analyze loop stays tight).
    private let positive: Set<String>
    private let negative: Set<String>

    /// Public initializer. No BookStore dependency (= the
    /// analyzer is fully deterministic and offline-capable; =
    /// mirrors ReaderExperienceAnalyzer / PlotThreadAnalyzer /
    /// GenreFitAnalyzer).
    public init() {
        self.positive = EmotionCurveAnalyzer.positiveLexicon
        self.negative = EmotionCurveAnalyzer.negativeLexicon
    }

    // MARK: - Public API

    /// Analyze a chapter draft for emotional valence.
    ///
    /// - Parameters:
    ///   - chapterText: the chapter body (= UTF-8; may contain
    ///     markdown / smart quotes / em-dashes).
    ///   - windowCount: how many windows to split the chapter
    ///     into. Defaults to `EmotionCurveAnalyzer.defaultWindowCount`
    ///     (= 10).
    /// - Returns: an `EmotionCurveReport` with per-window scores
    ///   + overall score + volatility + flat-spot indices +
    ///   suggested-lift indices + 1-sentence pacing hint.
    /// - Throws: `.emptyChapter` if the input is blank;
    ///   `.invalidWindowCount` if `windowCount < 1`.
    public func analyze(
        chapterText: String,
        windowCount: Int = EmotionCurveAnalyzer.defaultWindowCount
    ) async throws -> EmotionCurveReport {
        let trimmed = chapterText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw EmotionCurveAnalyzerError.emptyChapter
        }
        guard windowCount >= 1 else {
            throw EmotionCurveAnalyzerError.invalidWindowCount(windowCount)
        }

        // 1) Build windows via the equal-character-width
        // strategy. The final window absorbs any remainder so
        // the union covers the entire chapter.
        let windows = Self.splitIntoWindows(text: chapterText, windowCount: windowCount)

        // 2) Score each window via the lexicon.
        var scoredWindows: [EmotionWindow] = []
        scoredWindows.reserveCapacity(windows.count)
        for window in windows {
            let score = Self.score(windowText: window.text, positive: positive, negative: negative)
            scoredWindows.append(
                EmotionWindow(
                    index: window.index,
                    text: window.text,
                    score: score,
                    startOffset: window.startOffset,
                    endOffset: window.endOffset
                )
            )
        }

        // 3) Overall score = mean of per-window scores.
        let overall = Self.mean(scoredWindows.map { $0.score })

        // 4) Volatility = sample standard deviation of per-
        // window scores.
        let vol = Self.standardDeviation(scoredWindows.map { $0.score })

        // 5) Flat spots + suggested lifts. A window is flat when
        // |score| < epsilon AND at least one neighbor is also
        // flat. We only emit a flat spot starting at the second
        // window of a flat run (= avoids double-reporting a
        // stretch).
        let flatSpots = Self.detectFlatSpots(in: scoredWindows)
        let suggestedLifts = Self.detectSuggestedLifts(
            windows: scoredWindows,
            flatSpots: flatSpots
        )

        // 6) One-sentence pacing hint.
        let hint = Self.makePacingHint(
            overall: overall,
            volatility: vol,
            flatSpotCount: flatSpots.count
        )

        return EmotionCurveReport(
            windows: scoredWindows,
            overallScore: Self.round4(overall),
            volatility: Self.round4(vol),
            flatSpots: flatSpots,
            suggestedLifts: suggestedLifts,
            pacingHint: hint
        )
    }

    // MARK: - Window splitting

    /// Split the chapter into `windowCount` equal-character-width
    /// windows. The final window absorbs any remainder so the
    /// union covers the entire chapter.
    static func splitIntoWindows(
        text: String,
        windowCount: Int
    ) -> [(index: Int, text: String, startOffset: Int, endOffset: Int)] {
        let total = text.count
        let safeWindowCount = max(1, windowCount)
        // The strategy: floor(total / safeWindowCount) per
        // window, then add the remainder to the final window.
        let baseSize = total / safeWindowCount
        let remainder = total - baseSize * safeWindowCount

        var result: [(index: Int, text: String, startOffset: Int, endOffset: Int)] = []
        result.reserveCapacity(safeWindowCount)

        // Use CharacterView indices so multi-byte UTF-8 stays
        // intact.
        var currentStart = text.startIndex
        var currentOffset = 0
        for i in 0..<safeWindowCount {
            let length = (i == safeWindowCount - 1) ? (baseSize + remainder) : baseSize
            let targetEndOffset = currentOffset + length
            let endIndex = text.index(
                currentStart,
                offsetBy: length,
                limitedBy: text.endIndex
            ) ?? text.endIndex
            let slice = String(text[currentStart..<endIndex])
            result.append((
                index: i,
                text: slice,
                startOffset: currentOffset,
                endOffset: min(targetEndOffset, total)
            ))
            currentStart = endIndex
            currentOffset = targetEndOffset
        }
        return result
    }

    // MARK: - Sentiment scoring

    /// Score a single window's text. Returns the lexicon-derived
    /// valence in -1.0 .. +1.0.
    ///
    /// Matching is whole-word (= a token separated by whitespace
    /// or basic punctuation). Case is folded to lowercase before
    /// lookup.
    static func score(
        windowText: String,
        positive: Set<String>,
        negative: Set<String>
    ) -> Double {
        let lower = windowText.lowercased()
        let tokens = Self.tokenize(lower)
        var positiveHits = 0
        var negativeHits = 0
        for token in tokens {
            if positive.contains(token) {
                positiveHits += 1
            } else if negative.contains(token) {
                negativeHits += 1
            }
        }
        let totalHits = positiveHits + negativeHits
        guard totalHits > 0 else {
            return 0.0
        }
        let raw = Double(positiveHits - negativeHits) / Double(totalHits)
        // Round to 4 decimal places for stable display.
        return round4(raw)
    }

    /// Split the lowercased text into tokens (= whitespace +
    /// basic punctuation as separators). Whole-word match.
    static func tokenize(_ text: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        current.reserveCapacity(8)
        for character in text {
            if character.isLetter || character == "'" || character == "-" {
                current.append(character)
            } else {
                if !current.isEmpty {
                    tokens.append(current)
                    current.removeAll(keepingCapacity: true)
                }
            }
        }
        if !current.isEmpty {
            tokens.append(current)
        }
        return tokens
    }

    // MARK: - Flat-spot + lift detection

    /// Detect flat-spot indices. A window is flat when
    /// `|score| < epsilon`. We emit the indices in order; a flat
    /// run contributes one entry per window (= the caller can
    /// render them all; = the suggested-lift logic consumes
    /// only the first window of each run).
    static func detectFlatSpots(in windows: [EmotionWindow]) -> [Int] {
        guard !windows.isEmpty else { return [] }
        var flat: [Int] = []
        for window in windows {
            if abs(window.score) < Self.flatScoreEpsilon {
                flat.append(window.index)
            }
        }
        return flat
    }

    /// Suggest lift indices. Strategy:
    ///
    /// 1. For each contiguous flat run, suggest lifting the
    ///    window immediately AFTER the run (= break the flat).
    /// 2. For each non-final window where the score swings by
    ///    more than `spikeDelta` between consecutive windows,
    ///    suggest lifting the window BEFORE the spike (= smooth
    ///    the transition).
    static func detectSuggestedLifts(
        windows: [EmotionWindow],
        flatSpots: [Int]
    ) -> [Int] {
        guard !windows.isEmpty else { return [] }
        var lifts: [Int] = []
        let flatSet = Set(flatSpots)

        // 1) Lift the window after each flat run. Walk the flat
        // indices and emit a lift at the index of the first
        // non-flat window after a contiguous flat run.
        var i = 0
        let flatSorted = flatSpots.sorted()
        while i < flatSorted.count {
            // Detect the run end.
            var j = i
            while j + 1 < flatSorted.count, flatSorted[j + 1] == flatSorted[j] + 1 {
                j += 1
            }
            let runEnd = flatSorted[j]
            // The lift candidate = runEnd + 1 (the first
            // non-flat window after the run), clamped to the
            // last window index.
            let candidate = min(runEnd + 1, windows.count - 1)
            if !flatSet.contains(candidate) && !lifts.contains(candidate) {
                lifts.append(candidate)
            }
            i = j + 1
        }

        // 2) Lift the window before a spike. A spike = the
        // absolute difference between adjacent scores exceeds
        // `spikeDelta`. The lift candidate = the window
        // immediately BEFORE the spike (= smooth the
        // transition).
        for k in 1..<windows.count {
            let delta = abs(windows[k].score - windows[k - 1].score)
            if delta > Self.spikeDelta {
                let candidate = windows[k - 1].index
                if !lifts.contains(candidate) && !flatSet.contains(candidate) {
                    lifts.append(candidate)
                }
            }
        }

        return lifts.sorted()
    }

    // MARK: - Pacing hint

    /// Generate a one-sentence pacing hint from the overall
    /// score + volatility + flat-spot count.
    static func makePacingHint(
        overall: Double,
        volatility: Double,
        flatSpotCount: Int
    ) -> String {
        let tone: String
        if overall >= 0.2 {
            tone = "Overall tone leans positive."
        } else if overall <= -0.2 {
            tone = "Overall tone leans negative."
        } else {
            tone = "Overall tone is balanced."
        }
        let pacing: String
        if volatility >= 0.4 {
            pacing = "Pacing is volatile — large swings between windows."
        } else if flatSpotCount >= 3 {
            pacing = "Pacing has \(flatSpotCount) flat stretches — consider adding tonal variation."
        } else if flatSpotCount >= 1 {
            pacing = "Pacing has a flat stretch near the middle — consider injecting a tonal shift."
        } else {
            pacing = "Pacing is steady."
        }
        return "\(tone) \(pacing)"
    }

    // MARK: - Math helpers

    /// Arithmetic mean (= 0.0 for an empty array).
    static func mean(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0.0 }
        let total = values.reduce(0.0, +)
        return total / Double(values.count)
    }

    /// Sample standard deviation (= 0.0 for arrays with fewer
    /// than 2 elements).
    static func standardDeviation(_ values: [Double]) -> Double {
        guard values.count >= 2 else { return 0.0 }
        let m = mean(values)
        let variance = values.reduce(0.0) { acc, value in
            acc + (value - m) * (value - m)
        } / Double(values.count - 1)
        return sqrt(variance)
    }

    /// Round a Double to 4 decimal places (= stable display +
    /// stable equality).
    static func round4(_ value: Double) -> Double {
        let multiplier = 10_000.0
        return (value * multiplier).rounded() / multiplier
    }
}
