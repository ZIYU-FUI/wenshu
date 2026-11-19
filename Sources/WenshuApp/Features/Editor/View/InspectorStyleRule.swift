//
//  InspectorStyleRule.swift · Wenshu
//
//  The dashed line between two rows of the book's style table.
//
//  WHY A RULE AT ALL
//
//  The table is eleven rows of the same shape, = and a row of this table
//  says one thing about one role of the book. = Without a line the rows
//  run into each other and the reader has to find the edge of a row by
//  reading it (= the boss's ask: = one line between every style and the
//  next).
//
//  WHY DASHED, AND WHY THE NUMBERS ARE OURS
//
//  Apple ships `Divider`, = and `Divider` is solid. = A solid hairline
//  between two rows of one table reads as the end of a section, = which
//  is what it says everywhere else in this app (= the groups of the
//  inspector are separated by solid hairlines); = the line between a row
//  and its own row has to say LESS than the line between two groups, =
//  and a dashed rule is how a weaker line is drawn. = Nothing in the SDK
//  draws it, = so the dash is this app's own: = four points of ink,
//  = four of gap (= `DesignTokens.spacingIconic` on both sides, = which is
//  the app's own smallest layout step), = one point thick
//  (= `DesignTokens.dividerHeight`, = the app's own hairline), = in the
//  system's own separator colour.
//

import SwiftUI

/// One dashed hairline (= the rule between two rows of the style table).
struct InspectorStyleRule: View {
    var body: some View {
        GeometryReader { proxy in
            let midY = proxy.size.height / 2
            Path { path in
                path.move(to: CGPoint(x: 0, y: midY))
                path.addLine(to: CGPoint(x: proxy.size.width, y: midY))
            }
            .stroke(
                Color(nsColor: .separatorColor),
                style: StrokeStyle(
                    lineWidth: DesignTokens.dividerHeight,
                    dash: [DesignTokens.spacingIconic, DesignTokens.spacingIconic]
                )
            )
        }
        .frame(height: DesignTokens.dividerHeight)
        .accessibilityHidden(true)
    }
}
