// ChromeHairlineTests.swift · Wenshu
//
// The chrome bands in this app are closed by ONE hairline, and this
// suite holds every band that closes a band to that one mark.
//
// What the boss asked for (= 2026-11-13): the toolbar and the body read
// as one undifferentiated plane, = and the editor zone's document strip
// and the chat zone's session bar do not close their bands the way the
// other column-top bands close theirs.
//
// The measurement is the PAINTED result, not the source text. A band is
// rendered over a host ground the hairline cannot be mistaken for (= the
// ground is magenta, = a colour no separator paints), = and the pixels
// are read: = a band that closes with the hairline paints a line across
// its bottom edge, = and a band that does not leaves the ground showing.
//
// A source-text assertion cannot hold this: the hairline is one modifier
// on a shared component, = and the same component serves the three
// column-top bands that already had it, = so only the painted pixels say
// whether a given band got the mark.
//
// The ground is drawn INSIDE the rendered view (= a magenta layer under
// the band) rather than behind the window: = the hairline is an OVERLAY
// the band draws, = and it is the band's own pixels the measurement reads.
import AppKit
import SwiftUI
import Testing
@testable import WenshuApp
import WenshuData

@MainActor
@Suite("The chrome hairline")
struct ChromeHairlineTests {
    /// The ground no separator paints (= so a painted row is the hairline).
    private static let ground = Color(red: 1, green: 0, blue: 1)

    /// One painted row's colour.
    ///
    /// The rows alone cannot tell SwiftUI's own `Divider()` from a
    /// hand-rolled bar (= the two paint the same rows), = so the guard
    /// carries the colour too.
    private struct PaintedColour: Hashable {
        let red: Int
        let green: Int
        let blue: Int
    }

    /// The rows of a rendered view that are painted across its whole width.
    ///
    /// A hairline row is painted edge to edge (= the band's own content is
    /// ink at some columns and nothing at others, = so a row that is fully
    /// painted is the line, = not the content).
    ///
    /// The rows are counted from the BOTTOM of the rendering, = so index 0
    /// is the band's LOWER edge and the last index is its top edge.
    ///
    /// ⇒ ⇒ ⇒ MEASURED, = and the orientation is pinned against the PNG
    /// (= whose rows are top-down by spec): = a one-point marker rendered
    /// at the band's TOP yields indices [54, 55], = and the same marker at
    /// the BOTTOM yields [0, 1]. ⇒ ⇒ ⇒ The flip is `CGContext`'s own
    /// (= `draw(_:in:)` paints the image into a bottom-up context), = and
    /// `pixelHeight - 1 - row` is what undoes it.
    private func paintedRows<V: View>(
        of view: V,
        width: CGFloat = 240,
        height: CGFloat = DesignTokens.paneTabHotArea
    ) -> [Int] {
        let renderer = ImageRenderer(
            content: ZStack {
                Self.ground
                view
            }
            .frame(width: width, height: height)
        )
        // Two device pixels per point, = so a one-point hairline is two
        // rows and the measurement can tell a hairline from a smear.
        renderer.scale = 2

        guard let image = renderer.cgImage else { return [] }
        let pixelWidth = image.width
        let pixelHeight = image.height
        let bytesPerRow = pixelWidth * 4
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * pixelHeight)
        guard let context = CGContext(
            data: &pixels,
            width: pixelWidth,
            height: pixelHeight,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return [] }
        context.draw(image, in: CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))

        var fullRows: [Int] = []
        for row in 0 ..< pixelHeight {
            var painted = 0
            for x in 0 ..< pixelWidth {
                let offset = row * bytesPerRow + x * 4
                let red = Int(pixels[offset])
                let green = Int(pixels[offset + 1])
                let blue = Int(pixels[offset + 2])
                if !(abs(red - 255) < 24 && green < 110 && abs(blue - 255) < 24) {
                    painted += 1
                }
            }
            if painted > Int(Double(pixelWidth) * 0.9) {
                fullRows.append(pixelHeight - 1 - row)
            }
        }
        return fullRows.sorted()
    }

    /// The painted rows of a rendered view WITH their colour.
    ///
    /// `paintedRows` above keeps the row indices and DISCARDS the colour,
    /// = and that is what let a hand-rolled bar pass: = a `Rectangle` of a
    /// fixed colour and SwiftUI's own `Divider()` paint the same ROWS and
    /// differ only in their RGB.
    ///
    /// ⇒ ⇒ ⇒ MEASURED over the same magenta ground: = SwiftUI's own
    /// `Divider()` paints (230, 0, 230), = and
    /// `Rectangle().foregroundStyle(.secondary)` paints (128, 0, 128).
    /// ⇒ ⇒ ⇒ So the colour is what tells the two apart, = and a guard
    /// that reads only the rows cannot.
    private func paintedPixels<V: View>(
        of view: V,
        width: CGFloat = 240,
        height: CGFloat = DesignTokens.paneTabHotArea
    ) -> [Int: PaintedColour] {
        let renderer = ImageRenderer(
            content: ZStack {
                Self.ground
                view
            }
            .frame(width: width, height: height)
        )
        renderer.scale = 2

        guard let image = renderer.cgImage else { return [:] }
        let pixelWidth = image.width
        let pixelHeight = image.height
        let bytesPerRow = pixelWidth * 4
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * pixelHeight)
        guard let context = CGContext(
            data: &pixels,
            width: pixelWidth,
            height: pixelHeight,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return [:] }
        context.draw(image, in: CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))

        var painted: [Int: PaintedColour] = [:]
        for row in 0 ..< pixelHeight {
            var paintedColumns = 0
            var colour = PaintedColour(red: 0, green: 0, blue: 0)
            for x in 0 ..< pixelWidth {
                let offset = row * bytesPerRow + x * 4
                let red = Int(pixels[offset])
                let green = Int(pixels[offset + 1])
                let blue = Int(pixels[offset + 2])
                if !(abs(red - 255) < 24 && green < 110 && abs(blue - 255) < 24) {
                    paintedColumns += 1
                    colour = PaintedColour(red: red, green: green, blue: blue)
                }
            }
            if paintedColumns > Int(Double(pixelWidth) * 0.9) {
                painted[pixelHeight - 1 - row] = colour
            }
        }
        return painted
    }

    /// The columns painted across the WHOLE height of a rendering.
    ///
    /// A full-height column is a VERTICAL rule, = and the hairline is a
    /// horizontal one, = so this is how a vertical stub reads.
    private func fullHeightColumns<V: View>(
        of view: V,
        width: CGFloat = 240,
        height: CGFloat = DesignTokens.paneTabHotArea
    ) -> [Int] {
        let renderer = ImageRenderer(
            content: ZStack {
                Self.ground
                view
            }
            .frame(width: width, height: height)
        )
        renderer.scale = 2

        guard let image = renderer.cgImage else { return [] }
        let pixelWidth = image.width
        let pixelHeight = image.height
        let bytesPerRow = pixelWidth * 4
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * pixelHeight)
        guard let context = CGContext(
            data: &pixels,
            width: pixelWidth,
            height: pixelHeight,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return [] }
        context.draw(image, in: CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))

        var columns: [Int] = []
        for x in 0 ..< pixelWidth {
            var painted = 0
            for row in 0 ..< pixelHeight {
                let offset = row * bytesPerRow + x * 4
                let red = Int(pixels[offset])
                let green = Int(pixels[offset + 1])
                let blue = Int(pixels[offset + 2])
                if !(abs(red - 255) < 24 && green < 110 && abs(blue - 255) < 24) {
                    painted += 1
                }
            }
            if painted > Int(Double(pixelHeight) * 0.9) {
                columns.append(x)
            }
        }
        return columns
    }

    /// The band the test renders (= a plain band of the app's height).
    private func band() -> some View {
        Color.clear
            .frame(height: DesignTokens.paneTabHotArea)
    }

    /// The shared owner paints a line at the bottom edge of the band.
    ///
    /// The band is one `paneTabHotArea` row tall, = and the hairline is
    /// an OVERLAY (= not a row of its own), = so the line lands ON the
    /// band's bottom edge and the band keeps its height.
    @Test("The shared hairline closes a band at its bottom edge")
    @MainActor
    func theSharedHairlineClosesTheBandAtItsBottomEdge() {
        let rows = paintedRows(of: band().bandBottomHairline())

        #expect(
            rows == [0, 1],
            """
            The shared hairline painted rows \(rows) instead of the band's bottom \
            edge (= rows 0 and 1 of a \(DesignTokens.paneTabHotArea) point band, \
            counted from the BOTTOM): the line does not sit on the band's bottom \
            edge, = so the band does not read as chrome above its body.
            """
        )
    }

    /// A band with no hairline leaves the ground showing.
    ///
    /// This is the CONTROL case: = without it, = a suite that asked only
    /// for "a painted row" would pass on a view that paints anything.
    @Test("A band with no hairline paints no line")
    @MainActor
    func aBandWithNoHairlinePaintsNoLine() {
        let rows = paintedRows(of: band())

        #expect(
            rows.isEmpty,
            """
            A band with no hairline painted rows \(rows): the ground is not \
            showing through, = so a painted row cannot be read as the hairline.
            """
        )
    }

    /// The hairline costs the band no height.
    ///
    /// The line is an OVERLAY (= not a row of its own), = so the band is
    /// the same height with the hairline as without it. A hairline that
    /// took a row would push the band's content up, = and the bands are
    /// aligned on purpose (= every band is one `paneTabHotArea` row).
    @Test("The hairline costs the band no height")
    @MainActor
    func theHairlineCostsTheBandNoHeight() {
        let withHairline = paintedRows(of: band().bandBottomHairline())
        let without = paintedRows(of: band())

        #expect(
            withHairline.count == without.count + 2,
            """
            The band painted \(withHairline.count) full rows with the hairline and \
            \(without.count) without it: the hairline took a row of the band's own \
            height (= the bands' heights are aligned on purpose), = or it painted \
            more than a one-point line.
            """
        )
    }

    /// The editor zone's document strip closes its band with the mark.
    ///
    /// The strip is the editor column's column-top band, = and it is the
    /// band the boss named (= the document strip had no line, = so the
    /// editor column's top read as the top of one undifferentiated plane).
    @Test("The editor zone's document strip closes its band")
    @MainActor
    func theEditorDocumentStripClosesItsBand() {
        let tabs = (0 ..< 3).map { index in
            EditorTab(
                id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index))!,
                documentPath: "/library/book-\(index)/chapter-\(index).md",
                draft: "",
                originalBody: "",
                mode: .preview,
                title: nil
            )
        }
        let strip = EditorTabStrip(
            tabs: tabs,
            selectedTabId: tabs.first?.id,
            onSelect: { _ in },
            onClose: { _ in }
        )
        .frame(width: 240)

        let rows = paintedRows(of: strip)

        #expect(
            rows.contains { $0 <= 1 },
            """
            The editor zone's document strip painted rows \(rows) and none of them \
            is the band's bottom edge: the strip does not close its band with a \
            hairline, = so the editor column's top still reads as the top of one \
            undifferentiated plane.
            """
        )
    }

    /// The editor zone's document strip closes its band IN ITS HOST.
    ///
    /// ⇒ ⇒ ⇒ SwiftUI's `Divider()` takes its orientation from the
    /// AMBIENT stack: = inside an `HStack` it paints a VERTICAL rule, = and
    /// the editor zone's document strip IS hosted in an `HStack` (= the
    /// production host is `EditorView.swift:159`). ⇒ ⇒ ⇒ MEASURED on the
    /// app's own window: = with an unpinned `Divider()`, = the editor
    /// column painted 2 of 1297 columns at the band's row (= a one-point
    /// vertical stub at the strip's centre), = where the other three doors
    /// painted the full width. ⇒ ⇒ ⇒ ⇒ ⇒ So the strip is rendered HERE in
    /// its production host, = and the guard reads the FULL-HEIGHT painted
    /// columns (= a vertical rule), = which a standalone rendering cannot
    /// see.
    @Test("The editor zone's document strip closes its band in its host")
    @MainActor
    func theEditorDocumentStripClosesItsBandInItsHost() {
        let tabs = (0 ..< 3).map { index in
            EditorTab(
                id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index))!,
                documentPath: "/library/book-\(index)/chapter-\(index).md",
                draft: "",
                originalBody: "",
                mode: .preview,
                title: nil
            )
        }
        let strip = EditorTabStrip(
            tabs: tabs,
            selectedTabId: tabs.first?.id,
            onSelect: { _ in },
            onClose: { _ in }
        )
        .frame(width: 240)
        // The production host (= `EditorView.swift:159`).
        let hosted = HStack(spacing: 0) {
            strip
            Color.clear.frame(width: 28)
        }

        let columns = fullHeightColumns(of: hosted)

        #expect(
            columns.isEmpty,
            """
            The editor zone's document strip painted full-height columns \
            \(columns) in its production host: = the hairline drew a \
            VERTICAL stub instead of the horizontal edge the band needs, = \
            so the strip does not close its band.
            """
        )
    }

    /// The chat zone's session bar closes its band with the mark.
    ///
    /// The bar is the chat column's column-top band, = and it is the
    /// second band the boss named.
    @Test("The chat zone's session bar closes its band")
    @MainActor
    func theChatZoneSessionBarClosesItsBand() {
        let pages = (0 ..< 3).map { index in
            ChatScopePage(
                scope: .book(BookID(rawValue: "00000000-0000-0000-0000-\(String(format: "%012d", index))")),
                title: "Page \(index)"
            )
        }
        // The bar's own door for a test that measures its DRAWING
        // (= its `init` is private, = so that no other file can build a
        // bar whose pick does nothing).
        let bar = ChatZoneTabBar.unwired(
            pages: pages,
            selectedScope: pages[0].scope
        )
        .frame(width: 240)

        let rows = paintedRows(of: bar)

        #expect(
            rows.contains { $0 <= 1 },
            """
            The chat zone's session bar painted rows \(rows) and none of them is \
            the band's bottom edge: the bar does not close its band with a \
            hairline, = so the chat column's top still reads as the top of one \
            undifferentiated plane.
            """
        )
    }

    /// Every column-top band closes with the shared owner.
    ///
    /// The bands are the sidebar's switcher band, = the assets column's
    /// search band, = the inspector column's page band, = the editor
    /// zone's document strip, = and the chat zone's session bar. They
    /// close with the SAME mark, = so the rule is one rule and not five
    /// rules that drift.
    @Test("Every column-top band closes with the shared hairline")
    func everyColumnBandClosesWithTheSharedHairline() throws {
        let chrome = try SourceLocator.read(
            "Sources/WenshuApp/Features/Chrome/View/ChromeTopBar.swift"
        )
        let editorStrip = try SourceLocator.read(
            "Sources/WenshuApp/Features/Editor/Store/EditorTabStrip.swift"
        )
        let chatBar = try SourceLocator.read(
            "Sources/WenshuApp/Features/Chat/View/ChatZoneTabBar.swift"
        )

        #expect(
            chrome.contains("bandBottomHairline()"),
            "The shared column-top band must close with the shared hairline"
        )
        #expect(
            editorStrip.contains("bandBottomHairline()"),
            "The editor zone's document strip must close with the shared hairline"
        )
        #expect(
            chatBar.contains("bandBottomHairline()"),
            "The chat zone's session bar must close with the shared hairline"
        )
    }

    /// The window's toolbar strip closes with the shared mark.
    ///
    /// The strip is the window's own chrome above the columns, = and it
    /// is the edge the boss named first (= the toolbar and the body read
    /// as one plane). The hairline rides the CONTENT (= the view that
    /// starts where the strip ends), = so it lands on the strip's lower
    /// edge and spans the window's width.
    ///
    /// Apple's own parameter for this edge is
    /// `NSWindow.titlebarSeparatorStyle`, = and it is NOT what the app
    /// uses: = MEASURED on this window, = the property sets and reads
    /// back as `.line`, = and PAINTS NOTHING (= the window paints its
    /// toolbar background itself, = so the system edge is not drawn
    /// there). Apple's HIG names the scroll edge effect for this edge, =
    /// and its precondition (= a scroll view behind floating interface
    /// elements) is not met here, = because the content starts BELOW the
    /// strip. So the edge is the app's own, = drawn with the same
    /// `Divider()` every other edge in the app uses.
    @Test("The window's toolbar strip closes with the shared hairline")
    func theWindowToolbarStripClosesWithTheSharedHairline() throws {
        let root = try SourceLocator.read(
            "Sources/WenshuApp/Shared/UI/LibraryRootView.swift"
        )

        #expect(
            root.contains("windowToolbarBottomHairline()"),
            "The window's toolbar strip must close with the shared hairline"
        )
        #expect(
            !root.contains("WindowTitlebarSeparator"),
            """
            The window must not ask AppKit for this edge: = MEASURED on this \
            window, `titlebarSeparatorStyle` sets and reads back as `.line`, = and \
            paints NOTHING, = so a bridge that sets it buys no line and only \
            leaves a reader believing the edge is the system's.
            """
        )
    }

    /// The mark is one mark.
    ///
    /// The bands close with the same `Divider()` the app already used, =
    /// so the window's edge and the columns' edges are one kind of line
    /// and not two. A second mark (= a hairline of the app's own colour)
    /// would be a second kind of edge in the same place.
    ///
    /// ⇒ ⇒ ⇒ THE GUARD IS THE PAINTED RESULT, = = and NOT THE SOURCE
    /// TEXT: = a hand-rolled bar (= `Rectangle().foregroundStyle(.secondary)`)
    /// paints the same ROWS as SwiftUI's own `Divider()` and differs only
    /// in its RGB, = so a guard that reads the rows alone cannot tell
    /// them apart. ⇒ ⇒ ⇒ MEASURED over the same magenta ground: = the
    /// `Divider()` paints (230, 0, 230) and the hand-rolled bar paints
    /// (128, 0, 128). ⇒ ⇒ ⇒ MEASURED: the mutation that replaces the
    /// owner's `Divider()` with the hand-rolled bar leaves this test GREEN
    /// under a rows-only comparison, = and RED under this one.
    @Test("The hairline paints the system's own divider")
    @MainActor
    func theHairlinePaintsTheSystemsOwnDivider() {
        let owner = paintedPixels(of: ChromeHairline())
        let reference = paintedPixels(of: Divider())

        #expect(
            Set(owner.values) == Set(reference.values),
            """
            The shared hairline painted \(Set(owner.values)) where SwiftUI's \
            own `Divider()` painted \(Set(reference.values)): = the mark must \
            BE the system's separator, = so it follows the app's appearance, = \
            and a bar of a fixed colour is a second kind of edge in the same \
            place.
            """
        )
    }

    /// The mark is the system's own divider, in the CODE.
    ///
    /// ⇒ ⇒ ⇒ This is the ABSENCE half of the same claim, = and it reads
    /// the owner's CODE (= the comments and the string literals blanked)
    /// rather than its prose: = the file's own header names `Divider()`,
    /// = so a whole-file search is satisfied by a COMMENT and a
    /// hand-rolled bar would pass it. ⇒ ⇒ ⇒ MEASURED with the repo's own
    /// masker: = the masked owner's `Divider()` hits = 1 (= the call), =
    /// and under the mutation the masked file reads `Divider()` = false and
    /// `Rectangle(` = true.
    @Test("The hairline's own code is the system's divider")
    func theHairlinesOwnCodeIsTheSystemsDivider() throws {
        let owner = try SourceLocator.read(
            "Sources/WenshuApp/Shared/UI/ChromeHairline.swift"
        )
        let code = SourceCodeMask.code(of: owner)

        #expect(
            code.contains("Divider()"),
            "The shared hairline's own code must call SwiftUI's `Divider()`"
        )
        #expect(
            !code.contains("Rectangle("),
            """
            The shared hairline must not be a hand-rolled bar: = a \
            `Rectangle` of a fixed colour does not follow the app's \
            appearance, = so it is a second kind of edge in the same place.
            """
        )
        #expect(
            !code.contains("Color(") && !code.contains(".fill("),
            "The shared hairline must not paint a colour of its own"
        )
    }
}
