// Sources/WenshuApp/UI/PaneIconTab.swift
//
// v0.28 followup Boss UX round A (Boss 2026-08-30 OOB '你需要做一个组件索引,
// 以后如果有新的地方用到相同的东西, 会自然而然的找到组件, 而不是默认自动
// 写个新的'): Phase 2 of 5-phase component refactor.
//
// Single tab button component used by ALL pane tab bars (= sidebar / preview /
// editor / tools / chat / dynamic). Listed in ComponentIndex.md Level 3.1.
//
// = replaces the duplicated Button + Color.clear + LucideIcon + contentShape +
// matchedGeometry underline code (= was duplicated in 3 places: ZoneContentTabBar,
// DynamicZoneTabBar, ChatZoneTopChrome, ~90 LOC each = ~270 LOC total).
//
// Use this component for any new per-pane tab button. Don't write a new
// Button with the same pattern (= check ComponentIndex.md first).

import SwiftUI

/// Canonical per-pane tab button (= Apple HIG 28×28 hot area + Lucide icon +
/// selected-state underline with matchedGeometry slide animation).
///
/// **Use this** for any pane tab. The component handles:
/// - 28×28 PT hot area (= Apple HIG standard small button)
/// - Lucide icon with SF Symbol fallback (= LucideIconSystemFallback)
/// - Selected state: accent color + 3 PT underline at bottom
/// - Unselected state: secondary color, no underline
/// - Plain buttonStyle + contentShape (= no clipping issues, reliable hit-testing)
/// - matchedGeometryEffect namespace for slide animation between tabs
///
/// **DON'T** write a new Button with this pattern (= was the v0.27 mistake,
/// 3 implementations were ~90 LOC each = ~270 LOC duplication).
///
/// Example:
/// ```swift
/// @Namespace private var tabBarNamespace
/// @State private var selection: String = "library"
///
/// PaneIconTab(
///     id: "library",
///     icon: "square-library",
///     label: "书架",
///     isSelected: selection == "library",
///     namespace: tabBarNamespace,
///     namespaceID: "tabBarUnderline",
///     onTap: { selection = "library" }
/// )
/// ```
@MainActor
public struct PaneIconTab: View {
    /// Stable tab identifier (= usually the tab's enum raw value).
    public let id: String

    /// Lucide icon name (kebab-case, e.g. "square-library"). Falls back to
    /// SF Symbol via LucideIconSystemFallback if not found.
    public let icon: String

    /// Accessibility label (= screen reader voice + tooltip).
    public let label: String

    /// Whether this tab is currently selected (= controls accent color +
    /// underline visibility).
    public let isSelected: Bool

    /// SwiftUI namespace for the matchedGeometryEffect underline (= one
    /// namespace per tab bar class, e.g. `tabBarNamespace`).
    public let namespace: Namespace.ID

    /// Unique ID for the matchedGeometryEffect underline rectangle (= usually
    /// "tabBarUnderline" for the shared underline, or "chatTabUnderline" for
    /// the chat zone's separate underline).
    public let namespaceID: String

    /// Tap callback (= usually `selection = tab.id`).
    public let onTap: () -> Void

    public init(
        id: String,
        icon: String,
        label: String,
        isSelected: Bool,
        namespace: Namespace.ID,
        namespaceID: String = "tabBarUnderline",
        onTap: @escaping () -> Void
    ) {
        self.id = id
        self.icon = icon
        self.label = label
        self.isSelected = isSelected
        self.namespace = namespace
        self.namespaceID = namespaceID
        self.onTap = onTap
    }

    public var body: some View {
        Button(action: onTap) {
            // Apple HIG canonical tab pattern: Color.clear as BASE
            // (= its 28×28 frame becomes the Button's hit area), icon as
            // .overlay aligned .center (= icon visually centered, no clipping).
            Color.clear
                .frame(width: DesignTokens.paneTabHotArea, height: DesignTokens.paneTabHotArea)
                .overlay(alignment: .center) {
                    LucideIconSystemFallback(icon, size: DesignTokens.tabIconSize)
                        .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                }
                .contentShape(Rectangle())
                // Apple HIG canonical selected-state underline:
                // - 1 PT height (= DesignTokens.tabUnderlineHeight)
                // - accent color
                // - bottom-anchored (= at the bottom of the 28 PT hot area)
                // - matchedGeometryEffect for L/R slide animation (= not
                //   per-tab crossfade)
                // - .clipShape(Capsule()) for fully rounded ends (= two
                //   round caps on both sides, per boss 2026-08-30 OOB
                //   '加满圆角, 两头圆'). Capsule() is the same as a fully
                //   rounded RoundedRectangle (= radius = height/2 = 0.5 PT
                //   for a 1 PT line, giving a perfect oval/lozenge shape).
                .overlay(alignment: .bottom) {
                    if isSelected {
                        Rectangle()
                            .fill(Color.accentColor)
                            .frame(height: DesignTokens.tabUnderlineHeight)
                            .matchedGeometryEffect(id: namespaceID, in: namespace)
                            .clipShape(Capsule())  // Rounded ends
                    }
                }
        }
        .buttonStyle(.plain)
        .help(label)
    }
}