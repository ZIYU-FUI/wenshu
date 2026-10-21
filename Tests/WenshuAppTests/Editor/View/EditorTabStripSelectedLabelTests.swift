// Tests/WenshuAppTests/Editor/View/EditorTabStripSelectedLabelTests.swift
//
// Regression: the selected tab in the editor's tab strip rendered as a
// blank dark capsule, with no document name on it.
//
// Cause: the strip is an `NSSegmentedControl` with `role = .tabs`. On
// macOS 27 that role draws the selected segment as a dark inset and
// leaves its LABEL UNPAINTED, so a strip whose segments carry text loses
// the active document's name. The role is meant for icon segments, where
// the symbol carries the state.
//
// The test measures the rendered pixels rather than asserting on a
// property, because the defect was a rendering behaviour and a property
// assertion would not have caught it.

import AppKit
import Testing
@testable import WenshuApp

@Suite("Editor tab strip — the selected segment paints its label")
struct EditorTabStripSelectedLabelTests {

    /// Render a segmented control the way `LabelSegmentedControl`
    /// configures it, then report the brightest pixel in each segment.
    ///
    /// A segment carrying visible text peaks near 223; a segment whose
    /// text was never painted peaks at the background level (46 under the
    /// dark appearance) and has no pixels above 140.
    @MainActor
    private func measureSelectedSegment(role: NSSegmentedControl.Role) -> (maxLuminance: Int, pixelsAbove140: Int) {
        let control = NSSegmentedControl()
        control.segmentCount = 3
        control.setLabel("First Document", forSegment: 0)
        control.setLabel("Second Document", forSegment: 1)
        control.setLabel("Third Document", forSegment: 2)
        control.segmentStyle = .roundRect
        control.trackingMode = .selectOne
        control.segmentDistribution = .fillEqually
        control.controlSize = .large
        if #available(macOS 27.0, *) {
            control.role = role
        }
        control.selectedSegment = 1

        let width: CGFloat = 600
        let height: CGFloat = 40
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        let host = NSView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        host.wantsLayer = true
        host.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        host.addSubview(control)
        control.frame = NSRect(x: 0, y: 0, width: width, height: height)
        window.contentView = host
        window.orderFront(nil)
        host.layoutSubtreeIfNeeded()
        control.layoutSubtreeIfNeeded()
        window.displayIfNeeded()

        let bounds = host.bounds
        let result = host.bitmapImageRepForCachingDisplay(in: bounds).map { rep -> (Int, Int) in
            rep.size = bounds.size
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
            NSColor.windowBackgroundColor.setFill()
            bounds.fill()
            NSGraphicsContext.restoreGraphicsState()
            host.cacheDisplay(in: bounds, to: rep)

            guard let data = rep.bitmapData else { return (0, 0) }
            let pixelsWide = rep.pixelsWide
            let bytesPerRow = rep.bytesPerRow
            let samples = rep.samplesPerPixel
            let selectedStart = pixelsWide / 3
            let selectedEnd = (pixelsWide * 2) / 3
            var maxLuminance = 0
            var pixelsAbove140 = 0
            for y in 0..<rep.pixelsHigh {
                for x in selectedStart..<selectedEnd {
                    let offset = y * bytesPerRow + x * samples
                    let luminance = (
                        Int(data[offset]) * 299
                            + Int(data[offset + 1]) * 587
                            + Int(data[offset + 2]) * 114
                    ) / 1000
                    if luminance > maxLuminance { maxLuminance = luminance }
                    if luminance > 140 { pixelsAbove140 += 1 }
                }
            }
            return (maxLuminance, pixelsAbove140)
        }
        window.orderOut(nil)
        return result ?? (0, 0)
    }

    @Test("The selected segment's label is painted when the role is valueSelection")
    @MainActor
    func selectedLabelIsPainted() throws {
        let measurement = measureSelectedSegment(role: .valueSelection)
        #expect(
            measurement.pixelsAbove140 > 0,
            """
            The selected segment painted no text (max luminance \
            \(measurement.maxLuminance), \(measurement.pixelsAbove140) pixels \
            above 140). A text-labelled tab strip must not use the `.tabs` role.
            """
        )
    }

    @Test("The tabs role leaves the selected segment's label unpainted")
    @MainActor
    func tabsRoleHidesSelectedLabel() throws {
        // This asserts the platform behaviour that caused the defect, so
        // that a future macOS release which fixes it shows up as a failing
        // expectation rather than as a silent behaviour change.
        let measurement = measureSelectedSegment(role: .tabs)
        #expect(
            measurement.pixelsAbove140 == 0,
            """
            The `.tabs` role painted the selected segment's label \
            (\(measurement.pixelsAbove140) pixels above 140). If macOS now \
            paints it, this expectation can be retired, but the tab strip \
            must still keep the role that shows the document name.
            """
        )
    }
}
