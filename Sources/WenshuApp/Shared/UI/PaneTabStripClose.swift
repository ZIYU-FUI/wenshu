// PaneTabStripClose.swift
//
// The Safari-style close X that lives INSIDE a pane tab.
//
// WHY IT IS NOT A SWIFTUI BUTTON PER TAB
//
// ⇒ ⇒ ⇒ A SwiftUI tab strip that renders every open tab, each with its own
// close `Button`, crashed this app on macOS Liquid Glass (= the window's
// "Update Constraints in Window" pass count). = The shape that survived is
// ONE `NSSegmentedControl`, = because that is ONE AppKit view, = so the
// re-arm is bounded. = The X is therefore drawn by the control itself, =
// inside AppKit's own per-segment interior hook, = and it is NOT a sibling
// SwiftUI button.
//
// WHAT THIS FILE OWNS
//
// The X's metrics and the two rules that decide it: = whether it FITS in a
// segment, = and = how much room it takes from the title. = Both are pure,
// = so both are testable without a window.
//
// MEASURED (= `Tools/wenshu-devtool/probes/segmented_control_segment_frames.swift`):
//
//   - `NSSegmentedCell.drawSegment(_:inFrame:with:)` FIRES on macOS 27 (= 6
//     calls for 3 segments over 2 display passes), = so a drawing made in
//     it reaches the pixels (= a marker drawn there counted 400 red pixels
//     in the rendered bitmap, = the control's own bezel does not cover it).
//   - The segment frames the hook is given are EXACTLY the equal division
//     of the control's bounds (= 240 PT / 3 = 80 PT at x = 0, 80, 160), =
//     so the X's position is read from the frame AppKit itself provides, =
//     and never guessed.

import AppKit
import CoreGraphics

/// The close X of a pane tab (= the Safari-style one).
enum PaneTabStripClose {
    /// The SF Symbol the X is drawn with.
    ///
    /// ⇒ ⇒ ⇒ AND IT IS APPLE'S OWN OUTLINED BADGE: = the boss's own call, =
    /// and the reason is MEASURED: = on the selected tab's blue ground the
    /// FILLED variant reads as a plain white disc (= the hole is what shows
    /// the X, = and the hole is what the filled mark loses at that size), =
    /// while the OUTLINED variant keeps both the ring and the X legible.
    static let glyphName = "xmark.circle"

    /// The size the X is drawn at (= POINTS).
    ///
    /// ⇒ ⇒ ⇒ AND IT IS ONE POINT LARGER THAN THE TITLE: = the boss's own
    /// ruling (= one point larger than the title), and the reason is
    /// MEASURED: = Apple's own filled badge carries its X as a HOLE (=
    /// MEASURED: = 46.7% of its pixels are transparent at 13 PT), = and at
    /// that size the hole is too small to read (= the badge reads as a
    /// plain disc).
    static let glyphPointSize: CGFloat = 14

    /// The X's tap target (= POINTS).
    ///
    /// Apple HIG macOS: = "Layout > Tap targets > macOS = 28 PT minimum". =
    /// The X's INK is 13 PT, = and the tap target around it is the HIG's
    /// minimum, = so a thin mark is still easy to hit.
    static let hitArea: CGFloat = 28

    /// The gap between the X and the segment's LEADING edge (= POINTS).
    ///
    /// ⇒ ⇒ ⇒ AND THE FRAME IS THE CONTENT AREA: = Apple's own header says
    /// the hook's frame "has been adjusted to content area" (=
    /// `NSSegmentedCell.h`: = "For custom content drawing. = frame has been
    /// adjusted to content area"), = so the X's own gap is measured from
    /// there (= and NOT from the capsule's outer edge).
    static let leadingInset: CGFloat = 5

    /// The height of the strip's drawn capsule (= POINTS).
    ///
    /// ⇒ ⇒ ⇒ AND IT IS MEASURED, = NOT GUESSED: = the `.small` control
    /// size's capsule is 20 PT tall (= MEASURED on the control itself, =
    /// and the same height the sidebar's, the inspector's and the chat
    /// zone's switchers already draw at). = The control needs it because
    /// its OWN size is a constraint-solver product (= and the solver has
    /// not run when SwiftUI asks, =
    static let capsuleHeight: CGFloat = 20

    /// The gap between the X and the title (= POINTS).
    ///
    /// The title stops before the X, = and the X needs its own air, = so
    /// the gap is part of the room the X takes.
    static let titleGap: CGFloat = 4

    /// The room the X takes from the title (= POINTS).
    ///
    /// ⇒ ⇒ ⇒ This is the number the title's own budget gives up: = the X's
    /// size plus the gap that separates it from the title.
    static var room: CGFloat {
        glyphPointSize + titleGap
    }

    /// Whether the X FITS in a segment of `share` points.
    ///
    /// ⇒ ⇒ ⇒ THE RULE: = the X appears only when the tab can hold the X AND
    /// still name its document. = A segment that cannot fit the X keeps its
    /// title, = and the X is simply not drawn (= Safari hides the X in a
    /// tab too narrow to carry it). = The title's budget after the X took
    /// its room is the share minus the segment's own inset (= 20.5 PT, =
    /// `PaneTabStripWidth`) minus the X's room, = and it must still hold
    /// ONE character (= a tab that shows nothing but an X names nothing).
    static func fits(share: CGFloat, firstCharacterWidth: CGFloat) -> Bool {
        guard share > 0, firstCharacterWidth > 0 else { return false }
        let titleRoom = share - PaneTabStripWidth.segmentLabelInset - room
        return titleRoom >= firstCharacterWidth
    }

    /// The share a title is fitted against (= the segment's own share,
    /// minus the X's room when the X is drawn in that segment).
    ///
    /// ⇒ ⇒ ⇒ AND THE X IS IN THE SELECTED SEGMENT: = only the SELECTED tab
    /// carries the X, = so the room comes from the
    /// selected tab.
    static func titleShare(share: CGFloat, selected: Bool) -> CGFloat {
        selected ? share - room : share
    }

    /// The font the strip's titles are measured with (= the ONE font, so
    /// the width the scroll walks is the width the control draws).
    ///
    /// ⇒ ⇒ ⇒ AND IT IS THE CONTROL'S OWN LABEL FONT: = MEASURED: the
    /// segmented control's label font is the system font at 13 PT at both
    /// control sizes, = and the strip draws its titles with it.
    static func titleFont() -> NSFont {
        NSFont.systemFont(ofSize: 13)
    }

    /// The narrowest a collapsed tab may be (= POINTS).
    ///
    /// ⇒ ⇒ ⇒ AND IT IS THE CELL'S OWN MINIMUM: = AppKit's cell honours a
    /// label's own width plus the segment's own inset (= MEASURED: = a cell
    /// is `label + 20.5 PT`), = and a cell narrower than that BLOWS UP (=
    /// and the strip overflows the column it was given), =
    ///
    /// ⇒ ⇒ ⇒ AND THE LABEL IS ONE CHARACTER: = the narrowest tab shows its
    /// document's FIRST character, = AND IT IS THE
    /// LADDER'S OWN MEASUREMENT: = the character a collapsed tab draws (=
    /// the ladder's own width and not a number of its own), = so the floor
    /// a collapsed tab sits on is the width its own character holds.
    static var collapsedCharacterWidth: CGFloat {
        PaneTabStripTitle.drawnWidth(of: "十", font: titleFont())
    }

    /// The narrowest a collapsed tab may be (= POINTS).
    static var collapsedMinimumWidth: CGFloat {
        PaneTabStripWidth.segmentLabelInset + collapsedCharacterWidth
    }

    /// The width the SELECTED tab needs at its narrowest (= the cell's own
    /// minimum plus the X's room).
    static var selectedMinimumWidth: CGFloat {
        PaneTabStripWidth.segmentLabelInset + room + collapsedCharacterWidth
    }

    /// ⇒ ⇒ ⇒ AND THE SELECTED TAB'S OWN WIDTH IS ITS NATURAL WIDTH: = the
    /// boss's formula (= the total width minus the selected tab's natural
    /// width (= its own title's length plus the X's room) is what the
    /// others share), and the natural width is the title's own width plus
    /// the X's room plus the cell's own inset.
    static func naturalWidth(
        of title: String,
        font: NSFont,
        carriesTheX: Bool
    ) -> CGFloat {
        let titleWidth = PaneTabStripTitle.drawnWidth(of: title, font: font)
        let xRoom = carriesTheX ? room : 0
        return titleWidth + xRoom + PaneTabStripWidth.segmentLabelInset
    }

    /// ⇒ ⇒ ⇒ AND THE OTHERS SHARE WHAT IS LEFT, = AND THEY SHARE IT BY
    /// THEIR OWN TITLES' LENGTH (= the boss's gradient: = a long title
    /// keeps more room than a short one, = and no tab is crushed to a fixed
    /// width).
    ///
    /// ⇒ ⇒ ⇒ AND THE ANSWER IS NIL WHEN THE STRIP MUST NOT COLLAPSE: =
    ///
    /// ⇒ ⇒ ⇒ AND THE REASON IS APPKIT'S OWN CELL: = a cell is `label +
    /// segmentLabelInset` wide, =
    static func collapsedWidths(
        columnWidth: CGFloat,
        titles: [String],
        font: NSFont,
        selectedSegment: Int
    ) -> [CGFloat]? {
        let count = titles.count
        guard count > 1, columnWidth > 0, selectedSegment >= 0, selectedSegment < count else {
            return nil
        }
        let others = titles.indices.filter { $0 != selectedSegment }
        let othersMinimum = collapsedMinimumWidth
        let othersFloor = othersMinimum * CGFloat(others.count)
        // ⇒ ⇒ ⇒ AND THE SELECTED TAB KEEPS ITS OWN MINIMUM: = it shows a
        // character and the X, =
        let selectedMinimum = selectedMinimumWidth
        // ⇒ ⇒ ⇒ AND WHEN THE COLUMN CANNOT HOLD THE FLOOR, = THE STRIP DOES
        // NOT COLLAPSE: = the cells would blow up and the strip would
        // overflow its column.
        guard columnWidth >= othersFloor + selectedMinimum else {
            return nil
        }
        // ⇒ ⇒ ⇒ AND THE SELECTED TAB'S OWN WIDTH IS ITS NATURAL WIDTH: =
        // the boss's formula (= the total width minus the selected tab's
        // natural width (= its own title's length plus the X's room) is
        // what the others share).
        let selectedNatural = naturalWidth(
            of: titles[selectedSegment],
            font: font,
            carriesTheX: true
        )
        // ⇒ ⇒ ⇒ AND IT NEVER TAKES MORE THAN THE COLUMN LEAVES: = the
        // others keep their floor.
        let selectedWidth = min(selectedNatural, columnWidth - othersFloor)
        let remaining = columnWidth - selectedWidth
        // ⇒ ⇒ ⇒ AND THE OTHERS SHARE WHAT IS LEFT BY THEIR OWN TITLES:
        let othersNatural = others.map {
            max(
                naturalWidth(of: titles[$0], font: font, carriesTheX: false),
                othersMinimum
            )
        }
        let othersTotal = othersNatural.reduce(0, +)
        guard othersTotal > 0, remaining > 0 else {
            return nil
        }
        var widths = Array(repeating: CGFloat(0), count: count)
        widths[selectedSegment] = selectedWidth
        var given = 0.0
        for (position, index) in others.enumerated() {
            let share = max(remaining * othersNatural[position] / othersTotal, othersMinimum)
            widths[index] = share
            given += share
        }
        // ⇒ ⇒ ⇒ AND THE SELECTED TAB CARRIES THE ROUNDING: = the shares are
        // a division, = and a division leaves a fraction, = so the strip
        // still fills its column to the point.
        //
        // ⇒ ⇒ ⇒ AND IT IS THE SELECTED TAB, = and NOT one of the others: =
        // the others sit on their own floor (= the minimum a cell may
        // take), = and a rounding hair that landed on one of them put it
        // BELOW that floor (= MEASURED: the share came out
        // 31.439999999999948 against a floor of 31.439999999999998, and the
        // model refused the whole collapse over one hair).
        widths[selectedSegment] += remaining - given
        // ⇒ ⇒ ⇒ AND NO CELL IS WIDER THAN ITS SHARE: =
        let total = widths.reduce(0, +)
        if total > columnWidth {
            let scale = columnWidth / total
            for index in widths.indices {
                widths[index] *= scale
            }
        }
        // ⇒ ⇒ ⇒ AND NO CELL IS NARROWER THAN ITS OWN MINIMUM: = the last
        // tab's share can fall below it, = and a cell below its minimum
        // BLOWS UP.
        guard widths.allSatisfy({ $0 >= collapsedMinimumWidth }) else {
            return nil
        }
        return widths
    }

    /// ⇒ ⇒ ⇒ AND THE STRIP COLLAPSES ONLY WHEN IT MUST: = a strip that folded
    /// whenever it could would waste the room it was given, and so the equal share is
    /// kept as long as the SELECTED tab's title fits in it (= and the
    /// selected tab is the one that needs the room, = because it carries
    /// the X).
    static func selectedTitleFits(
        title: String,
        share: CGFloat,
        font: NSFont
    ) -> Bool {
        guard share > 0 else { return true }
        // ⇒ ⇒ ⇒ AND THE SELECTED TAB IS THE ONE THAT NEEDS THE ROOM: it
        // carries the X, = so its budget is the share minus the X's room.
        let budget = titleShare(share: share, selected: true)
        return PaneTabStripTitle.drawnWidth(of: title, font: font) <= budget
    }

    /// The frame the X's INK takes inside a segment's frame.
    ///
    /// The frame is the one AppKit's own per-segment hook provides, = so
    /// the X is placed where the segment really is.
    static func glyphRect(in segmentFrame: NSRect) -> NSRect {
        NSRect(
            x: segmentFrame.minX + leadingInset,
            y: segmentFrame.midY - glyphPointSize / 2,
            width: glyphPointSize,
            height: glyphPointSize
        )
    }

    /// The frame the X's HOVER paints behind the mark (= POINTS).
    ///
    /// ⇒ ⇒ ⇒ AND IT IS ONE RING BIGGER THAN THE MARK: = the boss's own
    /// ruling, = and the ring is the wash's OWN ring around the mark (= and
    /// not a bigger mark, = and the mark keeps the size the boss chose).
    ///
    /// ⇒ ⇒ ⇒ AND THE WASH IS THE TAP TARGET: = the HIG's own 28 PT minimum
    /// (= and the very rectangle the pointer's business covers), = and the
    /// mark sits in its middle (= and the wash's ring is what shows around
    /// it).
    ///
    /// ⇒ ⇒ ⇒ AND IT IS CLIPPED TO THE TAB'S OWN HEIGHT: = the strip's
    /// capsule is 20 PT tall (= MEASURED), = and a wash taller than the tab
    /// would spill into the content below it.
    ///
    /// ⇒ ⇒ ⇒ AND IT IS A WASH, NOT A DISC: = the wash is a TRANSLUCENT
    /// circle, = so the selected tab's own accent ground still shows
    /// through it (= and the mark's own white ring and X stay crisp on
    /// top).
    static func hoverWashRect(in segmentFrame: NSRect) -> NSRect {
        let ink = glyphRect(in: segmentFrame)
        let target = hitRect(in: segmentFrame)
        // ⇒ ⇒ ⇒ AND THE CIRCLE IS THE SMALLER OF THE TWO: = the tap
        // target's own size (= 28 PT), = and the tab's own height (= 20
        // PT), = and it stays centred on the mark either way.
        let diameter = min(target.height, segmentFrame.height)
        guard diameter > 0 else { return ink }
        return NSRect(
            x: ink.midX - diameter / 2,
            y: ink.midY - diameter / 2,
            width: diameter,
            height: diameter
        )
    }

    /// The alpha of the X's hover wash.
    ///
    /// ⇒ ⇒ ⇒ AND IT IS THE REPO'S OWN TOKEN: =
    /// `DesignTokens.surfaceActiveTintAlpha` (= the project SSOT's own
    /// "subtle accent overlay" alpha), = and NOT a number of this file's
    /// own.
    @MainActor
    static var hoverWashAlpha: CGFloat {
        DesignTokens.surfaceActiveTintAlpha
    }

    /// The frame a segment owns, = from the control's OWN geometry.
    ///
    /// ⇒ ⇒ ⇒ AND THE WIDTHS ARE THE SOURCE: = the segments are NOT equal
    /// any more (= the selected tab takes the room, and the others share
    /// what is left by their titles' length), = so a frame computed from an
    /// equal division lands on the WRONG tab.
    ///
    /// ⇒ ⇒ ⇒ AND THE WIDTHS COME FROM APPKIT: = the control's own
    /// `width(forSegment:)`, = which is what the control itself lays the
    /// cells out with.
    static func segmentFrame(
        ofSegment segment: Int,
        inControlBounds bounds: NSRect,
        segmentCount: Int,
        widths: [CGFloat]
    ) -> NSRect {
        guard segment >= 0, segmentCount > 0, bounds.width > 0 else { return .zero }
        // ⇒ ⇒ ⇒ AND THE WIDTHS WALK THE SEGMENTS: = the X's frame is the
        // sum of the widths before it, = which is where the tab really
        // starts.
        var x: CGFloat = 0
        for index in 0 ..< segment {
            x += index < widths.count ? widths[index] : 0
        }
        let width = segment < widths.count ? widths[segment] : 0
        guard width > 0 else { return .zero }
        return NSRect(
            x: x,
            y: 0,
            width: width,
            height: bounds.height
        )
    }

    /// The frame the X's TAP TARGET takes inside a segment's frame.
    ///
    /// The tap target is the HIG's 28 PT minimum, = centred on the X's ink,
    /// = and it is clamped to the segment's own frame (= so a narrow
    /// segment never claims a tap target that reaches into its neighbour).
    static func hitRect(in segmentFrame: NSRect) -> NSRect {
        let ink = glyphRect(in: segmentFrame)
        var target = NSRect(
            x: ink.midX - hitArea / 2,
            y: ink.midY - hitArea / 2,
            width: hitArea,
            height: hitArea
        )
        target = target.intersection(segmentFrame)
        return target
    }
}
