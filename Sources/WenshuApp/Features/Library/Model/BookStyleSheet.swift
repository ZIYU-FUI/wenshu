// BookStyleSheet.swift · Wenshu (Wenshu).1 (book module)
//
// The style sheet a book carries.
//
// A book's style is BOOK-level: = one style set runs through the whole
// book, = and every adjustment acts on the whole book. = The values here
// are the ones a printed book uses, = measured from CY/T 120-2015 (the
// academic publishing standard for book typesetting), = and folded to the
// screen:
//
//   body         Songti 13pt (= the print minimum is size 5 (10.5pt), = and
//                13pt is the HIG body size)
//   line spacing 1.55 (= print 1.50-1.60)
//   indent       two characters (= the print first-line indent of two
//                characters)
//   spacing      none (= the print segment spacing of zero)
//   headings     a LADDER of positions (= the print baseline is
//                16 / 14 / 12pt in Heiti, = and every position descends)
//   quote        Kai 12.5pt (= a print quote is a different face + size)
//   note         11pt (= the print small size 5 (9pt), = always smaller
//                than the body)
//   captions     11pt each (= a figure caption sits BELOW its figure, = and
//                a table caption ABOVE its table, = and both are always
//                smaller than the body)
//
// EVERY knob holds a FIXED POSITION, = never a free number: = a writer
// chooses a style, = not that a writer sets a size. = So the type is a
// set of enums, = and a number can only be reached through one of them.
//
// The heading ladder is one of those enums: = the sheet holds the
// POSITION, = and the sizes come from it, = so a book.json carries a
// ladder's NAME and never a list of numbers.
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

    /// Points on screen. = The print minimum for a novel's body is size 5
    /// (10.5pt), = and 13pt is the HIG body size, = so the middle position
    /// is the print baseline and the smallest one is a shade under it.
    var points: Double {
        switch self {
        case .small: return 12
        case .medium: return 13
        case .large: return 14
        }
    }

    /// Chinese display name (= the label a picker draws for this
    /// position).
    var displayName: String {
        switch self {
        case .small: return "小号"
        case .medium: return "中号"
        case .large: return "大号"
        }
    }
}

/// The line spacing a book can be set to. = Print books run 1.50-1.60
/// (= size 5 with 5.25-6.25pt of leading), = and the middle position is the
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

    /// Chinese display name (= the label a picker draws for this
    /// position).
    var displayName: String {
        switch self {
        case .tight: return "紧凑"
        case .standard: return "标准"
        case .loose: return "宽松"
        }
    }
}

/// The first-line indent a book can be set to. = A printed Chinese novel
/// indents two characters (= the print first-line indent of two
/// characters), = and that is the baseline.
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

    /// Chinese display name (= the label a picker draws for this
    /// position).
    var displayName: String {
        switch self {
        case .none: return "不缩进"
        case .twoCharacters: return "缩进两字"
        }
    }
}

/// The space between segments a book can be set to. = A printed Chinese
/// book uses NO space between segments (= the print segment spacing of
/// zero; = a blank line means a section ended), = and that is the baseline.
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

    /// Chinese display name (= the label a picker draws for this
    /// position).
    var displayName: String {
        switch self {
        case .none: return "无间距"
        case .halfCharacter: return "半字段距"
        }
    }
}

/// The face a book's body is set in. = The four faces a Chinese novel
/// actually uses: = the body face (= Songti), = the heading face (= Heiti),
/// the literary face (= Kaiti), = and the screen face (= PingFang).
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

    /// The family a HEADING is set in when the body is set in this one.
    ///
    /// = A printed book's headings are a different face from its body
    /// (= Heiti), = and they follow the body except when the body
    /// itself is already the heading face.
    ///
    /// = This is the ONE rule for the heading's face, = so the sheet's
    /// own default (= the print baseline's headings) and the reading of
    /// a book.json written before the heading had its own position
    /// cannot disagree.
    var derivedHeadingFamily: BookBodyFamily {
        switch self {
        case .songti: return .heiti
        case .heiti: return .heiti
        case .kai: return .kai
        case .pingFang: return .pingFang
        }
    }

    /// The face a HEADING is set in. = A printed book's headings are a
    /// different face from its body (= Heiti), = and they follow the body
    /// except when the body itself is already the heading face.
    var headingPostScriptName: String {
        derivedHeadingFamily.postScriptName
    }

    /// Chinese display name (= the label a picker draws for this face).
    var displayName: String {
        switch self {
        case .songti: return "宋体"
        case .heiti: return "黑体"
        case .kai: return "楷体"
        case .pingFang: return "苹方"
        }
    }
}

/// The heading ladder a book can be set to. = Three positions, = and every
/// one of them DESCENDS: = the print baseline in the middle.
///
/// A ladder is a POSITION, = not a list of numbers: = so a book can hold
/// only the ladders a printed book uses, = and the sizes are read from the
/// position (see `sizes`) = rather than written by a caller.
enum BookHeadingLadder: String, CaseIterable, Codable, Sendable {
    case printStandard
    case compact
    case generous

    /// The three levels' sizes, = in points. = The print ladder is size 3 /
    /// size 4 / small size 4 = (16 / 14 / 12pt), = and every position
    /// descends for every level.
    var sizes: [Double] {
        switch self {
        case .printStandard: return [16, 14, 12]
        case .compact: return [15, 13, 11]
        case .generous: return [18, 16, 14]
        }
    }

    /// Chinese display name (= the label a picker draws for this ladder).
    var displayName: String {
        switch self {
        case .printStandard: return "标准"
        case .compact: return "紧凑"
        case .generous: return "宽松"
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
    /// The quote's face. = A print quote is a different face from the
    /// body (= the literary face), = and this is that face.
    var quoteFamily: BookBodyFamily
    /// The heading ladder. = A POSITION, = and the sizes it holds come
    /// from it: = the sheet never stores a free number.
    var headingLadder: BookHeadingLadder
    /// The heading's own face.
    ///
    /// A PRINTED book's headings wear a different face from its body
    /// (= Heiti), = and that face is its own position, = so the general
    /// set can put the headings in the body's own face instead.
    var headingFamily: BookBodyFamily

    /// The measured print baseline: = a printed Chinese novel, = folded
    /// to the screen.
    static let `default` = BookStyleSheet(
        bodySize: .medium,
        lineSpacing: .standard,
        firstLineIndent: .twoCharacters,
        segmentSpacing: .none,
        bodyFamily: .songti,
        quoteFamily: .kai,
        headingLadder: .printStandard,
        headingFamily: .heiti
    )

    init(
        bodySize: BookBodySize = .medium,
        lineSpacing: BookLineSpacing = .standard,
        firstLineIndent: BookFirstLineIndent = .twoCharacters,
        segmentSpacing: BookSegmentSpacing = .none,
        bodyFamily: BookBodyFamily = .songti,
        quoteFamily: BookBodyFamily = .kai,
        headingLadder: BookHeadingLadder = .printStandard,
        headingFamily: BookBodyFamily = .heiti
    ) {
        self.bodySize = bodySize
        self.lineSpacing = lineSpacing
        self.firstLineIndent = firstLineIndent
        self.segmentSpacing = segmentSpacing
        self.bodyFamily = bodyFamily
        self.quoteFamily = quoteFamily
        self.headingLadder = headingLadder
        self.headingFamily = headingFamily
    }

    /// The three heading levels' sizes, = in points. = DERIVED from the
    /// ladder, = never stored: = the sheet holds a POSITION, = and the
    /// positions are the printed ones.
    var headingSizes: [Double] {
        headingLadder.sizes
    }

    /// The size of a heading level. = Level one is the biggest; = a level
    /// past the ladder falls back to the body size, = so a document with
    /// more levels than the ladder still has a defined size.
    func headingSize(forLevel level: Int) -> Double {
        let sizes = headingSizes
        guard level >= 1, level <= sizes.count else { return bodySize.points }
        return sizes[level - 1]
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

    /// The figure caption's size. = A print figure caption is always
    /// SMALLER than the body, = and it sits BELOW its figure.
    var figureCaptionSize: Double {
        11
    }

    /// The table caption's size. = A print table caption is always
    /// SMALLER than the body, = and it sits ABOVE its table.
    var tableCaptionSize: Double {
        11
    }

    /// The sheet with one knob moved to a position.
    ///
    /// A knob moves to a POSITION (= its enum's own name), = so a
    /// position this build does not know leaves the sheet alone
    /// (= the persisted field never carries a value the sheet cannot
    /// read back). = This is the domain's own operation, = so the page
    /// and the tests move a knob the same way.
    func setting(_ knob: BookStyleKnob, to position: String) -> BookStyleSheet {
        var sheet = self
        switch knob {
        case .bodySize:
            guard let value = BookBodySize(rawValue: position) else { return self }
            sheet.bodySize = value
        case .lineSpacing:
            guard let value = BookLineSpacing(rawValue: position) else { return self }
            sheet.lineSpacing = value
        case .firstLineIndent:
            guard let value = BookFirstLineIndent(rawValue: position) else { return self }
            sheet.firstLineIndent = value
        case .segmentSpacing:
            guard let value = BookSegmentSpacing(rawValue: position) else { return self }
            sheet.segmentSpacing = value
        case .bodyFamily:
            guard let value = BookBodyFamily(rawValue: position) else { return self }
            sheet.bodyFamily = value
        }
        return sheet
    }
}

// MARK: - The knobs

/// The five knobs a book's style sheet is fine-tuned with.
///
/// The knob's NAME is the persisted field's name (= the page's knob
/// id), = so a knob id and the sheet's own property are the same
/// string (= no second mapping to keep in step).
enum BookStyleKnob: String, CaseIterable, Sendable {
    case bodySize
    case lineSpacing
    case firstLineIndent
    case segmentSpacing
    case bodyFamily
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
        case bodySize, lineSpacing, firstLineIndent, segmentSpacing
        case bodyFamily, quoteFamily, headingLadder, headingFamily
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = BookStyleSheet.default
        // The ladder decodes LENIENTLY (= the repo's own convention for
        // a persisted position, = the same shape `Reference.layer`
        // uses): = the persisted field carries the ladder's NAME, = so a
        // name this build does not know (= one a later build writes, = or
        // a hostile one) must not fail the whole book.json. = It reads as
        // the print baseline, = and so does a value that is not a name
        // at all. = So a book.json can never carry a size into the sheet.
        let rawLadder = try? c.decode(String.self, forKey: .headingLadder)
        let ladder = rawLadder.flatMap(BookHeadingLadder.init(rawValue:)) ?? fallback.headingLadder
        // = A book.json written before the heading had its OWN
        // position keeps the headings it had: = the body's face
        // decides them (= the print convention's own rule), = so an
        // upgrade never re-voices a book's headings.
        let bodyFamily = try c.decodeIfPresent(BookBodyFamily.self, forKey: .bodyFamily) ?? fallback.bodyFamily
        try self.init(
            bodySize: c.decodeIfPresent(BookBodySize.self, forKey: .bodySize) ?? fallback.bodySize,
            lineSpacing: c.decodeIfPresent(BookLineSpacing.self, forKey: .lineSpacing) ?? fallback.lineSpacing,
            firstLineIndent: c.decodeIfPresent(BookFirstLineIndent.self, forKey: .firstLineIndent) ?? fallback.firstLineIndent,
            segmentSpacing: c.decodeIfPresent(BookSegmentSpacing.self, forKey: .segmentSpacing) ?? fallback.segmentSpacing,
            bodyFamily: bodyFamily,
            quoteFamily: c.decodeIfPresent(BookBodyFamily.self, forKey: .quoteFamily) ?? fallback.quoteFamily,
            headingLadder: ladder,
            headingFamily: c.decodeIfPresent(BookBodyFamily.self, forKey: .headingFamily)
                ?? bodyFamily.derivedHeadingFamily
        )
    }
}

// MARK: - The two sets

/// The two sets a book can be set to: = the print baseline, = and the
/// general set.
///
/// A set is a NAMED SHEET, = and the page writes one down in one
/// action, = so a book starts from the printed standard or from the
/// screen's.
///
/// THE GENERAL SET IS THE PRINT BASELINE WITH ONE CHANGE: = its
/// headings wear the body's own face, = because a screen reads a
/// heading in the body's face as one piece of text, = while a printed
/// page reads Heiti as another voice. = Its leading is the print
/// baseline's own (= 1.55), = so the two sets differ in one thing
/// only, = and a book that has fine-tuned a knob sits at neither.
enum BookStylePreset: String, CaseIterable, Sendable {
    case printBaseline
    case general

    /// Chinese display name (= the label a picker draws for this set).
    var displayName: String {
        switch self {
        case .printBaseline: return "印刷基线"
        case .general: return "通用"
        }
    }

    /// The sheet this set sets, = for a body in the given face.
    ///
    /// The general set is set AROUND the body's own face: = the body
    /// keeps it, = and the headings wear it too, = so a book whose body
    /// is PingFang gets PingFang headings, = and its positions are the
    /// print baseline's own (= the leading is 1.55).
    ///
    /// The print baseline is the PRINTED standard, = so it is the same
    /// sheet whatever face the body was in.
    func sheet(bodyFamily: BookBodyFamily) -> BookStyleSheet {
        switch self {
        case .printBaseline:
            return BookStyleSheet.default
        case .general:
            var sheet = BookStyleSheet.default
            sheet.bodyFamily = bodyFamily
            sheet.headingFamily = bodyFamily
            return sheet
        }
    }

    /// The set the sheet is at, = when it is at one of the sets.
    ///
    /// A sheet the book has fine-tuned is at neither, = and the page
    /// then draws no set as the chosen one.
    static func matching(_ sheet: BookStyleSheet) -> BookStylePreset? {
        if sheet == BookStyleSheet.default {
            return .printBaseline
        }
        if sheet == BookStylePreset.general.sheet(bodyFamily: sheet.bodyFamily) {
            return .general
        }
        return nil
    }
}
