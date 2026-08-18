// LayoutShellViewModel.swift · Wenshu (Wenshu) · v0.01.0 (= minimal splitter state)
//
// macOS-only state (= Package.swift .macOS(.v27)). Single source of truth for
// splitter drag ratios. v0.01.0 fixed ratios (= no live band split, no runtime
// hide/show), so the VM is intentionally minimal.
//
// FCP-measured default proportions (1452x984 baseline, owner 19:10 / 19:45):
//   upperRatios       [0.20, 0.50, 0.30]  Library | Editor | Inspector
//   lowerRatios       [0.70, 0.30]        Chat    | Console+Status
//   consoleStatusRatio 0.50                Console | Status  (internal 1:1)
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
// "拖拽时区域闪烁" (= SwiftUI layout invalidates the whole tree on every drag tick).
// NativeSplitter (NSView + NSViewRepresentable) does the drag inside AppKit's NSEvent
// pipeline, not SwiftUI's render pipeline → no flicker.

import SwiftUI
import Observation

@Observable
final class LayoutShellViewModel {
    /// Upper-band horizontal split ratios (= boss 19:45 口头约束 v0.01.0):
    ///   Library 20% / Editor 50% / Inspector 30% (= 0.20/0.50/0.30 of upper-band usable width).
    /// Boss 19:45 "library 20, editor 50, inspector 30".
    var upperRatios: [Double] = [0.20, 0.50, 0.30]
    /// Lower-band horizontal split ratios (= boss 19:45 "chat 70").
    /// Chat 70% of lower-band usable width, right side 30% (= Console + Status together).
    /// ratios[0] = Chat 0.70, ratios[1] = Console+Status 0.30.
    var lowerRatios: [Double] = [0.70, 0.30]
    /// Console|Status internal split (= boss 19:45 "console 15 status 15" =
    ///   each = 15% of total = 50% of right-side-30% = 0.50 internal).
    var consoleStatusRatio: Double = 0.50

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

    /// Lower-band Chat | Console+Status splitter.
    func adjustChatConsole(delta: CGFloat, totalWidth: CGFloat) {
        adjustPair(
            in: &lowerRatios,
            leftIndex: 0,
            rightIndex: 1,
            delta: delta,
            totalWidth: totalWidth
        )
    }

    /// Console | Status internal splitter.
    func adjustConsoleStatus(delta: CGFloat, totalWidth: CGFloat) {
        let clamped = min(
            max(consoleStatusRatio + Double(delta / totalWidth), Self.minRatio),
            Self.maxRatio
        )
        consoleStatusRatio = clamped
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