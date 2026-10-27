//
//  LabelSegmentedControlShapeTests.swift
//
//  The shared segmented control must draw a CAPSULE, not a rounded
//  rectangle.
//
//  The shape is not a free choice: `NSControl.borderShape` decides it,
//  and its DEFAULT is not the same shape at every control size.
//  Measured on macOS 27.0.1 (2x pixels, a labelled control):
//
//    .small  + automatic -> bezel 40 px, top row inset  6 px => ROUNDRECT
//    .small  + .capsule  -> bezel 40 px, top row inset 15 px => CAPSULE
//    .large  + automatic -> bezel 56 px, top row inset 22 px => CAPSULE
//    .large  + .capsule  -> bezel 56 px, top row inset 22 px => CAPSULE
//
//  So at the switcher's `.small` size the default bezel is a rounded
//  rectangle: its top row is nearly full width, because the corner
//  radius is small. A capsule's top row is inset by about half its
//  height, because the radius IS half the height. The same bytes are
//  drawn at `.large` either way, so asking for the capsule changes the
//  small control and leaves the large one alone.
//
//  The test measures the RENDERED bezel of the REAL production
//  control, because the defect is a rendering behaviour: a property
//  assertion alone would pass against a control AppKit ignores.
//

import AppKit
import SwiftUI
import Testing
@testable import WenshuApp

@MainActor
@Suite("Segmented control shape — the drawn bezel is a capsule")
struct LabelSegmentedControlShapeTests {

    /// The drawn bezel of a control: how far the topmost painted row
    /// is inset from the bezel's own left edge, and how tall the bezel
    /// is.
    ///
    /// A capsule's top row is inset by about half its height; a
    /// rounded rectangle's top row is nearly full width.
    private struct Bezel {
        let topRowInset: Int
        let height: Int

        /// Whether the drawn shape is a capsule (= the top row is
        /// inset by more than a third of the bezel's height).
        var isCapsule: Bool { topRowInset * 3 > height }
    }

    /// Find the `NSSegmentedControl` inside a view tree.
    private func segmentedControl(in view: NSView) -> NSSegmentedControl? {
        if let control = view as? NSSegmentedControl { return control }
        for subview in view.subviews {
            if let found = segmentedControl(in: subview) { return found }
        }
        return nil
    }

    /// The production control, configured by the production code, at a
    /// given control size.
    private func productionControl(controlSize: NSControl.ControlSize) throws -> NSSegmentedControl {
        // The production view. The wrapper is generic over its
        // selection type, so an Int selection exercises it without
        // changing the control's own configuration.
        let view = LabelSegmentedControl(
            selection: .constant(0),
            labels: [0, 1, 2],
            displayStrings: ["One", "Two", "Three"],
            controlSize: controlSize
        )
        let host = NSHostingView(rootView: view)
        host.frame = NSRect(x: 0, y: 0, width: 260, height: 60)
        let window = NSWindow(
            contentRect: host.frame,
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.contentView = host
        window.orderFront(nil)
        host.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.4))
        host.layoutSubtreeIfNeeded()
        let control = try #require(segmentedControl(in: host))
        // The control keeps its production configuration after it
        // leaves the hosting view, so the measurement below reads the
        // bezel the production code asked for.
        control.removeFromSuperview()
        window.orderOut(nil)
        return control
    }

    /// Render a control the way AppKit draws it, and measure the
    /// bezel it paints.
    ///
    /// The control sits alone in a plain container over a white
    /// background: the bezel is the only thing painted, so "a pixel
    /// that is not white" is the bezel's own edge on that row.
    private func drawnBezel(of control: NSSegmentedControl) -> Bezel? {
        let width: CGFloat = 240, height: CGFloat = 80
        let container = NSView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        let window = NSWindow(
            contentRect: container.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.appearance = NSAppearance(named: .aqua)
        window.backgroundColor = .white
        window.contentView = container
        container.addSubview(control)
        window.orderFront(nil)
        container.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        let controlHeight = max(control.fittingSize.height, 16)
        control.frame = NSRect(x: 10, y: (height - controlHeight) / 2, width: 200, height: controlHeight)
        container.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.6))

        let bounds = container.bounds
        let rep = container.bitmapImageRepForCachingDisplay(in: bounds)!
        rep.size = bounds.size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSColor.white.setFill()
        bounds.fill()
        NSGraphicsContext.restoreGraphicsState()
        container.cacheDisplay(in: bounds, to: rep)
        window.orderOut(nil)

        guard let data = rep.bitmapData else { return nil }
        let pixelsWide = rep.pixelsWide
        let pixelsHigh = rep.pixelsHigh
        let bytesPerRow = rep.bytesPerRow
        let samples = rep.samplesPerPixel

        func isPainted(_ x: Int, _ y: Int) -> Bool {
            let offset = y * bytesPerRow + x * samples
            let luminance = (
                Int(data[offset]) * 299
                    + Int(data[offset + 1]) * 587
                    + Int(data[offset + 2]) * 114
            ) / 1000
            return luminance < 252
        }

        // Every row that carries any paint, and the leftmost painted
        // pixel on it (= the bezel's edge on that row).
        var rows: [(y: Int, left: Int)] = []
        for y in 0..<pixelsHigh {
            var left = -1
            for x in 0..<pixelsWide where isPainted(x, y) { left = x; break }
            if left >= 0 { rows.append((y, left)) }
        }
        guard let first = rows.first, let last = rows.last else { return nil }
        let bezelLeft = rows.map { $0.left }.min() ?? first.left
        return Bezel(
            topRowInset: first.left - bezelLeft,
            height: last.y - first.y + 1
        )
    }

    @Test("The control asks AppKit for a capsule bezel")
    @MainActor
    func theControlAsksForACapsule() throws {
        let control = try productionControl(controlSize: .small)
        #expect(
            control.borderShape == .capsule,
            """
            The shared control asks AppKit for the \(control.borderShape) \
            bezel. The default bezel is a rounded rectangle at the \
            switcher's `.small` size, so the drawn pill is not a capsule.
            """
        )
    }

    @Test("The drawn bezel at the switcher's size is a capsule")
    @MainActor
    func theDrawnBezelIsACapsule() throws {
        let bezel = try #require(drawnBezel(of: try productionControl(controlSize: .small)))
        #expect(
            bezel.isCapsule,
            """
            The drawn bezel is not a capsule: its top row is inset \
            \(bezel.topRowInset) px on a \(bezel.height) px bezel \
            (= a rounded rectangle). A capsule's top row is inset by \
            about half the bezel's height.
            """
        )
    }

    @Test("The drawn bezel at the tab strip's size is a capsule too")
    @MainActor
    func theDrawnBezelIsACapsuleAtTheLargeSize() throws {
        let bezel = try #require(drawnBezel(of: try productionControl(controlSize: .large)))
        #expect(
            bezel.isCapsule,
            """
            The drawn bezel at `.large` is not a capsule: its top row \
            is inset \(bezel.topRowInset) px on a \(bezel.height) px bezel.
            """
        )
    }
}
