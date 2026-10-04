// Sources/WenshuApp/Views/Workspace/PreviewSortMenuButton.swift
//
// The sort-order cycle button on the preview pane top-right.
// One view per file (Apple HIG). `PreviewSortMenuButton` has
// 1 `@Binding` (`sortOrder`) + 1 `@State` (`isHover` for the
// `.onHover` tracking) and is otherwise self-contained.
//  DesignTokens.paneTabHotArea.
//
// Only call site = WorkspaceView's preview pane top-right;
// invoked as `PreviewSortMenuButton(sortOrder: $previewSortOrder)`.
// Extracting it does not change any caller signature.
//

import SwiftUI

struct PreviewSortMenuButton: View {
    @Binding var sortOrder: EntitySortOrder
    @State private var isHover: Bool = false

    var body: some View {
        // PaneIconTab pattern (= `Color.clear` base + overlay icon
        // + `contentShape`). The previous "plain Button + LucideIcon
        // + .frame(width: paneTabHotArea, height: paneTabHotArea)"
        // pattern collapsed to zero size inside ZoneContentView's
        // trailing slot (= AnyView wrapper erases intrinsic size).
        // Color.clear base provides a guaranteed 28x28 hit area that
        // survives AnyView wrapping, matching PaneIconTab which DOES
        // render in the same slot.
        //
        // Tap behavior: cycle through 3 sort orders. Icon updates
        // to reflect current order.
        Button {
            switch sortOrder {
            case .pinyinFirstLetter: sortOrder = .createdAt
            case .createdAt: sortOrder = .modifiedAt
            case .modifiedAt: sortOrder = .pinyinFirstLetter
            }
        } label: {
            // PaneIconTab pattern: Color.clear as BASE, icon as
            // .overlay centered. Fixed frame = intrinsic size preserved.
            Color.clear
                .frame(width: DesignTokens.paneTabHotArea, height: DesignTokens.paneTabHotArea)
                .overlay(alignment: .center) {
                    SFIcon(sortOrder.menuIcon, style: .paneTab, color: IconColor.secondary)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHover = hovering
        }
        .help(WenshuI18n.ts("workspace.preview.sort_method_help", sortOrder.rawValue))
    }
}
