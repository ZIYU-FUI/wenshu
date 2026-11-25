//
//  StoryForeshadow.swift
//
//  The chains a book hangs across its chapters (= a thread planted in one
//  chapter and paid off in another), read out of the chapters' own
//  marker lines, and the ways such a chain breaks.
//
//  Why: a book already writes its own threads down. The chapter
//  template carries a thread section, and each chapter's body names
//  what it plants and what it pays off, so the book's own files hold
//  the whole chain. Nothing reads it, so a thread that is never paid
//  off, a payoff that arrives before its plant, and a payoff pointing
//  at a chapter that never planted anything are all invisible to the
//  writer who has to fix them.
//
//  So the reading is deterministic (= the marker lines are the book's
//  own vocabulary) and the check is a graph walk over what the
//  chapters say. Neither needs a language model, and neither needs a
//  view: the result is a list of breaks, which any caller can print.
//
//  The marker vocabulary is the book's, not this file's, so it is
//  written as code points (= the file stays English-only, and the
//  marker can still change without a code edit).
//

import Foundation

/// One chapter's thread markers, as its body carries them.
public struct ForeshadowChapter: Sendable, Equatable {
    /// The chapter's number in the book (= 1-based, = the number the
    /// book's own text writes when it says which chapter it comes from).
    public let number: Int
    /// The chapter's body (= the markdown the writer's text lives in).
    public let body: String

    public init(number: Int, body: String) {
        self.number = number
        self.body = body
    }
}

/// A thread this chapter plants.
public struct ForeshadowPlant: Sendable, Equatable {
    /// The chapter that plants the thread.
    public let chapterNumber: Int
    /// What the chapter plants (= the writer's own words).
    public let text: String

    public init(chapterNumber: Int, text: String) {
        self.chapterNumber = chapterNumber
        self.text = text
    }
}

/// A thread this chapter pays off.
public struct ForeshadowPayoff: Sendable, Equatable {
    /// The chapter that pays the thread off.
    public let chapterNumber: Int
    /// The chapter the payoff names as the thread's origin (= nil when
    /// the payoff names no chapter the file can read).
    public let sourceChapter: Int?
    /// What the chapter pays off (= the writer's own words).
    public let text: String

    public init(chapterNumber: Int, sourceChapter: Int?, text: String) {
        self.chapterNumber = chapterNumber
        self.sourceChapter = sourceChapter
        self.text = text
    }
}

/// One payoff line, and the chapter it names as the thread's origin.
public struct ForeshadowPayoffMarker: Sendable, Equatable {
    /// What the chapter pays off (= the writer's own words).
    public let text: String
    /// The chapter the payoff names as the thread's origin (= nil when
    /// it names none the file can read).
    public let sourceChapter: Int?

    public init(text: String, sourceChapter: Int?) {
        self.text = text
        self.sourceChapter = sourceChapter
    }
}

/// The thread markers one chapter's body carries.
public struct ForeshadowMarkers: Sendable, Equatable {
    /// The threads the chapter plants (= the writer's own words).
    public let plants: [String]
    /// The threads the chapter pays off.
    public let payoffs: [ForeshadowPayoffMarker]

    public init(plants: [String], payoffs: [ForeshadowPayoffMarker]) {
        self.plants = plants
        self.payoffs = payoffs
    }
}

/// How a book's thread chains break.
public enum ForeshadowBreak: Sendable, Equatable, Hashable {
    /// A payoff arrives before the chapter that plants its thread.
    case payoffBeforePlant(payoffChapter: Int, plantChapter: Int)
    /// A payoff names a chapter that plants no thread.
    case payoffNamesChapterThatPlantsNothing(payoffChapter: Int, namedChapter: Int)
    /// A payoff names a chapter the book does not have.
    case payoffNamesChapterThatDoesNotExist(payoffChapter: Int, namedChapter: Int)
    /// No payoff in the book names this chapter as a thread's origin.
    case plantNeverPaidOff(plantChapter: Int)

    /// The chapter the break is reported against (= the chapter that
    /// causes it, so the earliest chapter's breaks read first).
    public var chapter: Int {
        switch self {
        case let .payoffBeforePlant(payoffChapter, _): return payoffChapter
        case let .payoffNamesChapterThatPlantsNothing(payoffChapter, _): return payoffChapter
        case let .payoffNamesChapterThatDoesNotExist(payoffChapter, _): return payoffChapter
        case let .plantNeverPaidOff(plantChapter): return plantChapter
        }
    }

    /// The order the breaks of one chapter read in.
    public var rank: Int {
        switch self {
        case .payoffBeforePlant: return 0
        case .payoffNamesChapterThatDoesNotExist: return 1
        case .payoffNamesChapterThatPlantsNothing: return 2
        case .plantNeverPaidOff: return 3
        }
    }

    /// The second number a break reads by (= two breaks of one chapter
    /// and one kind are ordered by the chapter they name).
    public var second: Int {
        switch self {
        case let .payoffBeforePlant(_, plantChapter): return plantChapter
        case let .payoffNamesChapterThatPlantsNothing(_, namedChapter): return namedChapter
        case let .payoffNamesChapterThatDoesNotExist(_, namedChapter): return namedChapter
        case let .plantNeverPaidOff(plantChapter): return plantChapter
        }
    }
}

/// The chains of a book, and the ways they break.
public enum ForeshadowChain {
    /// The threads a book's chapters plant and pay off, and the breaks
    /// among them.
    ///
    /// The order is the book's own order: a break is reported against
    /// the chapter that causes it, so the earliest chapter's breaks
    /// read first.
    ///
    /// A plant is judged at chapter grain (= a payoff names the chapter
    /// its thread was planted in, not the thread), so a chapter that
    /// plants two threads and has one of them paid off is no break. A
    /// caller that wants thread grain needs the writer to name the
    /// thread in the payoff, which the book's marker lines do not yet
    /// carry.
    ///
    /// A payoff whose origin the file cannot read could pay off any
    /// thread, so while one exists no thread counts as unpaid (= the
    /// report never cries wolf).
    public static func scan(chapters: [ForeshadowChapter]) -> [ForeshadowBreak] {
        let plants = chapters.flatMap { chapter -> [ForeshadowPlant] in
            markers(in: chapter.body).plants.map {
                ForeshadowPlant(chapterNumber: chapter.number, text: $0)
            }
        }
        let payoffs = chapters.flatMap { chapter -> [ForeshadowPayoff] in
            markers(in: chapter.body).payoffs.map {
                ForeshadowPayoff(
                    chapterNumber: chapter.number,
                    sourceChapter: $0.sourceChapter,
                    text: $0.text
                )
            }
        }

        let plantedIn = Set(plants.map(\.chapterNumber))
        let chaptersInBook = Set(chapters.map(\.number))
        let paidChapters = Set(payoffs.compactMap(\.sourceChapter))
        let hasUnreadablePayoff = payoffs.contains { $0.sourceChapter == nil }

        var breaks: [ForeshadowBreak] = []
        // A break names the chapter it is reported against and the
        // chapter it names, so two payoff lines that name the same
        // absent chapter are ONE break (= the writer has one thing to
        // fix, = = and the report says it once).
        var reported = Set<ForeshadowBreak>()
        for payoff in payoffs {
            guard let source = payoff.sourceChapter else { continue }
            let oneBreak: ForeshadowBreak
            if !chaptersInBook.contains(source) {
                // The chapter the payoff names is not in the book, so
                // this is one break (= it names no chapter at all, = and
                // that is what the writer has to fix).
                oneBreak = .payoffNamesChapterThatDoesNotExist(
                    payoffChapter: payoff.chapterNumber,
                    namedChapter: source
                )
            } else if !plantedIn.contains(source) {
                oneBreak = .payoffNamesChapterThatPlantsNothing(
                    payoffChapter: payoff.chapterNumber,
                    namedChapter: source
                )
            } else if source > payoff.chapterNumber {
                oneBreak = .payoffBeforePlant(
                    payoffChapter: payoff.chapterNumber,
                    plantChapter: source
                )
            } else {
                continue
            }
            guard reported.insert(oneBreak).inserted else { continue }
            breaks.append(oneBreak)
        }
        if !hasUnreadablePayoff {
            for chapter in plantedIn.sorted() where !paidChapters.contains(chapter) {
                breaks.append(.plantNeverPaidOff(plantChapter: chapter))
            }
        }
        return breaks.sorted { lhs, rhs in
            if lhs.chapter != rhs.chapter {
                return lhs.chapter < rhs.chapter
            }
            if lhs.rank != rhs.rank {
                return lhs.rank < rhs.rank
            }
            return lhs.second < rhs.second
        }
    }

    /// The thread markers a body carries (= the thread section's plant
    /// and payoff lines, and nothing else).
    ///
    /// A marker line whose text is the template's own placeholder (= the
    /// angle brackets the chapter template ships) is not a marker: the
    /// writer has not filled it in, so the book has not planted
    /// anything there yet.
    public static func markers(in body: String) -> ForeshadowMarkers {
        var plants: [String] = []
        var payoffs: [ForeshadowPayoffMarker] = []
        var inThreadSection = false
        for rawLine in body.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("#") {
                // A heading opens or closes the thread section, and the
                // heading's own text names the section.
                inThreadSection = headingText(of: line).contains(ForeshadowVocabulary.threadSection)
                continue
            }
            guard inThreadSection else { continue }
            guard let (text, label) = markerText(line) else { continue }
            if label == ForeshadowVocabulary.plantLabel {
                plants.append(text)
            } else {
                payoffs.append(ForeshadowPayoffMarker(
                    text: text,
                    sourceChapter: ForeshadowVocabulary.ordinal(in: text)
                ))
            }
        }
        return ForeshadowMarkers(plants: plants, payoffs: payoffs)
    }

    /// The text of a heading (= the marks stripped).
    private static func headingText(of line: String) -> String {
        var text = line
        while let first = text.first, first == "#" {
            text.removeFirst()
        }
        return text.trimmingCharacters(in: .whitespaces)
    }

    /// The text a marker line carries, and the label it carries it
    /// under (= nil when the line is not one).
    ///
    /// The label is read from the line's own head (= before its colon),
    /// and the head must BE the label once the markdown around it is
    /// stripped: a line whose head merely mentions the label (= a note
    /// that says "this chapter plants nothing") is not a marker, and
    /// reading it as one reports a thread the book does not have.
    private static func markerText(_ line: String) -> (text: String, label: String)? {
        guard let colon = line.firstIndex(where: { character in
            character == ":" || character == ForeshadowVocabulary.fullWidthColon
        }) else { return nil }
        let head = String(line[line.startIndex ..< colon])
        let label = markerLabel(inHead: head)
        guard let label else { return nil }
        let text = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty, !isPlaceholder(text) else { return nil }
        return (text, label)
    }

    /// The label a marker's head names (= nil when the head names
    /// none).
    ///
    /// The head is the markdown around the label, so the marks are
    /// stripped and what is left must BE the label: the book's own
    /// lines carry a bullet, a bold pair, or nothing at all.
    private static func markerLabel(inHead head: String) -> String? {
        var bare = ""
        for character in head {
            if character == "-" || character == "*" {
                continue
            }
            if character.isWhitespace {
                continue
            }
            bare.append(character)
        }
        if bare == ForeshadowVocabulary.plantLabel {
            return ForeshadowVocabulary.plantLabel
        }
        if bare == ForeshadowVocabulary.payoffLabel {
            return ForeshadowVocabulary.payoffLabel
        }
        return nil
    }

    /// Whether a marker's text is the template's own placeholder.
    private static func isPlaceholder(_ text: String) -> Bool {
        text.hasPrefix("<") && text.hasSuffix(">")
    }
}

/// The vocabulary the book's own files carry (= the words a chapter
/// uses to name its threads).
public enum ForeshadowVocabulary {
    /// The heading that opens a chapter's thread section.
    public static let threadSection = "\u{4F0F}\u{7B14}"
    /// The label a chapter's plant line carries.
    public static let plantLabel = "\u{57CB}\u{8BBE}"
    /// The label a chapter's payoff line carries.
    public static let payoffLabel = "\u{5151}\u{73B0}"
    /// The word a chapter number is written with.
    public static let chapterWord = "\u{7B2C}"
    /// The word a chapter is written with.
    public static let numberWord = "\u{7AE0}"
    /// The punctuation a book's own marker line separates its label
    /// from its text with (= the colon a Chinese writer types).
    ///
    /// The template ships the half-width colon, but a chapter a writer
    /// typed by hand carries the full-width one (= the punctuation the
    /// same template uses two lines away), so a kernel that reads only
    /// the half-width one reads nothing from exactly the chapters a
    /// human wrote.
    public static let fullWidthColon: Character = "\u{FF1A}"

    /// The chapter number a text names (= nil when it names none).
    ///
    /// The book's own way of writing it is accepted: an arabic number
    /// between the chapter word and the chapter's own word, or a
    /// number written in the book's own numerals. The chapter's own
    /// word is required, so an ordinary word that begins with the
    /// chapter word (= "the second time") names no chapter.
    public static func ordinal(in text: String) -> Int? {
        let characters = Array(text)
        guard let chapterIndex = characters.firstIndex(of: Character(chapterWord)) else { return nil }
        var index = chapterIndex + 1
        while index < characters.count, characters[index] == " " {
            index += 1
        }
        // An arabic number only: the book's own numerals are letters
        // that also read as numbers, and they are read below.
        var digits = ""
        while index < characters.count, characters[index].isASCII, characters[index].isNumber {
            digits.append(characters[index])
            index += 1
        }
        if !digits.isEmpty {
            guard let value = Int(digits) else { return nil }
            return closesChapter(characters, at: index) ? value : nil
        }
        var numerals = ""
        while index < characters.count, numeralsInBook.contains(characters[index]) {
            numerals.append(characters[index])
            index += 1
        }
        guard let value = bookNumeral(numerals) else { return nil }
        return closesChapter(characters, at: index) ? value : nil
    }

    /// Whether the characters at a position close a chapter's name.
    private static func closesChapter(_ characters: [Character], at index: Int) -> Bool {
        var position = index
        while position < characters.count, characters[position] == " " {
            position += 1
        }
        guard position < characters.count else { return false }
        return characters[position] == Character(numberWord)
    }

    /// The numerals the book's own numbers are written with.
    private static let numeralsInBook: Set<Character> = [
        "\u{4E00}", "\u{4E8C}", "\u{4E09}", "\u{56DB}", "\u{4E94}",
        "\u{516D}", "\u{4E03}", "\u{516B}", "\u{4E5D}", "\u{5341}",
    ]

    /// The value of a number written in the book's own numerals.
    private static func bookNumeral(_ numerals: String) -> Int? {
        if numerals.isEmpty {
            return nil
        }
        let digits: [String: Int] = [
            "\u{4E00}": 1, "\u{4E8C}": 2, "\u{4E09}": 3, "\u{56DB}": 4, "\u{4E94}": 5,
            "\u{516D}": 6, "\u{4E03}": 7, "\u{516B}": 8, "\u{4E5D}": 9, "\u{5341}": 10,
        ]
        if let value = digits[numerals] {
            return value
        }
        // Two parts (= ten plus a digit), = the book's own way of
        // writing a number above ten.
        guard let tenIndex = numerals.firstIndex(of: "\u{5341}") else { return nil }
        let head = String(numerals[..<tenIndex])
        let tail = String(numerals[numerals.index(after: tenIndex)...])
        let headValue = head.isEmpty ? 1 : digits[head]
        guard let headValue, let tailValue = tail.isEmpty ? 0 : digits[tail] else { return nil }
        return headValue * 10 + tailValue
    }
}
