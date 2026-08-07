// PanelContainer.swift · 文枢 (Wenshu) · v0.02.0 WO-LT-01
//
// One of the 5 slots in the 5-zone shell. Renders:
//   - a thin header bar with the panel title + a SF Symbol
//   - the panel content (passed in as `@ViewBuilder content`)
//
// LT-01-fix3: the header's chevron collapse button is GONE. Per macOS
// HIG / Final Cut Pro, show-hide is a menu-bar command (View → Cmd+1…5),
// not panel chrome. `CollapsedGutter` likewise lost its button and is now
// a passive strip rendered from persisted collapse state.
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
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(NSColor.windowBackgroundColor).opacity(0.4))
        .overlay(
            Rectangle()
                .strokeBorder(Color.secondary.opacity(0.18), lineWidth: 0.5)
        )
    }

    private var headerBar: some View {
        HStack(spacing: 6) {
            Image(systemName: panelID.symbolName)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            Text(panelID.title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
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
// LT-01-fix3: no button — the gutter is a passive indicator. Use
// View → <panel name> in the menu bar to bring a panel back.

struct CollapsedGutter: View {
    let panelID: PanelID

    var body: some View {
        VStack(spacing: 6) {
            VStack(spacing: 4) {
                Image(systemName: panelID.symbolName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(panelID.title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .fixedSize()
            }
            .frame(width: 48)
            .padding(.vertical, 8)

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
