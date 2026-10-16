// 
// … (= 46 rationale lines collapsed; = A112 docblock collapse per §1.8)
// 
import Foundation

// MARK: - Public surface
// … (= 5 rationale lines collapsed; = A112 docblock collapse per §1.8)
// / lexicon hits at all (= neutral).
struct EmotionWindow: Sendable, Codable, Equatable, Identifiable {

    // / Stable identifier. Each window owns a UUID so SwiftUI's
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / without needing a separate `id` key path.
    let id: UUID

    /// Zero-based window index (= 0..N-1 for the chapter).
    let index: Int

    // / The window's text slice. The slice is taken verbatim from
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / smart quotes / em-dashes if present).
    let text: String

    // / Lexicon-derived emotional valence: -1.0 .. +1.0.
    // … (= 8 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / 4 decimal places for stable display.
    let score: Double

    // / Character offset in the chapter where the window starts.
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / strategy); `startOffset == 0` for window 0.
    let startOffset: Int

    // / Character offset in the chapter where the window ends
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / chapter's total length.
    let endOffset: Int

    init(
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
struct EmotionCurveReport: Sendable, Codable, Equatable {

    /// Per-window sentiment scores (= length == window count;
    /// `windows[i].score` is the valence for window i).
    let windows: [EmotionWindow]

    // / Mean of `windows[*].score`. Negative = overall sad /
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / = neutral.
    let overallScore: Double

    // / Standard deviation of `windows[*].score`. A high
    // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / happy climax). Low volatility = consistent tone.
    let volatility: Double

    // / Indices of windows that the analyzer classified as "flat
    // … (= 3 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / boring stretch).
    let flatSpots: [Int]

    // / Indices of windows where the curve should "lift" (= the
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / break the flat spot OR to amplify an arc).
    let suggestedLifts: [Int]

    /// One-sentence overall pacing feedback. Generated from the
    /// overall score + volatility + flat-spot count.
    let pacingHint: String

    init(
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
    // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / for testing purposes).
    static func == (lhs: EmotionCurveReport, rhs: EmotionCurveReport) -> Bool {
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
// … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
// / (= a LocalizedError for each case; = no `fatalError` paths).
enum EmotionCurveAnalyzerError: Error, LocalizedError, Sendable, Equatable {
    case emptyChapter
    case invalidWindowCount(Int)

    var errorDescription: String? {
        switch self {
        case .emptyChapter:
            return "EmotionCurveAnalyzer: chapter text is empty."
        case .invalidWindowCount(let n):
            return "EmotionCurveAnalyzer: windowCount must be >= 1 (= got \(n))."
        }
    }
}

// MARK: - Actor
// … (= 13 rationale lines collapsed; = A112 docblock collapse per §1.8)
// / state across the SpecializedTools pane + chat loop callers).
actor EmotionCurveAnalyzer {

    /// Default window count (= mirrors the hermes Python
    /// default of 10 windows per chapter).
    static let defaultWindowCount = 10

    // / Lower bound on a "flat" score. Windows whose absolute
    // … (= 3 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / count as non-flat.)
    static let flatScoreEpsilon: Double = 0.05

    // / Lower bound on a "spike" delta between adjacent window
    // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / reader_experience uses for "spike" detection).
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

    // / Public initializer. No BookStore dependency (= the
    // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / GenreFitAnalyzer).
    init() {
        self.positive = EmotionCurveAnalyzer.positiveLexicon
        self.negative = EmotionCurveAnalyzer.negativeLexicon
    }

    // MARK: - Public API
    // … (= 12 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // /   `.invalidWindowCount` if `windowCount < 1`.
    func analyze(
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
        // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
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
        // … (= 3 rationale lines collapsed; = A112 docblock collapse per §1.8)
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
    // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / union covers the entire chapter.
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
    // … (= 5 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / lookup.
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
    // … (= 4 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / only the first window of each run).
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

    // / Suggest lift indices. Strategy:
    // … (= 6 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // /    the transition).
    static func detectSuggestedLifts(
        windows: [EmotionWindow],
        flatSpots: [Int]
    ) -> [Int] {
        guard !windows.isEmpty else { return [] }
        var lifts: [Int] = []
        let flatSet = Set(flatSpots)

        // 1) Lift the window after each flat run. Walk the flat
        // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
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
            // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // last window index.
            let candidate = min(runEnd + 1, windows.count - 1)
            if !flatSet.contains(candidate) && !lifts.contains(candidate) {
                lifts.append(candidate)
            }
            i = j + 1
        }

        // 2) Lift the window before a spike. A spike = the
        // … (= 3 rationale lines collapsed; = A112 docblock collapse per §1.8)
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
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / score + volatility + flat-spot count.
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
