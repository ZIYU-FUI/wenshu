//
//  IconStylesViews.swift
//
//  View-only SFIcon variants extracted from IconStyles.swift (= §6.6
//  god-class split: 5 view structs moved out = SFLabelRow / SFStatusBadge
//  / SFCardHero / SFToolbarButton / SFListRow = 188 LOC of pure-view
//  helpers). The 5 views are stateless (= only @Environment(.colorScheme)
//  for the badge variants; = safe to extract to a separate file).
//

import SwiftUI

// MARK: - SFListRow

/// Apple HIG generic list-row view wrapper. Renders a leading icon
/// + title + optional subtitle + optional trailing accessory stacked
/// horizontally (= the Apple Mail message-list / Finder list row
/// convention for non-sidebar lists).
///
/// Application position: every list row OUTSIDE a sidebar (= search
/// results, memory entries, settings rows, file lists). The sidebar
/// itself has its own `SFLabelRow` (= 22 PT height, 16 PT icon).
/// SFListRow is the general-list cousin (= 30 PT chrome-height,
/// 14 PT inline icon).
///
/// Every general-list row flows
/// through this surface so the next
/// "make all list rows 2 PT taller"
/// directive becomes a 1-line change
/// here (= the call sites inherit
/// automatically).
///
/// Apple's recommended form is `Label { ... } icon: { ... }`.
/// SFListRow delegates to it and adds the optional trailing
/// accessory slot.
///
/// ```swift
/// SFListRow(systemImage: "doc", title: "Chapter 1",
///           subtitle: "12 pages",
///           trailing: { Text("Today") })
/// ```
struct SFListRow<Trailing: View>: View {
    let systemImage: String
    let title: String
    let subtitle: String?
    let trailing: (() -> Trailing)?

    init(
        systemImage: String,
        title: String,
        subtitle: String? = nil,
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }
    ) {
        self.systemImage = systemImage
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing
    }

    var body: some View {
        Label {
            HStack(spacing: DesignTokens.spacingTight) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(title)
                        .font(.body)
                        .lineLimit(1)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                if let trailing {
                    trailing()
                }
            }
        } icon: {
            Image(systemName: systemImage)
                .font(.system(size: IconStyle.inlineSmall.pointSize,
                              weight: IconStyle.inlineSmall.fontWeight))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
                .frame(width: IconStyle.inlineSmall.pointSize + 4)
        }
        .frame(height: DesignTokens.chromeHeight)
    }
}
// MARK: - SFToolbarButton

/// Apple HIG toolbar-button view wrapper. Renders an icon-only button
/// at the macOS HIG toolbar control size (= the SwiftUI
/// `.controlSize(.regular)` point size).
///
/// Application position: every toolbar /
/// pane-tab / top-bar action button
/// in wenshu. Every wenshu toolbar
/// action flows through this surface
/// so the next "make the toolbar
/// button hot area 4 PT wider"
/// directive becomes a 1-line change
/// here (= the call sites inherit
/// automatically).
///
/// Apple's recommended form is `Button { ... } label: { ... }` with
/// the icon-only `.labelStyle(.iconOnly)`. SFToolbarButton delegates
/// to it and applies the standard control-size + 28 PT minimum hit
/// area (= Apple HIG macOS minimum tap target).
///
/// ```swift
/// SFToolbarButton(systemImage: "plus", action: { addItem() })
/// ```
struct SFToolbarButton: View {
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: IconStyle.toolbar.pointSize,
                              weight: IconStyle.toolbar.fontWeight))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .frame(width: IconStyle.hitArea.pointSize,
               height: IconStyle.hitArea.pointSize)
        .contentShape(Rectangle())
    }
}
// MARK: - SFCardHero

/// Apple HIG card-hero view wrapper. Renders a large icon + title +
/// optional subtitle stacked vertically (= the Apple Notes folder-card
/// / Apple Music album-card convention).
///
/// Application position: every place
/// in wenshu that needs a card with
/// a hero icon (= card picker,
/// library card, character portrait
/// card). Every wenshu hero card
/// flows through this surface so the
/// next "make the card icon 10 PT
/// larger" directive becomes a
/// 1-line change here (= the call
/// sites inherit automatically).
///
/// Apple's recommended form is `Label { ... } icon: { ... }` for
/// the icon-title pair; SFCardHero delegates to it and stacks the
/// optional subtitle via VStack below.
///
/// ```swift
/// SFCardHero(systemImage: "book.closed",
///            title: "Reference Library",
///            subtitle: "12 references")
/// ```
struct SFCardHero: View {
    let systemImage: String
    let title: String
    let subtitle: String?

    init(systemImage: String, title: String, subtitle: String? = nil) {
        self.systemImage = systemImage
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(spacing: DesignTokens.spacingModerate) {
            Image(systemName: systemImage)
                .font(.system(size: IconStyle.avatar.pointSize,
                              weight: IconStyle.avatar.fontWeight))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.tint)
            Text(title)
                .font(.headline)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
            }
        }
        .padding(DesignTokens.spacingLoose)
        .frame(maxWidth: .infinity)
    }
}
// MARK: - SFStatusBadge

/// Apple HIG status-badge view wrapper. Renders a small icon + text
/// in a Capsule-pill background (= the Apple Mail / Notes status
/// chip convention).
///
/// Application position: every place
/// in wenshu that needs a pill-shaped
/// status indicator (= e.g. "configured" /
/// "disconnected" / "N items" / etc. —
/// the strings live in
/// `Localizable.xcstrings` per locale).
/// All wenshu status pills flow
/// through this single surface so
/// that the next "make the status
/// pill smaller" directive becomes
/// a 1-line change in this file
/// (= the call sites inherit
/// automatically).
///
/// Apple's recommended form for a status chip is a `Label { ... }
/// icon: { ... }` rendered inside `Capsule().fill(...)`. SFStatusBadge
/// delegates to Label so the factory does not duplicate Apple's
/// canonical pattern.
///
/// ```swift
/// SFStatusBadge(systemImage: "checkmark.circle.fill",
///               text: "Configured",
///               tint: .green)
/// ```
struct SFStatusBadge: View {
    let systemImage: String
    let text: String
    let tint: Color

    init(systemImage: String, text: String, tint: Color = .accentColor) {
        self.systemImage = systemImage
        self.text = text
        self.tint = tint
    }

    var body: some View {
        Label {
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        } icon: {
            Image(systemName: systemImage)
                .font(.system(size: IconStyle.inlineSmall.pointSize,
                              weight: IconStyle.inlineSmall.fontWeight))
                .foregroundStyle(tint)
        }
        .padding(.horizontal, DesignTokens.spacingTight)
        .padding(.vertical, DesignTokens.spacingCaption)
        .background(
            Capsule().fill(tint.opacity(DesignTokens.accentTintOpacitySubtle))
        )
    }
}
// MARK: - SFLabelRow

/// Central Apple HIG sidebar-row factory. Renders one icon + title + optional
/// subtitle per Apple HIG Sidebars canonical pattern (=
/// `developer.apple.com/design/human-interface-guidelines/sidebars`:
/// "Short labels / Familiar SF Symbols / Calm the sidebar").
///
/// Application position: macOS 27 List(.sidebar) rows. Pinned to Apple's
/// own sidebar row anatomy = 22 PT row height (= SwiftUI List(.sidebar)
/// default), 16 PT leading icon (= Apple Mail / Finder / Settings sidebar
/// default), `.body` title + `.caption + .secondary` subtitle, with the
/// 10 PT inner gutter (= the Apple HIG standard sidebar inset).
///
/// Central factory preserved; each
/// application position gets its own
/// purpose-built surface (= the
/// `SFLabelRow` here is the "one icon
/// + one line of text" surface used
/// by the library tree's outline rows).
/// pattern). Apple's official recommended form is the `Label` view with
/// the title-and-icon initializer; SFLabelRow delegates to it so the
/// factory does not duplicate what Apple already gives us.
///
/// ```swift
/// SFLabelRow(title: "Documents", systemImage: "folder")
/// SFLabelRow(title: "Chapter 1", systemImage: "book",
///            subtitle: "12 pages")
/// ```
struct SFLabelRow: View {
    let title: String
    let systemImage: String
    let subtitle: String?
    let iconStyle: IconStyle

    init(
        title: String,
        systemImage: String,
        subtitle: String? = nil,
        iconStyle: IconStyle = .sidebarTree
    ) {
        self.title = title
        self.systemImage = systemImage
        self.subtitle = subtitle
        self.iconStyle = iconStyle
    }

    var body: some View {
        Label {
            HStack(alignment: .firstTextBaseline, spacing: DesignTokens.spacingTight) {
                Text(title)
                    .font(.body)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        } icon: {
            // Sidebar rows use one fixed icon slot. The same nominal point size alone is
            // not enough: SF Symbols with different intrinsic bounds can
            // still look larger or smaller beside one another. A fixed
            // slot plus the canonical regular weight keeps the tree
            // visually aligned without tuning each symbol individually.
            // Color follows Apple Tahoe sidebar default (= system primary,
            // not app accent). No explicit .symbolRenderingMode here (=
            // the SFIcon factory owns the rendering decision via
            // IconStyle.sidebar = .monochrome; per the boss 2026-10-08
            // (see OOB.md #2026-10-08) .hierarchical +
            // .foregroundStyle(Color.primary) surfaces the icon as system
            // tint = accent = blue; only .monochrome renders Color.primary
            // as the actual system primary color).
            SFIcon(
                systemImage,
                style: iconStyle,
                color: IconColor.primary
            )
            .padding(.horizontal, iconStyle.sidebarInset)
            .frame(width: iconStyle.sidebarWidth)
            .foregroundStyle(Color.primary)
        }
        .frame(height: DesignTokens.sidebarRowHeight)
    }
}
