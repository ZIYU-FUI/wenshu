// AppStatusbar.swift · Wenshu (文枢) · v0.28 followup TKT-028-015
//
// Boss 2026-08-29 OOB '完整复刻 hermes app, 用户体验第一' = port the
// AppRoot statusbar from Hermes Desktop verbatim. AppRoot component
// (= NOT inside the layout tree; sits fixed at bottom of root view).
//
// SOURCE (= Hermes verbatim port):
// /Volumes/ANAN/.hermes/hermes-agent/apps/desktop/src/app/shell/statusbar-controls.tsx
// = StatusbarItem (= id/label/detail/icon/className/disabled/hidden/href/
//     onSelect/actionId/title/to/variant/lockedVisible/menuContent/menuItems)
// + STATUSBAR_ACTION_CLASS (inline-flex h-full items-center gap-1 rounded-none
//     px-1.5 text-(--ui-text-tertiary) transition-colors hover:bg-(--chrome-action-hover)
//     hover:text-foreground disabled:cursor-default disabled:opacity-45)
// + $statusbarHiddenIds + $statusbarVisible + setStatusbarItemVisible + resetStatusbarLayout

import SwiftUI
import AppKit

// MARK: - Statusbar tokens (= matches hermes statusbar-controls.tsx)

/// Statusbar item height (= 30 PT, v0.28 followup Boss UX round 26:
/// unified with per-region tab bar height so all chrome lines up
/// flush when stacked vertically — was 24 PT previously, which
/// didn't match the 30 PT zone tab bar above it).
public let kStatusbarItemHeight: CGFloat = 30

/// Statusbar top border (= 1 PT Apple .separator hairline, macOS 26
/// Tahoe canonical Liquid Glass separator).
public let kStatusbarBorderHeight: CGFloat = 1

// MARK: - StatusbarItem (= matches hermes StatusbarItem)

/// One statusbar item (= text + optional icon + optional menu).
/// Matches Hermes `StatusbarItem` interface.
public struct StatusbarItem: Identifiable, Sendable {
    public enum Variant: String, Sendable {
        case action   // = button with onSelect
        case link     // = navigates to URL/route
        case menu     // = dropdown menu trigger
        case text     // = boxless quiet inline
    }

    public let id: String
    public let label: String?
    public let detail: String?
    public let iconName: String?  // SF Symbol name
    public let disabled: Bool
    public let hidden: Bool
    public let variant: Variant
    public let onSelect: (@Sendable () -> Void)?
    public let actionId: String?
    public let title: String?
    public let href: String?
    public let lockedVisible: Bool  // = cannot be hidden via right-click
    /// Plain-text name for the bar's right-click show/hide menu.
    public let toggleLabel: String?

    public init(
        id: String,
        label: String? = nil,
        detail: String? = nil,
        iconName: String? = nil,
        disabled: Bool = false,
        hidden: Bool = false,
        variant: Variant = .action,
        onSelect: (@Sendable () -> Void)? = nil,
        actionId: String? = nil,
        title: String? = nil,
        href: String? = nil,
        lockedVisible: Bool = false,
        toggleLabel: String? = nil
    ) {
        self.id = id
        self.label = label
        self.detail = detail
        self.iconName = iconName
        self.disabled = disabled
        self.hidden = hidden
        self.variant = variant
        self.onSelect = onSelect
        self.actionId = actionId
        self.title = title
        self.href = href
        self.lockedVisible = lockedVisible
        self.toggleLabel = toggleLabel
    }
}

// MARK: - AppStatusbar

/// The AppRoot statusbar (= fixed bottom, not in tree). Hosts registered
/// statusbar items via ContributionRegistry. Right-click on any non-
/// locked item opens a context menu to hide/show that item.
///
/// Visibility policy:
/// - `statusbarVisible` (= Wenshu @AppStorage flag) = whether bar shown.
/// - `statusbarHiddenIds: Set<String>` = per-item hidden (= from PaneVisibilityStore).
/// - `lockedVisible: true` items NEVER hidden (= they're critical: model,
///   errors, status).
@MainActor
public struct AppStatusbar: View {
    let leftItems: [StatusbarItem]
    let rightItems: [StatusbarItem]
    let visible: Bool
    let hiddenIds: Set<String>
    let onToggleItemVisibility: (String) -> Void
    let onResetLayout: () -> Void

    public init(
        leftItems: [StatusbarItem] = [],
        rightItems: [StatusbarItem] = [],
        visible: Bool = true,
        hiddenIds: Set<String> = [],
        onToggleItemVisibility: @escaping (String) -> Void = { _ in },
        onResetLayout: @escaping () -> Void = {}
    ) {
        self.leftItems = leftItems
        self.rightItems = rightItems
        self.visible = visible
        self.hiddenIds = hiddenIds
        self.onToggleItemVisibility = onToggleItemVisibility
        self.onResetLayout = onResetLayout
    }

    public var body: some View {
        if !visible { EmptyView() }
        else {
            VStack(spacing: 0) {
                // Top border (= 1 PT Apple .separator hairline).
                // v0.28 followup Boss UX round 26: Apple HierarchicalShapeStyle
                // .separator (= canonical Liquid Glass separator, macOS 26 Tahoe)
                // replaces Color(nsColor: .separatorColor) (= solid NSColor).
                Rectangle()
                    .frame(height: kStatusbarBorderHeight)
                    .foregroundStyle(.separator)
                HStack(spacing: 0) {
                    // Left cluster.
                    HStack(spacing: 0) {
                        ForEach(visibleItems(leftItems)) { item in
                            StatusbarItemView(item: item, onToggleVisibility: {
                                if !item.lockedVisible {
                                    onToggleItemVisibility(item.id)
                                }
                            })
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    // Right cluster.
                    HStack(spacing: 0) {
                        ForEach(visibleItems(rightItems)) { item in
                            StatusbarItemView(item: item, onToggleVisibility: {
                                if !item.lockedVisible {
                                    onToggleItemVisibility(item.id)
                                }
                            })
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.horizontal, LayoutTokens.chromePaddingMedium)
                .frame(height: kStatusbarItemHeight)
                // v0.28 followup Boss UX round 13 (Boss 2026-08-29 OOB
                // '其他区域背景, 组件什么的, 有没有需要适配液态玻璃的'):
                // Use .regularMaterial (= macOS 26 Tahoe Liquid Glass
                // translucency) instead of solid windowBackgroundColor.
                // Per Apple developer.apple.com/documentation/
                // swiftui/materials (= the Liquid Glass material catalog
                // for SwiftUI on macOS 13+), .regularMaterial is the
                // standard translucent material used for toolbars /
                // statusbars / sidebars (= exactly the macOS 26 Tahoe
                // Liquid Glass look applied to a custom statusbar view).
                .background(.regularMaterial)
                .contextMenu {
                    Button("Reset statusbar layout") {
                        onResetLayout()
                    }
                    Divider()
                    ForEach(allToggleableItems(), id: \.id) { item in
                        if let label = item.toggleLabel {
                            Button(item.hidden || hiddenIds.contains(item.id) ? "Show \(label)" : "Hide \(label)") {
                                onToggleItemVisibility(item.id)
                            }
                            .disabled(item.lockedVisible)
                        }
                    }
                }
            }
        }
    }

    private func visibleItems(_ items: [StatusbarItem]) -> [StatusbarItem] {
        items.filter { !$0.hidden && !hiddenIds.contains($0.id) }
    }

    private func allToggleableItems() -> [StatusbarItem] {
        (leftItems + rightItems).filter { $0.toggleLabel != nil }
    }
}

// MARK: - StatusbarItemView (= single item)

@MainActor
private struct StatusbarItemView: View {
    let item: StatusbarItem
    let onToggleVisibility: () -> Void
    @State private var isHover: Bool = false

    var body: some View {
        Button {
            item.onSelect?()
        } label: {
            HStack(spacing: 4) {
                if let iconName = item.iconName {
                    Image(systemName: iconName)
                        .font(.system(size: 10, weight: .regular))
                }
                if let label = item.label {
                    Text(label)
                        .font(.system(size: 11, weight: .regular))
                        .lineLimit(1)
                }
                if let detail = item.detail {
                    Text(detail)
                        .font(.system(size: 10, weight: .regular))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .foregroundColor(.secondary)
            .padding(.horizontal, LayoutTokens.chromePaddingMedium)
            .frame(height: kStatusbarItemHeight)
            .background(
                isHover
                    ? Color(nsColor: .controlBackgroundColor).opacity(0.4)
                    : Color.clear
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(item.disabled)
        .opacity(item.disabled ? 0.45 : 1.0)
        .onHover { hover in
            isHover = hover
        }
        .help(item.title ?? item.label ?? item.id)
        .accessibilityLabel(item.title ?? item.label ?? item.id)
    }
}

// MARK: - Default statusbar items (= wenshu baseline)

/// Default left-side statusbar items (= current model + status text).
@MainActor
public func defaultStatusbarLeftItems(
    modelName: String,
    llmStatus: String
) -> [StatusbarItem] {
    return [
        StatusbarItem(
            id: "model",
            label: modelName,
            iconName: "cpu",
            variant: .text,
            title: "Current model",
            toggleLabel: "Model"
        ),
        StatusbarItem(
            id: "status",
            detail: llmStatus,
            variant: .text,
            title: "LLM status",
            toggleLabel: "Status"
        ),
    ]
}

/// Default right-side statusbar items (= version + git + cpu/mem).
@MainActor
public func defaultStatusbarRightItems(
    version: String = "v0.28",
    sessionId: String? = nil
) -> [StatusbarItem] {
    var items: [StatusbarItem] = [
        StatusbarItem(
            id: "version",
            label: "wenshu \(version)",
            variant: .text,
            title: "Version",
            toggleLabel: "Version"
        ),
    ]
    if let sessionId {
        items.append(StatusbarItem(
            id: "session",
            label: sessionId,
            variant: .text,
            title: "Session ID",
            toggleLabel: "Session ID"
        ))
    }
    return items
}