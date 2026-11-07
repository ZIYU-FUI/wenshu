//
//  InspectorStylePageView.swift
//  wenshu
//
//  The trailing inspector column's style page: = the book's own style
//  sheet, = as two lists.
//
//  WHAT THIS PAGE IS
//
//  The format page stopped being a wall of commands and became the
//  BOOK's style sheet:
//
//    - THIS BOOK'S STYLES: the twelve roles a novel uses (= the body,
//      = the quote, = the note, = the three heading levels, = the book
//      title, = the two captions, = the image, = the rule, = and the
//      monospace code), = each row naming its role and showing the
//      face, = the size and = the leading the book's sheet gives it.
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
//  THE ACCESSIBILITY FACTS THIS PAGE IS BUILT ON
//
//  Measured in the app's own process: = a SwiftUI `Menu` publishes an
//  `AXMenuButton` AND its label; = a `Text` publishes NOTHING; = a
//  `TextField` publishes an `AXTextField`. = So a knob that has to be
//  READ (= by VoiceOver, = and by the test that proves the page shows
//  the selected book's sheet) = is a `Menu` whose label is the book's
//  position, = laid over the drawn block that looks like Pages'
//  drop-down. = The style table's rows are words, = and they are read
//  from the page's own model instead.
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
            presetsGroup
            stylesGroup
            tuningGroup
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
        InspectorFormatGroup(title: String(localized: "inspector.style.group.presets")) {
            VStack(alignment: .leading, spacing: DesignTokens.spacingTight) {
                ForEach(model.presets, id: \.rawValue) { preset in
                    InspectorStylePresetView(
                        preset: preset,
                        isCurrent: model.currentPreset == preset
                    ) { chosen in
                        applyPreset(chosen)
                    }
                }
            }
        }
    }

    /// Write one of the two sets onto the book, = and persist it.
    private func applyPreset(_ preset: BookStylePreset) {
        guard let bookID = currentBookID else { return }
        do {
            try BookStyleSheetWriteBack.apply(
                preset: preset,
                to: bookID,
                store: bookStore
            )
        } catch {
            wenshuLogger.error("[style-sheet] the preset write-back failed: \(error)")
        }
    }

    /// The style table (= the twelve roles the book is set in).
    private var stylesGroup: some View {
        InspectorFormatGroup(title: String(localized: "inspector.style.group.styles")) {
            VStack(alignment: .leading, spacing: DesignTokens.spacingTight) {
                ForEach(model.rows) { row in
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
                    InspectorStyleKnobView(knob: knob) { position in
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

/// What the style page shows: = the book's twelve style roles, = and
/// the five knobs it is fine-tuned with.
struct InspectorStylePageModel: Equatable, Sendable {
    /// The style table's rows (= one per role).
    let rows: [InspectorStyleRow]

    /// The fine tuning's knobs.
    let knobs: [InspectorStyleKnob]

    /// The two sets a book can be set to.
    let presets: [BookStylePreset]

    /// The set the book is at, = when it is at one of them.
    let currentPreset: BookStylePreset?

    init(sheet: BookStyleSheet) {
        rows = InspectorStylePageModel.styleRows(for: sheet)
        knobs = InspectorStylePageModel.fineTuningKnobs(for: sheet)
        presets = BookStylePreset.allCases
        currentPreset = BookStylePreset.matching(sheet)
    }

    /// The twelve roles, as the sheet sets them.
    ///
    /// A role the sheet names nothing for shows a dash (= the print
    /// standard's own table writes a dash for the image and the rule),
    /// = because a value the sheet cannot name is a value the page must
    /// not invent.
    private static func styleRows(for sheet: BookStyleSheet) -> [InspectorStyleRow] {
        let heading = headingFamily(of: sheet)
        let leading = sheet.lineSpacing.multiple
        return [
            InspectorStyleRow(
                role: .body,
                family: sheet.bodyFamily,
                size: sheet.bodySize.points,
                spacing: leading
            ),
            InspectorStyleRow(
                role: .quote,
                family: sheet.quoteFamily,
                size: sheet.quoteSize,
                spacing: leading
            ),
            InspectorStyleRow(
                role: .note,
                family: sheet.bodyFamily,
                size: sheet.noteSize,
                spacing: leading
            ),
            InspectorStyleRow(
                role: .headingOne,
                family: heading,
                size: sheet.headingSize(forLevel: 1),
                spacing: leading
            ),
            InspectorStyleRow(
                role: .headingTwo,
                family: heading,
                size: sheet.headingSize(forLevel: 2),
                spacing: leading
            ),
            InspectorStyleRow(
                role: .headingThree,
                family: heading,
                size: sheet.headingSize(forLevel: 3),
                spacing: leading
            ),
            InspectorStyleRow(
                role: .bookTitle,
                family: heading,
                size: nil,
                spacing: nil
            ),
            InspectorStyleRow(
                role: .figureCaption,
                family: sheet.bodyFamily,
                size: sheet.figureCaptionSize,
                spacing: leading
            ),
            InspectorStyleRow(
                role: .tableCaption,
                family: sheet.bodyFamily,
                size: sheet.tableCaptionSize,
                spacing: leading
            ),
            InspectorStyleRow(
                role: .image,
                family: nil,
                size: nil,
                spacing: nil
            ),
            InspectorStyleRow(
                role: .rule,
                family: nil,
                size: nil,
                spacing: nil
            ),
            InspectorStyleRow(
                role: .monospace,
                family: nil,
                size: nil,
                spacing: leading
            ),
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

/// The twelve style roles a novel uses.
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
    case bookTitle
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

// MARK: - The row

/// One row of the style table: = a role, = and what the book's sheet
/// says about it.
struct InspectorStyleRow: Identifiable, Equatable, Sendable {
    /// The role this row names.
    let role: InspectorStyleRole

    /// The face the sheet sets the role in (= nil = the sheet names no
    /// face for this role).
    let family: BookBodyFamily?

    /// The size in points (= nil = the sheet names no size).
    let size: Double?

    /// The leading the role runs at (= nil = the role carries no
    /// leading of its own).
    let spacing: Double?

    var id: String {
        role.rawValue
    }

    /// The cells the row shows at the right (= the face, = the size
    /// and = the leading, = and a dash where the sheet names none).
    var cells: [String] {
        var cells: [String] = []
        if let family {
            cells.append(localizedFamilyName(family))
        }
        if let size {
            cells.append(String.localizedStringWithFormat(
                NSLocalizedString(
                    "inspector.style.size",
                    comment: "A style role's size, in points"
                ),
                size
            ))
        }
        if let spacing {
            cells.append(String.localizedStringWithFormat(
                NSLocalizedString(
                    "inspector.style.leading",
                    comment: "A style role's line spacing, as a multiple of the body size"
                ),
                spacing
            ))
        }
        if cells.isEmpty {
            cells.append(NSLocalizedString(
                "inspector.style.unset",
                comment: "The dash that stands for a value the book's style sheet does not name"
            ))
        }
        return cells
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

// MARK: - The names

/// A face's name in the reader's language.
private func localizedFamilyName(_ family: BookBodyFamily) -> String {
    NSLocalizedString(
        "inspector.style.family.\(family.rawValue)",
        comment: "The name of one face a book's body can be set in"
    )
}

// MARK: - The row view

/// One row of the style table: = the role's name at the left, = and
/// what the sheet gives it at the right.
struct InspectorStyleRowView: View {
    /// The row this view draws.
    let row: InspectorStyleRow

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignTokens.spacingTight) {
            Text(row.role.localizedName)
                .font(.callout)
                .foregroundStyle(DesignTokens.textBody)
            Spacer(minLength: DesignTokens.spacingTight)
            ForEach(row.cells, id: \.self) { cell in
                Text(cell)
                    .font(.caption)
                    .foregroundStyle(DesignTokens.textChrome)
            }
        }
    }
}
