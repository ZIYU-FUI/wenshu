// App.swift · Wenshu (Wenshu) · v0.01.0 7-zone layout shell (v6 = stable revert)
//
// Source of truth: @wenshu-pour/architecture/CONTEXT.md + SPEC-v0.01.0.md
//
// v0.01.0 scaffold v6 (= stable revert after v5/v7/v8/v9 crashes).
//   v5  : NSSplitViewController via NSViewControllerRepresentable — silent crash on launch
//   v7  : SwiftUI native HStack/VStack + NSTrackingArea via NSViewRepresentable — hover
//         state never fired (= NSTrackingArea events swallowed by SwiftUI parent)
//   v8  : SwiftUI native + .onHover + DragGesture + NSCursor.push — hover fired but cursor
//         change was unreliable and drag was not wired through
//   v9  : NSSplitViewController via NSViewControllerRepresentable (Apple-standard pattern)
//         — clean build, silent crash on launch (= NSSplitViewController nesting inside
//         NSViewControllerRepresentable is fragile on macOS 27.0)
// v6 = SwiftUI native HStack/VStack (= stable, all 7+1 zones visible, FCP proportions
// applied via .frame() minWidth/idealWidth per pane). Apple HIG splitter UX (hover, cursor,
// drag) is a known SwiftUI 27.0 limitation; follow-up in v0.02.0.
//
// FCP-measured default proportions (1440x900 baseline, owner 18:35):
//   Library 12.5% / Editor 31% / Inspector 16% (Shelf 30% / Project 70% inside Library)
//   Chat 25% / (Console 50% / Status 50%)
// Owner 18:30 "纵向风格区域左右结构不是上下结构" → Console|Status laid out side-by-side.

import SwiftUI

@main
struct WenshuApp: App {
    var body: some Scene {
        WindowGroup("文枢") {
            LayoutShellView()
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
    }
}

/// Top-level layout shell (= SwiftUI HStack/VStack native, stable).
/// Apple HIG: HSplitView/VSplitView are SwiftUI 14+ standard layout primitives for macOS.
/// Library zone internally splits into Shelf (top) + Project (bottom) per CONTEXT.md Q5.
struct LayoutShellView: View {
    private static let upperBandRatios: (library: CGFloat, editor: CGFloat, inspector: CGFloat) =
        (library: 0.125, editor: 0.31, inspector: 0.16)
    private static let lowerBandChatRatio: CGFloat = 0.25
    private static let libraryShelfRatio: CGFloat = 0.30
    private static let defaultWidth: CGFloat = 1440

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ZoneScaffoldView(
                    name: "LIBRARY",
                    subZones: ["SHELF", "PROJECT"],
                    splitOrientation: .vertical
                )
                    .frame(
                        minWidth: Self.defaultWidth * Self.upperBandRatios.library,
                        idealWidth: Self.defaultWidth * Self.upperBandRatios.library,
                        maxWidth: .infinity
                    )
                ZoneScaffoldView(name: "EDITOR", background: .black)
                    .frame(
                        minWidth: Self.defaultWidth * Self.upperBandRatios.editor,
                        idealWidth: Self.defaultWidth * Self.upperBandRatios.editor,
                        maxWidth: .infinity
                    )
                ZoneScaffoldView(name: "INSPECTOR")
                    .frame(
                        minWidth: Self.defaultWidth * Self.upperBandRatios.inspector,
                        idealWidth: Self.defaultWidth * Self.upperBandRatios.inspector,
                        maxWidth: .infinity
                    )
            }
            .frame(maxHeight: .infinity)

            HStack(spacing: 0) {
                ZoneScaffoldView(name: "CHAT")
                    .frame(
                        minWidth: Self.defaultWidth * Self.lowerBandChatRatio,
                        idealWidth: Self.defaultWidth * Self.lowerBandChatRatio,
                        maxWidth: .infinity
                    )
                HStack(spacing: 0) {
                    ZoneScaffoldView(name: "CONSOLE")
                        .frame(minWidth: 240, maxWidth: .infinity)
                    ZoneScaffoldView(name: "STATUS")
                        .frame(minWidth: 240, maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity)
            }
            .frame(maxHeight: .infinity)
        }
        .frame(minWidth: 1280, idealWidth: 1440, minHeight: 800, idealHeight: 900)
    }
}

/// Scaffold view for a single zone (dim watermark + zone background + optional sub-zones).
struct ZoneScaffoldView: View {
    let name: String
    let subZones: [String]
    let splitOrientation: Axis
    let background: Color

    init(
        name: String,
        subZones: [String] = [],
        splitOrientation: Axis = .horizontal,
        background: Color = Color(NSColor.windowBackgroundColor)
    ) {
        self.name = name
        self.subZones = subZones
        self.splitOrientation = splitOrientation
        self.background = background
    }

    var body: some View {
        Group {
            if subZones.count >= 2 {
                if splitOrientation == .vertical {
                    HStack(spacing: 0) {
                        ForEach(Array(subZones.enumerated()), id: \.offset) { _, sub in
                            ZoneScaffoldView(name: sub)
                        }
                    }
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(subZones.enumerated()), id: \.offset) { _, sub in
                            ZoneScaffoldView(name: sub)
                        }
                    }
                }
            } else {
                ZStack {
                    background.ignoresSafeArea()
                    watermark
                }
            }
        }
        .overlay(alignment: .center) { parentWatermark }
    }

    private var parentWatermark: some View {
        Text(name)
            .font(.system(size: 18, weight: .semibold, design: .default))
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 4))
            .allowsHitTesting(false)
    }

    private var watermark: some View {
        Text(name)
            .font(.system(size: 72, weight: .bold, design: .default))
            .foregroundStyle(.secondary.opacity(0.18))
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .allowsHitTesting(false)
    }
}