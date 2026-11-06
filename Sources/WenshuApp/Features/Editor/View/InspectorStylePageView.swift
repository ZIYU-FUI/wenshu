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
//  THE KNOBS ARE READ-ONLY HERE
//
//  The five knobs SHOW the positions the book's sheet holds, and
//  nothing on this page writes them back: = the engine's own
//  configuration exposes relative multipliers only, = so the write-back
//  and the injection into the engine are the engine card's work. = So
//  each drop-down here offers the positions its knob can take and
//  leaves the book's own position where it is.
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

import SwiftUI

// MARK: - The page

/// The trailing inspector column's style page (= the book's own style
/// sheet, = as two lists).
struct InspectorStylePageView: View {
    /// The workspace's UI state (= the sidebar's selection).
    @Environment(WorkspaceUIState.self) private var workspaceUI

    /// The library's books (= the sheet the page reads).
    @Environment(BookStore.self) private var bookStore

    /// The book the page shows (= the sidebar's selection, = followed
    /// as it changes).
    @State private var currentBookID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingLoose) {
            stylesGroup
            tuningGroup
        }
        .onChange(of: workspaceUI.sidebarSelection, initial: true) { _, selection in
            currentBookID = selection?.bookId
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
        BookStyleSheetWriteBack.apply(
            knob: knob,
            position: position,
            to: bookID,
            store: bookStore
        )
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

    init(sheet: BookStyleSheet) {
        rows = InspectorStylePageModel.styleRows(for: sheet)
        knobs = InspectorStylePageModel.fineTuningKnobs(for: sheet)
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
        BookBodyFamily.allCases.first { $0.postScriptName == sheet.bodyFamily.headingPostScriptName }
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
    private static func knob(
        id: String,
        nameKey: String,
        positionKey: String,
        positions: [String],
        current: String
    ) -> InspectorStyleKnob {
        InspectorStyleKnob(
            id: id,
            name: NSLocalizedString(
                nameKey,
                comment: "The name of one fine-tuning knob of a book's style sheet"
            ),
            positions: positions.map {
                NSLocalizedString(
                    "\(positionKey).\($0)",
                    comment: "One position a fine-tuning knob of a book's style sheet can take"
                )
            },
            current: NSLocalizedString(
                "\(positionKey).\(current)",
                comment: "The position a fine-tuning knob of a book's style sheet sits at"
            )
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
    let positions: [String]

    /// The position the book sits at.
    let current: String
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

// MARK: - The knob view

/// One fine-tuning knob: = the knob's name at the left, = and the
/// position the book sits at in a drop-down at the right.
struct InspectorStyleKnobView: View {
    /// The knob this row carries.
    let knob: InspectorStyleKnob

    /// What happens when a position is chosen (= the page writes the
    /// position back onto the book's sheet).
    let onChoose: (String) -> Void

    var body: some View {
        HStack(spacing: DesignTokens.spacingTight) {
            Text(knob.name)
                .font(.callout)
                .foregroundStyle(DesignTokens.textBody)
            Spacer(minLength: DesignTokens.spacingTight)
            knobMenu
        }
    }

    /// The knob's drop-down.
    ///
    /// The menu carries the positions the knob can take, = and choosing
    /// one writes it back onto the book's sheet (= the page's own
    /// action). = The position the book already sits at is the menu's
    /// label, = so the accessibility tree publishes that position (= a
    /// SwiftUI `Menu` publishes its label, = and a `Text` publishes
    /// nothing).
    private var knobMenu: some View {
        ZStack(alignment: .leading) {
            knobBlock
            Menu {
                ForEach(knob.positions, id: \.self) { position in
                    Button {
                        onChoose(position)
                    } label: {
                        Text(position)
                    }
                }
            } label: {
                Text(knob.current).opacity(0)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(maxWidth: .infinity)
        }
    }

    /// The drawn block the drop-down rides on (= Pages' drop-down: =
    /// the position at the left, = the indicator at the right).
    ///
    /// SwiftUI draws a macOS menu's own title in the CENTRE of its
    /// button, = and Pages' block puts its title at the left, = so the
    /// block is drawn here and the real menu rides on top of it as a
    /// transparent button (= the menu itself, = its items, = and its
    /// accessibility role all stay the system's).
    private var knobBlock: some View {
        HStack(spacing: DesignTokens.spacingTight) {
            Text(knob.current)
            Spacer(minLength: 0)
            SFIcon(
                "chevron.down",
                style: .inlineSmall,
                color: IconColor.secondary
            )
        }
        .padding(.horizontal, DesignTokens.spacingStandard)
        .frame(height: DesignTokens.controlHeightLarge)
        .background(InspectorFormatBlock())
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
