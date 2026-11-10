//
//  EditorCodeBlockSurfaceTests.swift · Wenshu
//
//  A fenced code block in the editor must paint no slab of its own.
//
//  WHY
//  ===
//  The editor's code block used to be a big near-white rectangle laid over
//  the page: the vendored engine stamped the syntax highlighter's background
//  onto the code range, and the renderer painted the same colour across the
//  container's FULL width. A code block therefore read as an image dropped
//  on the text rather than as part of the draft.
//
//  The engine now takes the fenced block's fill from its own knob, and the
//  app asks for no fill, so the code sits on the editor's own surface.
//
//  WHAT THIS TEST DOES
//  ===================
//  It renders the REAL editor configuration the app builds
//  (= `WenshuEditorServicesFactory.make(...)`, = the same object the editor
//  pane hands the engine) over a host background the app never paints, and
//  reads the PAINTED pixels.
//
//  The measurement is the painted result, not the source text: the fill
//  reaches the screen through the engine's renderer, and only the pixels
//  say whether the slab is there.
//
//  The region measured is the RIGHT half of the text view's rows. A code
//  block's own text sits at the leading edge, so the trailing half of its
//  rows is empty: a slab fills it edge to edge, and no fill leaves the host
//  visible there.
//

import AppKit
import MarkdownEngine
import SwiftUI
import Testing
@testable import WenshuApp

@MainActor
@Suite("Editor code block surface")
struct EditorCodeBlockSurfaceTests {
    /// The host background the editor's own surfaces cannot be mistaken for.
    private static let hostColor = NSColor.magenta

    /// A document whose fenced code block sits at the leading edge, so the
    /// trailing half of its rows is empty.
    private static let document = """
    ```swift
    let answer = 42
    ```

    A paragraph of prose after the block.
    """

    /// The painted pixels of a view, rendered into a bitmap over the host
    /// background.
    private func paintedPixels<V: View>(
        of view: V,
        width: CGFloat = 600,
        height: CGFloat = 200
    ) -> (pixels: [UInt8], height: Int, width: Int) {
        let host = NSHostingController(rootView: view)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.backgroundColor = Self.hostColor
        window.contentView = host.view
        window.setFrame(NSRect(x: 0, y: 0, width: width, height: height), display: true)
        host.view.layoutSubtreeIfNeeded()
        window.layoutIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.6))
        host.view.layoutSubtreeIfNeeded()
        window.layoutIfNeeded()

        let bounds = host.view.bounds
        let rep = host.view.bitmapImageRepForCachingDisplay(in: bounds)!
        rep.size = bounds.size
        // Paint the host's background first, so a pixel that differs is
        // a pixel the view drew on.
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        Self.hostColor.setFill()
        bounds.fill()
        NSGraphicsContext.restoreGraphicsState()
        host.view.cacheDisplay(in: bounds, to: rep)

        window.orderOut(nil)
        let count = rep.pixelsHigh * rep.bytesPerRow
        let bytes = [UInt8](UnsafeBufferPointer(start: rep.bitmapData!, count: count))
        return (bytes, rep.pixelsHigh, rep.pixelsWide)
    }

    /// Whether a pixel still carries the host background.
    ///
    /// The host is magenta, so a pixel is the host only when it is still
    /// saturated magenta: any surface painted over it desaturates it and
    /// leaves the family (= the green channel rises).
    private func isHost(_ r: Int, _ g: Int, _ b: Int) -> Bool {
        r > 225 && g < 60 && b > 225
    }

    /// The share of the trailing half's pixels that carry the host, per row.
    ///
    /// Only the rows that carry INK (= the rows with text on them) are
    /// meaningful: an empty row above the text is the host by definition,
    /// and a row that is the host because nothing was drawn on it says
    /// nothing about a slab.
    private func trailingHostShare(
        _ pixels: (pixels: [UInt8], height: Int, width: Int)
    ) -> [Double] {
        let bytesPerRow = pixels.pixels.count / max(pixels.height, 1)
        let samplesPerPixel = bytesPerRow / max(pixels.width, 1)
        let trailingStart = pixels.width * 3 / 5
        let trailingWidth = max(1, pixels.width - trailingStart)
        return (0 ..< pixels.height).map { y in
            var host = 0
            for x in trailingStart ..< pixels.width {
                let offset = y * bytesPerRow + x * samplesPerPixel
                if isHost(Int(pixels.pixels[offset]),
                          Int(pixels.pixels[offset + 1]),
                          Int(pixels.pixels[offset + 2]))
                {
                    host += 1
                }
            }
            return Double(host) / Double(trailingWidth)
        }
    }

    /// The rows that carry ink (= the text's own rows).
    ///
    /// A row with no ink is a row nothing was drawn on.
    private func inkRows(
        _ pixels: (pixels: [UInt8], height: Int, width: Int)
    ) -> [Int] {
        let bytesPerRow = pixels.pixels.count / max(pixels.height, 1)
        let samplesPerPixel = bytesPerRow / max(pixels.width, 1)
        return (0 ..< pixels.height).filter { y in
            for x in 0 ..< pixels.width {
                let offset = y * bytesPerRow + x * samplesPerPixel
                if !isHost(Int(pixels.pixels[offset]),
                           Int(pixels.pixels[offset + 1]),
                           Int(pixels.pixels[offset + 2]))
                {
                    return true
                }
            }
            return false
        }
    }

    @Test("a fenced code block paints no slab of its own")
    func theCodeBlockPaintsNoSlab() {
        // The app's own bridge reads the current appearance from `NSApp`,
        // so the app instance must exist before the configuration is built
        // (= the test process has none until it asks for one).
        _ = NSApplication.shared

        // The app's OWN editor configuration (= the object the editor pane
        // hands the engine).
        let configuration = WenshuEditorServicesFactory.make(bookStore: nil)
        #expect(configuration.codeBlock.fill == .none,
                """
                the editor's configuration still asks for the code block's own \
                fill: the app must ask the engine for no fill, = so the code \
                sits on the editor's own surface.
                """)

        let view = NativeTextViewWrapper(
            text: .constant(Self.document),
            configuration: configuration,
            fontName: "SF Pro",
            fontSize: 14
        )
        let pixels = paintedPixels(of: view)
        let ink = Set(inkRows(pixels))
        #expect(!ink.isEmpty, "the editor must have painted its text (= the measurement is of something)")

        let shares = trailingHostShare(pixels)
        // The rows with ink are the code block's own rows: on those, the
        // trailing half is either the host (no fill) or the slab (a fill).
        let inkShares = ink.map { shares[$0] }
        let slabbed = inkShares.filter { $0 < 0.5 }
        #expect(
            slabbed.isEmpty,
            """
            \(slabbed.count) of the \(inkShares.count) text rows have their \
            trailing half painted by something other than the host: the code \
            block paints a slab across the column, = so it reads as a \
            rectangle laid over the page.
            """
        )
    }
}
