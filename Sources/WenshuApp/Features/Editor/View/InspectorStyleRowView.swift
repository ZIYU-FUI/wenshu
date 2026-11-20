//
//  InspectorStyleRowView.swift · Wenshu
//
//  One row of the style table: = the role's name at the left, = and the
//  role's own VOICE at the right.
//
//  WHY THIS LIVES IN ITS OWN FILE
//
//  The page file it came from is held under the 600-line ceiling, = and
//  the rows are not the page (= they neither read the document nor move
//  the selection). = Same reason the knob and the preset moved out
//  before it.
//
//  WHY THE RIGHT-HAND CELL IS A SAMPLE LINE
//
//  It used to be words: = the face, = the size and = the multiple, =
//  three numbers about a role that show none of them. = The
//  row now sets a couple of words the way the BOOK sets that role
//  (= `InspectorStylePreview`), = so the table reads as the book's own
//  type specimen from the first line to the last: = the title heavy and
//  tight, = the body on the book's grid, = the note small, = the code
//  monospaced. = The numbers do not vanish, = they go under the pointer
//  (= the row's help), = because they are what a reader quotes when
//  they describe the book to someone else, = and they are not what the
//  row is for.
//
//  WHY ONE SAMPLE AND NOT THE ROLE'S OWN WORDS
//
//  The roles are already named at the left of the row, = and a row that
//  spelled its own name out in its own voice said the same thing twice.
//  = So every row carries the same two lines, = and only the voice
//  changes (= which is the only difference worth seeing).
//

import AppKit
import SwiftUI

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

    /// The role's voice (= the face, = the size and = the line height
    /// the ENGINE gives it). = Total, because every role the table carries
    /// is words.
    let preview: InspectorStylePreview

    var id: String {
        role.rawValue
    }

    /// The cells the row keeps under the pointer (= the face, = the size
    /// and = the leading, = and only the ones the sheet names: = the code
    /// row carries the leading alone).
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
        return cells
    }
}

// MARK: - The names

/// A face's name in the reader's language.
func localizedFamilyName(_ family: BookBodyFamily) -> String {
    NSLocalizedString(
        "inspector.style.family.\(family.rawValue)",
        comment: "The name of one face a book's body can be set in"
    )
}

// MARK: - The row view

/// One row of the style table: = the role's name at the left, = and two
/// lines set in the book's own voice at the right.
///
/// WHY THE NAME IS CENTRED AND NOT ON THE FIRST LINE
///
/// The row is the unit (= the dashed rules are drawn BETWEEN rows), so the
/// name belongs to the whole row, = and the row's height is the sample's two
/// lines: = on the first baseline the name hung at the top of a two-line
/// block and read as a caption of the line under it.
struct InspectorStyleRowView: View {
    /// The row this view draws.
    let row: InspectorStyleRow

    var body: some View {
        HStack(alignment: .center, spacing: DesignTokens.spacingTight) {
            Text(row.role.localizedName)
                .font(.callout)
                .foregroundStyle(DesignTokens.textBody)

            Spacer(minLength: DesignTokens.spacingTight)

            sample
        }
        //  The numbers, = under the pointer and not on the face of it.
        .help(Text(row.cells.joined(separator: " ")))
    }

    /// The row's voice: = the same two words every row speaks, = set at
    /// the size and on the grid this role runs on.
    ///
    /// WHY THE FACE IS ASKED BY NAME
    ///
    /// `.custom(_:size:)` is the only route to a face the reader's book
    /// chose, = which is data and not design: = the sizes in this app's
    /// own type scale describe the APP's chrome, = and saying 13 pt in
    /// Songti is the book's business, = not the interface's. = This is
    /// why the value is a token-shaped exception (= one call, = one
    /// reason, = recorded in the ticket's spec).
    ///
    /// WHY NO `.bold()` IS ADDED
    ///
    /// A heading's weight is already in the face the preview names
    /// (= STHeitiSC-Medium, = not Light), = so a `.bold()` here would
    /// embolden a face that is bold, = which is the double paint this
    /// page is being corrected for.
    private var sample: some View {
        Text(sampleText)
            .font(.custom(row.preview.faceName, size: row.preview.size))
            .lineSpacing(row.preview.extraLeading)
            .multilineTextAlignment(.leading)
            .foregroundStyle(DesignTokens.textBody)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// The two lines every row speaks.
    private var sampleText: String {
        NSLocalizedString(
            "inspector.style.preview.sample",
            comment: "The two sample lines the book's style table sets in each role's own voice (a newline separates them)"
        )
    }
}
