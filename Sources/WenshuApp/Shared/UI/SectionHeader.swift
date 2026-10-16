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
// (AppleSidebarView '', PreviewPane '',
// EditorView tab strip '（）'). Lifted here so
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
        // RATIONALE: boss 2026-10-16 OOB "把搜索框的顶部间距都删掉" (=
        // only the spacing, not the title text). The prior layout had
        // 10 PT top inset + 10 PT bottom inset + 4 PT inner title↔divider
        // gap (= 24 PT of empty/decorative chrome wrapping the title
        // text). Drop all three; the title text + the divider remain
        // (= the divider is the hairline above whatever sits below
        // the section header — in the assets column, it's the editor's
        // 28 PT chrome band wrapping the search field). Net effect: the
        // title sits inline with the column chrome; the search field's
        // chrome band hugs the title's divider.
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
    }
}