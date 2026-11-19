//
//  InspectorStylePageView.swift
//  wenshu
//
//  The trailing inspector column's style page: = the book's own style
//  sheet, = as one choice, = five knobs, = and one table.
//
//  WHAT THIS PAGE IS
//
//  The format page stopped being a wall of commands and became the
//  BOOK's style sheet:
//
//    - THIS BOOK'S STYLES: the eleven roles a novel uses (= the body,
//      = the quote, = the note, = the three heading levels, = the two
//      captions, = the image, = the rule, = and the monospace code), =
//      each row naming its role and showing the face, = the size and =
//      the leading the book's sheet gives it.
//
//      THE BOOK'S OWN NAME IS NOT ONE OF THEM. = The book's title is
//      the book's own (= it is drawn on the cover, = and it is not a
//      kind of text the body is made of), = so it has no row here.
//    - FINE TUNING: the five knobs a book is set with (= the body
//      size, = the line spacing, = the first-line indent, = the space
//      between segments, = and the body's face), = each at one of its
//      fixed positions.
//
//  WHAT THE PAGE READS
//
//  The book is the one the sidebar has selected, and the sheet is that
//  book's own (= `Book.effectiveStyleSheet`), = so the page shows what
//  the book IS, = not what it would be.
//
//  A DIFFERENT BOOK IS CHOSEN
//
//  The selection is followed the way the repo follows it elsewhere
//  (= `ChatZoneView`: = an `onChange` -> the new book -> the book is
//  read again), = so the page follows the selection.
//
//  THE KNOBS WRITE THE SHEET BACK
//
//  Each drop-down offers the positions its knob can take, = and
//  choosing one writes that POSITION onto the book's own sheet (= the
//  raw value, = which is the name the sheet reads back) = and saves the
//  book (= `BookStyleSheetWriteBack`). = So the page is the book's own
//  sheet, = editable in place.
//
//  EVERY CHOICE ON THIS PAGE IS THE SYSTEM'S OWN CONTROL
//
//  A knob is a pop-up button and the two sets are one segmented control,
//  = both drawn by the system (= `Picker` with `.menu`, = and
//  `.segmented`). = The HIG names both for exactly this place: = a pop-up
//  button is for "a flat list of mutually exclusive options or states"
//  = and "can update its content to indicate the current selection" (=
//  pop-up-buttons, = alert-date 2023-10-24, = macOS), = and a segmented
//  control belongs in "a toolbar or inspector pane" (= segmented-controls,
//  = alert-date 2023-06-21, = macOS).
//
//  THE PAGE DREW ITS OWN CONTROLS UNTIL IT WAS CORRECTED. = A knob was a
//  block of the page's own drawing, = with the position inside it, = and a
//  borderless `Menu` laid over that block with the menu's own title painted
//  out (= `.foregroundStyle(.clear)`) = so the block could be the only
//  painter. = The two sets were two rows carrying a hand-drawn tick. = Both
//  were facsimiles: = one string needed a hack to silence the control that
//  was born to draw it, = and every measurement in the block (= its radius,
//  = its fill, = its height) = was this app's guess at what the system
//  already ships. = What the system ships follows the OS release, = the
//  accent colour, = and the reader's text size; = what was drawn here
//  followed none of them.
//
//  WHAT THE CONTROLS PUBLISH
//
//  Measured in the app's own process: = a pop-up button publishes its role
//  and its current selection, = a `Text` on its own publishes NOTHING, = and
//  a `TextField` publishes an `AXTextField`. = So the page's state is read
//  out of the controls (= `InspectorAXTree`), = which is also how the tests
//  prove the page shows the SELECTED book's sheet.
//
//  WHY "FINE-TUNED OFF BOTH SETS" NEEDS NO THIRD CONTROL
//
//  The set the book is at is the sheet's own optional (=
//  `BookStylePreset.matching`), = and a segmented `Picker` whose selection
//  matches no segment lights none (= measured: = AppKit reports its selected
//  segment as -1). = So the state is the control's own, = not a name the
//  page has to invent.
//  = (see OOB.md #2026-11-19: = the native control, = unless a business rule
//  = the control cannot express argues otherwise.)
//

import OSLog
import SwiftUI

private let wenshuLogger = Logger(subsystem: "com.wenshu", category: "inspectorstylepage")

// MARK: - The page

/// The trailing inspector column's style page (= the book's own style
/// sheet, = as two lists).
struct InspectorStylePageView: View {
    /// The library's books (= the sheet the page reads).
    @Environment(BookStore.self) private var bookStore

    /// The book the page shows (= the store's selected book).
    ///
    /// The store's selected book is the app's one record of WHICH BOOK
    /// IS THE ACTIVE ONE, = and it is written by the sidebar's
    /// selection (= `AppleSidebarSelection.forwardSelection`). = The
    /// EDITOR reads the same field (= `WenshuMarkdownEditor`), = so the
    /// page and the editor always name ONE book, = and a knob moved on
    /// the page is the sheet the editor renders.
    ///
    /// The book follows as it changes.
    @State private var currentBookID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingLoose) {
            //  The order is the order of a reader's questions: = which
            //  set is this book in, = what is fine-tuned off it, = and
            //  only then what every role of the sheet actually looks
            //  like (= the table is the LONGest group, = and it is the
            //  one a reader scrolls to rather than starts at).
            presetsGroup
            tuningGroup
            stylesGroup
        }
        .onChange(of: bookStore.selectedBookId, initial: true) { _, bookID in
            currentBookID = bookID
        }
    }

    /// The two sets (= the print baseline and the general one).
    ///
    /// The set is a WHOLE SHEET, = so choosing one writes the whole
    /// sheet down (= the same write-back the knobs use, = measured
    /// through the same seam).
    private var presetsGroup: some View {
        InspectorFormatGroup(
            title: String(localized: "inspector.style.group.presets"),
            showsDivider: false
        ) {
            InspectorStylePresetPicker(
                choices: model.choices,
                current: model.currentSelection
            ) { chosen in
                applySelection(chosen)
            }
        }
    }

    /// Take the book to one of the three places, = and persist it.
    private func applySelection(_ selection: BookStyleSelection) {
        guard let bookID = currentBookID else { return }
        do {
            try BookStyleSheetWriteBack.apply(
                selection: selection,
                to: bookID,
                store: bookStore
            )
        } catch {
            wenshuLogger.error("[style-sheet] the preset write-back failed: \(error)")
        }
    }

    /// The style table (= the eleven roles the book is set in, = each
    /// row showing that role's own voice = `InspectorStyleRowView`).
    private var stylesGroup: some View {
        InspectorFormatGroup(title: String(localized: "inspector.style.group.styles")) {
            VStack(alignment: .leading, spacing: DesignTokens.spacingTight) {
                //  Eleven rows of a table, = and a table of rows needs a line
                //  BETWEEN its rows (= not above and below each one): = the
                //  first row is separated from what it is not, = and so the
                //  rule is drawn before every row but the first.
                ForEach(Array(model.rows.enumerated()), id: \.element.id) { index, row in
                    if index > 0 {
                        InspectorStyleRule()
                    }
                    InspectorStyleRowView(row: row)
                }
            }
        }
    }

    /// The fine tuning (= the five knobs the book is set with).
    private var tuningGroup: some View {
        InspectorFormatGroup(title: String(localized: "inspector.style.group.tuning")) {
            VStack(alignment: .leading, spacing: DesignTokens.spacingTight) {
                ForEach(model.knobs) { knob in
                    InspectorStyleKnobView(knob: knob, columnWidth: knobColumnWidth) { position in
                        moveKnob(knob.id, to: position)
                    }
                }
            }
        }
    }

    /// Move one knob of the book to a position, and persist the book.
    ///
    /// The write-back is the LIBRARY's own operation (= the page calls
    /// the same one the tests measure), = so the knob moves on the
    /// book's sheet (= `Book.styleSheet`), = and the book is saved
    /// through the app's own save path for an existing book (= its
    /// `book.json`). = So the editor renders the new sheet (= the
    /// editor keys the engine by the sheet's values), = and the book
    /// keeps it (= the sheet is the book's own truth).
    private func moveKnob(_ knobID: String, to position: String) {
        guard let knob = BookStyleKnob(rawValue: knobID),
              let bookID = currentBookID
        else { return }
        // The write-back THROWS when the save fails (= a book that did
        // not reach the disk did not change), = and the page has no
        // error surface of its own, = so the failure is logged.
        do {
            try BookStyleSheetWriteBack.apply(
                knob: knob,
                position: position,
                to: bookID,
                store: bookStore
            )
        } catch {
            wenshuLogger.error("[style-sheet] the knob write-back failed: \(error)")
        }
    }

    /// The width one knob's pop-up is pinned to (= the widest of the five).
    ///
    /// MEASURED, = not guessed: = the system's own button is asked how wide
    /// it must be for every position any of the five knobs offers, = so the
    /// number carries the bezel, = the chevrons and = the reader's font,
    /// = and none of them is written down here.
    private var knobColumnWidth: CGFloat {
        model.knobs
            .map { ValuePopUpButton<String>.fittingWidth(forTitles: $0.positions.map(\.label)) }
            .max() ?? 0
    }

    /// What the page shows (= the selected book's own sheet).
    private var model: InspectorStylePageModel {
        InspectorStylePageModel(sheet: sheet)
    }

    /// The selected book's sheet.
    ///
    /// A book with no sheet reads the print baseline (= the model's own
    /// `effectiveStyleSheet`), = so the page never invents a sheet of
    /// its own.
    private var sheet: BookStyleSheet {
        guard let currentBookID,
              let book = bookStore.books.first(where: { $0.id == currentBookID })
        else { return .default }
        return book.effectiveStyleSheet
    }
}

// MARK: - The model

/// What the style page shows: = the book's eleven style roles, = and
/// the five knobs it is fine-tuned with.
struct InspectorStylePageModel: Equatable, Sendable {
    /// The style table's rows (= one per role).
    let rows: [InspectorStyleRow]

    /// The fine tuning's knobs.
    let knobs: [InspectorStyleKnob]

    /// The places the sheet can be set to (= Print, = General, = Custom).
    let choices: [BookStyleSelection]

    /// Where the book is (= the set its sheet names, = or its own tuning
    /// when it names none).
    let currentSelection: BookStyleSelection

    init(sheet: BookStyleSheet) {
        rows = InspectorStylePageModel.styleRows(for: sheet)
        knobs = InspectorStylePageModel.fineTuningKnobs(for: sheet)
        choices = BookStyleSelection.choices
        currentSelection = BookStyleSelection.select(sheet: sheet)
    }

    /// The eleven roles, as the sheet sets them.
    ///
    /// A role the sheet names nothing for shows a dash (= the print
    /// standard's own table writes a dash for the image and the rule),
    /// = because a value the sheet cannot name is a value the page must
    /// not invent.
    ///
    /// WHY A ROLE WITHOUT WORDS STILL GETS A VOICE
    ///
    /// The face, = the size and = the leading are what the SHEET says
    /// about a role; = the preview is what the ENGINE does with it. =
    /// They are not the same list (= a code block has no face in the
    /// sheet at all, = and a heading is not set on the book's multiple),
    /// = so a row whose preview was built from its own cells would show
    /// the sheet's words about a page the reader would never get.
    private static func styleRows(for sheet: BookStyleSheet) -> [InspectorStyleRow] {
        let heading = headingFamily(of: sheet)
        let leading = sheet.lineSpacing.multiple

        func row(
            _ role: InspectorStyleRole,
            _ family: BookBodyFamily?,
            _ size: Double?,
            _ spacing: Double? = nil
        ) -> InspectorStyleRow {
            InspectorStyleRow(
                role: role,
                family: family,
                size: size,
                spacing: spacing,
                preview: InspectorStylePreview.resolve(role: role, sheet: sheet)
            )
        }

        return [
            row(.body, sheet.bodyFamily, sheet.bodySize.points, leading),
            row(.quote, sheet.quoteFamily, sheet.quoteSize, leading),
            row(.note, sheet.bodyFamily, sheet.noteSize, leading),
            row(.headingOne, heading, sheet.headingSize(forLevel: 1), leading),
            row(.headingTwo, heading, sheet.headingSize(forLevel: 2), leading),
            row(.headingThree, heading, sheet.headingSize(forLevel: 3), leading),
            row(.figureCaption, sheet.bodyFamily, sheet.figureCaptionSize, leading),
            row(.tableCaption, sheet.bodyFamily, sheet.tableCaptionSize, leading),
            row(.image, nil, nil),
            row(.rule, nil, nil),
            row(.monospace, nil, nil, leading),
        ]
    }

    /// The face the book's headings are set in.
    ///
    /// The sheet names the body's face, and a book's headings follow
    /// it (= the sheet's own heading face), = so the face is read back
    /// out of the sheet rather than guessed at.
    private static func headingFamily(of sheet: BookStyleSheet) -> BookBodyFamily {
        BookBodyFamily.allCases.first { $0 == sheet.headingFamily }
            ?? sheet.bodyFamily
    }

    /// The five knobs, as the sheet holds them.
    private static func fineTuningKnobs(for sheet: BookStyleSheet) -> [InspectorStyleKnob] {
        [
            knob(
                id: "bodySize",
                nameKey: "inspector.style.knob.bodySize",
                positionKey: "inspector.style.bodySize",
                positions: BookBodySize.allCases.map(\.rawValue),
                current: sheet.bodySize.rawValue
            ),
            knob(
                id: "lineSpacing",
                nameKey: "inspector.style.knob.lineSpacing",
                positionKey: "inspector.style.lineSpacing",
                positions: BookLineSpacing.allCases.map(\.rawValue),
                current: sheet.lineSpacing.rawValue
            ),
            knob(
                id: "firstLineIndent",
                nameKey: "inspector.style.knob.firstLineIndent",
                positionKey: "inspector.style.firstLineIndent",
                positions: BookFirstLineIndent.allCases.map(\.rawValue),
                current: sheet.firstLineIndent.rawValue
            ),
            knob(
                id: "segmentSpacing",
                nameKey: "inspector.style.knob.segmentSpacing",
                positionKey: "inspector.style.segmentSpacing",
                positions: BookSegmentSpacing.allCases.map(\.rawValue),
                current: sheet.segmentSpacing.rawValue
            ),
            knob(
                id: "bodyFamily",
                nameKey: "inspector.style.knob.bodyFamily",
                positionKey: "inspector.style.family",
                positions: BookBodyFamily.allCases.map(\.rawValue),
                current: sheet.bodyFamily.rawValue
            ),
        ]
    }

    /// One knob, with its positions named.
    ///
    /// Each position carries its RAW value (= the sheet's own enum's
    /// name, = what the write-back reads) = and its label (= what the
    /// reader sees). = The raw value is never localized, = because the
    /// sheet reads a position by that name.
    private static func knob(
        id: String,
        nameKey: String,
        positionKey: String,
        positions: [String],
        current: String
    ) -> InspectorStyleKnob {
        let made = positions.map { rawValue in
            InspectorStylePosition(
                rawValue: rawValue,
                label: NSLocalizedString(
                    "\(positionKey).\(rawValue)",
                    comment: "One position a fine-tuning knob of a book's style sheet can take"
                )
            )
        }
        let currentPosition = made.first { $0.rawValue == current }
            ?? InspectorStylePosition(
                rawValue: current,
                label: NSLocalizedString(
                    "\(positionKey).\(current)",
                    comment: "The position a fine-tuning knob of a book's style sheet sits at"
                )
            )
        return InspectorStyleKnob(
            id: id,
            name: NSLocalizedString(
                nameKey,
                comment: "The name of one fine-tuning knob of a book's style sheet"
            ),
            positions: made,
            current: currentPosition
        )
    }
}

// MARK: - The role

/// The eleven style roles a novel uses.
///
/// The roles are the book's own (= the kinds of text a book is made
/// of), = and the sheet sets what each of them looks like.
enum InspectorStyleRole: String, CaseIterable, Sendable {
    case body
    case quote
    case note
    case headingOne
    case headingTwo
    case headingThree
    case figureCaption
    case tableCaption
    case image
    case rule
    case monospace

    /// The role's name in the reader's language.
    var localizedName: String {
        NSLocalizedString(
            "inspector.style.role.\(rawValue)",
            comment: "The name of one style role in the book's style table"
        )
    }
}

// MARK: - The knob

/// One fine-tuning knob: = the positions it can take, = and the one
/// the book sits at.
struct InspectorStyleKnob: Identifiable, Equatable, Sendable {
    /// The knob's own name (= the key it is known by).
    let id: String

    /// The knob's name in the reader's language.
    let name: String

    /// The positions the knob can take (= in order).
    let positions: [InspectorStylePosition]

    /// The position the book sits at.
    let current: InspectorStylePosition
}

/// One position of a knob: = its RAW value (= the sheet's own enum's
/// name, = the thing the sheet can read back) = and its name in the
/// reader's language.
///
/// WHY BOTH, AND WHY THE RAW VALUE IS THE ONE THE ACTION CARRIES
///
/// The sheet reads a POSITION by its raw value (= `BookBodySize
/// (rawValue:)`), = so the action must carry the raw value. = A
/// display name cannot be read back (= "Large" is not a position), =
/// so a knob that carried only the display name could never move the
/// sheet. = So the position carries BOTH: = the raw value goes to the
/// sheet, = and the label is what the reader sees.
struct InspectorStylePosition: Identifiable, Equatable, Sendable {
    /// The position's raw value (= the sheet's own enum's name).
    let rawValue: String

    /// The position's name in the reader's language.
    let label: String

    var id: String {
        rawValue
    }
}
