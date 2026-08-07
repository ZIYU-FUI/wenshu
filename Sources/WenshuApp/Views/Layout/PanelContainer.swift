// PanelContainer.swift · 文枢 (Wenshu) · v0.02.0 WO-LT-01
//
// One of the 5 slots in the 5-zone shell. Renders:
//   - a thin header bar with a chevron toggle (FCP-style double-chevron),
//     the panel title, and a SF Symbol
//   - the panel content (passed in as `@ViewBuilder content`)
//   - when `isCollapsed`, just the header bar (50px for upper row,
//     30px for lower row)
//
// Collapsed width/height is supplied by the caller via `frame(width:)`
// / `frame(height:)` modifiers — the container itself only renders the
// inner chrome. This keeps the parent's GeometryReader-based layout
// arithmetic in one place (LayoutShellView).
//
// Why header bar instead of plain expanded content?
// - AGENTS §8.1: "上半折叠到 gutter (≈ 50px icon bar)" /
//   "下半折叠到只剩标题栏 (≈ 30px)". The collapsed form IS the header bar;
//   we don't render content in collapsed mode.

import SwiftUI

struct PanelContainer<Content: View>: View {
    let panelID: PanelID
    let isCollapsed: Bool
    let onToggle: () -> Void
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            if !isCollapsed {
                Divider()
                content()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color(NSColor.windowBackgroundColor).opacity(0.4))
        .overlay(
            Rectangle()
                .strokeBorder(Color.secondary.opacity(0.18), lineWidth: 0.5)
        )
    }

    private var headerBar: some View {
        HStack(spacing: 6) {
            Button(action: onToggle) {
                Image(systemName: isCollapsed ? "chevron.right" : "chevron.left")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 16, height: 16)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help(isCollapsed ? "展开 \(panelID.title)" : "折叠 \(panelID.title)")

            Image(systemName: panelID.symbolName)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            // Hide title text when collapsed (gutter is narrow).
            if !isCollapsed {
                Text(panelID.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            } else {
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, isCollapsed ? 4 : 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
        .contentShape(Rectangle())
    }
}

// MARK: - Convenience: vertical "collapsed" gutter for upper row panels
//
// When the upper row's panel is collapsed, the panel itself is replaced
// by a 50px-wide vertical icon strip. We render this as a vertical
// variant of the header bar so the chrome matches.
//
// Note: callers can use `PanelContainer`'s collapsed state directly with
// a narrow `frame(width: 50)` — the header bar collapses gracefully. We
// keep this struct for clarity / API stability for future LTs.

struct CollapsedGutter: View {
    let panelID: PanelID
    let onToggle: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            Button(action: onToggle) {
                VStack(spacing: 4) {
                    Image(systemName: panelID.symbolName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text(panelID.title)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .fixedSize()
                        // Vertical text via rotation — keep horizontal
                        // text for readability (FCP actually uses
                        // horizontal labels on 50px gutters).
                }
                .frame(width: 48)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .help("展开 \(panelID.title)")

            Spacer(minLength: 0)
        }
        .frame(width: LayoutSnapshot.topCollapsedPixels)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
        .overlay(
            Rectangle()
                .strokeBorder(Color.secondary.opacity(0.18), lineWidth: 0.5)
        )
    }
}
