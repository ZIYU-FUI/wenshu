// ChromeBottomFooterHeightTests.swift · Wenshu
//
// Every column's bottom bar is the same height, so the window's bottom
// edge reads as one clean line.
//
// The shared `ChromeBottomFooter` used to have no height of its own: the
// bar's size was whatever the caller's content happened to be. Two call
// sites put one line of text in it (= a `.callout` row), and the materials
// column put a default-size bordered button in it (= ~9 PT taller), so the
// materials column's bar juts up past its neighbours'.
//
// The component now pins its content row to a fixed height, so the bar's
// height is a property of the shared component and not of the content each
// caller passes. Anything taller than the row is clipped, which is why the
// materials column's action is a plain `.callout` button.
//
// The measurement is the PAINTED height, not the proposed one: the footer
// is rendered into an `NSBitmapImageRep` and the rows whose pixels differ
// from the host's background are counted. A view that merely proposes a
// fixed height but paints something taller still renders taller, and this
// test catches that.
import AppKit
import SwiftUI
import Testing
@testable import WenshuApp

@Suite("Chrome bottom footer height")
struct ChromeBottomFooterHeightTests {

    /// The height the shared footer must paint at, in points.
    @MainActor
    private var canonicalHeight: CGFloat { DesignTokens.chromeBottomFooterHeight }

    // MARK: - The measurement

    /// The painted height of a view, in points.
    ///
    /// The view is hosted in a real `NSWindow`, rendered into an
    /// `NSBitmapImageRep` via `cacheDisplay(in:to:)`, and the rows whose
    /// pixels differ from the host's background are counted. The count is
    /// the painted height: a view that proposes one height and paints
    /// another is caught here.
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
        // A background the footer's own surface cannot be mistaken for.
        window.backgroundColor = .magenta
        window.contentView = host
        window.orderFront(nil)
        host.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.4))
        host.layoutSubtreeIfNeeded()

        let bounds = host.bounds
        let rep = host.bitmapImageRepForCachingDisplay(in: bounds)!
        rep.size = bounds.size
        // Paint the host's background first, so a row that differs is a
        // row the view drew on.
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
        for y in 0..<rep.pixelsHigh {
            for x in 0..<width {
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
        // The rep is in device pixels; the height is in points.
        let scale = Double(rep.pixelsHigh) / Double(bounds.height)
        return CGFloat(paintedRows) / scale
    }

    // MARK: - The three call sites' content shapes

    /// The sidebar's and the chat's shape: one line of `.callout` text.
    @MainActor
    private func textRow() -> some View {
        HStack(spacing: DesignTokens.spacingTight) {
            SFIcon("tray.full", style: .inlineSmall, color: IconColor.secondary)
            Text("12")
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    /// The materials column's shape before the fix: the same row with a
    /// DEFAULT-size bordered button in it.
    @MainActor
    private func rowWithDefaultButton() -> some View {
        HStack(spacing: DesignTokens.spacingTight) {
            textRow()
            Button("Make covers") {}
        }
    }

    /// The materials column's shape after the fix: the same row with a
    /// SMALL button in it.
    @MainActor
    private func rowWithSmallButton() -> some View {
        HStack(spacing: DesignTokens.spacingTight) {
            textRow()
            Button("Make covers") {}
                .controlSize(.small)
        }
    }

    // MARK: - The facts

    @Test("Every column's bottom bar paints at the same height")
    @MainActor
    func everyColumnBarIsTheSameHeight() throws {
        let textOnly = paintedHeight(of: ChromeBottomFooter { textRow() })
        let defaultButton = paintedHeight(of: ChromeBottomFooter { rowWithDefaultButton() })
        let smallButton = paintedHeight(of: ChromeBottomFooter { rowWithSmallButton() })

        #expect(
            abs(textOnly - defaultButton) <= 1,
            """
            A bar carrying a text row painted \(textOnly) PT while a bar carrying \
            the same row plus a default-size button painted \(defaultButton) PT: the \
            bar's height still comes from the content it carries.
            """
        )
        #expect(
            abs(textOnly - smallButton) <= 1,
            """
            A bar carrying a text row painted \(textOnly) PT while a bar carrying \
            the same row plus a small button painted \(smallButton) PT: the bar's \
            height still comes from the content it carries.
            """
        )
    }

    @Test("The bar paints at the shared footer's canonical height")
    @MainActor
    func theBarPaintsAtTheCanonicalHeight() throws {
        let textOnly = paintedHeight(of: ChromeBottomFooter { textRow() })
        #expect(
            abs(textOnly - canonicalHeight) <= 1,
            """
            The bar painted \(textOnly) PT; the shared footer's canonical height is \
            \(canonicalHeight) PT.
            """
        )
    }

    @Test("The sidebar's bottom bar paints at the canonical height")
    @MainActor
    func theSidebarBarIsTheCanonicalHeight() throws {
        let sidebar = paintedHeight(of: AppleSidebarBottomNewButton(action: {}))
        #expect(
            abs(sidebar - canonicalHeight) <= 1,
            """
            The sidebar's bottom bar painted \(sidebar) PT; the shared footer's \
            canonical height is \(canonicalHeight) PT.
            """
        )
    }

    @Test("The chat's bottom bar paints at the canonical height")
    @MainActor
    func theChatBarIsTheCanonicalHeight() throws {
        // The chat's footer carries one line of `.callout` text, the same
        // shape the sidebar's bar carries.
        let chat = paintedHeight(of: ChromeBottomFooter { chatFooterRow() })
        #expect(
            abs(chat - canonicalHeight) <= 1,
            """
            The chat's bottom bar painted \(chat) PT; the shared footer's canonical \
            height is \(canonicalHeight) PT.
            """
        )
    }

    /// The chat footer's content row (= the token counter).
    ///
    /// The same shape `ChatInputBarView` puts in the shared footer.
    @MainActor
    private func chatFooterRow() -> some View {
        HStack(spacing: DesignTokens.spacingTight) {
            Text("1200 tokens used")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    @Test("The chat's footer still goes through the shared component")
    func theChatFooterUsesTheSharedComponent() throws {
        let url = SourceLocator.url("Sources/WenshuApp/Features/Chat/View/ChatInputBarView.swift")
        let raw = try String(contentsOf: url, encoding: .utf8)
        #expect(
            raw.contains("ChromeBottomFooter"),
            """
            The chat's footer no longer goes through the shared `ChromeBottomFooter`, \
            so its bar is no longer the same component as the other columns' bars.
            """
        )
    }
}
