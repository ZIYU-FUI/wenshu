//
//  ChatPinnedHeaderBandTests.swift · Wenshu
//
//  The chat's pinned user row must NOT paint a surface of its own.
//
//  WHY
//  ===
//  The transcript's user row is a pinned section header (= it sticks to the
//  scroll viewport's top edge while its replies scroll under it). That row
//  used to carry a `.regularMaterial` background, which was a SECOND
//  material layer: the window's root already carries the one behind-window
//  material, and the chat column is transparent, so that single layer shows
//  through the column. The extra layer composited over it and read as a
//  brighter strip laid across the whole row (= the reported defect: the
//  user's bubble carried an extra background block the width of the column).
//
//  The rule the app follows everywhere else is ONE material at the window's
//  root, and nothing inside the window painting a surface of its own.
//
//  WHAT THIS TEST DOES
//  ===================
//  It hosts the REAL ChatView (= the app's own view, not a mock of it) in a
//  window whose background is a colour the app never paints, and reads the
//  PAINTED pixels: the rows of the transcript's leading edge.
//
//  A band that paints its own surface fills those rows edge to edge, so
//  every pixel in them differs from the host. A row that paints nothing
//  leaves the host visible. The measurement is the painted result, not the
//  source text: the material is one modifier in a shared file, and only the
//  pixels say whether this call site got the transparent band.
//
//  The bubble itself is checked too (= the row must still paint the user's
//  own card), so a test that renders nothing at all cannot pass.
//

import AppKit
import SwiftUI
import Testing
import WenshuAgent
@testable import WenshuApp
import WenshuData

@MainActor
@Suite("Chat pinned header band")
struct ChatPinnedHeaderBandTests {
    /// The host background the chat column cannot be mistaken for.
    ///
    /// Magenta is used because the app's own surfaces never carry it, and
    /// because a material composited over it desaturates it (= it leaves
    /// the magenta family), so the two are told apart by their pixels.
    private static let hostColor = NSColor.magenta

    /// The transcript's scroll view, found in the hosted tree.
    ///
    /// The chat hosts more than one scroll view (= the transcript, and the
    /// composer's own text view), so the transcript is the one with the
    /// TALLEST document.
    private static func transcriptScrollView(in root: NSView) -> NSScrollView? {
        var found: NSScrollView?
        var tallest: CGFloat = -1
        func walk(_ view: NSView) {
            if let scroll = view as? NSScrollView {
                let height = scroll.documentView?.frame.height ?? 0
                if height > tallest {
                    tallest = height
                    found = scroll
                }
            }
            for subview in view.subviews {
                walk(subview)
            }
        }
        walk(root)
        return found
    }

    /// The painted pixels of the hosted chat, over the host background.
    private func paintedPixels(
        of view: some View,
        width: CGFloat = 600,
        height: CGFloat = 500
    ) -> (pixels: [UInt8], height: Int, width: Int) {
        let host = NSHostingController(
            rootView: AnyView(view.environment(WorkspaceUIState()))
        )
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.backgroundColor = Self.hostColor
        window.contentView = host.view
        window.setFrame(NSRect(x: 0, y: 0, width: width, height: height), display: true)
        host.view.layoutSubtreeIfNeeded()
        window.layoutIfNeeded()

        // Let the lazy rows materialize and the history load.
        RunLoop.current.run(until: Date().addingTimeInterval(1.5))
        host.view.layoutSubtreeIfNeeded()
        window.layoutIfNeeded()

        // The transcript is scrolled to its top, so the FIRST turn's user
        // row (= a pinned section header) sits at the viewport's top edge.
        // Its band, if it paints one, is then in the rows this test reads.
        if let scroll = Self.transcriptScrollView(in: host.view) {
            scroll.contentView.scroll(to: .zero)
            scroll.reflectScrolledClipView(scroll.contentView)
        }
        RunLoop.current.run(until: Date().addingTimeInterval(0.3))
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
    /// saturated magenta: a material composited over it desaturates it and
    /// leaves the family (= the green channel rises well above magenta's).
    private func isHost(_ r: Int, _ g: Int, _ b: Int) -> Bool {
        r > 225 && g < 60 && b > 225
    }

    /// The share of the leading edge's pixels that carry the host, per row.
    ///
    /// The leading edge (= the left quarter of the column) is the region
    /// the user's own bubble does NOT reach (= the bubble is trailing), so
    /// it is where a full-width band shows itself.
    private func hostSharePerRow(
        _ pixels: (pixels: [UInt8], height: Int, width: Int)
    ) -> [Double] {
        let bytesPerRow = pixels.pixels.count / max(pixels.height, 1)
        let samplesPerPixel = bytesPerRow / max(pixels.width, 1)
        let leadingWidth = max(1, pixels.width / 4)
        return (0 ..< pixels.height).map { y in
            var host = 0
            for x in 0 ..< leadingWidth {
                let offset = y * bytesPerRow + x * samplesPerPixel
                if isHost(Int(pixels.pixels[offset]),
                          Int(pixels.pixels[offset + 1]),
                          Int(pixels.pixels[offset + 2]))
                {
                    host += 1
                }
            }
            return Double(host) / Double(leadingWidth)
        }
    }

    /// The messages the transcript shows.
    ///
    /// The FIRST one is a user message (= its row is the pinned section
    /// header this test reads), and the second is an agent reply (= the
    /// text that would show through if the row masked nothing).
    private func makeMessages() -> [ChatMessage] {
        [
            ChatMessage(
                role: .user,
                source: .user,
                content: "The pinned row probe question."
            ),
            ChatMessage(
                role: .agent,
                source: .wenshu,
                content: String(
                    repeating: "The reply that scrolls behind the pinned row. ",
                    count: 12
                )
            ),
        ]
    }

    @Test("the pinned user row paints no surface of its own")
    func thePinnedRowPaintsNoSurface() {
        let messages = makeMessages()
        let vm = ChatViewModel(
            initialMessages: messages,
            repository: FixedChatRepository(messages: messages),
            providersConfigured: { true }
        )
        let pixels = paintedPixels(of: ChatView(vm: vm))
        let shares = hostSharePerRow(pixels)

        // The rows this test reads: the transcript's top band (= the pinned
        // user row is there), leaving the composer's own bar alone.
        let rows = shares.prefix(max(1, pixels.height / 3))

        // A band that paints its own surface fills the leading edge edge
        // to edge, so those rows carry almost no host.
        let banded = rows.filter { $0 < 0.1 }
        #expect(
            banded.count <= 2,
            """
            \(banded.count) of the first \(rows.count) rows of the transcript's \
            leading edge are painted edge to edge by something other than the \
            host: the pinned user row paints a surface of its own (= a band \
            across the whole column), instead of leaving the column's own \
            surface visible.
            """
        )

        // And the row is really there: the user's own bubble paints its
        // card on the trailing side, so a transcript that rendered nothing
        // cannot pass this.
        let bytesPerRow = pixels.pixels.count / max(pixels.height, 1)
        let samplesPerPixel = bytesPerRow / max(pixels.width, 1)
        let trailingStart = pixels.width * 3 / 4
        var paintedOnTrailing = false
        for y in 0 ..< max(1, pixels.height / 3) {
            for x in trailingStart ..< pixels.width {
                let offset = y * bytesPerRow + x * samplesPerPixel
                if !isHost(Int(pixels.pixels[offset]),
                           Int(pixels.pixels[offset + 1]),
                           Int(pixels.pixels[offset + 2]))
                {
                    paintedOnTrailing = true
                    break
                }
            }
            if paintedOnTrailing {
                break
            }
        }
        #expect(paintedOnTrailing,
                "the user's own bubble must still paint its card (= the row's surface was removed, the bubble's was not)")
    }
}
