//
//  ChatUserBubbleShapeTests.swift
//
//  The user's own message must read as a BUBBLE: a pill that hugs its
//  words, sized to the message, sitting on the trailing edge of the
//  chat column, with fully rounded ends and no hairline.
//
//  These assertions measure the RENDERED GEOMETRY of the real
//  `ChatMessageView` (= NSHostingView + cacheDisplay), not the source
//  text: the bubble's painted extent, its end profile and its
//  trailing edge are all read back from the pixels.
//

import Foundation
import Testing
import SwiftUI
import AppKit
@testable import WenshuApp

// The palette is MainActor-isolated (= it reads the actor-isolated
// DesignTokens), so the suite runs on the main actor too.
@MainActor
@Suite("Chat user bubble shape — the outgoing bubble hugs its words")
struct ChatUserBubbleShapeTests {

    /// The chat column width the bubble is measured inside (= the
    /// width the running app's chat column measures).
    private static let columnWidth: CGFloat = 723

    /// A backdrop colour no chat surface can collide with (= the
    /// bubble's fill and its glyphs are both clearly different from
    /// it, so "painted" pixels are unambiguous).
    private static let backdrop = (r: 255, g: 0, b: 255)

    /// One rendered frame of the real message view.
    private struct Frame {
        /// RGBA bytes, row-major, top row first.
        let bytes: [UInt8]
        let pixelWidth: Int
        let pixelHeight: Int
        /// Device pixels per point.
        let scale: CGFloat
        /// The colour of the backdrop the bubble was rendered on.
        let backdrop: (r: Int, g: Int, b: Int)
        /// The colour of the bubble's fill as painted.
        let fill: (r: Int, g: Int, b: Int)

        func rgb(x: Int, y: Int) -> (r: Int, g: Int, b: Int) {
            let i = (y * pixelWidth + x) * 4
            return (Int(bytes[i]), Int(bytes[i + 1]), Int(bytes[i + 2]))
        }

        /// True when the pixel is far enough from the backdrop to be
        /// part of the bubble (= its fill or its glyphs; = the faint
        /// antialiasing fringe of the bubble's edge is not).
        func isPainted(x: Int, y: Int) -> Bool {
            let p = rgb(x: x, y: y)
            let b = backdrop
            return abs(p.r - b.r) > 12 || abs(p.g - b.g) > 12 || abs(p.b - b.b) > 12
        }

        /// How much of the pixel the bubble's fill covers (= 1 = solid
        /// fill, 0 = untouched backdrop).
        ///
        /// The fill and the backdrop are opaque, so a pixel on the
        /// bubble's edge is a blend of the two: the blend's distance
        /// along the backdrop -> fill line is its coverage.
        func coverage(x: Int, y: Int) -> Double {
            let p = rgb(x: x, y: y)
            let dr = Double(fill.r - backdrop.r)
            let dg = Double(fill.g - backdrop.g)
            let db = Double(fill.b - backdrop.b)
            let lengthSquared = dr * dr + dg * dg + db * db
            guard lengthSquared > 0 else { return 0 }
            let pr = Double(p.r - backdrop.r)
            let pg = Double(p.g - backdrop.g)
            let pb = Double(p.b - backdrop.b)
            let t = (pr * dr + pg * dg + pb * db) / lengthSquared
            return min(1, max(0, t))
        }

        /// The bubble's leading edge (= its leftmost painted edge), in
        /// device pixels, sub-pixel accurate.
        ///
        /// The edge cell holds the fill's coverage on its trailing
        /// side, so the edge sits one coverage step inside the cell.
        func leadingEdge(row: Int) -> CGFloat? {
            for x in 0 ..< pixelWidth where isPainted(x: x, y: row) {
                return CGFloat(x) + 1 - CGFloat(coverage(x: x, y: row))
            }
            return nil
        }

        /// The bubble's trailing edge, in device pixels, sub-pixel
        /// accurate.
        func trailingEdge(row: Int) -> CGFloat? {
            for x in stride(from: pixelWidth - 1, through: 0, by: -1)
            where isPainted(x: x, y: row) {
                return CGFloat(x) + CGFloat(coverage(x: x, y: row))
            }
            return nil
        }

        /// The bubble's top edge, in device pixels, sub-pixel accurate.
        func topEdge(column: Int) -> CGFloat? {
            for y in 0 ..< pixelHeight where isPainted(x: column, y: y) {
                return CGFloat(y) + 1 - CGFloat(coverage(x: column, y: y))
            }
            return nil
        }

        /// The bubble's bottom edge, in device pixels, sub-pixel
        /// accurate.
        func bottomEdge(column: Int) -> CGFloat? {
            for y in stride(from: pixelHeight - 1, through: 0, by: -1)
            where isPainted(x: column, y: y) {
                return CGFloat(y) + CGFloat(coverage(x: column, y: y))
            }
            return nil
        }
    }

    /// The bubble's painted bounding box (= its fill and its glyphs).
    private struct Extent {
        let left: CGFloat
        let right: CGFloat
        let top: CGFloat
        let bottom: CGFloat
        var width: CGFloat { right - left }
        var height: CGFloat { bottom - top }
    }

    /// Render the REAL outgoing message view over a known backdrop.
    ///
    /// The hosting view is deliberately windowless: the bubble's
    /// geometry is a pure layout question, and a window would raise a
    /// panel on the user's screen for nothing.
    private func render(_ text: String, appearance: NSAppearance) -> Frame? {
        let message = ChatMessage(role: .user, source: .user, content: text)
        let root = ChatMessageView(message: message)
            .frame(width: Self.columnWidth, alignment: .leading)
            .background(Color(
                red: Double(Self.backdrop.r) / 255,
                green: Double(Self.backdrop.g) / 255,
                blue: Double(Self.backdrop.b) / 255
            ))

        let hosting = NSHostingView(rootView: AnyView(root))
        hosting.appearance = appearance
        hosting.frame = NSRect(x: 0, y: 0, width: Self.columnWidth, height: 200)
        hosting.layoutSubtreeIfNeeded()
        hosting.displayIfNeeded()

        guard let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else {
            return nil
        }
        rep.size = hosting.bounds.size
        // Paint the backdrop first, so a pixel that differs from it is
        // a pixel the view drew.
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSColor(
            calibratedRed: Double(Self.backdrop.r) / 255,
            green: Double(Self.backdrop.g) / 255,
            blue: Double(Self.backdrop.b) / 255,
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

        // The fill's own colour (= the most frequent painted colour:
        // the glyphs cover far less area than the fill).
        let painted = Frame(
            bytes: bytes,
            pixelWidth: width,
            pixelHeight: height,
            scale: CGFloat(width) / Self.columnWidth,
            backdrop: Self.backdrop,
            fill: Self.backdrop
        )
        let fill = dominantPaintedColour(of: painted) ?? Self.backdrop
        return Frame(
            bytes: bytes,
            pixelWidth: width,
            pixelHeight: height,
            scale: CGFloat(width) / Self.columnWidth,
            backdrop: Self.backdrop,
            fill: fill
        )
    }

    /// The most frequent painted colour (= the bubble's fill).
    private func dominantPaintedColour(of frame: Frame) -> (r: Int, g: Int, b: Int)? {
        var minX = frame.pixelWidth, maxX = -1
        var minY = frame.pixelHeight, maxY = -1
        for y in 0 ..< frame.pixelHeight {
            for x in 0 ..< frame.pixelWidth where frame.isPainted(x: x, y: y) {
                if x < minX { minX = x }
                if x > maxX { maxX = x }
                if y < minY { minY = y }
                if y > maxY { maxY = y }
            }
        }
        guard maxX >= 0 else { return nil }
        var counts: [Int: Int] = [:]
        for y in (minY + 2) ..< maxY {
            for x in (minX + 2) ..< maxX where frame.isPainted(x: x, y: y) {
                let p = frame.rgb(x: x, y: y)
                counts[p.r << 16 | p.g << 8 | p.b, default: 0] += 1
            }
        }
        guard let key = counts.max(by: { $0.value < $1.value })?.key else { return nil }
        return (key >> 16 & 0xFF, key >> 8 & 0xFF, key & 0xFF)
    }

    /// The painted extent of the bubble, in points.
    private func extent(of frame: Frame) -> Extent? {
        var minX = frame.pixelWidth, maxX = -1
        var minY = frame.pixelHeight, maxY = -1
        for y in 0 ..< frame.pixelHeight {
            for x in 0 ..< frame.pixelWidth where frame.isPainted(x: x, y: y) {
                if x < minX { minX = x }
                if x > maxX { maxX = x }
                if y < minY { minY = y }
                if y > maxY { maxY = y }
            }
        }
        guard maxX >= 0 else { return nil }
        let s = frame.scale
        return Extent(
            left: CGFloat(minX) / s,
            right: CGFloat(maxX + 1) / s,
            top: CGFloat(minY) / s,
            bottom: CGFloat(maxY + 1) / s
        )
    }

    /// A message long enough to wrap onto a second line inside the
    /// bubble's capped width (= so the bubble grows taller than its
    /// resting height).
    private static let longMessage =
        "Please summarize the research notes we collected for the current review."

    @Test("The outgoing bubble is narrower than the chat column and respects the canonical bubble width")
    func bubbleIsNarrowerThanTheColumn() throws {
        let appearance = try #require(NSAppearance(named: .aqua))
        let frame = try #require(render(Self.longMessage, appearance: appearance))
        let extent = try #require(extent(of: frame))

        #expect(
            extent.width < Self.columnWidth - 1,
            "The bubble must not span the chat column; painted \(extent.width) PT of a \(Self.columnWidth) PT column"
        )
        #expect(
            extent.width <= DesignTokens.chatBubbleMaxWidth + DesignTokens.spacingModerate * 2,
            "The bubble must respect the canonical chat-bubble width; painted \(extent.width) PT"
        )
    }

    @Test("The outgoing bubble hugs its words: a longer message paints a wider bubble")
    func bubbleWidthGrowsWithTheMessage() throws {
        let appearance = try #require(NSAppearance(named: .aqua))

        let shortFrame = try #require(render("Hi", appearance: appearance))
        let shortExtent = try #require(extent(of: shortFrame))
        let longFrame = try #require(render(Self.longMessage, appearance: appearance))
        let longExtent = try #require(extent(of: longFrame))

        #expect(
            longExtent.width > shortExtent.width + 1,
            "A longer message must paint a wider bubble; short = \(shortExtent.width) PT, long = \(longExtent.width) PT"
        )
        #expect(
            shortExtent.width < DesignTokens.chatBubbleMaxWidth / 2,
            "A short message must paint a bubble far narrower than the canonical cap; painted \(shortExtent.width) PT"
        )
    }

    @Test("The bubble's ends are fully rounded: the top edge starts where the cap is")
    func bubbleEndsAreFullyRounded() throws {
        let appearance = try #require(NSAppearance(named: .aqua))
        let frame = try #require(render(Self.longMessage, appearance: appearance))
        let extent = try #require(extent(of: frame))

        // The bubble's own height, in device pixels.
        let s = frame.scale
        let middleColumn = Int(((extent.left + extent.right) / 2 * s).rounded())
        let top = try #require(frame.topEdge(column: middleColumn))
        let bottom = try #require(frame.bottomEdge(column: middleColumn))
        let height = bottom - top

        // The corner's radius, read off the rendered arc.
        //
        // A rounded corner is a quarter circle tangent to the top
        // edge and to the leading edge, so its centre sits one radius
        // in from both. A point of the arc therefore satisfies
        // (a - r)^2 + (b - r)^2 = r^2 for a = the horizontal distance
        // from the leading edge and b = the vertical distance from
        // the top edge, which solves to r = a + b + sqrt(2ab).
        //
        // The samples are taken up the arc, where the edge is steep
        // and the radius is most sensitive to the measurement.
        let middleRow = Int((top + bottom) / 2)
        let left = try #require(frame.leadingEdge(row: middleRow))
        var radii: [CGFloat] = []
        for row in stride(from: Int(top.rounded()) + 2, to: middleRow, by: 4) {
            guard let edge = frame.leadingEdge(row: row) else { continue }
            let a = edge - left
            // The row's centre, not its first scan line.
            let b = CGFloat(row) + 0.5 - top
            guard a > 0, b > 0 else { continue }
            radii.append(a + b + (2 * a * b).squareRoot())
        }
        let sorted = radii.sorted()
        let radius = try #require(sorted[sorted.count / 2], "the corner arc must be readable from the pixels")
        let radiusPoints = radius / s

        #expect(
            radius >= height / 2 - 2,
            """
            The bubble's ends must be fully rounded (= the radius reaches half the \
            bubble's height); measured radius \(radiusPoints) PT of a \(height / s) PT bubble
            """
        )
        print("DIAG radius=\(radiusPoints) height=\(height / s) samples=\(radii.map { $0 / s })")
    }

    @Test("The bubble sits against the chat column's trailing edge")
    func bubbleSitsAtTheTrailingEdge() throws {
        let appearance = try #require(NSAppearance(named: .aqua))
        let frame = try #require(render(Self.longMessage, appearance: appearance))
        let extent = try #require(extent(of: frame))

        #expect(
            abs(extent.right - Self.columnWidth) <= 2,
            "The bubble's trailing edge must sit at the column's trailing edge; painted right edge = \(extent.right) PT of \(Self.columnWidth) PT"
        )
    }

    @Test("The bubble draws no stroke: the pixels step straight from the panel to the fill")
    func bubbleDrawsNoStroke() throws {
        let appearance = try #require(NSAppearance(named: .aqua))
        let frame = try #require(render(Self.longMessage, appearance: appearance))
        let extent = try #require(extent(of: frame))
        let fill = frame.fill

        // Scan the bubble's leading edge at mid height: the only
        // pixels allowed between the backdrop and the fill are the
        // blends of the two (= antialiasing). A stroke would put a
        // third colour there.
        let s = frame.scale
        let y = Int(((extent.top + extent.bottom) / 2 * s).rounded())
        let start = Int((extent.left * s).rounded(.down)) - 6
        let end = start + 12
        guard start >= 0, end < frame.pixelWidth else { return }

        let backdrop = Self.backdrop
        let dr = Double(fill.r - backdrop.r)
        let dg = Double(fill.g - backdrop.g)
        let db = Double(fill.b - backdrop.b)
        let lengthSquared = dr * dr + dg * dg + db * db
        guard lengthSquared > 0 else { return }

        for x in start ..< end {
            let p = frame.rgb(x: x, y: y)
            let pr = Double(p.r - backdrop.r)
            let pg = Double(p.g - backdrop.g)
            let pb = Double(p.b - backdrop.b)
            // Position along the backdrop -> fill line, and the
            // distance from it.
            let t = (pr * dr + pg * dg + pb * db) / lengthSquared
            let perpendicular = sqrt(
                max(0, (pr * pr + pg * pg + pb * pb) - t * t * lengthSquared)
            )
            #expect(
                perpendicular <= 12,
                "The bubble's edge must step straight from the panel to the fill; pixel at x=\(x) sits \(String(format: "%.1f", perpendicular)) off the line"
            )
        }
    }
}
