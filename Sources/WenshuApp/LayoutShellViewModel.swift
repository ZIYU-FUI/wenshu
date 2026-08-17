// LayoutShellViewModel.swift · Wenshu (Wenshu) · v0.01.0 (= minimal splitter state)
//
// macOS-only state (= Package.swift .macOS(.v27)). Single source of truth for
// splitter drag positions. v0.01.0 fixed positions (= no live band split, no
// runtime hide/show), so the VM is intentionally minimal.
//
// Boss-measured default column-splitter x positions (Sketch page 2 baseline
// 3840x1968 pt @ -1441,-587, 2026-08-17 Sketch page 2 "Home" frame, 6 groups +
// 4 vertical drag lines + 1 horizontal drag line):
//   upperRatios          [0.1042, 0.3948, 0.7896]  project-mgmt A | project-mgmt B | editor | tools
//   lowerRatios          [0.1042, 0.7896]          chat A | chat B | dynamic
// (= Boss 8/17 "按 PT 设置的大小, 是否需要转成比例"; 1:1 pt reproduction of
//  boss's drag-line x positions: v1=400, v2=1516, v3=3032.)
//
// Note: v0.01.0 had a single [library, editor, inspector] width-fraction array
// (= wenshu 7-zone layout shell per SPEC-v0.01.0.md). 2026-08-17 boss Sketch
// page 2 redesigns as 4-column upper + 3-column lower (= 6 zones, 5 vertical
// splitters + 1 horizontal). Replaced per wenshu-pocock-style macOS-only
// cleanup pattern: drop Optional fallback / dead state / dead funcs (= boss
// 8/15 14:55 "把通用逻辑代码替换 macOS 唯一", 8/15 15:14 inline v31 commit).
//
// The 50/50 upper/lower band split is HARD-CODED (= boss 19:55 lock, no
// resizable band split in v0.01.0); there is no `lowerBandRatio` state.
//
// v0.02.x had a `libraryShelfFraction` (= internal Shelf | Project split
// inside the Library zone). v50 removes it: the structure was wrong
// (= a fixed split inside a single outline list, instead of a single
// list with DisclosureGroup-style collapse/expand).
//
// Boss 19:00 fix: replaces v10's SwiftUI .frame(width: fraction) which caused
// "drag flicker area area" (= SwiftUI layout invalidates the whole tree on every drag tick).
// NativeSplitter (NSView + NSViewRepresentable) does the drag inside AppKit's NSEvent
// pipeline, not SwiftUI's render pipeline → no flicker.

import SwiftUI
import Observation

@Observable
final class LayoutShellViewModel {
    /// Upper-band column-splitter x positions (= Boss 2026-08-17 Sketch page 2
    /// "Home" baseline 3840 pt, 1:1 pt reproduction):
    ///   upperRatios[0] = 0.1042  (v1 = 400 pt, project-mgmt sub-A | sub-B)
    ///   upperRatios[1] = 0.3948  (v2 = 1516 pt, project-mgmt | editor)
    ///   upperRatios[2] = 0.7896  (v3 = 3032 pt, editor | tools)
    /// Each value is the splitter's x / totalWidth (NOT a column-width fraction).
    /// Step 1 1:1 pt (= 3840 baseline); step 3 will keep the same conceptual
    /// mapping once the boss signs off.
    var upperRatios: [Double] = [0.1042, 0.3948, 0.7896]
    /// Lower-band column-splitter x positions:
    ///   lowerRatios[0] = 0.1042  (v1 = 400 pt, chat sub-A | sub-B)
    ///   lowerRatios[1] = 0.7896  (v3 = 3032 pt, chat sub-B | Dynamic)
    var lowerRatios: [Double] = [0.1042, 0.7896]

    /// Drag bounds for any ratio (= owner拍 "常识性功能", Apple HIG splitter limits).
    static let minRatio: Double = 0.08
    static let maxRatio: Double = 0.92

    // MARK: - Splitter drag callbacks

    /// Library | Editor column splitter.
    func adjustLibraryEditor(delta: CGFloat, totalWidth: CGFloat) {
        adjustPair(
            in: &upperRatios,
            leftIndex: 0,
            rightIndex: 1,
            delta: delta,
            totalWidth: totalWidth
        )
    }

    /// Editor | Inspector column splitter.
    func adjustEditorInspector(delta: CGFloat, totalWidth: CGFloat) {
        adjustPair(
            in: &upperRatios,
            leftIndex: 1,
            rightIndex: 2,
            delta: delta,
            totalWidth: totalWidth
        )
    }

    /// Lower-band Chat | Dynamic splitter.
    func adjustChatDynamic(delta: CGFloat, totalWidth: CGFloat) {
        adjustPair(
            in: &lowerRatios,
            leftIndex: 0,
            rightIndex: 1,
            delta: delta,
            totalWidth: totalWidth
        )
    }

    /// Upper-band column splitter at the given column-pair index (0=v1, 1=v2, 2=v3).
    /// The corresponding upperRatios[i] is the x-position of column splitter i
    /// (NOT a width fraction — boss Sketch v1=400, v2=1516, v3=3032 are absolute
    /// PT positions scaled by the 3840 baseline). Drag shifts splitter i by `delta`
    /// pt; adjacent columns adjust width automatically.
    func adjustColumnUpper(idx: Int, delta: CGFloat, totalWidth: CGFloat) {
        guard totalWidth > 0, idx >= 0, idx < upperRatios.count else { return }
        let step = Double(delta / totalWidth)
        let newPos = upperRatios[idx] + step
        guard newPos >= Self.minRatio, newPos <= Self.maxRatio else { return }
        // Adjacent splitter positions: cannot cross.
        let minGap: Double = 0.02  // 2% of total width = ~77pt at 3840 baseline
        if idx > 0, newPos <= upperRatios[idx - 1] + minGap { return }
        if idx < upperRatios.count - 1, newPos >= upperRatios[idx + 1] - minGap { return }
        upperRatios[idx] = newPos
    }

    /// Lower-band column splitter at the given column-pair index (0=v1, 1=v3).
    /// Same shape as adjustColumnUpper.
    func adjustColumnLower(idx: Int, delta: CGFloat, totalWidth: CGFloat) {
        guard totalWidth > 0, idx >= 0, idx < lowerRatios.count else { return }
        let step = Double(delta / totalWidth)
        let newPos = lowerRatios[idx] + step
        guard newPos >= Self.minRatio, newPos <= Self.maxRatio else { return }
        let minGap: Double = 0.02
        if idx > 0, newPos <= lowerRatios[idx - 1] + minGap { return }
        if idx < lowerRatios.count - 1, newPos >= lowerRatios[idx + 1] - minGap { return }
        lowerRatios[idx] = newPos
    }

    /// Upper / lower band splitter — present in the view tree (= gives the user
    /// a visible divider + grab cursor on the band seam) but inert: the split is
    /// locked at 50/50 per owner 19:55. Drag does nothing.
    func adjustBandSplit() {
        // intentional no-op; band ratio is hard-coded in LayoutShellView.bandRatio
    }

    // MARK: - Internal

    /// Shared drag math: shift `leftIndex` by `delta/totalWidth`, debited from
    /// `rightIndex`. Both neighbors stay within `minRatio`..`maxRatio` or the
    /// drag is rejected (= the splitter snaps, no over-shrink).
    private func adjustPair(
        in ratios: inout [Double],
        leftIndex: Int,
        rightIndex: Int,
        delta: CGFloat,
        totalWidth: CGFloat
    ) {
        guard totalWidth > 0 else { return }
        let step = Double(delta / totalWidth)
        let newLeft = ratios[leftIndex] + step
        let newRight = ratios[rightIndex] - step
        guard newLeft >= Self.minRatio, newLeft <= Self.maxRatio,
              newRight >= Self.minRatio, newRight <= Self.maxRatio else { return }
        ratios[leftIndex] = newLeft
        ratios[rightIndex] = newRight
    }
}