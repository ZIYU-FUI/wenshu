//
//  PreviewSortMenuButton.swift · Wenshu · v0.40 apple-001 Q2 slice 5
//
//  Extracted from WorkspaceView.swift (formerly inline private
//  struct at line 2128). Q2 boss拍 split WorkspaceView. Slice 5
//  = the sort-order cycle button on the preview pane top-right.
//
//  Apple HIG = one view per file. PreviewSortMenuButton has 1
//  @Binding (sortOrder) + 1 @State (isHover for the .onHover
//  tracking) and is otherwise self-contained. Already uses
//  DesignTokens.paneTabHotArea + DesignTokens.tabIconSize.
//
//  This slice ALSO bundles an AGENTS.md English-only sweep:
//  the original line 2157 = `.help("排序方式: \(sortOrder.rawValue)")`
//  (= the literal Chinese word 排序方式 = "sort method"). The
//  new value = `WenshuI18n.t("workspace.preview.sort_method_help")`
//  with a `ts(_:arg:)` variant (= the WenshuI18n.ts signature takes
//  a String interpolation arg). Both en + zh-Hans Localizable.strings
//  receive the new key in this same commit (= I18n parity invariant).
//
//  Only call site = WorkspaceView's preview pane top-right; invoked
//  as `PreviewSortMenuButton(sortOrder: $previewSortOrder)`.
//  Extracting it does not change any caller signature.
//

import SwiftUI

struct PreviewSortMenuButton: View {
    @Binding var sortOrder: EntitySortOrder
    @State private var isHover: Bool = false

    var body: some View {
        // Q34 ticket 01 of v0.30-topbar-card-alignment: PaneIconTab
        // pattern exactly (= Color.clear base + overlay icon +
        // contentShape). The previous "plain Button + LucideIcon
        // + .frame(width: DesignTokens.paneTabHotArea, height: DesignTokens.paneTabHotArea)" pattern collapsed to
        // zero size inside ZoneContentView's trailing slot (= AnyView
        // wrapper at ZoneContentTabBar erases intrinsic size).
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
                    LucideIcon(sortOrder.menuIcon, size: DesignTokens.tabIconSize)
                        .foregroundStyle(Color.secondary)
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
