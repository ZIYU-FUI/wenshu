//
//  ManuscriptTarget.swift · Wenshu
//
//  The submission target a manuscript is shaped for (= the platforms
//  a Chinese web novel is actually submitted to).
//
//  WHY THIS IS A NAMED POSITION AND NOT A SET OF NUMBERS
//
//  The manuscript's SHAPE per target is not a free-form setting.
//  It is measured per platform, and the measurements differ in
//  DIRECTION, not in degree:
//
//    - Jinjiang carries its segment indent IN THE CONTENT (= the first
//      characters of a segment are two full-width spaces U+3000
//      U+3000, = its reading end has text-indent: 0), = and its
//      paragraph spacing is carried by a BLANK LINE between
//      segments (= its reading end has margin 0 on every
//      paragraph).
//    - Qidian gives the indent with CSS (= text-indent 2em) and the
//      spacing with CSS (= p { margin-top: .8em }), = so the
//      manuscript must carry NEITHER: no leading spaces, no blank
//      lines between segments.
//    - Tomato gives the indent with CSS (= text-indent 2em), = and
//      its official rule says the platform DELETES extra spaces
//      inside a segment and extra blank lines between segments on
//      publish, = so the manuscript carries neither either.
//
//  A model of free numbers (= "indent = 2", = "blank lines = 1")
//  would let the user build a shape that no platform accepts, and
//  it would make the measured per-platform facts unreadable. So
//  each target is a POSITION, and the position carries its own
//  measured rules. = The same pattern the book style sheet's
//  heading ladder uses (= `BookHeadingLadder`).
//
//  THE MEASUREMENTS
//
//  From `.scratch/2026-11-05-book-style-sheet/spec.md` §6 and the
//  platform study (= `webnovel-platform-specs.md` §5 / §6 B1-B2):
//
//  | target | chapter title | segment indent | blank line between segments |
//  |---|---|---|---|
//  | Qidian / Tomato | a chapter-title field | none (= the platform indents) | none |
//  | Jinjiang | a chapter-title field | two full-width spaces U+3000 U+3000 | yes |
//
//  The title is a SEPARATE FIELD for every web-novel target (= the
//  platforms' own chapter-title input), = and it does NOT go into
//  the body. = The manuscript's own word count is measured on the
//  BODY (= Tomato's official rule: "the body word count, excluding the title").
//
//  the real publication (= the print target) is NOT here: its shape needs a
//  volume / part / section hierarchy (= spec §6's row = "volume /
//  chapter / section headings"), = and the book model carries no volume. = The
//  boss's open item (§7) also leaves the print / general split
//  undecided. = So this type holds the targets whose shape the
//  current data model can honestly produce.
//

import Foundation

/// Where a manuscript is being submitted (= the target whose
/// measured shape the export applies).
enum ManuscriptTarget: String, CaseIterable, Identifiable, Sendable {
    /// Qidian / Yuewen. The platform renders the indent (= text-indent
    /// 2em) and the spacing (= p { margin-top: .8em }), = so the
    /// manuscript carries neither.
    case qidian

    /// Tomato. The platform renders the indent (= text-indent 2em)
    /// and deletes the extra spaces inside a segment and the extra
    /// blank lines between segments on publish (= its official
    /// rule), = so the manuscript carries neither.
    case fanqie

    /// Jinjiang. The indent lives IN THE CONTENT (= two full-width
    /// spaces U+3000 U+3000 at the start of every segment) and the
    /// spacing lives in a BLANK LINE between segments (= its
    /// reading end has text-indent: 0 and margin 0).
    case jinjiang

    var id: String {
        rawValue
    }

    /// The target's name, in the house pattern for a model's
    /// display name (= a hard-coded Chinese literal).
    var displayName: String {
        switch self {
        case .qidian: return "起点"
        case .fanqie: return "番茄"
        case .jinjiang: return "晋江"
        }
    }

    /// The prefix every segment carries (= the platform's indent).
    ///
    /// Jinjiang's indent is IN THE CONTENT (= two full-width spaces
    /// U+3000 U+3000). = The other two platforms render the indent
    /// themselves, = so the manuscript carries nothing.
    var segmentIndent: String {
        switch self {
        case .qidian, .fanqie: return ""
        case .jinjiang: return "\u{3000}\u{3000}"
        }
    }

    /// The target's segment indent, in the reader's language.
    ///
    /// The indent is the one thing a reader cannot guess: = a
    /// platform that renders it must be told so, = and a platform that
    /// carries it in the content must be told THAT.
    ///
    /// The text is DERIVED from the measured rule (= the indent the
    /// shaper writes), = not copied from it: = so a rule that changes
    /// brings the panel's own words with it, = and the panel cannot
    /// state a shape the export does not produce.
    var indentDescription: String {
        let spaces = segmentIndent.filter { $0 == "\u{3000}" }.count
        guard spaces > 0 else { return "每段首行不缩进" }
        return "每段首行\(Self.countWord(spaces))个全角空格"
    }

    /// The target's spacing between segments, in the reader's language.
    ///
    /// Derived from the measured rule, = for the same reason.
    /// What the platform COUNTS, = in the reader's words.
    ///
    /// = The rule is the app's own export's: = the chapter title is
    /// the platform's own field, = so it is never part of the body
    /// the platform counts, = and the body is counted in its own
    /// characters (= the punctuation included, = because no platform
    /// publishes whether its counter drops it).
    var wordCountRule: String {
        switch self {
        case .qidian, .jinjiang: return "按正文计，标题单独计"
        case .fanqie: return "按正文计，不含标题"
        }
    }

    /// The platform's published range for ONE chapter's word count, =
    /// when the platform publishes one.
    ///
    /// = `nil` means the platform publishes no per-chapter word rule
    /// this build could source, = so the app checks nothing against a
    /// number it cannot point at, = and the panel then shows the count
    /// alone.
    ///
    /// = The Qidian range is the public writers' help centre's own
    /// rule (= one chapter at most 20,000 characters), = as a
    /// third-party guide that cites it relays it. = The other two
    /// publish no per-chapter word rule this build could verify.
    var chapterWordRange: ClosedRange<Int>? {
        switch self {
        case .qidian: return 0...20_000
        case .fanqie, .jinjiang: return nil
        }
    }

    var spacingDescription: String {
        separatesSegmentsWithBlankLine ? "段间空一行" : "段间无空行"
    }

    /// The Chinese word for a small count (= so a derived count reads
    /// the way a reader writes it, = and not as a digit).
    private static func countWord(_ count: Int) -> String {
        switch count {
        case 1: return "一"
        case 2: return "两"
        case 3: return "三"
        case 4: return "四"
        case 5: return "五"
        case 6: return "六"
        case 7: return "七"
        case 8: return "八"
        case 9: return "九"
        case 10: return "十"
        default: return String(count)
        }
    }

    /// Whether a blank line separates two segments.
    ///
    /// Jinjiang's reading end has margin 0 on every paragraph (= its
    /// spacing IS the blank line in the manuscript). = Qidian gives
    /// the spacing with CSS (= no blank line), = and Tomato deletes
    /// the extra blank lines on publish (= no blank line).
    var separatesSegmentsWithBlankLine: Bool {
        switch self {
        case .qidian, .fanqie: return false
        case .jinjiang: return true
        }
    }
}
