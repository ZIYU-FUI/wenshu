//
//  InspectorFormatPageView.swift
//  wenshu
//
//  The format page of the trailing inspector column.
//
//  WHAT THIS PAGE IS
//
//  The book's own style sheet (= `InspectorStylePageView`), = and nothing
//  else. = The page used to carry this app's copy of Pages' inspector: = a
//  font menu, = three groups of format commands, = a heading menu and a
//  link field. = It is now the sheet a book is written in, = because a
//  novel sets its types once, = in its sheet, = rather than one selection
//  at a time.
//
//  WHY THE CHARACTER GROUP IS GONE
//
//  Bold, = italic and = the underline sat here as three glyph buttons in
//  one rounded block. = The boss's ruling removed them (= 2026-11-19): =
//  those three commands were the least of what the page had to say, = the
//  manuscript's own markdown carries them, = and the editor's selection
//  toolbar already offers them where the selection is. = A control that
//  changes what the reader is looking at without being asked is a control
//  the reader has to ignore every time the panel opens.
//
//  WHY THE RIGHT COLUMN AND NOT THE EDITOR
//
//  Measured against Apple Pages (Pages Creator Studio, com.apple.Pages)
//  with REA's native-UI and accessibility-tree readers: Pages puts its
//  format inspector in the RIGHT column, next to the document, and that
//  column is about 276 PT wide. The editor column's own chrome row (= a
//  strip of icons) is the shape Pages does NOT use.
//
//  WHAT SURVIVES OF THE PAGES MEASUREMENT
//
//  Two rules, and they are the two the style page is built on:
//
//    1. THE COLUMN HAS NO CARDS. Pages' controls sit directly on the
//       column's own background; nothing is drawn behind a group or a
//       row (= the column's other pages use `InspectorCard`, = and they
//       are a different subject with a different contract).
//    2. A LABEL SITS AT THE LEFT OF ITS CONTROL, = and the control sits at
//       the right edge of the column.
//
//  What did not survive is the drawn control surface: Pages draws a
//  pop-up, = this app used to draw a rounded block with a `Menu` inside
//  it, = and the second is a facsimile of the first (= see
//  `InspectorStyleKnobView` and `ValuePopUpButton` for the ruling and the
//  measurement that replaced it).
//

import SwiftUI

/// The trailing inspector column's format page.
///
/// The book's style sheet, = scrolled inside the column.
struct InspectorFormatPageView: View {
    var body: some View {
        ScrollView {
            InspectorStylePageView()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, DesignTokens.spacingLoose)
                .padding(.bottom, DesignTokens.spacingLoose)
        }
    }
}

// MARK: - Group

/// One group of the format page (= the group's heading and its rows).
///
/// The heading is Pages' heading: = the primary ink at heading size, =
/// with no plate behind it. The hairline above the group is the separator
/// Pages draws between the groups of its inspector (= and the FIRST group
/// carries none, = because there is nothing above it to separate from).
struct InspectorFormatGroup<Content: View>: View {
    /// The group's heading (= the group's own name).
    let title: String

    /// The group's rows.
    let content: Content

    /// Whether a hairline separates this group from the one above it.
    let showsDivider: Bool

    init(
        title: String,
        showsDivider: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.showsDivider = showsDivider
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingRelaxed) {
            if showsDivider {
                Divider()
            }
            Text(title)
                .font(.headline)
                .foregroundStyle(DesignTokens.textBody)
            content
        }
    }
}
