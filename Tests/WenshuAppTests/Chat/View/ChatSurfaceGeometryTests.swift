//
//  ChatSurfaceGeometryTests.swift · Wenshu
//
//  The outgoing message band and the composer field share their
//  resting height floor and their growth rule, NOT their outline: the
//  band is a rounded rectangle at the card radius, the field a capsule
//  through 72 PT (= its own five-line ceiling is above that).
//
//  This suite measures the LAYOUT (= the frame SwiftUI hands the
//  compositor), because the band's height IS its laid-out height: the
//  surface is drawn over the frame the view hands up. The glass itself
//  does not PAINT offscreen (it needs a live compositor), but SwiftUI
//  lays it out identically headless, so the measurement is exact and
//  does not depend on a screenshot.
//
//  Method: `sizeThatFits(_:)` — SwiftUI's own answer to "how big do you
//  want to be at this width" — with a real proposed width, so a Text
//  that does not fit WRAPS (which is what makes a band grow).
//

import AppKit
import Foundation
import SwiftUI
import Testing
@testable import WenshuApp

@MainActor
@Suite("ChatSurfaceGeometry — the band and the field share one height rule")
struct ChatSurfaceGeometryTests {
    /// The height the view asks for at the given width.
    ///
    /// SwiftUI's own layout engine decides this: the view is hosted in
    /// a real `NSHostingView` and the height it asks for is read back
    /// as the host's `fittingSize`. Constraining the width FIRST
    /// (= `.frame(width:)`) is what makes the measurement meaningful:
    /// a `maxWidth: .infinity` view asked for its ideal size would
    /// never wrap, so a band whose text overflows would never grow.
    private func height(
        _ view: some View,
        width: CGFloat
    ) -> CGFloat {
        let hosting = NSHostingView(rootView: AnyView(view.frame(width: width)))
        hosting.layoutSubtreeIfNeeded()
        return hosting.fittingSize.height
    }

    /// The composer field, built exactly as `ChatInputBarView` builds it
    /// (= the same chain of modifiers, so the measurement is of the real
    /// geometry).
    private func composerField() -> some View {
        TextField("", text: .constant(""))
            .textFieldStyle(.plain)
            .padding(.leading, DesignTokens.spacingModerate)
            .frame(minHeight: DesignTokens.controlHeightLarge)
            .frame(maxWidth: .infinity)
    }

    /// The REAL outgoing band (= the production `ChatMessageView` with
    /// an outgoing message; = `isOutgoing` is `message.source == .user`).
    private func outgoingBand(_ text: String) -> some View {
        ChatMessageView(
            message: ChatMessage(role: .user, source: .user, content: text)
        )
    }

    @Test("The composer field rests at 36 PT")
    func composerFieldRestsAt36() {
        let h = height(composerField(), width: 400)
        #expect(abs(h - 36.0) <= 0.5,
                "The composer field must rest at 36 PT (= DesignTokens.controlHeightLarge); asked for \(h) PT")
    }

    @Test("A one-line outgoing band rests at the SAME height as the composer field")
    func oneLineBandMatchesComposerField() {
        let bandHeight = height(outgoingBand("你现在能查看资料库吗"), width: 400)
        let fieldHeight = height(composerField(), width: 400)

        #expect(abs(bandHeight - fieldHeight) <= 0.5,
                "A one-line outgoing band must rest at the composer field's height; band = \(bandHeight) PT, field = \(fieldHeight) PT")
    }

    @Test("A wrapped outgoing band grows past the resting height")
    func wrappedBandGrows() {
        let resting = height(outgoingBand("短消息"), width: 400)
        // A long message at a narrow width MUST wrap, so the band has to
        // be taller than its resting height.
        let grown = height(
            outgoingBand("你现在能查看资料库吗，看一下我们现在有哪些调研资料，然后把清单整理出来给我"),
            width: 160
        )

        #expect(resting > 0, "the one-line band must lay out")
        #expect(grown > resting + 8.0,
                "A band whose text wraps must grow past the resting height; resting = \(resting) PT, wrapped = \(grown) PT")
    }

    @Test("The band's resting height is the floor, not a fixed height")
    func bandUsesAFloorNotAFixedHeight() {
        // A band whose content is SHORTER than the floor still rests at
        // the floor (= the composer's height); one whose content is
        // TALLER is taller than the floor (= it grows).
        let short = height(outgoingBand("好"), width: 400)
        #expect(abs(short - 36.0) <= 0.5,
                "A short band must still rest at the 36 PT floor; asked for \(short) PT")

        let tall = height(
            outgoingBand("你现在能查看资料库吗，看一下我们现在有哪些调研资料，然后把清单整理出来给我"),
            width: 160
        )
        #expect(tall > 36.0,
                "A band whose text wraps must exceed the 36 PT floor; asked for \(tall) PT")
    }

    @Test("ChatSurfaceShape tracks half the height until the 36 PT cap")
    func shapeRadiusTracksHalfHeightUntilTheCap() {
        // This measures the composer field's own outline: the radius is
        // min(half the height, the 36 PT cap), so the shape rounds its ends
        // all the way (= a capsule) through 72 PT, and only a taller surface
        // stays a rounded rectangle (= the glyphs never spill out of a
        // degenerate ellipse).
        let shape = ChatSurfaceShape()
        let restingRect = CGRect(x: 0, y: 0, width: 400, height: 36)
        let grownRect = CGRect(x: 0, y: 0, width: 400, height: 72)
        let tallRect = CGRect(x: 0, y: 0, width: 400, height: 100)

        let resting = shape.path(in: restingRect)
        let grown = shape.path(in: grownRect)
        let tall = shape.path(in: tallRect)

        #expect(resting.boundingRect.height == restingRect.height,
                "The shape must fill the resting surface it outlines")
        #expect(grown.boundingRect.height == grownRect.height,
                "The shape must fill a grown surface too")

        // The radius, READ OFF THE SHAPE'S OWN PATH (= not a restatement
        // of the token): the shape's outline is the rounded rectangle
        // whose corner radius the path itself carries.
        #expect(radius(of: resting, in: restingRect) == 18,
                "A 36 PT surface must round its ends all the way (= a capsule); the shape reads \(radius(of: resting, in: restingRect)) PT")
        #expect(radius(of: grown, in: grownRect) == 36,
                "A 72 PT surface must still round its ends all the way (= a capsule); the shape reads \(radius(of: grown, in: grownRect)) PT")
        #expect(radius(of: tall, in: tallRect) == 36,
                "A surface past the cap must keep the 36 PT cap (= never an ellipse); the shape reads \(radius(of: tall, in: tallRect)) PT")
    }

    /// The corner radius a shape's path carries, read off that path.
    ///
    /// `Path` exposes no radius, so the reading walks the candidate radii
    /// and keeps the one whose rounded rectangle IS the path (= the
    /// shape's own answer, not a token restated).
    private func radius(of path: Path, in rect: CGRect) -> CGFloat? {
        var candidate: CGFloat = 0
        while candidate <= rect.height / 2 + 0.001 {
            if Path(roundedRect: rect, cornerRadius: candidate) == path {
                return candidate
            }
            candidate += 0.25
        }
        return nil
    }
}
