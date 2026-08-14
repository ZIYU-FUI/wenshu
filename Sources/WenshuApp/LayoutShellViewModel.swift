// LayoutShellViewModel.swift · Wenshu (Wenshu) · v0.01.0 (= minimal splitter state)
//
// Single source of truth for splitter drag ratios in v0.01.0 (= 5 ratios: 3 upper columns
// + 2 lower columns). FCP-measured default proportions:
//   ratios[0] = Library   0.125
//   ratios[1] = Editor    0.310 (of upper band)
//   ratios[2] = Inspector 0.160 (of upper band)
//   ratios[3] = Lower band height (= 0.50 of total)
//   ratios[4] = Console   0.50  (of lower band right side)
//
// Library internally splits Shelf/Project 30/70 (= hardcoded, not user-resizable in v0.01.0).
// Console+Status splits 50/50 (hardcoded).
//
// Boss 19:00 fix: replaces v10's SwiftUI .frame(width: fraction) which caused
// "拖拽时区域闪烁" (= SwiftUI layout invalidates the whole tree on every drag tick).
// NativeSplitter (NSView + NSViewRepresentable) does the drag inside AppKit's NSEvent
// pipeline, not SwiftUI's render pipeline → no flicker.

import SwiftUI
import Observation

@Observable
final class LayoutShellViewModel {
    /// Upper-band horizontal split ratios (= FCP-measured, owner 19:10 "精准测量"):
    ///   Library 20.7% / Editor 51.7% / Inspector 27.6% (= 300/750/400 of 1452pt total).
    /// Library is widest at 20.7% (= FCP 实测 Library 列 x=0..300 pt); Editor is widest
    /// at 51.7% (= FCP Viewer x=300..1050 pt); Inspector at 27.6% (= FCP x=1050..1450).
    var upperRatios: [Double] = [0.207, 0.517, 0.276]
    /// Lower-band vertical-vs-upper split ratio (= 0.50 = half-half).
    var lowerBandRatio: Double = 0.50
    /// Lower-band horizontal split ratios. ratios[0]+ratios[1] = 1.0.
    /// ratios[0] = Chat, ratios[1] = Console+Status half (= total right side share).
    var lowerRatios: [Double] = [0.25, 0.75]
    /// Console|Status internal split (= 0.50 = half-half).
    var consoleStatusRatio: Double = 0.50

    /// Min/max bounds (= owner拍 "常识性功能", Apple HIG splitter limits).
    static let minRatio: Double = 0.08
    static let maxRatio: Double = 0.92
    static let minLowerBandRatio: Double = 0.20
    static let maxLowerBandRatio: Double = 0.80

    /// Drag callback from upper-band NativeSplitter(splitterIndex 0 or 1).
    /// `splitterIndex` = 0 means split between ratios[0] (Library) and ratios[1] (Editor);
    /// = 1 means split between ratios[1] (Editor) and ratios[2] (Inspector).
    func adjustUpperColumn(splitterIndex: Int, delta: CGFloat, totalWidth: CGFloat) {
        guard totalWidth > 0 else { return }
        guard splitterIndex == 0 || splitterIndex == 1 else { return }
        let left = splitterIndex
        let right = splitterIndex + 1
        let available = totalWidth
        guard available > 0 else { return }
        let deltaRatio = Double(delta / available)

        // Move delta from `right` to `left` when delta > 0 (= drag right → left grows).
        let newLeft = upperRatios[left] + deltaRatio
        let newRight = upperRatios[right] - deltaRatio

        guard newLeft >= Self.minRatio, newLeft <= Self.maxRatio,
              newRight >= Self.minRatio, newRight <= Self.maxRatio else { return }

        var updated = upperRatios
        updated[left] = newLeft
        updated[right] = newRight
        upperRatios = updated
    }

    /// Drag callback from upper/lower band horizontal NativeSplitter (= split heights).
    func adjustLowerBandHeight(delta: CGFloat, totalHeight: CGFloat) {
        guard totalHeight > 0 else { return }
        // NativeSplitter axisDelta: vertical orientation → start.y - current.y > 0 = drag down.
        // Drag down should shrink lower band (lower band pushes up).
        let deltaRatio = Double(delta / totalHeight)
        let newRatio = lowerBandRatio - deltaRatio
        guard newRatio >= Self.minLowerBandRatio, newRatio <= Self.maxLowerBandRatio else { return }
        lowerBandRatio = newRatio
    }

    /// Drag callback from lower-band NativeSplitter (split between Chat and Console+Status).
    func adjustLowerColumn(delta: CGFloat, totalWidth: CGFloat) {
        guard totalWidth > 0 else { return }
        let deltaRatio = Double(delta / totalWidth)
        let newLeft = lowerRatios[0] + deltaRatio
        let newRight = lowerRatios[1] - deltaRatio
        guard newLeft >= Self.minRatio, newLeft <= Self.maxRatio,
              newRight >= Self.minRatio, newRight <= Self.maxRatio else { return }
        lowerRatios = [newLeft, newRight]
    }

    /// Drag callback from Console|Status internal NativeSplitter.
    func adjustConsoleStatus(delta: CGFloat, totalWidth: CGFloat) {
        guard totalWidth > 0 else { return }
        let deltaRatio = Double(delta / totalWidth)
        let newLeft = consoleStatusRatio + deltaRatio
        let newRight = (1.0 - consoleStatusRatio) - deltaRatio
        guard newLeft >= Self.minRatio, newLeft <= Self.maxRatio,
              newRight >= Self.minRatio, newRight <= Self.maxRatio else { return }
        consoleStatusRatio = newLeft
    }
}