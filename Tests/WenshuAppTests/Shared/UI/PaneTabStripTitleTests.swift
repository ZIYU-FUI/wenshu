// Tests/WenshuAppTests/Shared/UI/PaneTabStripTitleTests.swift
//
// The title rule a pane tab strip's segment follows.
//
// The boss's rule (= 2026-11-12):
//
// - "有可能让 teb 栏宽度显示文字，这种情况被允许" (= a narrow tab may
//   still show text, = and a truncated title is text).
// - "缩到一定程度，那个...就没有意义了，不如只能显示...的时候，连...
//   都不显示" (= once it shrinks so far that only the '…' would show,
//   = that '…' has no meaning, = so show nothing at all).
//
// The two halves of this suite are the two kinds of evidence the rule
// needs:
//
// 1. The RULE's own answers (= the pure function, = so a wrong tier is
//    a wrong string).
// 2. The DRAWN PIXELS (= the real control in a real window, = so the
//    rule is proved against what AppKit actually paints, = and not
//    against the rule's own arithmetic).
//
// The second half is the one that bites: the rule says "nothing" and
// only the pixels can say whether the cell really draws nothing (=
// and the OLD behaviour, = where AppKit drew the lone ellipsis, = is
// exactly the defect this rule removes).

import AppKit
import Testing
@testable import WenshuApp

@Suite("The pane tab strip's title rule")
struct PaneTabStripTitleTests {
    /// The font the control draws its label with (= the system font
    /// at 13 PT, = MEASURED at both control sizes).
    ///
    /// It is a FUNCTION and not a stored property because `NSFont` is
    /// not `Sendable` (= Swift 6's concurrency check reads a stored
    /// static of that type as shared mutable state).
    @MainActor
    private static func labelFont() -> NSFont {
        NSFont.systemFont(ofSize: 13)
    }

    /// The width of a string in the label font.
    @MainActor
    private static func width(of string: String) -> CGFloat {
        (string as NSString).size(withAttributes: [.font: labelFont()]).width
    }

    // MARK: - The rule's own answers

    @Test("A title that fits is drawn whole")
    @MainActor
    func wholeTitleWhenItFits() {
        let title = "十二地仙"
        let width = Self.width(of: title)
        // The cell has room for the title and more.
        let share = width + 20
        #expect(PaneTabStripTitle.fitted(title, share: share, font: Self.labelFont()) == title)
    }

    @Test("A title that does not fit is cut at its start and marked with an ellipsis")
    @MainActor
    func truncatedTitleKeepsItsStart() {
        let title = "十二地仙"
        // The cell fits two characters and the ellipsis.
        let share = PaneTabStripTitle.drawnWidth(of: "十二", font: Self.labelFont())
            + PaneTabStripTitle.ellipsisCost + 1
        let fitted = PaneTabStripTitle.fitted(title, share: share, font: Self.labelFont())
        #expect(fitted == "十二…")
        // The truncation keeps the START (= the part that names the
        // title), = not its tail.
        #expect(fitted.hasPrefix("十二"))
    }

    @Test("A cell that can hold only the ellipsis holds nothing")
    @MainActor
    func nothingWhenOnlyTheEllipsisWouldFit() {
        let title = "十二地仙"
        // The cell fits the ellipsis and NOT one character beside it.
        let share = PaneTabStripTitle.ellipsisCost + 1
        let fitted = PaneTabStripTitle.fitted(title, share: share, font: Self.labelFont())
        #expect(fitted == PaneTabStripTitle.nothingMarker)
        // The lone ellipsis is the case the boss ruled out.
        #expect(!fitted.contains("…"))
        // And the marker draws nothing: = it measures 0 PT wide.
        #expect(
            PaneTabStripTitle.drawnWidth(of: fitted, font: Self.labelFont()) < 0.5,
            "the nothing marker must measure 0 PT wide"
        )
    }

    @Test("A cell too narrow for the ellipsis holds nothing either")
    @MainActor
    func nothingWhenNothingWouldFit() {
        let title = "十二地仙"
        for share in [0.5, 1, 4, 8, 11] {
            let fitted = PaneTabStripTitle.fitted(title, share: share, font: Self.labelFont())
            #expect(
                fitted == PaneTabStripTitle.nothingMarker,
                "share \(share) must draw nothing, = it drew '\(fitted)'"
            )
        }
    }

    @Test("A strip that has not been measured yet keeps every title whole")
    @MainActor
    func unmeasuredStripKeepsWholeTitles() {
        let title = "十二地仙"
        #expect(PaneTabStripTitle.fitted(title, share: 0, font: Self.labelFont()) == title)
    }

    @Test("The rule never returns the lone ellipsis, whatever the title")
    @MainActor
    func theLoneEllipsisIsNeverDrawn() {
        // Every title, = at every share, = must land on whole, = on a
        // truncation that carries at least one character, = or on
        // nothing. = The lone ellipsis is not an answer.
        let titles = ["仙", "十二", "十二地仙", "A", "Chapter One", "第 1 章"]
        for title in titles {
            for share in stride(from: 0.5, through: 80, by: 0.5) {
                let fitted = PaneTabStripTitle.fitted(title, share: share, font: Self.labelFont())
                if fitted == "…" {
                    Issue.record("the lone ellipsis is not an answer: title '\(title)' at \(share) PT")
                }
                if fitted.hasSuffix("…") {
                    // A truncation must carry at least one character of
                    // the title beside the ellipsis.
                    #expect(
                        fitted.count > 1,
                        "a truncation must carry a character: title '\(title)' at \(share) PT drew '\(fitted)'"
                    )
                }
                if fitted == PaneTabStripTitle.nothingMarker {
                    // Nothing is an answer, = but only when NOTHING of
                    // the title fits beside the ellipsis: = that is
                    // exactly the case where AppKit's own truncation
                    // would leave the lone ellipsis (= MEASURED: 34 ink
                    // pixels at a 12 to 25 PT cell), = and the lone
                    // ellipsis is the case the boss ruled out.
                    let characterWidth = title.first.map {
                        PaneTabStripTitle.drawnWidth(of: String($0), font: Self.labelFont())
                    } ?? 0
                    #expect(
                        characterWidth + PaneTabStripTitle.ellipsisCost > share,
                        "nothing is only right when no character fits beside the ellipsis: title '\(title)' at \(share) PT"
                    )
                }
            }
        }
    }

    // MARK: - The drawn pixels

    /// The TEXT pixels the FIRST cell of a strip draws.
    ///
    /// The measurement path is the HOUSE's proven one
    /// (= `EditorTabStripSelectedLabelTests.swift`): = a real
    /// `NSSegmentedControl` in a real `NSWindow`, = `displayIfNeeded`,
    /// = then `bitmapImageRepForCachingDisplay` + `cacheDisplay(in:to:)`.
    /// The TEXT's own pixels are counted by luminance (> 140), = the
    /// house's own rule.
    @MainActor
    private static func firstCellInk(
        title: String,
        share: CGFloat,
        tabs: Int
    ) -> Int {
        let height: CGFloat = 40
        let regionWidth = share * CGFloat(tabs)
        let control = NSSegmentedControl()
        control.segmentCount = tabs
        for index in 0 ..< tabs {
            control.setLabel(title, forSegment: index)
        }
        control.segmentStyle = .roundRect
        control.trackingMode = .selectOne
        control.segmentDistribution = .fillEqually
        control.controlSize = .small
        if #available(macOS 27.0, *) {
            control.role = .valueSelection
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: regionWidth, height: height),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        let host = NSView(frame: NSRect(x: 0, y: 0, width: regionWidth, height: height))
        host.wantsLayer = true
        host.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        window.contentView = host
        host.addSubview(control)
        control.frame = host.bounds
        host.layoutSubtreeIfNeeded()
        control.layoutSubtreeIfNeeded()
        window.orderFront(nil)
        window.displayIfNeeded()

        var ink = 0
        let bounds = host.bounds
        if let rep = host.bitmapImageRepForCachingDisplay(in: bounds) {
            rep.size = bounds.size
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
            NSColor.windowBackgroundColor.setFill()
            bounds.fill()
            NSGraphicsContext.restoreGraphicsState()
            host.cacheDisplay(in: bounds, to: rep)

            if let data = rep.bitmapData {
                let wide = rep.pixelsWide
                let tall = rep.pixelsHigh
                let rowBytes = rep.bytesPerRow
                let samples = rep.samplesPerPixel
                let limit = Int(share * 2)
                for y in 0 ..< tall {
                    for x in 0 ..< min(wide, limit) {
                        let offset = y * rowBytes + x * samples
                        guard offset < rowBytes * tall else { break }
                        let red = Int(data[offset])
                        let green = offset + 1 < rowBytes * tall ? Int(data[offset + 1]) : 0
                        let blue = offset + 2 < rowBytes * tall ? Int(data[offset + 2]) : 0
                        let luminance = (red * 299 + green * 587 + blue * 114) / 1000
                        if luminance > 140 {
                            ink += 1
                        }
                    }
                }
            }
        }
        window.orderOut(nil)
        return ink
    }

    @Test("A cell that can hold only the ellipsis paints NOTHING")
    @MainActor
    func aNarrowCellPaintsNothing() {
        // The OLD behaviour, = measured: = at these widths AppKit drew
        // the lone ellipsis (= 34 ink pixels, = the three dots of '…')
        // and below them a clipped piece of a dot (= 15 to 37 ink
        // pixels, = which is no text at all). = The rule now hands the
        // control the NOTHING MARKER, = and the marker paints zero
        // pixels.
        let title = "十二地仙"
        for share in [4.0, 8.0, 11.0, 12.0, 16.0, 20.0, 24.0] {
            let drawn = PaneTabStripTitle.fitted(
                title,
                share: share,
                font: Self.labelFont()
            )
            #expect(
                drawn == PaneTabStripTitle.nothingMarker,
                "share \(share) must draw nothing, = the rule drew '\(drawn)'"
            )

            let ink = Self.firstCellInk(title: drawn, share: share, tabs: 8)
            #expect(ink == 0, "a cell at \(share) PT painted \(ink) pixels, = it must paint none")
        }
    }

    @Test("A cell that can hold a truncated title paints that truncation")
    @MainActor
    func aNarrowCellPaintsItsTruncation() {
        // The tier the boss ALLOWED: = the tab still shows text, = and
        // the text is the start of the title plus the ellipsis.
        let title = "十二地仙"
        for share in [26.0, 30.0, 36.0, 40.0, 48.0] {
            let drawn = PaneTabStripTitle.fitted(
                title,
                share: share,
                font: Self.labelFont()
            )
            #expect(drawn.hasSuffix("…"), "share \(share) must draw a truncation, = it drew '\(drawn)'")
            #expect(drawn.count > 1, "a truncation must carry a character, = it drew '\(drawn)'")

            let ink = Self.firstCellInk(title: drawn, share: share, tabs: 8)
            #expect(ink > 0, "a cell at \(share) PT painted nothing, = it must paint its truncation")
        }
    }

    @Test("A cell with room for the title paints the whole title")
    @MainActor
    func aWideCellPaintsTheWholeTitle() {
        let title = "十二地仙"
        let reference = Self.firstCellInk(title: title, share: 200, tabs: 8)
        #expect(reference > 0)
        for share in [52.0, 60.0, 80.0] {
            let drawn = PaneTabStripTitle.fitted(
                title,
                share: share,
                font: Self.labelFont()
            )
            #expect(drawn == title, "share \(share) must draw the whole title, = it drew '\(drawn)'")

            let ink = Self.firstCellInk(title: drawn, share: share, tabs: 8)
            #expect(
                ink == reference,
                "a cell at \(share) PT painted \(ink) pixels, = the whole title is \(reference)"
            )
        }
    }

    // MARK: - The marker and the division

    /// The drawn cell boundaries (= the hairline dividers AppKit draws
    /// between two cells).
    @MainActor
    private static func dividers(of control: NSSegmentedControl) -> [CGFloat] {
        var raw: [CGFloat] = []
        func scan(_ layer: CALayer) {
            let frame = layer.frame
            if String(describing: type(of: layer)) == "CALayer",
               frame.width == 1,
               frame.height > 6,
               frame.height < 18
            {
                raw.append(frame.origin.x)
            }
            for sub in layer.sublayers ?? [] {
                scan(sub)
            }
        }
        if let layer = control.layer {
            scan(layer)
        }
        var out: [CGFloat] = []
        for position in raw.sorted()
            where out.last.map({ abs($0 - position) > 0.5 }) ?? true
        {
            out.append(position)
        }
        return out
    }

    /// A control whose cells all carry `label`, = in a region of
    /// `region` points.
    @MainActor
    private static func strip(
        label: String,
        tabs: Int,
        region: CGFloat
    ) -> (dividers: [CGFloat], window: NSWindow, host: NSView) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: region, height: 40),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        let host = NSView(frame: NSRect(x: 0, y: 0, width: region, height: 40))
        host.wantsLayer = true
        window.contentView = host
        let control = NSSegmentedControl()
        control.segmentCount = tabs
        for index in 0 ..< tabs {
            control.setLabel(label, forSegment: index)
        }
        control.segmentStyle = .roundRect
        control.trackingMode = .selectOne
        control.segmentDistribution = .fillEqually
        control.controlSize = .small
        if #available(macOS 27.0, *) {
            control.role = .valueSelection
        }
        host.addSubview(control)
        control.frame = host.bounds
        window.orderFront(nil)
        host.layoutSubtreeIfNeeded()
        window.displayIfNeeded()
        return (Self.dividers(of: control), window, host)
    }

    @Test("A cell that shows nothing still takes its share of the region")
    @MainActor
    func theNothingMarkerKeepsTheDivision() {
        // MEASURED: an EMPTY label breaks the division. = AppKit gives
        // a cell with no title its own minimum width (= about 21 PT), =
        // so the cells stop adding up to the region: = 12 empty cells
        // in a 200 PT region stepped by 21.0 / 21.5 PT and drew their
        // last divider at 205.5 PT (= 5.5 PT OVER the region), = and
        // 24 of them drew it at 332 PT (= 132 PT over).
        //
        // ⇒ ⇒ ⇒ SO THE MARKER IS A ZERO WIDTH SPACE: = it carries a
        // character (= so AppKit divides the frame), = and it draws
        // nothing (= so the cell shows nothing).
        let tabs = 12
        let region: CGFloat = 200
        let share = region / CGFloat(tabs)

        let empty = Self.strip(label: "", tabs: tabs, region: region)
        let emptySteps = (0 ..< max(empty.dividers.count - 1, 0)).map {
            empty.dividers[$0 + 1] - empty.dividers[$0]
        }
        empty.window.orderOut(nil)

        let marked = Self.strip(
            label: PaneTabStripTitle.nothingMarker,
            tabs: tabs,
            region: region
        )
        let markedSteps = (0 ..< max(marked.dividers.count - 1, 0)).map {
            marked.dividers[$0 + 1] - marked.dividers[$0]
        }
        let lastDivider = marked.dividers.last ?? 0
        marked.window.orderOut(nil)

        #expect(
            !emptySteps.isEmpty,
            "the empty label's cells must have been measured, = the division was not read"
        )
        #expect(
            markedSteps.allSatisfy { abs($0 - share) < 1.5 },
            """
            A strip whose cells show nothing stepped by \
            \(markedSteps.map { String(format: "%.1f", $0) }) in a \
            \(Int(region)) PT region (= a \(String(format: "%.2f", share)) PT \
            share). = Every cell must take its share, = or the strip \
            overflows the column it was given.
            """
        )
        #expect(
            lastDivider <= region,
            "the last divider landed at \(lastDivider) PT, = past the \(Int(region)) PT region"
        )
    }
}
