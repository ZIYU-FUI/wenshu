//
//  BoardViewportTests.swift
//  WenshuBoardTests
//
//  The viewport is the arithmetic of an infinite canvas, and it is the part
//  that can be proved without a window: a zoom that keeps the point under the
//  cursor under the cursor, a scale that clamps, a round trip that returns
//  where it started.
//

import CoreGraphics
import Testing

@testable import WenshuBoardKit

@Suite("Board viewport")
struct BoardViewportTests {

    // MARK: - The mapping

    @Test("An identity viewport maps a world point to the same screen point")
    func identityMapping() {
        let viewport = BoardViewport()
        let screen = viewport.screenPoint(for: CGPoint(x: 10, y: 20))
        #expect(screen == CGPoint(x: 10, y: 20))
    }

    @Test("The scale multiplies the world coordinate and the offset adds on top")
    func scaleAndOffset() {
        let viewport = BoardViewport(scale: 2, offset: CGPoint(x: 5, y: -5))
        let screen = viewport.screenPoint(for: CGPoint(x: 10, y: 20))
        #expect(screen == CGPoint(x: 25, y: 35))
    }

    @Test("The inverse mapping returns the world point it was given")
    func inverseRoundTrip() {
        let viewport = BoardViewport(scale: 1.75, offset: CGPoint(x: -33, y: 91))
        let world = CGPoint(x: 120, y: 480)
        let recovered = viewport.worldPoint(for: viewport.screenPoint(for: world))
        #expect(abs(recovered.x - world.x) < 0.0001)
        #expect(abs(recovered.y - world.y) < 0.0001)
    }

    // MARK: - Zooming

    @Test("A zoom keeps the world point under the anchor under the anchor")
    func zoomKeepsTheAnchorStill() {
        let viewport = BoardViewport(scale: 1, offset: CGPoint(x: 40, y: 60))
        let anchor = CGPoint(x: 300, y: 200)
        let worldUnderAnchor = viewport.worldPoint(for: anchor)

        let zoomed = viewport.zoomed(to: 2.5, about: anchor)

        let screenAfter = zoomed.screenPoint(for: worldUnderAnchor)
        #expect(abs(screenAfter.x - anchor.x) < 0.0001)
        #expect(abs(screenAfter.y - anchor.y) < 0.0001)
    }

    @Test("A zoom about the view centre is the same operation, about the centre")
    func zoomAboutTheCentre() {
        let viewport = BoardViewport(scale: 1)
        let centre = CGPoint(x: 500, y: 400)
        let worldUnderCentre = viewport.worldPoint(for: centre)
        let zoomed = viewport.zoomed(to: 2, about: centre)
        let screenAfter = zoomed.screenPoint(for: worldUnderCentre)
        #expect(abs(screenAfter.x - centre.x) < 0.0001)
        #expect(abs(screenAfter.y - centre.y) < 0.0001)
    }

    @Test("A zoom below the floor clamps to the floor")
    func zoomClampsLow() {
        let viewport = BoardViewport(scale: 1)
        let zoomed = viewport.zoomed(to: 0.01, about: .zero)
        #expect(zoomed.scale == BoardViewport.minimumScale)
    }

    @Test("A zoom above the ceiling clamps to the ceiling")
    func zoomClampsHigh() {
        let viewport = BoardViewport(scale: 1)
        let zoomed = viewport.zoomed(to: 99, about: .zero)
        #expect(zoomed.scale == BoardViewport.maximumScale)
    }

    @Test("A zoom to the current scale changes nothing")
    func zoomToTheSameScaleIsIdentity() {
        let viewport = BoardViewport(scale: 1.5, offset: CGPoint(x: 7, y: 9))
        #expect(viewport.zoomed(to: 1.5, about: CGPoint(x: 1, y: 1)) == viewport)
    }

    // MARK: - Panning

    @Test("A pan moves the world by the delta on the screen")
    func pan() {
        let viewport = BoardViewport(scale: 2, offset: .zero)
        let panned = viewport.panned(by: CGSize(width: 30, height: -12))
        let screen = panned.screenPoint(for: .zero)
        #expect(screen == CGPoint(x: 30, y: -12))
    }

    // MARK: - Culling

    @Test("The visible world rect is the screen rect pulled back into the world")
    func visibleWorldRect() {
        let viewport = BoardViewport(scale: 2, offset: CGPoint(x: 100, y: 50))
        let rect = viewport.visibleWorldRect(in: CGSize(width: 400, height: 200))
        #expect(abs(rect.minX - (-50)) < 0.0001)
        #expect(abs(rect.minY - (-25)) < 0.0001)
        #expect(abs(rect.width - 200) < 0.0001)
        #expect(abs(rect.height - 100) < 0.0001)
    }

    @Test("An item inside the visible rect is visible and one outside is not")
    func culling() {
        let viewport = BoardViewport(scale: 1)
        let size = CGSize(width: 400, height: 200)
        #expect(viewport.isVisible(CGRect(x: 10, y: 10, width: 50, height: 50), in: size))
        #expect(!viewport.isVisible(CGRect(x: 900, y: 900, width: 50, height: 50), in: size))
    }

    @Test("An item off screen comes back when the world is panned onto it")
    func cullingFollowsTheViewport() {
        let viewport = BoardViewport(scale: 1)
        let size = CGSize(width: 400, height: 200)
        let item = CGRect(x: 900, y: 900, width: 50, height: 50)
        #expect(!viewport.isVisible(item, in: size))
        let panned = viewport.panned(by: CGSize(width: -900, height: -900))
        #expect(panned.isVisible(item, in: size))
    }
}


@Suite("The canvas gestures")
struct CanvasGestureTests {

    @Test("A pan between two points moves the world by their difference")
    func panMovesByTheDifference() {
        let viewport = BoardViewport()
        let panned = viewport.panned(from: CGPoint(x: 100, y: 50), to: CGPoint(x: 130, y: 20))
        #expect(panned.offset == CGPoint(x: 30, y: -30))
    }

    @Test("A pan measured from the previous point does not accumulate")
    func panDoesNotAccumulate() {
        // The regression this pins: a viewport that ADDS its delta, fed a
        // displacement measured from the start of the gesture, re-sends the
        // first event's movement on every event, so the world runs away from
        // the cursor. Ten events of ten pixels must move the world by a
        // hundred pixels, not by five hundred and fifty.
        var viewport = BoardViewport()
        var previous = CGPoint(x: 0, y: 0)
        for step in 1...10 {
            let current = CGPoint(x: CGFloat(step * 10), y: 0)
            viewport = viewport.panned(from: previous, to: current)
            previous = current
        }
        #expect(viewport.offset == CGPoint(x: 100, y: 0))
    }

    @Test("A relative magnification multiplies the scale instead of replacing it")
    func relativeMagnificationMultiplies() {
        let viewport = BoardViewport(scale: 2)
        let zoomed = viewport.zoomed(by: 1.5, about: .zero)
        #expect(abs(zoomed.scale - 3.0) < 0.0001)
    }

    @Test("A relative magnification of one leaves the board where it was")
    func relativeMagnificationOfOneIsNoChange() {
        let viewport = BoardViewport(scale: 1.75, offset: CGPoint(x: 12, y: -8))
        let zoomed = viewport.zoomed(by: 1, about: CGPoint(x: 40, y: 40))
        #expect(zoomed == viewport)
    }

    @Test("A relative magnification keeps the world point under the anchor")
    func relativeMagnificationKeepsTheAnchor() {
        let viewport = BoardViewport(scale: 1.5, offset: CGPoint(x: 20, y: 10))
        let anchor = CGPoint(x: 300, y: 200)
        let worldBefore = viewport.worldPoint(for: anchor)
        let zoomed = viewport.zoomed(by: 1.2, about: anchor)
        let worldAfter = zoomed.worldPoint(for: anchor)
        #expect(abs(worldBefore.x - worldAfter.x) < 0.0001)
        #expect(abs(worldBefore.y - worldAfter.y) < 0.0001)
    }

    @Test("A pinch applied to the already-zoomed viewport would compound, and the base does not")
    func theBaseIsWhatTheMagnificationAppliesTo() {
        // The gesture's magnification is relative to the viewport the gesture
        // started from. Applying it twice to the current viewport would give
        // 1.5 x 1.5; applying it to the base gives 1.5.
        let base = BoardViewport(scale: 1)
        let once = base.zoomed(by: 1.5, about: .zero)
        let appliedToTheCurrent = once.zoomed(by: 1.5, about: .zero)
        #expect(abs(once.scale - 1.5) < 0.0001)
        #expect(abs(appliedToTheCurrent.scale - 2.25) < 0.0001)
    }
}
