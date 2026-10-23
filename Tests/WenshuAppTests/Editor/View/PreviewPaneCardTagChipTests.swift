//
//  PreviewPaneCardTagChipTests.swift
//
//  A material card's tag chip must read as QUIET METADATA: a label that
//  is clearly readable, on a pill that reads as a surface, and a pill
//  that hugs its label.
//
//  These assertions measure the RENDERED pixels of the real chip
//  (`CardTagChip`, the recipe the card actually draws), not the source
//  text: the label's contrast against its own pill and the pill's
//  contrast against the ground behind it are both read back from the
//  painted frame.
//
//  The ground is the point. A white label on a translucent white pill
//  measured 3.07:1 on a PALE cover (= every generated cover in the
//  library is a pale Chinese landscape painting), so the test renders
//  over a pale ground: a dark test ground would pass against the
//  broken recipe.
//

import Foundation
import Testing
import SwiftUI
import AppKit
@testable import WenshuApp

@MainActor
@Suite("Card tag chip — the tag reads as quiet metadata")
struct PreviewPaneCardTagChipTests {

    /// The pale ground the chip is measured over (= the colour of the
    /// palest cover in the library, a cream-and-gold painting, UNDER the
    /// card's black wash, = the ground the tag row actually sits on).
    private static let paleGround = (r: 126, g: 112, b: 92)

    /// The dark ground the chip is measured over (= a dark painting
    /// under the same wash).
    private static let darkGround = (r: 44, g: 40, b: 35)

    /// The ground of a card with no picture (= the paper gradient's
    /// bottom-left, where the words sit in ink).
    private static let paperGround = (r: 199, g: 187, b: 168)

    /// The tag the chip carries (= two characters, = the case that
    /// measured as a wide lozenge before).
    private static let tag = "大纲"

    /// One rendered frame of the real chip.
    private struct Frame {
        let bytes: [UInt8]
        let pixelWidth: Int
        let pixelHeight: Int
        let ground: (r: Int, g: Int, b: Int)

        func rgb(x: Int, y: Int) -> (r: Int, g: Int, b: Int) {
            let i = (y * pixelWidth + x) * 4
            return (Int(bytes[i]), Int(bytes[i + 1]), Int(bytes[i + 2]))
        }

        /// True when the pixel is far enough from the ground to be the
        /// chip's fill or its glyphs (= the antialiasing fringe of the
        /// pill's edge is not).
        func isChip(x: Int, y: Int) -> Bool {
            let p = rgb(x: x, y: y)
            let g = ground
            return abs(p.r - g.r) > 12 || abs(p.g - g.g) > 12 || abs(p.b - g.b) > 12
        }
    }

    /// Renders the REAL chip over the given ground and returns the
    /// painted frame.
    ///
    /// The chip is rendered through `NSHostingView` +
    /// `cacheDisplay(in:to:)`, the way the app's own surfaces are
    /// measured, so the numbers are the numbers the app paints.
    private func renderChip(over ground: (r: Int, g: Int, b: Int), hasCover: Bool) -> Frame? {
        let chip = CardTagChip(tag: Self.tag, hasCover: hasCover)
        let hosting = NSHostingView(
            rootView: chip.padding(20).background(Color(nsColor: .clear))
        )
        hosting.frame = NSRect(x: 0, y: 0, width: 160, height: 44)
        hosting.appearance = NSAppearance(named: .aqua)
        hosting.layoutSubtreeIfNeeded()
        hosting.displayIfNeeded()

        guard let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else {
            return nil
        }
        rep.size = hosting.bounds.size
        // Paint the ground first, so a pixel that differs from it is a
        // pixel the chip drew.
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSColor(
            calibratedRed: Double(ground.r) / 255,
            green: Double(ground.g) / 255,
            blue: Double(ground.b) / 255,
            alpha: 1
        ).setFill()
        hosting.bounds.fill()
        NSGraphicsContext.restoreGraphicsState()
        hosting.cacheDisplay(in: hosting.bounds, to: rep)

        guard let data = rep.bitmapData else { return nil }
        let width = rep.pixelsWide
        let height = rep.pixelsHigh
        let rowBytes = rep.bytesPerRow
        let samples = rep.samplesPerPixel
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        for y in 0 ..< height {
            for x in 0 ..< width {
                let source = y * rowBytes + x * samples
                let destination = (y * width + x) * 4
                bytes[destination] = data[source]
                bytes[destination + 1] = data[source + 1]
                bytes[destination + 2] = data[source + 2]
                bytes[destination + 3] = 255
            }
        }
        return Frame(
            bytes: bytes,
            pixelWidth: width,
            pixelHeight: height,
            ground: ground
        )
    }

    /// The relative luminance of a colour, per WCAG.
    private func luminance(_ colour: (r: Int, g: Int, b: Int)) -> Double {
        func channel(_ value: Int) -> Double {
            let c = Double(value) / 255
            return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(colour.r)
            + 0.7152 * channel(colour.g)
            + 0.0722 * channel(colour.b)
    }

    /// The contrast ratio between two colours, per WCAG.
    private func contrast(
        _ a: (r: Int, g: Int, b: Int),
        _ b: (r: Int, g: Int, b: Int)
    ) -> Double {
        let la = luminance(a)
        let lb = luminance(b)
        let hi = max(la, lb)
        let lo = min(la, lb)
        return (hi + 0.05) / (lo + 0.05)
    }

    /// The chip's own pixels, split into its LABEL (= the extreme
    /// tone) and its FILL (= the pill's own wash).
    ///
    /// The label is the brightest (or darkest) painted pixel; the fill
    /// is the modal painted colour (= the pill covers far more area
    /// than the strokes do).
    private func splitChip(in frame: Frame) -> (label: (r: Int, g: Int, b: Int), fill: (r: Int, g: Int, b: Int), widthPx: Int)? {
        var minX = frame.pixelWidth, maxX = -1
        var minY = frame.pixelHeight, maxY = -1
        for y in 0 ..< frame.pixelHeight {
            for x in 0 ..< frame.pixelWidth where frame.isChip(x: x, y: y) {
                if x < minX { minX = x }
                if x > maxX { maxX = x }
                if y < minY { minY = y }
                if y > maxY { maxY = y }
            }
        }
        guard maxX >= 0, maxY >= 0 else { return nil }

        var painted: [(r: Int, g: Int, b: Int)] = []
        for y in (minY + 1) ..< maxY {
            for x in (minX + 1) ..< maxX where frame.isChip(x: x, y: y) {
                painted.append(frame.rgb(x: x, y: y))
            }
        }
        guard !painted.isEmpty else { return nil }

        // The FILL = the most frequent painted colour (= the pill's
        // own wash; = the glyphs cover far less area).
        var counts: [Int: Int] = [:]
        for p in painted {
            counts[p.r << 16 | p.g << 8 | p.b, default: 0] += 1
        }
        let fillKey = counts.max { $0.value < $1.value }?.key ?? 0
        let fill = (
            r: (fillKey >> 16) & 0xFF,
            g: (fillKey >> 8) & 0xFF,
            b: fillKey & 0xFF
        )

        // The LABEL = the painted pixel furthest from the GROUND, but
        // the label's own SHADOW is painted too, and on a dark pill a
        // black shadow is FURTHER from the ground than the white glyph
        // is. So the label is the extreme tone on the side the LABEL
        // is on: the glyphs are the brightest pixels when the pill is
        // darker than the ground, and the darkest when it is lighter.
        let groundLum = luminance(frame.ground)
        let fillIsDarker = luminance(fill) < groundLum
        let label = painted.max { lhs, rhs in
            if fillIsDarker {
                return luminance(lhs) < luminance(rhs)
            } else {
                return luminance(lhs) > luminance(rhs)
            }
        } ?? painted[0]

        return (label: label, fill: fill, widthPx: maxX - minX + 1)
    }

    @Test("On a pale cover the tag's label is clearly readable against its own pill")
    func paleCoverLabelIsReadable() throws {
        let frame = try #require(renderChip(over: Self.paleGround, hasCover: true))
        let chip = try #require(splitChip(in: frame))

        let labelOnPill = contrast(chip.label, chip.fill)
        #expect(
            labelOnPill >= 4.5,
            """
            the tag's label must be readable on its own pill over a pale cover: \
            measured \(String(format: "%.2f", labelOnPill)):1 \
            (label \(chip.label), pill \(chip.fill))
            """
        )
    }

    @Test("On a dark cover the tag's label is clearly readable against its own pill")
    func darkCoverLabelIsReadable() throws {
        let frame = try #require(renderChip(over: Self.darkGround, hasCover: true))
        let chip = try #require(splitChip(in: frame))

        let labelOnPill = contrast(chip.label, chip.fill)
        #expect(
            labelOnPill >= 4.5,
            """
            the tag's label must be readable on its own pill over a dark cover: \
            measured \(String(format: "%.2f", labelOnPill)):1 \
            (label \(chip.label), pill \(chip.fill))
            """
        )
    }

    @Test("On paper the tag's label is clearly readable against its own pill")
    func paperLabelIsReadable() throws {
        let frame = try #require(renderChip(over: Self.paperGround, hasCover: false))
        let chip = try #require(splitChip(in: frame))

        let labelOnPill = contrast(chip.label, chip.fill)
        #expect(
            labelOnPill >= 4.5,
            """
            the tag's label must be readable on its own pill on paper: \
            measured \(String(format: "%.2f", labelOnPill)):1 \
            (label \(chip.label), pill \(chip.fill))
            """
        )
    }

    @Test("The tag is never an invisible smudge on any ground")
    func pillIsAVisibleSurface() throws {
        // A tag must be READABLE. It does not have to be a visible
        // SURFACE in every case: on a cover the pill is a scrim (= its
        // job is to give the white label a darker ground to sit on),
        // and on an already-dark artwork the scrim has nothing left to
        // darken, so the label's own contrast against the artwork
        // carries the read instead.
        //
        // So the tag passes if EITHER the pill reads as a surface
        // against the ground (>= 1.3:1) OR the label reads against
        // the ground directly (>= 4.5:1). A tag that fails BOTH is a
        // smudge: it disappears into the card.
        for (name, ground, hasCover) in [
            ("pale cover", Self.paleGround, true),
            ("dark cover", Self.darkGround, true),
            ("paper", Self.paperGround, false)
        ] {
            let frame = try #require(renderChip(over: ground, hasCover: hasCover))
            let chip = try #require(splitChip(in: frame))

            let pillOnGround = contrast(chip.fill, ground)
            let labelOnGround = contrast(chip.label, ground)
            #expect(
                pillOnGround >= 1.3 || labelOnGround >= 4.5,
                """
                the tag must not be an invisible smudge on \(name): \
                the pill is \(String(format: "%.2f", pillOnGround)):1 against the \
                ground and the label is \(String(format: "%.2f", labelOnGround)):1 \
                (pill \(chip.fill), label \(chip.label), ground \(ground))
                """
            )
        }
    }

    @Test("The tag's pill hugs its label instead of being a wide lozenge")
    func pillHugsItsLabel() throws {
        let frame = try #require(renderChip(over: Self.paleGround, hasCover: true))
        let chip = try #require(splitChip(in: frame))

        // The pill's width in points, against the label's own width.
        // The label is the extreme tone; the pill's width is the
        // painted extent.
        var minX = frame.pixelWidth, maxX = -1
        for y in 0 ..< frame.pixelHeight {
            for x in 0 ..< frame.pixelWidth where frame.isChip(x: x, y: y) {
                if x < minX { minX = x }
                if x > maxX { maxX = x }
            }
        }
        let pillWidthPx = maxX - minX + 1
        let scale = Double(frame.pixelWidth) / 160.0
        let pillWidthPt = Double(pillWidthPx) / scale

        // The glyphs alone: the columns holding the extreme tone.
        let groundLum = luminance(frame.ground)
        var glyphMinX = frame.pixelWidth, glyphMaxX = -1
        for y in 0 ..< frame.pixelHeight {
            for x in 0 ..< frame.pixelWidth where frame.isChip(x: x, y: y) {
                let p = frame.rgb(x: x, y: y)
                if abs(luminance(p) - groundLum) > 0.35 {
                    if x < glyphMinX { glyphMinX = x }
                    if x > glyphMaxX { glyphMaxX = x }
                }
            }
        }
        let glyphWidthPt = glyphMaxX >= glyphMinX
            ? Double(glyphMaxX - glyphMinX + 1) / scale
            : 0

        // The old recipe used 8 PT of horizontal padding on each side,
        // so the pill was the label's width plus 16 PT. It must now be
        // narrower than that.
        #expect(
            pillWidthPt < glyphWidthPt + 16,
            """
            the tag's pill must hug its label: the pill is \
            \(String(format: "%.1f", pillWidthPt)) PT wide for \
            \(String(format: "%.1f", glyphWidthPt)) PT of label
            """
        )
    }
}
