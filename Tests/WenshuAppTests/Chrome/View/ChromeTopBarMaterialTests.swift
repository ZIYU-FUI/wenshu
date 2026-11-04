// ChromeTopBarMaterialTests.swift · Wenshu
//
// A column-top chrome band that belongs to the column's body must not
// paint its own material. The band then reads as part of the column
// instead of a brighter strip floating above it.
//
// The measurement is the PAINTED result, not the source text: the band
// is rendered into a real NSBitmapImageRep over a host background the
// band's own surface cannot be mistaken for, and the pixels inside the
// band are compared against that host. A band with the material paints
// a different shade; a transparent band leaves the host visible.
//
// A source-text assertion cannot catch this: the material is one
// modifier in a shared component, and the same file serves the editor
// format toolbar, which KEEPS the material. Only the rendered pixels
// say whether a given call site got the transparent band.
import AppKit
import SwiftUI
import Testing
@testable import WenshuApp

@Suite("Chrome top bar material")
struct ChromeTopBarMaterialTests {

    /// The host background the band's own surface cannot be mistaken for.
    private static let hostColor = NSColor.magenta

    /// The painted pixels of a view, rendered into a bitmap over the
    /// host background.
    @MainActor
    private func paintedPixels<V: View>(of view: V, width: CGFloat = 240) -> (pixels: [UInt8], height: Int, width: Int) {
        let host = NSHostingView(rootView: view)
        host.frame = NSRect(x: 0, y: 0, width: width, height: 60)
        let window = NSWindow(
            contentRect: host.frame,
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.backgroundColor = Self.hostColor
        window.contentView = host
        window.orderFront(nil)
        host.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.4))
        host.layoutSubtreeIfNeeded()

        let bounds = host.bounds
        let rep = host.bitmapImageRepForCachingDisplay(in: bounds)!
        rep.size = bounds.size
        // Paint the host's background first, so a pixel that differs is
        // a pixel the view drew on.
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        Self.hostColor.setFill()
        bounds.fill()
        NSGraphicsContext.restoreGraphicsState()
        host.cacheDisplay(in: bounds, to: rep)

        window.orderOut(nil)
        let count = rep.pixelsHigh * rep.bytesPerRow
        let bytes = [UInt8](UnsafeBufferPointer(start: rep.bitmapData!, count: count))
        return (bytes, rep.pixelsHigh, rep.pixelsWide)
    }

    /// The share of the band's interior pixels that carry the host's
    /// background (= 1.0 when the band is transparent, lower when the
    /// band painted its own surface).
    @MainActor
    private func hostShare<V: View>(of view: V, sampleRowFraction: Double = 0.5) -> Double {
        let (pixels, height, width) = paintedPixels(of: view)
        let bytesPerRow = pixels.count / max(height, 1)
        let samplesPerPixel = bytesPerRow / max(width, 1)
        let row = min(height - 1, max(0, Int(Double(height) * sampleRowFraction)))
        var host = 0
        var total = 0
        for x in 0..<width {
            let offset = row * bytesPerRow + x * samplesPerPixel
            let r = Int(pixels[offset]), g = Int(pixels[offset + 1]), b = Int(pixels[offset + 2])
            total += 1
            if abs(r - 255) < 24 && g < 110 && abs(b - 255) < 24 { host += 1 }
        }
        return total > 0 ? Double(host) / Double(total) : 0
    }

    /// The band's content: a short text run, so the band has something
    /// to lay out and the row has a measurable height.
    @MainActor
    private func bandContent() -> some View {
        HStack(spacing: DesignTokens.spacingIconic) {
            SFIcon("magnifyingglass", style: .inlineSmall, color: IconColor.secondary)
            Text("search")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(height: DesignTokens.paneTabHotArea)
    }

    /// A transparent band leaves the column's background visible.
    @Test("A band that asks for no material paints no surface of its own")
    @MainActor
    func aBandWithoutMaterialLeavesTheHostVisible() throws {
        let transparent = hostShare(of: ChromeTopBar(usesMaterial: false) { bandContent() })
        #expect(
            transparent > 0.9,
            """
            A band built with `usesMaterial: false` painted only \
            \(Int(transparent * 100))% of the host background: the band still \
            carries a surface of its own, so it reads as a strip above the column.
            """
        )
    }

    /// The default band paints NO material (= the band belongs to its
    /// column's body).
    ///
    /// The default used to be the material (= the editor's format-toolbar
    /// band was the one production band that wanted the window-chrome
    /// tint, = and that band is gone with the format commands' move to
    /// the inspector column's format page). Every band the app draws
    /// today belongs to its column, so the default says so.
    @Test("The shared default band paints no material of its own")
    @MainActor
    func theDefaultBandPaintsNoMaterial() {
        let material = hostShare(of: ChromeTopBar { bandContent() })
        #expect(
            material > 0.9,
            """
            The shared default band painted only \(Int(material * 100))% of the host \
            background: the default still carries a surface of its own, so a column's \
            band reads as a bar floating above the column.
            """
        )
    }

    /// A band that asks for the window-chrome material still gets it.
    @Test("A band that asks for the chrome material paints it")
    @MainActor
    func aBandThatAsksForTheMaterialGetsIt() {
        let material = hostShare(of: ChromeTopBar(usesMaterial: true) { bandContent() })
        #expect(
            material < 0.6,
            """
            A band built with `usesMaterial: true` painted \(Int(material * 100))% of \
            the host background: the window-chrome material is no longer painted, so a \
            window-chrome band cannot carry the surface.
            """
        )
    }

    /// Every column band asks for no material.
    ///
    /// The three bands the app draws (= the sidebar's switcher band, =
    /// the assets column's search band, = the inspector column's page
    /// band) all belong to their column's body, so all three ask for
    /// no material.
    @Test("Every column band asks for no material")
    func everyColumnBandAsksForNoMaterial() throws {
        let sidebar = try SourceLocator.read(
            "Sources/WenshuApp/Features/Library/View/AppleSidebarView.swift"
        )
        let assets = try SourceLocator.read(
            "Sources/WenshuApp/Features/Editor/View/AssetsPane.swift"
        )
        let inspector = try SourceLocator.read(
            "Sources/WenshuApp/Features/Editor/View/InspectorView.swift"
        )

        #expect(
            sidebar.contains("usesMaterial: false"),
            "The left column's switcher band must ask for no material (= it belongs to the column)"
        )
        #expect(
            assets.contains("usesMaterial: false"),
            "The assets column's search band must ask for no material (= it belongs to the column)"
        )
        #expect(
            inspector.contains("usesMaterial: false"),
            "The inspector column's page band must ask for no material (= it belongs to the column)"
        )
    }
}
