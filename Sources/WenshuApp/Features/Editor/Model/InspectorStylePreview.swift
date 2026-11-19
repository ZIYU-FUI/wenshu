//
//  InspectorStylePreview.swift · Wenshu
//
//  What one role of the book's style sheet LOOKS like, = in the
//  engine's own numbers: = the face it resolves for that role, = the
//  size it sets it at, = and the line height it gives it.
//
//  WHY A SAMPLE LINE AND NOT A NUMBER
//
//  The style table used to state each role in words: = the face's name, =
//  the size, = and the book's multiple, = three numbers that show none
//  of them: = a face cannot be seen in
//  the word for it, = 13 pt cannot be told from 14 pt by reading, =
//  and a leading is invisible in a multiple (= it only exists as the
//  gap between two lines). = So the row shows the role's own voice, =
//  set the way the book sets it, = and keeps its numbers for the
//  pointer (= the row's help, = and see OOB.md #2026-11-19).
//
//  WHY IT READS THE MAPPED SHEET, = AND NOT THE SHEET
//
//  The engine is not given the sheet: = it is given the mapped sheet
//  (= `EngineStyleSheetBridge`), = and it does not treat every role
//  the same way. = A heading does not take the book's multiple, = a
//  note keeps the book's leading PER POINT at its own smaller size, =
//  a quote adds its own extra, = and a code block takes a face the
//  sheet does not name at all. = So a preview that read the sheet's
//  one multiple for all eleven roles would draw eleven rows of a
//  leading the book never sets, = which is a worse lie than a number.
//  = These are the engine's own rules, = read off the same mapped
//  values the editor is configured from.
//
//  THE RULES THIS MIRRORS (= cited where they are set, = pinned by
//  `StylePreviewSpec` in the tests)
//
//    the body's height    MarkdownASTStyler.swift:42-44     the size ×
//                         the multiple, = rounded UP to whole points
//    a heading            MarkdownASTStyler.swift:676-680   the heading
//                         face at the ladder's size, = bold, = the
//                         height its own face gives, = rounded up, + 1
//    a quote              MarkdownASTStyler.swift:913-917   the body's
//                         height at the quote's size, + the quote's extra
//    a note, a caption    MarkdownASTStyler.swift:736-739   the body's
//                         height at the role's own size
//    a code block         MarkdownASTStyler.swift:49-51     the
//                         highlighter's face at the code block's scale
//
//  WHY THE FACE CARRIES A POSTSCRIPT NAME, = AND NOT A FAMILY NAME
//
//  "Heiti SC" is one family and two faces: = at 16 pt the name above
//  the body resolves to STHeitiSC-Light, = and the engine's bold is a
//  DIFFERENT face (= STHeitiSC-Medium), = not a weight it borrows. =
//  Measured in this app's own process. = So the preview hands over
//  the name of the face the engine actually draws (= `NSFont.fontName`),
//  = and SwiftUI reaches that same face by that same name, = and no
//  `.bold()` is added on top of it (= which would double it).
//
//  WHY NO PIXEL TEST CAN GUARD THIS
//
//  What a row is set at is a NUMBER, = and a screenshot cannot tell
//  16 pt from 16.4 pt, = nor a leading of 21 from one of 20. = So the
//  proof is the arithmetic against the cited rule, = and the drawing
//  test only proves a row paints at all.
//

import AppKit
import Foundation
import MarkdownEngine

/// One role's voice: = the face, = the size, = the line height.
struct InspectorStylePreview: Equatable, Sendable {
    /// The POSTSCRIPT name of the face the engine resolves for the
    /// role (= the name a font is asked by).
    let faceName: String

    /// The size the role is set at, = in points.
    let size: Double

    /// The line height the engine gives the role, = in points.
    let lineHeight: Double

    /// What must be ADDED to the face's own height to reach that line
    /// height.
    ///
    /// WHY AN EXTRA AND NOT A TARGET
    ///
    /// SwiftUI's `lineSpacing` adds to the height a face already has
    /// (= it cannot pull two lines closer than the face allows), = so
    /// what a sample line needs is the engine's height minus the
    /// face's own. = Measured in this app's own process: = Songti SC at 13 pt
    /// with this extra puts its lines 21.0 pt apart, = which is the
    /// engine's number to the point, = and the face alone puts them
    /// 18.2 pt apart.
    let extraLeading: Double

    /// The role's voice, = or nil when the role carries no type of its
    /// own (= the image and the rule: = they are not words, = so they
    /// have no voice to show).
    static func resolve(role: InspectorStyleRole, sheet: BookStyleSheet) -> InspectorStylePreview? {
        let body = font(named: EngineStyleSheetBridge.fontName(for: sheet),
                        at: EngineStyleSheetBridge.fontSize(for: sheet))
        let bodyLineHeight = baseLineHeight(of: body, sheet: sheet)

        switch role {
        case .image, .rule:
            return nil

        case .body:
            return voice(of: body, lineHeight: bodyLineHeight)

        case .headingOne, .headingTwo, .headingThree:
            let ladder = EngineStyleSheetBridge.headingMultipliers(for: sheet)
            let step = ladder.indices.contains(level(of: role)) ? ladder[level(of: role)] : 1
            //  The engine asks for the heading face at the ladder's size
            //  and then unions the bold trait onto it (= the trait union
            //  is how `MarkdownASTStyler.bolded` is built, = :1202-1205),
            //  = which is what lands a Heiti title on its Medium face.
            let heading = bolded(font(named: EngineStyleSheetBridge.headingFontName(for: sheet),
                                      at: body.pointSize * step))
            return voice(of: heading, lineHeight: ceil(naturalHeight(of: heading)) + 1)

        case .quote:
            let style = EngineStyleSheetBridge.blockquoteStyle(for: sheet)
            let quote = font(named: style.fontName ?? body.fontName,
                             at: style.fontSize ?? body.pointSize)
            return voice(of: quote,
                         lineHeight: atOwnSize(bodyLineHeight, body: body, face: quote)
                             + style.extraLineHeight)

        case .note:
            let style = EngineStyleSheetBridge.footnoteStyle(for: sheet)
            let note = font(named: style.fontName ?? body.fontName,
                            at: style.fontSize ?? body.pointSize)
            return voice(of: note, lineHeight: atOwnSize(bodyLineHeight, body: body, face: note))

        case .figureCaption, .tableCaption:
            //  A caption is set in the BODY's face (= the styler's
            //  `styleCaption` passes `ctx.fontName`, = :809-812) = at the
            //  caption's own size, = and takes its own height, = not the
            //  book's.
            let captions = EngineStyleSheetBridge.captionStyle(for: sheet)
            let size = (role == .figureCaption ? captions.figureFontSize : captions.tableFontSize)
                ?? body.pointSize
            let caption = font(named: body.fontName, at: size)
            return voice(of: caption, lineHeight: atOwnSize(bodyLineHeight, body: body, face: caption))

        case .monospace:
            //  The code face is the highlighter's own list, = tried in
            //  order, = falling back to the system monospace
            //  (= HighlighterSwiftBridge.swift:63 for the names, = :123-130
            //  for the route, = and MarkdownASTStyler.swift:49 for the
            //  size). = And the size is the code block's own scale, = not
            //  a number this file invents (= :314).
            let size = round(body.pointSize * CodeBlockStyle.default.fontSizeScale)
            let code = monospaced(at: size)
            return voice(of: code, lineHeight: ceil(naturalHeight(of: code)))
        }
    }

    /// The faces the code blocks are set in, = in the order the
    /// highlighter tries them (= the same list, = and the same
    /// fallback, = as `HighlighterSwiftBridge.codeFont`).
    ///
    /// WHY THE LIST IS MIRRORED, = AND THE BRIDGE NOT ASKED
    ///
    /// The bridge cannot be constructed to be ASKED a font: = its init
    /// reads the running application's appearance (= :113, = through
    /// `NSApp`), = and a style table that is being measured, = previewed
    /// or drawn before any window exists has no application to read. =
    /// A page that crashes the process to show a face is not a page. =
    /// The list is therefore copied (= two names, = one fallback), = and
    /// the test that holds it reads the bridge's own source, = so the
    /// day the engine's list moves, = this one is caught out.
    static let codeFaceNames = ["SF Mono", "Menlo"]

    private static func monospaced(at size: CGFloat) -> NSFont {
        for name in codeFaceNames {
            if let font = NSFont(name: name, size: size) {
                return font
            }
        }
        return .monospacedSystemFont(ofSize: size, weight: .regular)
    }

    // MARK: - The engine's arithmetic

    /// The base line height (= MarkdownASTStyler.swift:42-44): = the
    /// body's size times the sheet's multiple, = rounded UP to whole
    /// points, = or the face's own height when the sheet names no
    /// multiple.
    private static func baseLineHeight(of body: NSFont, sheet: BookStyleSheet) -> CGFloat {
        let multiple = CGFloat(sheet.lineSpacing.multiple)
        guard multiple > 0 else { return naturalHeight(of: body) }
        return ceil(body.pointSize * multiple)
    }

    /// The body's line height read at another role's size (= the
    /// styler's `ownSizeParagraphStyle`, = :736-739): = a role set
    /// smaller than the body keeps the same leading PER POINT, = so a
    /// note does not run on the body's 21-point grid.
    private static func atOwnSize(_ bodyLineHeight: CGFloat, body: NSFont, face: NSFont) -> CGFloat {
        guard body.pointSize > 0 else { return bodyLineHeight }
        return bodyLineHeight * (face.pointSize / body.pointSize)
    }

    /// The height a face gives a line on its own (= the engine's own
    /// formula, = :593, = :680, = :739).
    private static func naturalHeight(of font: NSFont) -> CGFloat {
        font.ascender - font.descender + font.leading
    }

    /// The bold face the engine asks for (= `withSymbolicTraits(union
    /// [.bold])`, = :1203-1204).
    private static func bolded(_ font: NSFont) -> NSFont {
        let merged = font.fontDescriptor.symbolicTraits.union(.bold)
        return NSFont(descriptor: font.fontDescriptor.withSymbolicTraits(merged),
                      size: font.pointSize) ?? font
    }

    /// A face by the name the sheet gives it (= the sheet spells four
    /// of them as a family, = and `NSFont(name:)` answers to both
    /// spellings; = what comes back is the face the engine draws).
    private static func font(named name: String, at size: CGFloat) -> NSFont {
        NSFont(name: name, size: size) ?? .systemFont(ofSize: size)
    }

    /// The heading's rung in the ladder (= level 1 is the first step).
    private static func level(of role: InspectorStyleRole) -> Int {
        switch role {
        case .headingOne: 0
        case .headingTwo: 1
        default: 2
        }
    }

    /// The row's voice, = from the face the engine draws and the height
    /// it gives it.
    private static func voice(of font: NSFont, lineHeight: CGFloat) -> InspectorStylePreview {
        InspectorStylePreview(
            faceName: font.fontName,
            size: Double(font.pointSize),
            lineHeight: Double(lineHeight),
            extraLeading: Double(max(0, lineHeight - naturalHeight(of: font)))
        )
    }
}
