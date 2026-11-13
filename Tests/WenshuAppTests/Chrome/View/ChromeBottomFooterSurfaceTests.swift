// ChromeBottomFooterSurfaceTests.swift · Wenshu
//
// Every column's bottom bar wears the SAME surface, and that surface is
// the system's own OPAQUE colour.
//
// WHY THE SURFACE MUST NOT BE A MATERIAL: the window is translucent
// (= one behind-window material at the root), = so a MATERIAL paints
// whatever is BEHIND the bar. = Each column's bar then sampled a
// different patch of the desktop and every bar came out a different
// grey, = and every one of those values moved when the desktop moved.
// An OPAQUE system colour resolves to the same value in every column
// of one appearance, = so the window's bottom edge reads as ONE line.
//
// WHICH FACTS ARE MEASURED AND WHICH ARE READ:
//  - The surface itself is a SOURCE fact (= which layer paints what),
//    so it is read from the component's own CODE (= the comments are
//    stripped, = because a comment beside the surface quotes the old
//    recipe and would satisfy a naive whole-file search).
//  - The bar's GEOMETRY and its THEME behaviour are RUNTIME facts, so
//    they are measured on the rendered pixels.
//
// A NOTE ON WHAT THE RENDER CAN AND CANNOT SEE: an offscreen render
// paints a MATERIAL as an opaque fallback (= the window has no real
// desktop behind it), = so the rendered pixels alone cannot tell a
// material from an opaque fill. = That is why the surface is asserted
// structurally, = and why the rendered measurements below hold the
// geometry and the theme instead.

import AppKit
import SwiftUI
import Testing
@testable import WenshuApp

@Suite("Chrome bottom footer surface")
struct ChromeBottomFooterSurfaceTests {
    // MARK: - The facts

    /// The shared footer's own code, without its prose.
    ///
    /// The comments beside the surface describe the recipe, so a
    /// whole-file search would read the recipe and not the code.
    private func footerCode() throws -> String {
        let raw = try SourceLocator.read(
            "Sources/WenshuApp/Features/Chrome/View/ChromeBottomFooter.swift"
        )
        return raw
            .split(separator: "\n")
            .map { line -> String in
                guard let comment = line.range(of: "//") else { return String(line) }
                return String(line[..<comment.lowerBound])
            }
            .joined(separator: "\n")
    }

    /// The column's bottom bar renders at the shared footer's height.
    ///
    /// The bar's height is the height of its content ROW, = so a slot
    /// that renders nothing collapses the bar to its hairline. = The
    /// right column's bar carries an EMPTY slot on purpose, = so its
    /// row must still be there.
    @MainActor
    private func paintedHeight<V: View>(of view: V) -> CGFloat {
        let host = NSHostingView(rootView: view)
        host.frame = NSRect(x: 0, y: 0, width: 400, height: 200)
        let window = NSWindow(
            contentRect: host.frame,
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        // A ground the footer's own surface cannot be mistaken for.
        window.backgroundColor = .magenta
        window.contentView = host
        window.orderFront(nil)
        host.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.4))
        host.layoutSubtreeIfNeeded()

        let bounds = host.bounds
        let rep = host.bitmapImageRepForCachingDisplay(in: bounds)!
        rep.size = bounds.size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSColor.magenta.setFill()
        bounds.fill()
        NSGraphicsContext.restoreGraphicsState()
        host.cacheDisplay(in: bounds, to: rep)

        let data = rep.bitmapData!
        let width = rep.pixelsWide
        let rowBytes = rep.bytesPerRow
        let samples = rep.samplesPerPixel
        var paintedRows = 0
        for y in 0 ..< rep.pixelsHigh {
            for x in 0 ..< width {
                let offset = y * rowBytes + x * samples
                let red = Int(data[offset])
                let green = Int(data[offset + 1])
                let blue = Int(data[offset + 2])
                if abs(red - 255) > 12 || abs(green) > 12 || abs(blue - 255) > 12 {
                    paintedRows += 1
                    break
                }
            }
        }

        window.orderOut(nil)
        let scale = Double(rep.pixelsHigh) / Double(bounds.height)
        return CGFloat(paintedRows) / scale
    }

    /// The colour the bar's surface paints, read from the rendered
    /// pixels of a bar with no glyph in it.
    ///
    /// The ground behind the bar is painted first, = so a pixel that
    /// differs from it is a pixel the bar drew on.
    @MainActor
    private func paintedSurface(
        of view: some View,
        appearance: NSAppearance.Name
    ) -> (r: Int, g: Int, b: Int)? {
        let host = NSHostingView(rootView: view)
        host.frame = NSRect(x: 0, y: 0, width: 200, height: 100)
        let window = NSWindow(
            contentRect: host.frame,
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.backgroundColor = .magenta
        window.appearance = NSAppearance(named: appearance)
        window.contentView = host
        window.orderFront(nil)
        host.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.4))
        host.layoutSubtreeIfNeeded()

        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else {
            window.orderOut(nil)
            return nil
        }
        rep.size = host.bounds.size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSColor.magenta.setFill()
        host.bounds.fill()
        NSGraphicsContext.restoreGraphicsState()
        host.cacheDisplay(in: host.bounds, to: rep)

        var counts: [String: Int] = [:]
        var colors: [String: (r: Int, g: Int, b: Int)] = [:]
        for x in stride(from: 10, to: 190, by: 4) {
            for y in stride(from: 10, to: 90, by: 4) {
                guard let c = rep.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { continue }
                let key = "\(Int(c.redComponent * 255)),\(Int(c.greenComponent * 255)),\(Int(c.blueComponent * 255))"
                counts[key, default: 0] += 1
                colors[key] = (
                    Int(c.redComponent * 255),
                    Int(c.greenComponent * 255),
                    Int(c.blueComponent * 255)
                )
            }
        }
        window.orderOut(nil)
        guard let modal = counts.max(by: { $0.value < $1.value })?.key else { return nil }
        return colors[modal]
    }

    /// The bar's surface, with no glyph in the row to read.
    @MainActor
    private func barSurface(appearance: NSAppearance.Name) -> (r: Int, g: Int, b: Int)? {
        paintedSurface(
            of: ChromeBottomFooter {
                Color.clear
            },
            appearance: appearance
        )
    }

    /// The colour the bar's surface paints when the window behind it
    /// carries the given ground.
    ///
    /// Two grounds, = two renders of the same bar. = A surface that
    /// carries the ground reads differently over each one; = an opaque
    /// surface reads the same, = so the desktop behind the window can
    /// never reach the bar.
    @MainActor
    private func surfaceOver(ground: NSColor) throws -> (r: Int, g: Int, b: Int) {
        let host = NSHostingView(rootView: ChromeBottomFooter { Color.clear })
        host.frame = NSRect(x: 0, y: 0, width: 200, height: 100)
        let window = NSWindow(
            contentRect: host.frame,
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = ground
        window.contentView = host
        window.orderFront(nil)
        host.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.4))
        host.layoutSubtreeIfNeeded()

        let rep = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        rep.size = host.bounds.size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        ground.setFill()
        host.bounds.fill()
        NSGraphicsContext.restoreGraphicsState()
        host.cacheDisplay(in: host.bounds, to: rep)

        var counts: [String: Int] = [:]
        var colors: [String: (r: Int, g: Int, b: Int)] = [:]
        for x in stride(from: 10, to: 190, by: 4) {
            for y in stride(from: 10, to: 90, by: 4) {
                guard let c = rep.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { continue }
                let key = "\(Int(c.redComponent * 255)),\(Int(c.greenComponent * 255)),\(Int(c.blueComponent * 255))"
                counts[key, default: 0] += 1
                colors[key] = (
                    Int(c.redComponent * 255),
                    Int(c.greenComponent * 255),
                    Int(c.blueComponent * 255)
                )
            }
        }
        window.orderOut(nil)
        let modal = try #require(counts.max(by: { $0.value < $1.value })?.key)
        return try #require(colors[modal])
    }

    // MARK: - The surface

    /// The shared footer paints the system's own OPAQUE control
    /// background, and no material.
    ///
    /// This is the fact the whole change rests on: a material paints
    /// whatever is behind the bar, = and this window is translucent, =
    /// so a material bar reads as a different grey in every column.
    @Test("The shared footer paints an opaque system surface, not a material")
    func theFooterPaintsAnOpaqueSystemSurface() throws {
        let code = try footerCode()

        #expect(
            code.contains("controlBackgroundColor"),
            """
            The shared footer does not paint the system's own opaque control \
            background (= `NSColor.controlBackgroundColor`), so its surface is not \
            the one every column can share.
            """
        )
        #expect(
            !code.contains("Material") && !code.contains("background(.bar"),
            """
            The shared footer still paints a material: a material is translucent, so \
            it paints whatever is behind the bar and the bars drift apart.
            """
        )
    }

    /// Every column's bottom bar renders through the shared component.
    ///
    /// The component owns the surface, = so a column that draws a
    /// surface of its own would break the one line the window's bottom
    /// edge reads as.
    @Test("Every column's bottom bar renders through the shared component")
    func everyColumnBarRendersThroughTheSharedComponent() throws {
        let callSites = [
            "Sources/WenshuApp/Features/Library/View/AppleSidebarBottomNewButton.swift",
            "Sources/WenshuApp/Features/Editor/View/AssetsPane.swift",
            "Sources/WenshuApp/Features/Chat/View/ChatInputBarView.swift",
            "Sources/WenshuApp/Features/Editor/View/EditorStatusBarView.swift",
            "Sources/WenshuApp/Features/Editor/View/InspectorView.swift",
        ]
        for path in callSites {
            let raw = try SourceLocator.read(path)
            #expect(
                raw.contains("ChromeBottomFooter"),
                """
                \(path) does not render its bottom bar through the shared \
                `ChromeBottomFooter`, so its surface is not the shared one.
                """
            )
        }
    }

    /// The bar's surface follows the appearance.
    ///
    /// One appearance = one value, = and the light and dark appearances
    /// each resolve to their own (= the bar follows the theme, = it does
    /// not become one fixed grey in both).
    @Test("The bar's surface follows the appearance")
    @MainActor
    func theBarSurfaceFollowsTheAppearance() throws {
        let light = try #require(barSurface(appearance: .aqua), "the bar did not render in light")
        let dark = try #require(barSurface(appearance: .darkAqua), "the bar did not render in dark")

        #expect(
            light != dark,
            """
            The bar paints \(light) in light and \(dark) in dark: the surface does \
            not follow the appearance.
            """
        )
    }

    /// The bar's surface does not carry the ground behind it.
    ///
    /// Two different grounds, = two renders of the same bar. = A surface
    /// that carries the ground reads differently over each one; = an
    /// opaque surface reads the same, = so the desktop behind the
    /// window can never reach the bar.
    @Test("The bar's surface does not carry the ground behind it")
    @MainActor
    func theBarSurfaceDoesNotCarryTheGround() throws {
        let overSaturated = try surfaceOver(
            ground: NSColor(srgbRed: 0.9, green: 0.1, blue: 0.3, alpha: 1)
        )
        let overPale = try surfaceOver(ground: NSColor(white: 0.92, alpha: 1))

        #expect(
            overSaturated == overPale,
            """
            The bar reads \(overSaturated) over a saturated ground and \(overPale) over a \
            pale one: the surface carries what is behind it, so the desktop reaches the bar.
            """
        )
    }

    // MARK: - The right column's bar

    /// The right column ends on a bottom bar.
    ///
    /// It is the one column whose bottom edge had no bar at all, = so
    /// the window's bottom edge read as one broken line instead of one
    /// clean one.
    @Test("The right column ends on a bottom bar")
    func theRightColumnEndsOnABottomBar() throws {
        let raw = try SourceLocator.read(
            "Sources/WenshuApp/Features/Editor/View/InspectorView.swift"
        )
        #expect(
            raw.contains("ChromeBottomFooter"),
            """
            The right column does not render a bottom bar, so its ground runs straight \
            to the window's bottom edge while every other column ends on a bar.
            """
        )
        #expect(
            raw.contains(".safeAreaInset(edge: .bottom"),
            """
            The right column's bar is not a bottom inset, so it does not sit at the \
            window's bottom edge (= the line every other column's bar sits on).
            """
        )
    }

    /// The right column's bar is the shared footer's shape.
    ///
    /// Its content slot is EMPTY on purpose (= the bar is the row's
    /// shape, = not a placeholder for a feature), = and an empty slot
    /// must still paint the row, = because the bar's height is the
    /// height of that row.
    @Test("The right column's empty bar still paints the shared bar's height")
    @MainActor
    func theEmptyBarStillPaintsTheCanonicalHeight() {
        let empty = paintedHeight(of: ChromeBottomFooter { Color.clear })
        let canonical = DesignTokens.chromeBottomFooterHeight

        #expect(
            abs(empty - canonical) <= 1,
            """
            A bar carrying an empty slot painted \(empty) PT; the shared footer's \
            canonical height is \(canonical) PT.
            """
        )
    }
}
