// BookStyleSheet.swift · Wenshu (Wenshu).1 (book module)
//
// The style sheet a book carries.
//
// A book's style is BOOK-level: = one style set runs through the whole
// book, = and every adjustment acts on the whole book. = The values here
// are the ones a printed book uses, = measured from CY/T 120-2015
// (学术出版规范 图书版式), = and folded to the screen:
//
//   body         Songti 13pt (= the print minimum is 五号 / 10.5pt, = and
//                13pt is the HIG body size)
//   line spacing 1.55 (= print 1.50-1.60)
//   indent       two characters (= print 首行缩进 2 字)
//   spacing      none (= print 段间距 0)
//   headings     16 / 14 / 12pt in Heiti (= print 三号 / 四号 / 小四)
//   quote        Kai 12.5pt (= print 引文 = a different face + size)
//   note         11pt (= print 小五 9pt, = always smaller than the body)
//   captions     11pt (= print 图题 / 表题, = always smaller than the body)
//
// EVERY knob holds a FIXED POSITION, = never a free number: = the boss's
// rule is that a writer chooses a style, = not that a writer sets a size.
// So the type is a set of enums, = and a number can only be reached
// through one of them.
//
// The engine package (= nodes-app/swift-markdown-engine) = does not yet
// carry a document-level font family, = an absolute size per level, = a
// first-line indent, = or a line spacing: = its configuration exposes
// relative multipliers only. = So this sheet is the MODEL: = the app side
// reads it, = and the engine's own knobs arrive in their own card.

import Foundation

// MARK: - The positions

/// The body size a book can be set to. Three positions, = the print
/// baseline in the middle.
enum BookBodySize: String, CaseIterable, Codable, Sendable {
    case small
    case medium
    case large

    /// Points on screen. = The print minimum for a novel's body is 五号
    /// (10.5pt), = and 13pt is the HIG body size, = so the middle position
    /// is the print baseline and the smallest one is a shade under it.
    var points: Double {
        switch self {
        case .small: return 12
        case .medium: return 13
        case .large: return 14
        }
    }
}

/// The line spacing a book can be set to. = Print books run 1.50-1.60
/// (= 五号 with 5.25-6.25pt of leading), = and the middle position is the
/// measured baseline.
enum BookLineSpacing: String, CaseIterable, Codable, Sendable {
    case tight
    case standard
    case loose

    /// Multiples of the body size.
    var multiple: Double {
        switch self {
        case .tight: return 1.45
        case .standard: return 1.55
        case .loose: return 1.70
        }
    }
}

/// The first-line indent a book can be set to. = A printed Chinese novel
/// indents two characters (= 首行缩进 2 字), = and that is the baseline.
enum BookFirstLineIndent: String, CaseIterable, Codable, Sendable {
    case none
    case twoCharacters

    /// The indent, in characters (= the body font's em is the unit).
    var characters: Double {
        switch self {
        case .none: return 0
        case .twoCharacters: return 2
        }
    }
}

/// The space between segments a book can be set to. = A printed Chinese
/// book uses NO space between segments (= 段间距 0; = a blank line means
/// a section ended), = and that is the baseline.
enum BookSegmentSpacing: String, CaseIterable, Codable, Sendable {
    case none
    case halfCharacter

    /// The spacing, in characters.
    var characters: Double {
        switch self {
        case .none: return 0
        case .halfCharacter: return 0.5
        }
    }
}

/// The face a book's body is set in. = The four faces a Chinese novel
/// actually uses: = the body face (= 宋体), = the heading face (= 黑体),
/// the literary face (= 楷体), = and the screen face (= 苹方).
///
/// The names are the PostScript names macOS ships them under, = so a
/// renderer can ask for them without a lookup table.
enum BookBodyFamily: String, CaseIterable, Codable, Sendable {
    case songti
    case heiti
    case kai
    case pingFang

    /// The face's PostScript name (= what `NSFont(name:size:)` takes).
    var postScriptName: String {
        switch self {
        case .songti: return "Songti SC"
        case .heiti: return "Heiti SC"
        case .kai: return "Kaiti SC"
        case .pingFang: return "PingFang SC"
        }
    }

    /// The face a HEADING is set in. = A printed book's headings are a
    /// different face from its body (= 黑体), = and they follow the body
    /// except when the body itself is already the heading face.
    var headingPostScriptName: String {
        switch self {
        case .songti: return "Heiti SC"
        case .heiti: return "Heiti SC"
        case .kai: return "Kaiti SC"
        case .pingFang: return "PingFang SC"
        }
    }
}

// MARK: - The sheet

/// The style sheet one book carries.
///
/// Every knob is a POSITION, = so the sheet cannot express a size the
/// printer would not set. = A book with no sheet reads
/// `BookStyleSheet.default`, = which is the measured print baseline.
struct BookStyleSheet: Codable, Hashable, Sendable {
    /// The body's size.
    var bodySize: BookBodySize
    /// The body's leading.
    var lineSpacing: BookLineSpacing
    /// The first-line indent of a segment.
    var firstLineIndent: BookFirstLineIndent
    /// The space between segments.
    var segmentSpacing: BookSegmentSpacing
    /// The body's face (= and, by default, the headings' face).
    var bodyFamily: BookBodyFamily
    /// The three heading levels' sizes, = in points. = The print ladder
    /// is 三号 / 四号 / 小四 = (16 / 14 / 12pt), = and it descends for
    /// every level.
    var headingSizes: [Double]

    /// The measured print baseline: = a printed Chinese novel, = folded
    /// to the screen.
    static let `default` = BookStyleSheet(
        bodySize: .medium,
        lineSpacing: .standard,
        firstLineIndent: .twoCharacters,
        segmentSpacing: .none,
        bodyFamily: .songti,
        headingSizes: [16, 14, 12]
    )

    init(
        bodySize: BookBodySize = .medium,
        lineSpacing: BookLineSpacing = .standard,
        firstLineIndent: BookFirstLineIndent = .twoCharacters,
        segmentSpacing: BookSegmentSpacing = .none,
        bodyFamily: BookBodyFamily = .songti,
        headingSizes: [Double] = [16, 14, 12]
    ) {
        self.bodySize = bodySize
        self.lineSpacing = lineSpacing
        self.firstLineIndent = firstLineIndent
        self.segmentSpacing = segmentSpacing
        self.bodyFamily = bodyFamily
        self.headingSizes = headingSizes
    }

    /// The size of a heading level. = Level one is the biggest; = a level
    /// past the ladder falls back to the body size, = so a document with
    /// more levels than the ladder still has a defined size.
    func headingSize(forLevel level: Int) -> Double {
        guard level >= 1, level <= headingSizes.count else { return bodySize.points }
        return headingSizes[level - 1]
    }

    /// The quote's size. = A print quote is a different face AND a
    /// different size from the body.
    var quoteSize: Double {
        12.5
    }

    /// The note's size. = A print note is always SMALLER than the body.
    var noteSize: Double {
        11
    }

    /// The caption's size, = for both figures and tables. = Always smaller
    /// than the body.
    var captionSize: Double {
        11
    }
}

// MARK: - Codable back-compat

//
// A book.json written before the sheet existed has no 'styleSheet' key,
// and one written with an older sheet may carry fewer keys. = So both the
// Book's own decode and this type's decode default what is missing,
// rather than failing (= the repo's own convention for every optional
// field it has added).

extension BookStyleSheet {
    private enum CodingKeys: String, CodingKey {
        case bodySize, lineSpacing, firstLineIndent, segmentSpacing, bodyFamily, headingSizes
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = BookStyleSheet.default
        try self.init(
            bodySize: c.decodeIfPresent(BookBodySize.self, forKey: .bodySize) ?? fallback.bodySize,
            lineSpacing: c.decodeIfPresent(BookLineSpacing.self, forKey: .lineSpacing) ?? fallback.lineSpacing,
            firstLineIndent: c.decodeIfPresent(BookFirstLineIndent.self, forKey: .firstLineIndent) ?? fallback.firstLineIndent,
            segmentSpacing: c.decodeIfPresent(BookSegmentSpacing.self, forKey: .segmentSpacing) ?? fallback.segmentSpacing,
            bodyFamily: c.decodeIfPresent(BookBodyFamily.self, forKey: .bodyFamily) ?? fallback.bodyFamily,
            headingSizes: c.decodeIfPresent([Double].self, forKey: .headingSizes) ?? fallback.headingSizes
        )
    }
}
