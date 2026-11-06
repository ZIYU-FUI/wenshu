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
//  The engine's configuration carries the heading sizes as
//  MULTIPLIERS of its base font (= `headings.fontMultipliers`), = its
//  paragraph spacing as a factor (= `paragraph.spacingFactor`) and
//  an extra height (= `paragraph.lineHeightExtraSpacing`), = and its
//  base font as a NAME and a SIZE (= `NativeTextViewWrapper`'s
//  `fontName:` and `fontSize:`). = So the sheet's own numbers are
//  turned into those: = the ladder's absolute sizes become
//  multipliers of the body's size, = and the sheet's line spacing
//  becomes the factor.
//
//  WHAT THE ENGINE CANNOT TAKE YET
//
//  Two of the sheet's values have no engine knob: = a heading face
//  DISTINCT from the body's (= the engine has one base font, = and a
//  heading is the base font at a multiplier), = and a first-line
//  indent (= the engine sets a first-line indent for code blocks,
//  lists and quotes, = and not for a body paragraph). = Those two
//  stay in the sheet (= the sheet is the book's own truth) = and
//  wait for the upstream package to carry them.
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

    /// The engine's base font SIZE for a sheet (= the body's size).
    static func fontSize(for sheet: BookStyleSheet) -> CGFloat {
        CGFloat(sheet.bodySize.points)
    }

    /// The engine's paragraph style for a sheet.
    ///
    /// The line spacing becomes the spacing FACTOR (= the engine adds
    /// it to its own line height), = and the segment spacing becomes
    /// the extra height between paragraphs (= the engine's own
    /// paragraph gap is a fraction of the line height, = so the
    /// sheet's half-character segment spacing is added as points:
    /// = half a CHARACTER, = and a character is the body's size).
    static func paragraphStyle(for sheet: BookStyleSheet) -> ParagraphStyle {
        var style = ParagraphStyle()
        style.spacingFactor = CGFloat(sheet.lineSpacing.multiple)
        style.lineHeightExtraSpacing = CGFloat(
            sheet.segmentSpacing.characters * sheet.bodySize.points
        )
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
    /// heading multipliers, = fresh paragraph spacing), = and a sheet
    /// that does not change leaves the editor alone (= no remount, = no
    /// lost caret, = no lost scroll).
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
            sheet.headingLadder.rawValue,
            sheet.quoteFamily.rawValue,
        ].joined(separator: "|")
    }
}
