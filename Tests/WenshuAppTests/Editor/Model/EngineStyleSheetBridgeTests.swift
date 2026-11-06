//
//  EngineStyleSheetBridgeTests.swift · Wenshu
//
//  The sheet's values, turned into what the engine takes.
//
//  The bridge is the seam between the book's own style sheet and the
//  Markdown engine's configuration, = so these cases measure that
//  seam directly: = a sheet that changes the sheet's own values
//  change what the engine is given, = and a sheet that does not
//  change them does not.
//
//  The mutations these hold against (= the ones that would break the
//  mapping) are named per case.
//

import MarkdownEngine
@testable import WenshuApp
import XCTest

final class EngineStyleSheetBridgeTests: XCTestCase {
    /// The heading multipliers ARE the ladder's absolute sizes, =
    /// divided by the body's size (= because the engine takes
    /// multipliers of its base font).
    ///
    /// MUTATION: = taking the ladder's sizes as they are (= not
    /// divided) = gives the engine a heading at 16 × the body.
    func testTheHeadingMultipliersAreTheLadderOverTheBodySize() {
        let sheet = BookStyleSheet.default
        let multipliers = EngineStyleSheetBridge.headingMultipliers(for: sheet)

        XCTAssertEqual(multipliers.count, 6, "the engine has six heading levels")
        // The print baseline: = body 13 PT, = the ladder 16 / 14 / 12.
        XCTAssertEqual(multipliers[0], 16.0 / 13.0, accuracy: 0.0001)
        XCTAssertEqual(multipliers[1], 14.0 / 13.0, accuracy: 0.0001)
        XCTAssertEqual(multipliers[2], 12.0 / 13.0, accuracy: 0.0001)
        // Levels past the ladder are flat with the body.
        XCTAssertEqual(multipliers[3], 1.0, accuracy: 0.0001)
        XCTAssertEqual(multipliers[4], 1.0, accuracy: 0.0001)
        XCTAssertEqual(multipliers[5], 1.0, accuracy: 0.0001)
    }

    /// A different body's size moves the base, = so the multipliers
    /// move with it (= the ladder's printed sizes do not).
    ///
    /// MUTATION: = dividing by a FIXED base (= not the sheet's own)
    /// = would give the wrong heading size for every other body size.
    func testTheMultipliersFollowTheSheetsOwnBodySize() {
        var sheet = BookStyleSheet.default
        sheet.bodySize = .large
        let multipliers = EngineStyleSheetBridge.headingMultipliers(for: sheet)

        // Body 14 PT: = the ladder 16 / 14 / 12.
        XCTAssertEqual(multipliers[0], 16.0 / 14.0, accuracy: 0.0001)
        XCTAssertEqual(multipliers[1], 1.0, accuracy: 0.0001, "14 over 14 is flat")
        XCTAssertEqual(multipliers[2], 12.0 / 14.0, accuracy: 0.0001)
    }

    /// The base font is the sheet's own face and size.
    ///
    /// MUTATION: = a hard-coded font (= "SF Pro") = would ignore the
    /// sheet's face entirely.
    func testTheBaseFontIsTheSheetsOwnFaceAndSize() {
        var sheet = BookStyleSheet.default
        sheet.bodyFamily = .kai
        sheet.bodySize = .small

        XCTAssertEqual(EngineStyleSheetBridge.fontName(for: sheet), "Kaiti SC")
        XCTAssertEqual(EngineStyleSheetBridge.fontSize(for: sheet), 12)
    }

    /// THE THREE SPACING KNOBS LAND ON THE ENGINE'S OWN KNOBS.
    ///
    /// - THE LINE SPACING = the engine's line height as a MULTIPLE OF
    ///   THE BODY'S SIZE (= 行距 1.70 = = 1.70 x 13pt).
    /// - THE SEGMENT SPACING = the engine's paragraph gap, = which is a
    ///   FRACTION OF THAT LINE HEIGHT (= half a character over 1.70).
    /// - THE EXTRA-POINTS KNOB = unused (= the multiple carries the line
    ///   height, = and the points knob would add to the font's own
    ///   leading on top of it).
    ///
    /// MUTATION: = putting the line spacing into the GAP (= the two were
    /// swapped) = would render a 1.70x gap between paragraphs and the
    /// font's natural leading between the lines.
    func testTheParagraphStyleCarriesTheSheetsOwnSpacing() {
        var sheet = BookStyleSheet.default
        sheet.lineSpacing = .loose
        sheet.segmentSpacing = .halfCharacter
        let style = EngineStyleSheetBridge.paragraphStyle(for: sheet)

        XCTAssertEqual(style.lineHeightMultipleOfFontSize ?? 0, 1.70, accuracy: 0.0001)
        // Half a character, = over the line height.
        XCTAssertEqual(style.spacingFactor, 0.5 / 1.70, accuracy: 0.0001)
        XCTAssertEqual(style.lineHeightExtraSpacing, 0, accuracy: 0.0001)
    }

    /// A sheet with no segment spacing has NO gap (= the engine's own
    /// paragraph gap is the only gap).
    func testNoSegmentSpacingAddsNoHeight() {
        var sheet = BookStyleSheet.default
        sheet.segmentSpacing = .none
        let style = EngineStyleSheetBridge.paragraphStyle(for: sheet)

        XCTAssertEqual(style.spacingFactor, 0, accuracy: 0.0001)
    }

    /// THE FIRST-LINE INDENT REACHES THE ENGINE.
    ///
    /// MUTATION: = leaving it out of the paragraph style (= the engine's
    /// knob exists now) = would store the indent and never draw it.
    func testTheFirstLineIndentReachesTheEngine() {
        var sheet = BookStyleSheet.default
        sheet.bodySize = .medium
        let style = EngineStyleSheetBridge.paragraphStyle(for: sheet)

        // Two characters, = and a character is the body's size.
        XCTAssertEqual(style.firstLineHeadIndent, 2 * 13, accuracy: 0.0001)

        var plain = sheet
        plain.firstLineIndent = .none
        XCTAssertEqual(EngineStyleSheetBridge.paragraphStyle(for: plain).firstLineHeadIndent, 0, accuracy: 0.0001)
    }

    /// THE HEADING FACE REACHES THE ENGINE, = and it is the face that
    /// follows the body (= a printed book's headings wear their own).
    ///
    /// MUTATION: = handing the BODY's face to the headings (= the engine's
    /// default) = would draw the headings in the body's face.
    func testTheHeadingFaceReachesTheEngine() {
        var sheet = BookStyleSheet.default
        sheet.bodyFamily = .songti
        XCTAssertEqual(EngineStyleSheetBridge.fontName(for: sheet), "Songti SC")
        XCTAssertEqual(EngineStyleSheetBridge.headingFontName(for: sheet), "Heiti SC")

        sheet.bodyFamily = .kai
        XCTAssertEqual(EngineStyleSheetBridge.headingFontName(for: sheet), "Kaiti SC")
    }

    /// The sheet is the model's own truth, = and a knob moves it to a
    /// POSITION (= its enum's name), = so a position this build does
    /// not know leaves the sheet alone.
    ///
    /// MUTATION: = writing a free value (= a number) = would break the
    /// sheet's own invariant (= the sheet holds positions).
    func testAKnobMovesToAPositionAndAnUnknownOneChangesNothing() {
        var sheet = BookStyleSheet.default
        sheet = sheet.setting(.bodySize, to: BookBodySize.large.rawValue)
        XCTAssertEqual(sheet.bodySize, .large)

        sheet = sheet.setting(.lineSpacing, to: BookLineSpacing.tight.rawValue)
        XCTAssertEqual(sheet.lineSpacing, .tight)

        sheet = sheet.setting(.firstLineIndent, to: BookFirstLineIndent.none.rawValue)
        XCTAssertEqual(sheet.firstLineIndent, .none)

        sheet = sheet.setting(.segmentSpacing, to: BookSegmentSpacing.halfCharacter.rawValue)
        XCTAssertEqual(sheet.segmentSpacing, .halfCharacter)

        sheet = sheet.setting(.bodyFamily, to: BookBodyFamily.heiti.rawValue)
        XCTAssertEqual(sheet.bodyFamily, .heiti)

        // A position the sheet cannot read back changes nothing.
        let unchanged = sheet.setting(.bodySize, to: "enormous")
        XCTAssertEqual(unchanged, sheet)
    }

    /// The knob's NAME is the sheet's own field name, = so a knob id
    /// and the property are the same string (= no second mapping).
    func testEveryKnobIsTheSheetOwnFieldName() {
        XCTAssertEqual(BookStyleKnob.allCases.count, 5)
        XCTAssertEqual(Set(BookStyleKnob.allCases.map(\.rawValue)), [
            "bodySize", "lineSpacing", "firstLineIndent", "segmentSpacing", "bodyFamily",
        ])
    }

    /// THE FINGERPRINT IS THE SHEET'S VALUES THE ENGINE HONORS: = a
    /// sheet that changes them changes the fingerprint (= and so the
    /// engine remounts), = and a sheet that does not change leaves it
    /// alone (= and so the editor does not remount, = and keeps its
    /// caret and its scroll).
    ///
    /// MUTATION: = a fingerprint that ignores a value (= the body
    /// size, = say) = would leave the engine rendering the old size
    /// after the knob moved.
    ///
    /// EVERY KNOB MOVES IT: = the engine honors all five now (= the
    /// first-line indent included, = because the engine's own knob for
    /// it is ours), = and a remount for a value the engine cannot apply
    /// would throw away the caret for nothing.
    func testTheFingerprintFollowsTheSheetsValues() {
        var sheet = BookStyleSheet.default
        let base = EngineStyleSheetBridge.fingerprint(for: sheet)

        // A sheet that does not change has the same fingerprint.
        XCTAssertEqual(EngineStyleSheetBridge.fingerprint(for: sheet), base)

        // Every knob moves the fingerprint.
        for knob in BookStyleKnob.allCases {
            var moved = sheet
            switch knob {
            case .bodySize: moved.bodySize = .large
            case .lineSpacing: moved.lineSpacing = .loose
            case .firstLineIndent: moved.firstLineIndent = .none
            case .segmentSpacing: moved.segmentSpacing = .halfCharacter
            case .bodyFamily: moved.bodyFamily = .kai
            }
            XCTAssertNotEqual(
                EngineStyleSheetBridge.fingerprint(for: moved),
                base,
                "the \(knob.rawValue) knob must move the fingerprint (= the engine remounts)"
            )
        }

        // The first-line indent DOES move it: = the engine applies it.
        var indented = sheet
        indented.firstLineIndent = .none
        XCTAssertNotEqual(
            EngineStyleSheetBridge.fingerprint(for: indented),
            base,
            "the engine applies the first-line indent, = so it must remount for it"
        )
    }
}
