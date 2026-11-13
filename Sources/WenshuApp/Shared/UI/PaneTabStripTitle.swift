// PaneTabStripTitle.swift
//
// The title rule a pane tab strip's segment follows when the strip
// divides the column it was given.
//
// Two strips ask this question: the editor's document strip and the
// chat zone's session bar. The answer lives here so the two strips
// cannot drift (= one door per question = one answer).

import AppKit
import CoreGraphics

/// The title a pane tab strip segment draws.
enum PaneTabStripTitle {
    /// The room one CHARACTER of the title takes beyond the width
    /// `NSString` measures it at.
    ///
    /// MEASURED on the real control in the real app (= the smallest
    /// cell that draws a title WHOLE, = against the title's measured
    /// width):
    ///
    /// | title | measured width | drawn whole at | slack |
    /// | --- | --- | --- | --- |
    /// | 仙 | 12.899 PT | 13 PT | 0.101 PT |
    /// | 十二 | 25.798 PT | 26 PT | 0.202 PT |
    /// | 十二地 | 38.696 PT | 39 PT | 0.303 PT |
    /// | 十二地仙 | 51.595 PT | 52 PT | 0.405 PT |
    ///
    /// ⇒ So the drawn width is the measured width plus about a tenth
    /// of a point PER CHARACTER (= the drawn advance of one character
    /// is 13.0 PT, = while `NSString.size` reports 12.899 PT), = and
    /// this slack is what keeps the app's own arithmetic on the same
    /// side of the line AppKit draws on.
    static let characterSlack: CGFloat = 0.1

    /// The room the ELLIPSIS takes in a cell.
    ///
    /// MEASURED, from the same ladder (= the title '十二地仙', = in a
    /// cell of the given width):
    ///
    /// - 52 PT and up => the WHOLE title (= 697 ink pixels)
    /// - 39 to 51 PT => '十二…' (= 245 ink pixels)
    /// - 26 to 38 PT => '十…' (= 142 ink pixels)
    /// - 12 to 25 PT => the ELLIPSIS ALONE (= 34 ink pixels, = the
    ///   three dots of '…' and nothing else)
    /// - 8 to 11 PT => a clipped fragment of the ellipsis (= 22 to 37
    ///   ink pixels, = which is no text at all)
    ///
    /// ⇒ So AppKit truncates a title that does not fit (= it keeps the
    /// START of the title and adds '…'), = and it does NOT stop at the
    /// ellipsis: = at a narrow enough width it draws the lone '…',
    /// = and below that it draws a piece of a dot.
    ///
    /// ⇒ AND THE BOSS'S RULE IS ABOUT EXACTLY THAT CASE: "缩到一定
    /// 程度，那个...就没有意义了，不如只能显示...的时候，连...都不
    /// 显示" (= once it shrinks so far that only the '…' would show,
    /// = that '…' has no meaning, = so show nothing at all).
    ///
    /// ⇒ ⇒ ⇒ SO THE APP OWNS THE TITLE: = AppKit's own truncation
    /// cannot be asked for a blank, = because AppKit's fallback for a
    /// title that does not fit is the ellipsis (= never nothing). = The
    /// app therefore sets the title it wants drawn, = and the three
    /// answers are decided here, = in one place, = for both strips.
    ///
    /// The ellipsis costs one CHARACTER of the cell (= 13.0 PT):
    /// '十…' first fits in a 26 PT cell (= 13 for the character + 13
    /// for the ellipsis), = and '十二…' first fits in a 39 PT cell
    /// (= 26 + 13).
    static let ellipsisCost: CGFloat = 13

    /// The label a cell carries when it shows NOTHING.
    ///
    /// A ZERO WIDTH SPACE (= U+200B). = It measures 0 PT wide, = so it
    /// draws no ink at all (= the cell shows nothing, = not an ellipsis
    /// and not a sliced glyph), = and it can never be truncated (= so
    /// AppKit cannot turn it into the lone '…' = the case the boss
    /// ruled out).
    ///
    /// ⇒ ⇒ ⇒ AND IT MUST NOT BE AN EMPTY STRING. = MEASURED, = 12
    /// cells in a 200 PT region (= a 16.67 PT share):
    ///
    /// | the label | the drawn cells step by | the last divider |
    /// | --- | --- | --- |
    /// | `""` (empty) | 21.0 / 21.5 PT | 205.5 PT (= OVER the region) |
    /// | `" "` (a space) | 16.5 / 17.0 PT | 181.5 PT (= inside) |
    /// | `"\u{200B}"` | 16.5 / 17.0 PT | 181.5 PT (= inside) |
    ///
    /// ⇒ ⇒ ⇒ SO AN EMPTY LABEL BREAKS THE DIVISION: = AppKit gives a
    /// cell with NO title its own minimum width (= about 21 PT, = the
    /// same floor `setWidth` has), = so the strip then exceeds the
    /// region it was given (= 24 empty cells in a 200 PT region drew a
    /// divider at 332 PT, = and the strip overflowed its column by
    /// 132 PT). = A label that carries a CHARACTER is what lets
    /// AppKit divide the region exactly, = and a zero width space is
    /// a character that draws nothing.
    static let nothingMarker = "\u{200B}"

    /// The title one segment draws at `share` points wide.
    ///
    /// The boss's rule (= 2026-11-12), in two tiers:
    ///
    /// - "有可能让 teb 栏宽度显示文字，这种情况被允许" (= a narrow
    ///   tab may still show text, = and a truncated title is text).
    /// - "缩到一定程度，那个...就没有意义了，不如只能显示...的时候，
    ///   连...都不显示" (= once it shrinks so far that only the '…'
    ///   would show, = that '…' has no meaning, = so show nothing at
    ///   all).
    ///
    /// So there are three answers, and this is the one place they are
    /// decided:
    ///
    /// 1. The title fits => the whole title.
    /// 2. A prefix of it plus the ellipsis fits => that prefix and the
    ///    ellipsis (= the readable truncation, = and the tier the boss
    ///    allowed).
    /// 3. Not even that fits => NOTHING (= the `nothingMarker`, = which
    ///    MEASURED paints zero pixels: = the cell draws no text at
    ///    all, = not a lone ellipsis and not a sliced glyph, = and it
    ///    still takes its share of the region).
    ///
    /// The truncation keeps the START of the title (= the part that
    /// names it) and cuts the tail, = which is how Apple's own tab
    /// bars shorten a title that does not fit.
    ///
    /// - Parameters:
    ///   - title: The title as the caller knows it (= the whole name).
    ///   - share: The width one segment takes (= the region's width
    ///     over the segment count).
    ///   - font: The font the control draws the label with (= its own
    ///     font, = so the measurement is the measurement).
    /// - Returns: The string the segment draws.
    static func fitted(_ title: String, share: CGFloat, font: NSFont) -> String {
        // A share of zero means the strip has not been measured yet,
        // and the control is on its own fitting width (= every label
        // fits), = so the title is the whole title.
        guard share > 0 else { return title }

        // The whole title, when the cell has room for it.
        if drawnWidth(of: title, font: font) <= share {
            return title
        }

        // The longest START of the title that fits beside the
        // ellipsis. The prefix must carry at least one character of
        // the title: = an ellipsis on its own is the case the boss
        // ruled out (= "连...都不显示"), = and it is also the only
        // way to tell a truncated title from a whole one.
        var kept = ""
        for character in title {
            let candidate = kept + String(character)
            let width = drawnWidth(of: candidate, font: font)
            guard width + ellipsisCost <= share else { break }
            kept = candidate
        }
        guard !kept.isEmpty else { return nothingMarker }
        return kept + "…"
    }

    /// The width a string takes AS DRAWN (= the measured width plus
    /// the per-character slack, = which is what the ladder measured).
    static func drawnWidth(of string: String, font: NSFont) -> CGFloat {
        let measured = (string as NSString).size(withAttributes: [.font: font]).width
        return measured + CGFloat(string.count) * characterSlack
    }
}
