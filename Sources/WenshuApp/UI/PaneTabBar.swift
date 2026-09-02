// Sources/WenshuApp/UI/PaneTabBar.swift
//
// v0.28 followup Boss UX round A (Boss 2026-08-30 OOB '你需要做一个组件索引,
// 以后如果有新的地方用到相同的东西, 会自然而然的找到组件, 而不是默认自动
// 写个新的'): Phase 3 of 5-phase component refactor.
//
// Generic wrapper for a list of PaneIconTab + optional trailing buttons.
// Listed in ComponentIndex.md Level 3.2.
//
// = replaces ZoneContentTabBar (166 LOC) + DynamicZoneTabBar (135 LOC) +
// ChatZoneTopChrome (74 LOC) = 375 LOC of duplicated tab bar code.
//
// Use this for ANY per-pane top tab bar (= sidebar/preview/editor/tools/
// chat/dynamic). Don't write a new tab bar component from scratch.

import SwiftUI

/// Canonical per-pane tab bar (= RegionTabBar chrome + ForEach of
/// PaneIconTab + optional trailing buttons). Replaces 3 legacy
/// tab bar implementations with 1 generic component.
///
/// **Use this** for any pane's top tab bar (= sidebar/preview/editor/
/// tools/chat/dynamic). Provides:
/// - RegionTabBar Liquid Glass chrome (= 30 PT + .regularMaterial +
///   .separator bottom hairline)
/// - ForEach of PaneIconTab (= Apple HIG 28×28 hot area + Lucide icon +
///   matchedGeometry selected-state underline)
/// - Optional trailing buttons (= e.g. editor's expand/shrink button,
///   or library's 新建 / 入驻 menu buttons) at the rightmost edge
/// - matchedGeometryEffect namespace for slide animation
///
/// Example (single tab + trailing button, like chat zone):
/// ```swift
/// @Namespace private var tabBarNamespace
/// @State private var selection: String = "chat"
///
/// PaneTabBar(
///     items: [
///         PaneTabItem(id: "chat", icon: "bot", label: "对话"),
///     ],
///     selection: $selection,
///     namespace: tabBarNamespace,
///     trailing: {
 // Button { ... } label: { Image(systemName: "inbox") }
 ///     }
/// )
/// ```
///
/// Example (multiple tabs, like sidebar/preview/editor/tools):
/// ```swift
/// PaneTabBar(
///     items: [
///         PaneTabItem(id: "library", icon: "square-library", label: "书架"),
///         PaneTabItem(id: "preview", icon: "book-open-text", label: "预览"),
///     ],
///     selection: $selection,
///     namespace: tabBarNamespace
///     // No trailing buttons
/// )
/// ```
@MainActor
public struct PaneTabBar<Item: Identifiable & Sendable, Trailing: View>: View {
    /// Tab items to display.
    public let items: [Item]

    /// KeyPath to extract the tab's String id (= used for selection binding).
    public let idKeyPath: KeyPath<Item, String>

    /// KeyPath to extract the tab's Lucide icon name (= kebab-case, e.g.="square-library").
    public let iconKeyPath: KeyPath<Item, String>

    /// KeyPath to extract the tab's accessibility label.
    public let labelKeyPath: KeyPath<Item, String>

    /// Currently selected tab id (= drives `PaneIconTab.isSelected`).
    @Binding public var selection: String

    /// SwiftUI namespace for the matchedGeometryEffect underline.
    public let namespace: Namespace.ID

    /// matchedGeometryEffect ID for the underline rectangle.
    public let namespaceID: String

    /// Optional trailing buttons (= rendered at rightmost edge with Spacer).
    @ViewBuilder public let trailing: () -> Trailing

    public init(
        items: [Item],
        idKeyPath: KeyPath<Item, String>,
        iconKeyPath: KeyPath<Item, String>,
        labelKeyPath: KeyPath<Item, String>,
        selection: Binding<String>,
        namespace: Namespace.ID,
        namespaceID: String = "tabBarUnderline",
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }
    ) {
        self.items = items
        self.idKeyPath = idKeyPath
        self.iconKeyPath = iconKeyPath
        self.labelKeyPath = labelKeyPath
        self._selection = selection
        self.namespace = namespace
        self.namespaceID = namespaceID
        self.trailing = trailing
    }

    /// Convenience initializer for `PaneTabItem` (= the most common item type).
    public init(
        items: [PaneTabItem],
        selection: Binding<String>,
        namespace: Namespace.ID,
        namespaceID: String = "tabBarUnderline",
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }
    ) where Item == PaneTabItem {
        self.init(
            items: items,
            idKeyPath: \.id,
            iconKeyPath: \.icon,
            labelKeyPath: \.label,
            selection: selection,
            namespace: namespace,
            namespaceID: namespaceID,
            trailing: trailing
        )
    }

    public var body: some View {
        RegionTabBar {
            HStack(spacing: DesignTokens.chromePaddingClusterGap) {
                ForEach(items) { item in
                    PaneIconTab(
                        id: item[keyPath: idKeyPath],
                        icon: item[keyPath: iconKeyPath],
                        label: item[keyPath: labelKeyPath],
                        isSelected: item[keyPath: idKeyPath] == selection,
                        namespace: namespace,
                        namespaceID: namespaceID,
                        onTap: { selection = item[keyPath: idKeyPath] }
                    )
                }
                // Trailing buttons: pushed to the right edge via Spacer
                // (= independent of how many tabs the pane has = always
                // sits at the rightmost position). Apple HIG canonical
                // toolbar pattern (toolbars.action buttons at trailing edge).
                // v0.30 ponytail fix v2: remove `Trailing.self == EmptyView.self`
                // check (= always render trailing). Previous code skipped
                // trailing when `Trailing` was inferred as EmptyView (= the
                // default). When callers pass a real trailing via AnyView,
                // SwiftUI's @ViewBuilder inference sometimes collapses the
                // trailing closure's return type to EmptyView (= the
                // type-check trick at runtime doesn't catch this) = trailing
                // skipped = sort icon / expand icon never render.
                //
                // Fix: always render trailing. EmptyView collapses to 0
                // width anyway (= no visual difference for callers that
                // pass nil).
                Spacer(minLength: 0)
                trailing()
            }
            // v0.34 boss 2026-09-02 OOB '父组件需要定一下, 左右间距对称':
            // the PaneTabBar chrome parent controls the symmetric outer
            // inset. Previously (.padding(.leading, chromePaddingLeading)
            // only) the inner HStack was left-aligned with 18 PT left
            // edge inset but 0 PT right (= visually asymmetric across
            // the 6 zones). Apple HIG canonical toolbar = symmetric
            // outer edge inset (Photos / Music / Mail tab bar use the
            // same leading + trailing value). Now both sides use
            // chromePaddingLeading (= 18 PT) = Apple HIG symmetric.
            .padding(.horizontal, DesignTokens.chromePaddingLeading)
            // ponytail fix: the inner HStack had only intrinsic width
            // (= sum of children), so the Spacer(minLength: 0) before
            // trailing() had zero extra space to consume = trailing
            // collapsed to sit immediately after the last tab. Adding
            // .frame(maxWidth: .infinity) forces the inner HStack to
            // fill the outer RegionTabBar's full width (= RegionTabBar
            // already has .frame(maxWidth: .infinity) on its outer
            // HStack), giving the Spacer real horizontal space to
            // expand into = trailing button pushed to the right edge.
            .frame(maxWidth: .infinity)
        }
        .animation(.default, value: selection)
    }
}

/// Convenience value type for `PaneTabBar` items (= used when caller
/// doesn't have a custom Identifiable type).
public struct PaneTabItem: Identifiable, Sendable {
    public let id: String
    public let icon: String
    public let label: String

    public init(id: String, icon: String, label: String) {
        self.id = id
        self.icon = icon
        self.label = label
    }
}