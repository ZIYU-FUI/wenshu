// Sources/WenshuApp/Views/Layout/PaneSplitter.swift
//
// v0.28 followup Boss UX round B (Boss 2026-08-30 OOB '5根拖拽线可以
// 抽象吗' = boss asked if the 5 splitters can be abstracted into a
// single unified component). YES they can.
//
// Before this commit: the 5 splitters (= D_v0 horizontal band split +
// D_v1/D_v2/D_v3/D_v5 vertical zone splits) used 2 different patterns:
// - D_v0 = inline NativeSplitter(...) call in LayoutShellView body
// - D_v1/D_v2/D_v3/D_v5 = wrapped in VSplitter(= inline NativeSplitter
//   + vm.adjust callback) = 2 implementations for the same thing.
//
// The wrapper was created in v0.15 ticket 006 to avoid Shotgun Surgery
// (= changing 1 splitter position = need to update 5 places). But the
// wrapper only took a magic `splitterIndex` (= 0/1/2/4 = skips 3 = not
// data-driven).
//
// Round B refactor: introduce `SplitterSpec` (= value type) + `PaneSplitter`
// (= View component). All 5 splitters now described uniformly as
// `SplitterSpec` values, rendered via `PaneSplitter`. Adding a new
// splitter = add 1 entry to `splitterSpecs` array (= 0 risk of forgetting
// a callback).
//
// Listed in ComponentIndex.md Level 5.5.

import SwiftUI

// MARK: - SplitterSpec

/// Describes one draggable pane splitter (= orientation + dimensions +
/// drag callback). Listed in ComponentIndex.md Level 5.5.
///
/// Use this value type when defining any new splitter (= instead of
/// inlining `NativeSplitter(...)` or calling `VSplitter` directly).
/// Add a new splitter = add 1 `SplitterSpec` to the `splitterSpecs`
/// array in `LayoutShellView`. Boss's audit: this was the gap that
/// caused D_v0 (= horizontal band split) to bypass `VSplitter` entirely.
public struct SplitterSpec: Identifiable, Sendable {
    public enum Orientation: Sendable, Equatable {
        case horizontal  // = drag up/down (= e.g. D_v0 band split)
        case vertical    // = drag left/right (= e.g. D_v1/D_v2/D_v3/D_v5)
    }

    public let id: String  // = stable name like "D_v0", "D_v1", "D_v2", "D_v3", "D_v5"
    public let orientation: Orientation
    public let length: CGFloat
    public let totalSize: CGFloat  // = totalWidth for vertical, totalHeight for horizontal
    public let onDrag: @Sendable (CGFloat) -> Void

    public init(
        id: String,
        orientation: Orientation,
        length: CGFloat,
        totalSize: CGFloat,
        onDrag: @escaping @Sendable (CGFloat) -> Void
    ) {
        self.id = id
        self.orientation = orientation
        self.length = length
        self.totalSize = totalSize
        self.onDrag = onDrag
    }
}

// MARK: - PaneSplitter

/// Canonical pane splitter (= wraps NativeSplitter with consistent defaults
/// + SplitterSpec ergonomics). Listed in ComponentIndex.md Level 5.5.
///
/// **Use this** for any pane splitter (= don't inline NativeSplitter
/// or call the legacy VSplitter wrapper). PaneSplitter takes a
/// `SplitterSpec` (= data-driven) so adding a new splitter = add 1
/// `SplitterSpec` value, no boilerplate.
///
/// Example (replaces legacy VSplitter wrapper):
/// ```swift
/// PaneSplitter(spec: SplitterSpec(
///     id: "D_v1",
///     orientation: .vertical,
///     length: bandH,
///     totalSize: totalW,
///     onDrag: { dx in vm.adjustSidebarPreview(delta: dx, totalWidth: totalW) }
/// ))
/// ```
@MainActor
public struct PaneSplitter: View {
    public let spec: SplitterSpec

    public init(spec: SplitterSpec) {
        self.spec = spec
    }

    public var body: some View {
        switch spec.orientation {
        case .horizontal:
            NativeSplitter(orientation: .horizontal, length: spec.length, onDrag: spec.onDrag)
        case .vertical:
            NativeSplitter(orientation: .vertical, length: spec.length, onDrag: spec.onDrag)
        }
    }
}