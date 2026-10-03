// SectionHeader.swift · Wenshu
//
// Reusable column section header:
//     <10 PT top inset>
//     HStack { Spacer; Text title (.body .secondary); Spacer }
//     <4 PT gap>
//     Divider
//     <10 PT bottom inset>
//
// The same pattern repeats at the top of every column
// (AppleSidebarView '书架', PreviewPane '素材',
// EditorView tab strip '写作（小说）'). Lifted here so
// future columns use SectionHeader(...) instead of inlining the
// same HStack + Divider block three times.
//
// Spacing constants live in DesignTokens (= single source of truth
// for chrome dimensions per ComponentIndex).
//
// Apple HIG reference for the centered-section-header idiom:
// - Apple Mail section headers ("Today / Yesterday / Last week")
// - Apple Notes folder list section dividers
// - Apple Pages section-header text "DOCUMENT"
// All three use: centered secondary-tint text + hairline divider below.

import SwiftUI

/// Column-top section header: 10 PT inset, centered secondary title text,
/// 4 PT gap, hairline divider, 10 PT inset below. The canonical column-top
/// chrome in macOS Mail / Notes / Finder section-header idiom.
struct SectionHeader: View {
    let title: String
    let showsDivider: Bool

    init(title: String, showsDivider: Bool = true) {
        self.title = title
        self.showsDivider = showsDivider
    }

    var body: some View {
        VStack(spacing: DesignTokens.spacingIconic) {
            // 10 PT top inset (= the column-header pattern; = the
            // rest of the panes keep the older 18 PT top inset
            // unchanged).
            Color.clear.frame(height: DesignTokens.spacingModerate)

            HStack {
                Spacer()
                Text(title)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .textCase(nil)
                Spacer()
            }

            if showsDivider {
                Divider()
            }

            // 10 PT bottom inset (= balances the top inset; = gives
            // the hairline a settled 'pad' before the content
            // starts; = matches the previous PreviewPane .padding
            // (.bottom, 4) + sidebar (no inset) net visual weight).
            Color.clear.frame(height: DesignTokens.spacingModerate)
        }
    }
}