// PanelSplitter.swift · 文枢 (Wenshu) · v0.02.0 WO-LT-01
//
// Draggable splitter bar between two panels. Used for all 4 drag handles
// in the 5-zone shell:
//   - 2 vertical (between upper-left / upper-center, upper-center / upper-right)
//   - 1 horizontal (between upper band / lower band)
//   - 1 vertical (between lower-left / lower-right)
//
// (Spec said "共 5 个分隔条" but the geometry only fits 4 functional splitters.
// See ACCEPTANCE log for the discrepancy note.)
//
// Behavior:
// - `DragGesture(minimumDistance: 0)` so the drag starts on mouse-down
//   without an extra 3-pixel "dead zone" (FCP-style).
// - `.onChanged` fires for every micro-pixel of drag; we hand the
//   translation delta to the View Model which keeps its own debounce
//   for persistence (see LayoutShellViewModel.scheduleSave).
// - The visual is a 6px-wide (or tall) rounded rect with a subtle hover
//   state: clear → light gray, hover → mid gray. macOS HIG minimum hit
//   target is 4px; we use 6px so a 1px-overshoot cursor still lands.
//
// Concurrency: the gesture's value.translation is `CGSize` and is captured
// into `@State` from the main thread (gestures are MainActor by default).

import SwiftUI

enum SplitterOrientation {
    case horizontal // drag left/right → resizes panels horizontally
    case vertical   // drag up/down    → resizes bands vertically
}

struct PanelSplitter: View {
    let orientation: SplitterOrientation
    /// Pixel delta since drag start (positive = drag direction).
    let onDrag: (CGFloat) -> Void

    @State private var isHovering: Bool = false
    @State private var lastReportedDragValue: CGFloat = 0

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.clear)
                .contentShape(Rectangle())

            Rectangle()
                .fill(isHovering
                      ? Color.secondary.opacity(0.45)
                      : Color.secondary.opacity(0.20))
                .frame(
                    width: orientation == .horizontal ? LayoutSnapshot.splitterPixels : nil,
                    height: orientation == .vertical ? LayoutSnapshot.splitterPixels : nil
                )
        }
        .frame(
            width: orientation == .horizontal ? LayoutSnapshot.splitterPixels : nil,
            height: orientation == .vertical ? LayoutSnapshot.splitterPixels : nil
        )
        .onHover { hovering in
            isHovering = hovering
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    // We need incremental delta, not absolute translation.
                    // First call: lastReportedDragValue == 0, so delta = absolute.
                    let absolute = orientation == .horizontal
                        ? value.translation.width
                        : value.translation.height
                    let incremental = absolute - lastReportedDragValue
                    lastReportedDragValue = absolute
                    if incremental != 0 {
                        onDrag(incremental)
                    }
                }
                .onEnded { _ in
                    lastReportedDragValue = 0
                }
        )
    }
}
