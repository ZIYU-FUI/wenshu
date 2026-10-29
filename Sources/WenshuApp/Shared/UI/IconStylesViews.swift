//
//  IconStylesViews.swift
//
//  View-only SFIcon variants extracted from IconStyles.swift (= the
//  god-class split for the file-size cap). One view struct lives here
//  (= SFLabelRow, the sidebar-row surface the design-system sweep
//  suites read as the central factory's reference implementation).
//
//  SFLabelRow has no production call site today (= the library tree
//  rows draw their own icon slot instead). It stays because the
//  design-system suites read it as the factory's reference
//  implementation: it is the one wrapper that proves a view hands
//  its icon to SFIcon(..., style:) instead of forking it.
//

import SwiftUI

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
/// The library tree rows do not instantiate this wrapper yet (= they
/// draw their own icon slot); = the wrapper is the reference
/// implementation the design-system suites read to prove the central
/// factory's shape.
///
/// Central factory preserved; each
/// application position gets its own
/// purpose-built surface (= the
/// `SFLabelRow` here is the "one icon
/// + one line of text" surface the
/// icon-factory rule points at, read by
/// the design-system suites; = it has no
/// production call site).
/// Apple's official recommended form is the `Label` view with
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
