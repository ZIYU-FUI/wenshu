// ChromeBottomFooterSurfaceTests.swift · Wenshu
//
// The shared footer's surface, by the edge the bar sits on.
//
// TWO SURFACES, = = and the difference is the bar's EDGE: = =
// - a WINDOW-EDGE bar (= the window's bottom edge) wears the system's own
//   OPAQUE control background, = = so one appearance gives every column's
//   bar the SAME value (= the window's bottom edge reads as ONE line).
// - an INTERIOR SEAM bar (= a zone's bottom edge, = with another zone
//   below it) wears the system's own UNDER-WINDOW MATERIAL, = = so the
//   band is TRANSLUCENT and reads as a row of its column instead of a
//   plate pasted onto it.
//
// WHY THE WINDOW-EDGE SURFACE MUST NOT BE A MATERIAL: the window is
// translucent (= one behind-window material at the root), = so a
// MATERIAL paints whatever is BEHIND the bar. = Each column's bar then
// sampled a different patch of the desktop and every bar came out a
// different grey, = and every one of those values moved when the
// desktop moved. = An OPAQUE system colour resolves to the same value
// in every column of one appearance, = so the desktop can no longer
// reach it, = so the window's bottom edge reads as ONE line, = and the
// light and dark appearances each resolve to their own value (= the bar
// follows the theme).
//
// WHY THE INTERIOR SEAM WEARS A MATERIAL ANYWAY: that reason is a
// WINDOW-EDGE reason, = = and the ground behind an interior seam is the
// app's OWN ground (= the same one the column's body shows), = = so
// there is no desktop to keep out and no second column to agree with.
// = An OPAQUE plate there reads as a FOREIGN SLAB (= its own value sits
// against the column's ground, = = and the step between them is the
// pasted bar the eye sees), = = and NO fill at all reads as no bar.
// = The material is the system's own UNDER-WINDOW surface (= = the
// layer under the window's content), = = in the WITHIN-WINDOW blending
// (= = it samples the app's OWN content behind the band, = = not the
// desktop behind the window), = = so the band is a BAND that shows the
// column through it.
//
// MEASURED, over a KNOWN saturated ground (= = magenta) in a REAL
// on-screen window, = = in ONE probe window whose rows each carry
// their own marker strip (= = so a row's number cannot be read off
// its neighbour): = = this material resolves to (79,33,79) (= = the
// magenta coming through it), = = where an opaque control background
// over the same ground resolves to (28,28,28) (= = no magenta at
// all). = = So the band really does TRANSMIT the column behind it, and
// it takes that column from INSIDE the window (= = so the desktop
// never reaches it, = = the defect the 2026-11-14 session found when
// the footer wore `.bar`, = = a behind-window material).
//
// AND IN THE REAL APP, = = on screen, = = in both appearances, = = and
// each capture's foreground PROVEN to be the app before its pixels
// were read: = = the window-edge bars resolve to 28 (dark) / 255
// (light), = = and this band's material resolves to 48 (dark) / 222
// (light), = = so the band sits BETWEEN this column's own ground (= =
// 78 dark / 190 light) and the bars' value, = = its step against that
// ground is 30 (dark) / 32 (light) = = where the opaque plate's was
// 50 (dark) / 67 (light).
//
// WHICH FACTS ARE MEASURED AND WHICH ARE READ:
//  - The surface itself is a SOURCE fact (= which layer paints what),
//    so it is read from the component's own CODE (= the comments are
//    stripped, = because a comment beside the surface quotes the old
//    recipe and would satisfy a naive whole-file search).
//  - The bar's GEOMETRY and its THEME behaviour are RUNTIME facts, so
//    they are measured on the rendered pixels.
//  - WHICH edge each call site sits on is a SOURCE fact too (= the
//    call site's own code names the surface it asks for).
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
        try code(of: "Sources/WenshuApp/Features/Chrome/View/ChromeBottomFooter.swift")
    }

    /// The window-edge branch's own code, without its prose.
    ///
    /// The footer's file carries BOTH surfaces, = = so a whole-file
    /// search cannot tell which branch paints what. = This reads the
    /// one branch that must not paint a material.
    private func windowEdgeBranch() throws -> String {
        let code = try footerCode()
        guard let start = code.range(of: "case .windowEdge:") else {
            return code
        }
        let rest = code[start.upperBound...]
        guard let end = rest.range(of: "case .columnMaterial:") else {
            return String(rest)
        }
        return String(rest[..<end.lowerBound])
    }

    /// A file's own code, without its prose (= the same rule the
    /// footer's own code is read by).
    private func code(of path: String) throws -> String {
        let raw = try SourceLocator.read(path)
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
    private func barSurface(
        appearance: NSAppearance.Name,
        surface: ChromeBottomFooterSurface = .windowEdge
    ) -> (r: Int, g: Int, b: Int)? {
        paintedSurface(
            of: ChromeBottomFooter(surface: surface) {
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
    private func surfaceOver(
        ground: NSColor,
        surface: ChromeBottomFooterSurface = .windowEdge
    ) throws -> (r: Int, g: Int, b: Int) {
        let host = NSHostingView(
            rootView: ChromeBottomFooter(surface: surface) {
                Color.clear
            }
        )
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

    // MARK: - The surfaces

    /// The shared footer paints the system's own OPAQUE control
    /// background for a window-edge bar, and no material.
    ///
    /// This is the fact the whole window-edge contract rests on: a
    /// material paints whatever is behind the bar, = and this window is
    /// translucent, = so a material bar reads as a different grey in
    /// every column.
    @Test("The window-edge surface is the system's own opaque colour, not a material")
    func theWindowEdgeSurfaceIsOpaqueAndNotAMaterial() throws {
        let code = try footerCode()

        #expect(
            code.contains("controlBackgroundColor"),
            """
            The shared footer's window-edge surface does not paint the system's own opaque \
            control background (= `NSColor.controlBackgroundColor`), so its surface is not \
            the one every column can share.
            """
        )
        let windowEdge = try windowEdgeBranch()
        #expect(
            !windowEdge.contains("Material") && !windowEdge.contains("background(.bar"),
            """
            The window-edge branch still paints a material: a material is translucent, so \
            it paints whatever is behind the bar and the bars drift apart.
            """
        )
    }

    /// An interior seam's bar wears its column's ground.
    ///
    /// The two cases are the component's own, = and the source names
    /// both of them, = so a reader sees the choice without reading the
    /// whole file.
    @Test("The footer offers both surfaces, one per edge")
    func theFooterOffersBothSurfaces() throws {
        let code = try footerCode()

        #expect(
            code.contains("case windowEdge") && code.contains("case columnMaterial"),
            """
            The shared footer does not carry both surfaces, = = so a bar cannot choose \
            the one its edge asks for.
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
            #expect(
                !raw.contains("surface: .columnMaterial"),
                """
                \(path) renders a bar at the WINDOW's bottom edge, = = so it wears the \
                window-edge surface (= the opaque one), = = and the window's bottom edge \
                reads as one line.
                """
            )
        }
    }

    /// The editor's status bar is an interior seam, = = so it wears
    /// the interior seam's material.
    ///
    /// The editor zone sits ABOVE the chat zone in the detail column,
    /// = = so the editor zone's bottom edge is a seam between two
    /// zones, = = and NOT the window's bottom edge. = = A bar there
    /// that wears the window-edge's opaque surface reads as a plate
    /// pasted onto the column, = = and its own value sits against the
    /// column's own ground, = = and that step is what the eye reads as
    /// a black bar pasted on. = = A bar with NO fill at all reads as no
    /// bar, = = so the seam's surface is the system's own material.
    @Test("The editor's status bar wears the interior seam's material")
    func theEditorStatusBarWearsTheInteriorSeamsMaterial() throws {
        let raw = try SourceLocator.read(
            "Sources/WenshuApp/Features/Editor/View/EditorStatusBarView.swift"
        )
        #expect(
            raw.contains("surface: .columnMaterial"),
            """
            The editor's status bar does not ask for the interior seam's surface, = = so \
            it wears the window-edge's opaque surface, = = and it reads as a plate pasted \
            onto the editor column instead of a translucent band.
            """
        )
    }

    /// The bar's surface follows the appearance.
    ///
    /// One appearance = one value, = and the light and dark appearances
    /// each resolve to their own (= the bar follows the theme).
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

    /// The window-edge bar's surface does not carry the ground behind it.
    ///
    /// Two different grounds, = two renders of the same bar. = A surface
    /// that carries the ground reads differently over each one; = an
    /// opaque surface reads the same, = so the desktop behind the
    /// window can never reach the bar.
    @Test("The window-edge surface does not carry the ground behind it")
    @MainActor
    func theWindowEdgeSurfaceDoesNotCarryTheGround() throws {
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

    /// The interior seam's bar wears the system's chrome MATERIAL.
    ///
    /// ⇒ ⇒ ⇒ AND THIS IS THE MIRROR OF THE FACT ABOVE, = = and it is
    /// what makes the two surfaces ONE decision instead of two: = = the
    /// window-edge bar refuses the ground behind it (= so every column
    /// agrees, = = so the bottom edge is one line), = = and the
    /// interior seam's bar wears the system's own chrome material (= so
    /// the band is translucent, = = and it is not a plate).
    ///
    /// WHY THIS IS A SOURCE FACT AND NOT A RENDERED ONE: = an
    /// offscreen render paints a MATERIAL as an OPAQUE FALLBACK (= the
    /// window has no real desktop behind it), = so the rendered pixels
    /// read the SAME for a material and for an opaque fill. = ⇒ ⇒ ⇒ So
    /// the material is asserted from the branch's own CODE (= the
    /// comments stripped, = = because a comment beside the surface
    /// quotes the recipe and would satisfy a naive whole-file search),
    /// and the rendered measurements hold the geometry and the theme.
    @Test("The interior seam's surface is the system's chrome material")
    func theInteriorSeamSurfaceIsTheSystemsChromeMaterial() throws {
        let code = try footerCode()
        guard let start = code.range(of: "case .columnMaterial:") else {
            Issue.record("The shared footer's interior-seam surface branch is gone.")
            return
        }
        let branch = String(code[start.upperBound...])

        #expect(
            branch.contains("ChromeBottomFooterMaterial.contentArea"),
            """
            The interior seam's surface does not paint the system's own content-area \
            material, so it is an opaque plate on the column instead of a translucent band.
            """
        )
        #expect(
            !branch.contains("controlBackgroundColor"),
            """
            The interior seam's surface paints the opaque control background, = = so the \
            band is a solid plate pasted onto the column instead of a translucent band.
            """
        )
        #expect(
            !branch.contains("Color.clear\n"),
            """
            The interior seam's surface has no material under it, = = so the band paints \
            nothing at all and the row reads as more of the column instead of a bar.
            """
        )
    }

    /// The interior seam's material is the CONTENT-AREA one, = = in the
    /// WITHIN-WINDOW blending.
    ///
    /// ⇒ ⇒ ⇒ AND IT IS MEASURED, = = not asserted by name: = = the
    /// material's own code names the AppKit material and the blending
    /// mode (= = and the blending mode is the load-bearing half, = = for
    /// the reason the 2026-11-14 session's window-edge rule cannot
    /// apply here).
    @Test("The interior seam's material samples the app, not the desktop")
    func theInteriorSeamMaterialSamplesTheAppNotTheDesktop() throws {
        // The RECIPE lives in the shared file (= one surface for the card
        // and the band), so the recipe is read there.
        let code = try code(of: "Sources/WenshuApp/Shared/UI/ContentAreaMaterial.swift")
        guard let material = code.range(of: "view.material = ") else {
            Issue.record("The interior seam's material no longer names its AppKit material.")
            return
        }
        let materialLine = String(code[material.lowerBound...].prefix(60))
        let blending = code.range(of: "view.blendingMode = ")

        #expect(
            materialLine.contains(".underWindowBackground"),
            """
            The interior seam's material is not the under-window material (= = the layer \
            under the window's own content), so the band stops showing the column \
            through it.
            """
        )
        guard let blending else {
            Issue.record("The interior seam's material no longer names its blending mode.")
            return
        }
        let blendingLine = String(code[blending.lowerBound...].prefix(60))
        #expect(
            blendingLine.contains(".withinWindow"),
            """
            The interior seam's material blends BEHIND THE WINDOW (= = it samples the \
            desktop), so the band changes value whenever the desktop changes = = and in \
            the light appearance it paints a white slab across the editor's dark paper.
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
