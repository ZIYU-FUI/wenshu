// 
// … (= 75 rationale lines collapsed; = A112 docblock collapse per §1.8)
// 
import Foundation

// MARK: - Public surface
// … (= 7 rationale lines collapsed; = A112 docblock collapse per §1.8)
// / `ReaderExperienceKind`, `LongFormGuardrailKind`).
enum LiteraryGenre: String, Sendable, Codable, CaseIterable, Identifiable {
    /// Literary fiction (= general literary prose).
    case literary
    /// Crime / mystery / detective.
    case mystery
    /// Romance.
    case romance
    /// Science fiction.
    case sciFi
    /// Fantasy.
    case fantasy
    /// Thriller / suspense.
    case thriller
    /// Horror.
    case horror
    /// Historical fiction.
    case historical
    /// Young-adult fiction.
    case youngAdult
    /// Literary-fiction (a narrower literary subset; = separated
    /// from `.literary` to allow distinct preset).
    case literaryFiction

    var id: String { rawValue }

    /// Display label for the SwiftUI picker.
    var displayName: String {
        switch self {
        case .literary:         return "Literary"
        case .mystery:          return "Mystery"
        case .romance:          return "Romance"
        case .sciFi:            return "Sci-Fi"
        case .fantasy:          return "Fantasy"
        case .thriller:         return "Thriller"
        case .horror:           return "Horror"
        case .historical:       return "Historical"
        case .youngAdult:       return "Young Adult"
        case .literaryFiction:  return "Literary Fiction"
        }
    }

    /// One-sentence hint shown next to the picker.
    var hint: String {
        switch self {
        case .literary:
            return "Literary prose: introspective, image-rich, restrained dialogue."
        case .mystery:
            return "Mystery: crime introduced, clues planted, alibi tested, reveal."
        case .romance:
            return "Romance: meet-cute, rising attraction, conflict, commitment."
        case .sciFi:
            return "Sci-Fi: speculative tech, world-building, ethical question."
        case .fantasy:
            return "Fantasy: magic system, quest, mentor, chosen-one arc."
        case .thriller:
            return "Thriller: ticking clock, chase, reveal, narrow escape."
        case .horror:
            return "Horror: dread, uncanny detail, body horror or possession."
        case .historical:
            return "Historical: period detail, social constraints, era voice."
        case .youngAdult:
            return "Young Adult: first-person voice, identity, agency, hope."
        case .literaryFiction:
            return "Literary Fiction: ambiguity, interiority, subtext, restraint."
        }
    }

    // / SF Symbols 6 icon name (= Apple canonical; = used by
    // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / Migrated to outline glyphs.
    var icon: String {
        switch self {
        case .literary:         return "book.pages"                  // Lucide 'book-open'
        case .mystery:          return "magnifyingglass"             // Lucide 'magnifyingglass'
        case .romance:          return "heart"                       // Lucide 'heart'
        case .sciFi:            return "airplane"                    // Lucide 'rocket'
        case .fantasy:          return "wand.and.stars"              // Lucide 'wand-2'
        case .thriller:         return "bolt"                        // Lucide 'zap'
        case .horror:           return "skull"                       // Lucide 'skull'
        case .historical:       return "building.columns"            // Lucide 'landmark'
        case .youngAdult:       return "face.smiling"                // Lucide 'smile'
        case .literaryFiction:  return "leaf"                        // Lucide 'feather'
        }
    }
}

// / A single genre's convention preset. Each genre owns exactly
// … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
// / concurrent callers.
struct GenreConvention: Sendable, Codable, Equatable {
    /// The genre this preset belongs to.
    let genre: LiteraryGenre

    // / Required structural beats (= e.g. mystery: "crime
    // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / appears in the chapter text.
    let requiredBeats: [String]

    // / Expected vocabulary tokens (= e.g. mystery: "alibi",
    // … (= 3 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / found at least once).
    let expectedVocab: [String]

    // / Forbidden patterns (= e.g. romance: "deus ex machina",
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / `forbiddenHit`.
    let forbiddenPatterns: [String]

    init(
        genre: LiteraryGenre,
        requiredBeats: [String],
        expectedVocab: [String],
        forbiddenPatterns: [String]
    ) {
        self.genre = genre
        self.requiredBeats = requiredBeats
        self.expectedVocab = expectedVocab
        self.forbiddenPatterns = forbiddenPatterns
    }
}

/// The analyzer output (= matches the task spec verbatim).
struct GenreFitReport: Sendable, Codable, Equatable {
    let genre: LiteraryGenre

    // / Normalized score in 0..100. Higher = more conventions met
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / `GenreFitAnalyzer.score(...)`.
    let score: Double

    /// Required beats that the chapter exhibits (= matched at
    /// least one hint phrase).
    let matchedBeats: [String]

    /// Required beats that the chapter omits (= no hint phrase
    /// detected).
    let missingBeats: [String]

    // / Forbidden patterns that appeared in the chapter (= each
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / caller can render an evidence list).
    let forbiddenHits: [String]

    /// Expected vocabulary tokens that WERE found in the
    /// chapter (= at least one occurrence).
    let expectedVocabUsed: [String]

    /// Expected vocabulary tokens that were NOT found in the
    /// chapter (= zero occurrences).
    let expectedVocabMissing: [String]

    init(
        genre: LiteraryGenre,
        score: Double,
        matchedBeats: [String],
        missingBeats: [String],
        forbiddenHits: [String],
        expectedVocabUsed: [String],
        expectedVocabMissing: [String]
    ) {
        self.genre = genre
        self.score = max(0.0, min(100.0, score))
        self.matchedBeats = matchedBeats
        self.missingBeats = missingBeats
        self.forbiddenHits = forbiddenHits
        self.expectedVocabUsed = expectedVocabUsed
        self.expectedVocabMissing = expectedVocabMissing
    }
}

/// Lightweight summary of a single genre for the picker. The
/// view layer renders one row per `GenreSummary`.
struct GenreSummary: Sendable, Codable, Equatable, Identifiable {
    let genre: LiteraryGenre
    let displayName: String
    let requiredBeatCount: Int

    var id: String { genre.rawValue }

    init(genre: LiteraryGenre, displayName: String, requiredBeatCount: Int) {
        self.genre = genre
        self.displayName = displayName
        self.requiredBeatCount = requiredBeatCount
    }
}

// MARK: - Errors
// … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
// / case; = no `fatalError` paths).
enum GenreFitAnalyzerError: Error, LocalizedError, Sendable, Equatable {
    case emptyChapter
    case unknownGenre(String)

    var errorDescription: String? {
        switch self {
        case .emptyChapter:
            return "GenreFitAnalyzer: chapter text is empty."
        case .unknownGenre(let raw):
            return "GenreFitAnalyzer: unknown genre raw value `\(raw)`."
        }
    }
}

// MARK: - Actor
// … (= 8 rationale lines collapsed; = A112 docblock collapse per §1.8)
// / SpecializedTools pane + chat loop callers).
actor GenreFitAnalyzer {

    // / Cached convention presets (= keyed by LiteraryGenre raw
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / dictionary reads.
    private let presets: [String: GenreConvention]

    // / Public initializer. No BookStore dependency (= the
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / mirrors ReaderExperienceAnalyzer).
    init() {
        var built: [String: GenreConvention] = [:]
        for genre in LiteraryGenre.allCases {
            built[genre.rawValue] = GenreFitAnalyzer.preset(for: genre)
        }
        self.presets = built
    }

    // MARK: - Public API
    // … (= 6 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // /   never fire in practice).
    func conventions(for genre: LiteraryGenre) throws -> GenreConvention {
        guard let preset = presets[genre.rawValue] else {
            throw GenreFitAnalyzerError.unknownGenre(genre.rawValue)
        }
        return preset
    }

    // / Score a chapter draft against a genre's conventions.
    // … (= 10 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // /   practice since the enum is exhaustive).
    func analyze(
        chapterText: String,
        genre: LiteraryGenre
    ) async throws -> GenreFitReport {
        let trimmed = chapterText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw GenreFitAnalyzerError.emptyChapter
        }
        let preset = try conventions(for: genre)

        let lower = trimmed.lowercased()

        // 1) Required beats: a beat is matched when ANY of its
        // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // chapter.
        var matchedBeats: [String] = []
        var missingBeats: [String] = []
        for beat in preset.requiredBeats {
            let hints = Self.hintPhrases(for: beat)
            let isMatched = hints.contains { lower.contains($0) }
            if isMatched {
                matchedBeats.append(beat)
            } else {
                missingBeats.append(beat)
            }
        }

        // 2) Expected vocab: each token is a single word
        // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // word (= whitespace / punctuation boundary).
        var expectedVocabUsed: [String] = []
        var expectedVocabMissing: [String] = []
        for token in preset.expectedVocab {
            if Self.containsWord(token.lowercased(), in: lower) {
                expectedVocabUsed.append(token)
            } else {
                expectedVocabMissing.append(token)
            }
        }

        // 3) Forbidden patterns: count each distinct forbidden
        // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // multi-word patterns work as-is).
        var forbiddenHits: [String] = []
        for forbidden in preset.forbiddenPatterns {
            if lower.contains(forbidden.lowercased()) {
                forbiddenHits.append(forbidden)
            }
        }

        // 4) Score.
        let score = Self.computeScore(
            beatTotal: preset.requiredBeats.count,
            matchedBeats: matchedBeats.count,
            expectedVocabTotal: preset.expectedVocab.count,
            expectedVocabUsed: expectedVocabUsed.count,
            forbiddenHits: forbiddenHits.count
        )

        return GenreFitReport(
            genre: genre,
            score: score,
            matchedBeats: matchedBeats,
            missingBeats: missingBeats,
            forbiddenHits: forbiddenHits,
            expectedVocabUsed: expectedVocabUsed,
            expectedVocabMissing: expectedVocabMissing
        )
    }

    // / List all available genres with their convention
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / picker without having to introspect each preset.
    func availableGenres() async -> [GenreSummary] {
        LiteraryGenre.allCases.map { genre in
            let preset = presets[genre.rawValue]
            return GenreSummary(
                genre: genre,
                displayName: genre.displayName,
                requiredBeatCount: preset?.requiredBeats.count ?? 0
            )
        }
    }

    // MARK: - Scoring formula
    // … (= 17 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / does not fit the genre).
    static func computeScore(
        beatTotal: Int,
        matchedBeats: Int,
        expectedVocabTotal: Int,
        expectedVocabUsed: Int,
        forbiddenHits: Int
    ) -> Double {
        let beatFraction = beatTotal > 0
            ? Double(matchedBeats) / Double(beatTotal)
            : 0.0
        let vocabFraction = expectedVocabTotal > 0
            ? Double(expectedVocabUsed) / Double(expectedVocabTotal)
            : 0.0
        let base = 60.0 * beatFraction + 30.0 * vocabFraction
        let penalty = 12.0 * Double(forbiddenHits)
        return max(0.0, min(100.0, base - penalty))
    }

    // MARK: - Beat → hint phrases
    // … (= 5 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / "red herring", "false lead", "decoy").
    static func hintPhrases(for beat: String) -> [String] {
        let key = beat.lowercased()
        switch key {
        // Mystery
        case "crime introduction":
            return ["murder", "the body", "the victim", "crime scene", "found dead",
                    "discovered the body", "a body", "crime was", "killed"]
        case "investigation":
            return ["investigate", "investigation", "detective", "inspector",
                    "examined the", "looked for clues", "searched the", "interrogated"]
        case "clue":
            return ["clue", "evidence", "found a", "noticed a", "the footprints",
                    "a fingerprint", "a trace", "a hair", "a button"]
        case "suspect":
            return ["suspect", "the butler", "witness", "person of interest",
                    "had motive", "had means", "had opportunity"]
        case "red herring":
            return ["red herring", "false lead", "decoy", "wrongly suspected",
                    "seemed guilty", "looked like the culprit"]
        case "alibi":
            return ["alibi", "was elsewhere", "couldn't have", "proved innocent",
                    "denied it"]
        case "revelation":
            return ["revelation", "the truth", "it was", "realized", "twist",
                    "the killer was", "actually", "in fact it was"]
        case "resolution":
            return ["arrested", "confessed", "case closed", "brought to justice",
                    "the killer is", "culprit is", "justice"]

        // Romance
        case "meet cute":
            return ["meet-cute", "meet cute", "first time we met", "first saw her",
                    "first saw him", "our eyes met", "locked eyes", "bumped into"]
        case "rising attraction":
            return ["attracted to", "felt a spark", "couldn't stop thinking",
                    "drawn to", "chemistry", "flirted"]
        case "conflict":
            return ["argument", "misunderstanding", "broke up", "push apart",
                    "couldn't forgive", "wall between"]
        case "commitment":
            return ["i love you", "marry me", "be mine", "together forever",
                    "committed", "forever"]

        // Sci-fi
        case "speculative tech":
            return ["warp drive", "hyperdrive", "faster than light", "ftl",
                    "quantum computer", "ai", "nanotech", "robot", "android",
                    "spaceship", "starship", "cryogenic"]
        case "world-building":
            return ["galaxy", "planet", "colony", "space station", "empire",
                    "federation", "the year 2", "the year 3", "terraform"]
        case "ethical question":
            return ["is it ethical", "moral dilemma", "what does it mean to be human",
                    "rights of", "trolley problem", "utilitarian", "should we",
                    "playing god"]

        // Fantasy
        case "magic system":
            return ["spell", "magic", "wizard", "sorcerer", "mage", "enchanted",
                    "conjure", "incantation", "rune", "potion", "mana"]
        case "quest":
            return ["quest", "journey", "mission", "task", "must find",
                    "must retrieve", "set out to"]
        case "mentor":
            return ["mentor", "old wizard", "wise", "taught me", "master",
                    "the elder", "the sage"]
        case "chosen one":
            return ["chosen one", "prophecy", "destiny", "the one", "foretold",
                    "marked by", "the chosen"]

        // Thriller
        case "ticking clock":
            return ["deadline", "countdown", "in 24 hours", "by midnight",
                    "ticking", "before it's too late", "race against"]
        case "chase":
            return ["chase", "pursuit", "ran through", "footsteps behind",
                    "fled", "hot pursuit", "tailed by"]
        case "narrow escape":
            return ["narrowly escaped", "just in time", "barely made it",
                    "escaped by", "got away", "cut it close"]

        // Horror
        case "dread":
            return ["dread", "unease", "creeping", "something was wrong",
                    "an ominous", "a chill", "goosebumps", "the hair stood"]
        case "uncanny detail":
            return ["the lights flickered", "the door was open", "a whisper",
                    "a sound", "a creak", "scratching", "something moved",
                    "the wrong", "the smile"]
        case "body horror":
            return ["body horror", "the flesh", "skin peeled", "bone cracked",
                    "transformed into", "mutated", "the wound"]
        case "possession":
            return ["possessed", "taken over", "voice inside", "not in control",
                    "eyes turned black", "the demon"]

        // Historical
        case "period detail":
            return ["in the year", "the regiment", "the empire", "the dynasty",
                    "the colon", "the war of", "the era", "the 18", "the 19",
                    "the 17", "ancient", "medieval", "victorian"]
        case "social constraints":
            return ["a woman could not", "a man must", "propriety", "custom",
                    "scandal", "ruined", "out of wedlock", "marriage arranged"]
        case "era voice":
            return ["thee", "thou", "hath", "hitherto", "verily", "permit me",
                    "good sir", "good madam", "kind sir"]

        // Young adult
        case "first-person voice":
            return ["i felt", "i thought", "i wondered", "i realized",
                    "i couldn't", "i had to", "my heart", "my mind"]
        case "identity":
            return ["who am i", "what am i", "my identity", "find myself",
                    "discover who", "fitting in", "belonged"]
        case "agency":
            return ["my choice", "my decision", "i chose", "i decided",
                    "i refused", "i wouldn't", "i stood up"]
        case "hope":
            return ["hope", "believe", "tomorrow", "better days", "a future",
                    "things will get", "we can"]

        // Literary / literary fiction (defaults)
        case "interiority":
            return ["she thought", "he thought", "she felt", "he felt",
                    "his mind", "her mind", "wondered", "brooded"]
        case "image-rich":
            return ["the light", "the color", "the smell", "the sound",
                    "shadows", "rain", "snow", "wind", "the trees",
                    "the river", "the sky"]
        case "restraint":
            return ["said little", "few words", "silent", "quiet", "still",
                    "withheld", "understated"]
        case "ambiguity":
            return ["perhaps", "maybe", "unclear", "uncertain", "ambiguous",
                    "it might have been", "or perhaps"]
        case "subtext":
            return ["underneath", "beneath", "implied", "unsaid", "between the lines",
                    "the tension", "what was not said"]

        default:
            // Fallback: treat the beat label itself as the
            // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // keeps new beats workable without an enum update.
            return [key]
        }
    }

    // MARK: - Word matcher
    // … (= 4 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / matches "the warp drive was" but NOT "the warp-driver").
    static func containsWord(_ word: String, in haystack: String) -> Bool {
        guard !word.isEmpty else { return false }
        var searchRange = haystack.startIndex..<haystack.endIndex
        while let found = haystack.range(of: word, range: searchRange) {
            let beforeOK: Bool
            if found.lowerBound == haystack.startIndex {
                beforeOK = true
            } else {
                let prev = haystack.index(before: found.lowerBound)
                beforeOK = !haystack[prev].isLetter && !haystack[prev].isNumber
            }
            let afterOK: Bool
            if found.upperBound == haystack.endIndex {
                afterOK = true
            } else {
                let after = found.upperBound
                afterOK = !haystack[after].isLetter && !haystack[after].isNumber
            }
            if beforeOK && afterOK {
                return true
            }
            searchRange = found.upperBound..<haystack.endIndex
        }
        return false
    }

    // MARK: - Presets
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / (= 1:1 port of the Python module's GENRE_PRESETS dict.)
    private static func preset(for genre: LiteraryGenre) -> GenreConvention {
        switch genre {
        case .literary:
            return GenreConvention(
                genre: .literary,
                requiredBeats: ["interiority", "image-rich", "restraint"],
                expectedVocab: ["memory", "silence", "light", "shadow",
                                "winter", "loss", "absence", "voice"],
                forbiddenPatterns: ["suddenly", "meanwhile", "in conclusion"]
            )

        case .mystery:
            return GenreConvention(
                genre: .mystery,
                requiredBeats: ["crime introduction", "investigation", "clue",
                                "suspect", "red herring", "alibi",
                                "revelation", "resolution"],
                expectedVocab: ["alibi", "suspect", "clue", "motive",
                                "evidence", "detective", "witness"],
                forbiddenPatterns: ["deus ex machina", "psychic vision",
                                    "convenient coincidence"]
            )

        case .romance:
            return GenreConvention(
                genre: .romance,
                requiredBeats: ["meet cute", "rising attraction", "conflict",
                                "commitment"],
                expectedVocab: ["kiss", "love", "heart", "together",
                                "forever", "beloved"],
                forbiddenPatterns: ["deus ex machina", "sudden love",
                                    "insta-love", "love at first sight"]
            )

        case .sciFi:
            return GenreConvention(
                genre: .sciFi,
                requiredBeats: ["speculative tech", "world-building",
                                "ethical question"],
                expectedVocab: ["warp drive", "spaceship", "starship",
                                "planet", "android", "quantum",
                                "galaxy", "terraform", "colony"],
                forbiddenPatterns: ["magic wand", "fairy dust", "prophecy"]
            )

        case .fantasy:
            return GenreConvention(
                genre: .fantasy,
                requiredBeats: ["magic system", "quest", "mentor",
                                "chosen one"],
                expectedVocab: ["spell", "wizard", "quest", "dragon",
                                "sword", "kingdom", "prophecy"],
                forbiddenPatterns: ["wifi", "smartphone", "computer",
                                    "subway", "satellite"]
            )

        case .thriller:
            return GenreConvention(
                genre: .thriller,
                requiredBeats: ["ticking clock", "chase", "narrow escape"],
                expectedVocab: ["deadline", "chase", "agent", "weapon",
                                "target", "enemy", "asset"],
                forbiddenPatterns: ["happily ever after", "and then they",
                                    "all was well"]
            )

        case .horror:
            return GenreConvention(
                genre: .horror,
                requiredBeats: ["dread", "uncanny detail", "body horror",
                                "possession"],
                expectedVocab: ["dread", "shadow", "whisper", "scream",
                                "blood", "creature", "ritual"],
                forbiddenPatterns: ["happily ever after", "it was all a dream",
                                    "just a prank"]
            )

        case .historical:
            return GenreConvention(
                genre: .historical,
                requiredBeats: ["period detail", "social constraints",
                                "era voice"],
                expectedVocab: ["empire", "dynasty", "regiment", "colony",
                                "war", "queen", "king", "revolution"],
                forbiddenPatterns: ["google", "iphone", "tweet", "selfie",
                                    "smartphone", "wifi"]
            )

        case .youngAdult:
            return GenreConvention(
                genre: .youngAdult,
                requiredBeats: ["first-person voice", "identity", "agency",
                                "hope"],
                expectedVocab: ["school", "friend", "family", "fear",
                                "secret", "first", "choice"],
                forbiddenPatterns: ["happily ever after", "it was all a dream",
                                    "deus ex machina"]
            )

        case .literaryFiction:
            return GenreConvention(
                genre: .literaryFiction,
                requiredBeats: ["interiority", "image-rich", "ambiguity",
                                "subtext"],
                expectedVocab: ["memory", "silence", "absence", "voice",
                                "shadow", "winter", "loss"],
                forbiddenPatterns: ["the end", "happily ever after",
                                    "and they all lived"]
            )
        }
    }
}
