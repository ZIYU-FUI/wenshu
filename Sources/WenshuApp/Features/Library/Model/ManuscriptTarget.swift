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
//    - 晋江 carries its segment indent IN THE CONTENT (= the first
//      characters of a segment are two full-width spaces U+3000
//      U+3000, = its reading end has text-indent: 0), = and its
//      paragraph spacing is carried by a BLANK LINE between
//      segments (= its reading end has margin 0 on every
//      paragraph).
//    - 起点 gives the indent with CSS (= text-indent 2em) and the
//      spacing with CSS (= p { margin-top: .8em }), = so the
//      manuscript must carry NEITHER: no leading spaces, no blank
//      lines between segments.
//    - 番茄 gives the indent with CSS (= text-indent 2em), = and
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
//  | 起点 / 番茄 | a chapter-title field | none (= the platform indents) | none |
//  | 晋江 | a chapter-title field | two full-width spaces U+3000 U+3000 | yes |
//
//  The title is a SEPARATE FIELD for every web-novel target (= the
//  platforms' own chapter-title input), = and it does NOT go into
//  the body. = The manuscript's own word count is measured on the
//  BODY (= 番茄's official rule: "章节正文字数（不含标题）").
//
//  真实出版 (= the print target) is NOT here: its shape needs a
//  volume / part / section hierarchy (= spec §6's row = "卷 / 章 /
//  节 headings"), = and the book model carries no volume. = The
//  boss's open item (§7) also leaves the print / general split
//  undecided. = So this type holds the targets whose shape the
//  current data model can honestly produce.
//

import Foundation

/// Where a manuscript is being submitted (= the target whose
/// measured shape the export applies).
enum ManuscriptTarget: String, CaseIterable, Identifiable, Sendable {
    /// 起点 / 阅文. The platform renders the indent (= text-indent
    /// 2em) and the spacing (= p { margin-top: .8em }), = so the
    /// manuscript carries neither.
    case qidian

    /// 番茄. The platform renders the indent (= text-indent 2em)
    /// and deletes the extra spaces inside a segment and the extra
    /// blank lines between segments on publish (= its official
    /// rule), = so the manuscript carries neither.
    case fanqie

    /// 晋江. The indent lives IN THE CONTENT (= two full-width
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
    /// 晋江's indent is IN THE CONTENT (= two full-width spaces
    /// U+3000 U+3000). = The other two platforms render the indent
    /// themselves, = so the manuscript carries nothing.
    var segmentIndent: String {
        switch self {
        case .qidian, .fanqie: return ""
        case .jinjiang: return "\u{3000}\u{3000}"
        }
    }

    /// Whether a blank line separates two segments.
    ///
    /// 晋江's reading end has margin 0 on every paragraph (= its
    /// spacing IS the blank line in the manuscript). = 起点 gives
    /// the spacing with CSS (= no blank line), = and 番茄 deletes
    /// the extra blank lines on publish (= no blank line).
    var separatesSegmentsWithBlankLine: Bool {
        switch self {
        case .qidian, .fanqie: return false
        case .jinjiang: return true
        }
    }
}
