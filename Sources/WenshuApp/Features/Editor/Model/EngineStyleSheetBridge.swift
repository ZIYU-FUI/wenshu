//
//  EngineStyleSheetBridge.swift · Wenshu
//
//  A book's style sheet, turned into what the Markdown engine takes.
//
//  WHY A BRIDGE AND NOT THE VIEW
//
//  The mapping is DOMAIN knowledge (= what a sheet means to the
//  engine), = and the view that holds it (= `WenshuMarkdownEditor`)
//  is a SwiftUI view, = so the mapping lives here: = a test can
//  measure it without a window, = and the editor reads it.
//
//  WHAT THE ENGINE TAKES
//
//  The engine's configuration carries the heading sizes as MULTIPLIERS
//  of its base font (= `headings.fontMultipliers`), = the heading FACE
//  beside it (= `headings.fontName`), = the line height as a multiple
//  of the body's own size (= `paragraph.lineHeightMultipleOfFontSize`),
//  = the paragraph gap as a fraction of that line height (=
//  `paragraph.spacingFactor`), = and the first line's indent in points
//  (= `paragraph.firstLineHeadIndent`). = So the sheet's own numbers are
//  turned into those: = the ladder's absolute sizes become multipliers
//  of the body's size, = the line spacing becomes the multiple, = the
//  segment spacing becomes the fraction, = and the first-line indent
//  becomes the points.
//
//  THE THREE KNOBS THE ENGINE COULD NOT TAKE (BEFORE THEY WERE OURS)
//
//  A heading face distinct from the body's, = a first-line indent on a
//  body paragraph, = and a line spacing as a MULTIPLE (the engine's own
//  line-height knob adds POINTS to the font's natural leading, = so it
//  cannot say "1.55 times the body size"). = The engine is vendored in
//  this repository now (= `Vendor/MarkdownEngine`), = so those three are
//  the engine's own knobs (= `HeadingStyle.fontName`, =
//  `ParagraphStyle.lineHeightMultipleOfFontSize` and =
//  `ParagraphStyle.firstLineHeadIndent`).
//

import Foundation
import MarkdownEngine

/// Turns a book's style sheet into the engine's own inputs.
enum EngineStyleSheetBridge {
    /// The engine's heading multipliers for a sheet.
    ///
    /// The ladder holds ABSOLUTE sizes (= the printed ones), = and the
    /// engine takes multipliers of its base font, = so each level is
    /// divided by the body's size. = A level past the ladder is the
    /// body's own size (= the engine has six levels, = so the last
    /// three are flat with the body).
    static func headingMultipliers(for sheet: BookStyleSheet) -> [CGFloat] {
        let base = sheet.bodySize.points
        guard base > 0 else { return [1, 1, 1, 1, 1, 1] }
        let sizes = sheet.headingSizes
        return (1 ... 6).map { level in
            guard level <= sizes.count else { return 1 }
            return CGFloat(sizes[level - 1] / base)
        }
    }

    /// The engine's base font NAME for a sheet (= the body's face).
    static func fontName(for sheet: BookStyleSheet) -> String {
        sheet.bodyFamily.postScriptName
    }

    /// The engine's HEADING FACE for a sheet.
    ///
    /// A printed book's headings wear a different face from its body
    /// (= Heiti over a Songti body), = and the engine takes that face
    /// beside the body's own (= `headings.fontName`).
    static func headingFontName(for sheet: BookStyleSheet) -> String {
        sheet.headingFamily.postScriptName
    }

    /// The engine's base font SIZE for a sheet (= the body's size).
    static func fontSize(for sheet: BookStyleSheet) -> CGFloat {
        CGFloat(sheet.bodySize.points)
    }

    /// The engine's paragraph style for a sheet.
    ///
    /// THE LINE SPACING = the engine's line height as a MULTIPLE OF THE
    /// BODY'S OWN SIZE (= the line spacing of 1.55 = = 1.55 x 13pt). = The engine's other
    /// line-height knob adds POINTS to the font's natural leading, = so it
    /// cannot express a multiple, = and it stays unused here.
    ///
    /// THE SEGMENT SPACING = the engine's paragraph gap, = which is a
    /// FRACTION OF THE LINE HEIGHT. = So the sheet's half-character gap
    /// is half a character over the line height (= 0.5 / 1.55), = and
    /// "none" is zero (= no gap at all).
    ///
    /// THE FIRST-LINE INDENT = the engine's first-line indent, = in
    /// points (= the sheet's characters over the body's own size).
    static func paragraphStyle(for sheet: BookStyleSheet) -> ParagraphStyle {
        var style = ParagraphStyle()
        let multiple = CGFloat(sheet.lineSpacing.multiple)
        style.lineHeightMultipleOfFontSize = multiple > 0 ? multiple : nil
        style.lineHeightExtraSpacing = 0
        style.spacingFactor = multiple > 0
            ? CGFloat(sheet.segmentSpacing.characters) / multiple
            : 0
        style.firstLineHeadIndent = CGFloat(
            sheet.firstLineIndent.characters * sheet.bodySize.points
        )
        return style
    }

    /// The engine's BLOCKQUOTE STYLE for a sheet.
    ///
    /// A print quote is a different face AND a different size from the
    /// body (= the sheet's quote wears Kai at the quote's own size), =
    /// and the engine takes that beside its base font.
    static func blockquoteStyle(for sheet: BookStyleSheet) -> BlockquoteStyle {
        var style = BlockquoteStyle()
        style.fontName = sheet.quoteFamily.postScriptName
        style.fontSize = CGFloat(sheet.quoteSize)
        return style
    }

    /// The sheet's FINGERPRINT: = what the editor's engine view is
    /// keyed by.
    ///
    /// The engine's `updateNSView` does NOT write back `headings`,
    /// `paragraph` or `theme` (= `NativeTextViewWrapper.swift:397+`),
    /// = so a new configuration does NOT reach a live editor. = So the
    /// engine view is keyed by the sheet's own values: = a sheet that
    /// changes REMOUNTS the engine (= a fresh base font, = fresh
    /// heading multipliers and face, = fresh paragraph spacing), = and a
    /// sheet that does not change leaves the editor alone (= no remount,
    /// = no lost caret, = no lost scroll).
    ///
    /// It is the sheet's VALUES (= not its identity), = so a book whose
    /// sheet is written back remounts the engine, = and a book whose
    /// sheet is unchanged does not.
    static func fingerprint(for sheet: BookStyleSheet) -> String {
        [
            sheet.bodyFamily.rawValue,
            sheet.bodySize.rawValue,
            sheet.lineSpacing.rawValue,
            sheet.segmentSpacing.rawValue,
            sheet.firstLineIndent.rawValue,
            sheet.headingLadder.rawValue,
            sheet.quoteFamily.rawValue,
            sheet.headingFamily.rawValue,
        ].joined(separator: "|")
    }
}
