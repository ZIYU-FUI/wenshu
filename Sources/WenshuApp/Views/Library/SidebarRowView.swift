// SidebarRowView.swift · Wenshu · v1.68b
//
// One row in the macOS 27 Apple HIG sidebar. Used by
// AppleSidebarView's List(.sidebar) — Apple takes care of the
// disclosure indicator (= children property of the row's data)
// + the selection tint (= List(selection:) binding) + the hover
// highlight (= macOS 14+ default on List(.sidebar)) + the indent
// (= per-level indent from the data tree's depth). The row itself
// just renders the icon + title + subtitle (= the Apple HIG
// sidebar row content).
//
// v1.68b differs from the reverted v1.68a (= same idea, =
// the boss accepted the architecture but rejected the rest of the
// v1.68a patch because it leaked changes into LibraryStores /
// BookStore.init / 12 test fixtures — none of those are touched
// here).

import SwiftUI

struct SidebarRowView: View {
    let node: SidebarNode

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: node.systemImage)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 0) {
                Text(node.title)
                    .font(.body)
                    .lineLimit(1)
                if let subtitle = node.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 4)
        }
        // macOS 27 standard sidebar row height (= matches the
        // v1.75 fix the LazySidebarView had — = 30 PT chrome row).
        .frame(height: DesignTokens.chromeHeight)
    }
}